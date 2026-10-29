import importlib.util
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


merge = load('custom_merge', 'custom-merge.py')
release = load('custom_release', 'custom-release-needed.py')
watchdog = load('custom_watchdog', 'custom-watchdog.py')


def cat(strings):
    return json.dumps({'sourceLanguage': 'en', 'strings': strings, 'version': '1.0'})


def translation(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


class MergeTests(unittest.TestCase):
    def test_independent_catalog_edits_and_reordered_keys(self):
        base = cat({'a': {}, 'b': {}})
        ours = cat({'b': {}, 'a': {}, 'personal': {'comment': '中文'}})
        theirs = cat({'a': {}, 'b': {}, 'new': {'comment': 'upstream'}})
        merged = json.loads(merge.catalog(base, ours, theirs))['strings']
        self.assertEqual(set(merged), {'a', 'b', 'personal', 'new'})

    def test_chinese_override_and_new_upstream_language_both_survive(self):
        b = {'localizations': {'zh-Hans': translation('旧文案')}}
        o = {'localizations': {'zh-Hans': translation('个人文案')}}
        t = {'localizations': {'zh-Hans': translation('上游文案'), 'ja': translation('新規')}}
        merged = json.loads(merge.catalog(cat({'a': b}), cat({'a': o}), cat({'a': t})))
        self.assertEqual(merged['strings']['a']['localizations'], o['localizations'] | {'ja': translation('新規')})

    def test_unknown_semantic_collision_stops(self):
        with self.assertRaises(merge.Conflict):
            merge.catalog(cat({'a': {'comment': 'base'}}), cat({'a': {'comment': 'ours'}}), cat({'a': {'comment': 'theirs'}}))

    def test_upstream_deletion_of_unchanged_entry_is_respected(self):
        b = cat({'old': {}, 'keep': {}})
        self.assertNotIn('old', json.loads(merge.catalog(b, b, cat({'keep': {}})))['strings'])

    def test_build_counter_does_not_block_new_version_or_dependencies(self):
        b = 'settings:\n  CURRENT_PROJECT_VERSION: "24"\n  MARKETING_VERSION: "1.22.0"\ndependency: old\n'
        o = b.replace('"24"', '"38"')
        t = b.replace('"24"', '"25"').replace('1.22.0', '1.23.0').replace('dependency: old', 'dependency: new')
        result = merge.project(b, o, t)
        self.assertIn('CURRENT_PROJECT_VERSION: "38"', result)
        self.assertIn('MARKETING_VERSION: "1.23.0"', result)
        self.assertIn('dependency: new', result)

    def test_other_project_collision_is_never_forced(self):
        b = 'CURRENT_PROJECT_VERSION: "24"\nidentity: base\n'
        with self.assertRaises(merge.Conflict):
            merge.project(b, b.replace('base', 'personal'), b.replace('base', 'upstream'))

    def test_historical_123_catalog_and_build_conflicts_resolve(self):
        # A real upgrade that stopped the old workflow, without checking out,
        # modifying or deleting anything in the user's active source tree.
        def read(ref, path):
            return subprocess.check_output(['git', 'show', ref + ':' + path], cwd=ROOT, text=True)
        own = '948379bbbb7ad5d2239cc34cdadb24ddebee904a'
        upstream = '9e7cd3d48673'
        ancestor = subprocess.check_output(['git', 'merge-base', own, upstream], cwd=ROOT, text=True).strip()
        path = 'Sources/Localizable.xcstrings'
        result = json.loads(merge.catalog(read(ancestor, path), read(own, path), read(upstream, path)))
        old = json.loads(read(own, path))
        for key in ['Lifetime tokens', '30-day tokens']:
            self.assertEqual(result['strings'][key]['localizations']['zh-Hans'], old['strings'][key]['localizations']['zh-Hans'])
        self.assertIn('Working indicator', result['strings'])
        p = merge.project(read(ancestor, 'project.yml'), read(own, 'project.yml'), read(upstream, 'project.yml'))
        self.assertIn('MARKETING_VERSION: "1.23.0"', p)
        self.assertIn('CURRENT_PROJECT_VERSION: "38"', p)
        self.assertIn('com.shaoyou11.codenotcht', p)

    def test_git_uses_driver_and_does_not_resolve_swift_conflicts(self):
        root = Path(tempfile.mkdtemp(prefix='codenotcht-git-test-'))
        def git(*args, check=True):
            return subprocess.run(['git', *args], cwd=root, capture_output=True, text=True, check=check)
        git('init', '-b', 'personal')
        git('config', 'user.name', 'shaoyou11')
        git('config', 'user.email', 'shaoyou11@users.noreply.github.com')
        (root / '.gitattributes').write_text('catalog.json merge=codenotcht-catalog\n')
        git('config', 'merge.codenotcht-catalog.driver', f'python3 "{ROOT / "Scripts/custom-merge.py"}" catalog "%O" "%A" "%B"')
        (root / 'catalog.json').write_text(cat({'base': {}}))
        (root / 'UI.swift').write_text('let behavior = "base"\n')
        git('add', '.'); git('commit', '-m', '测试：基线')
        git('branch', 'upstream')
        (root / 'catalog.json').write_text(cat({'base': {}, 'personal': {}}))
        (root / 'UI.swift').write_text('let behavior = "personal"\n')
        git('add', '.'); git('commit', '-m', '测试：个人定制')
        git('checkout', 'upstream')
        (root / 'catalog.json').write_text(cat({'base': {}, 'upstream': {}}))
        (root / 'UI.swift').write_text('let behavior = "upstream"\n')
        git('add', '.'); git('commit', '-m', '测试：上游更新')
        git('checkout', 'personal')
        outcome = git('merge', 'upstream', check=False)
        self.assertNotEqual(outcome.returncode, 0)
        self.assertEqual(git('diff', '--name-only', '--diff-filter=U').stdout.strip(), 'UI.swift')
        self.assertEqual(set(json.loads((root / 'catalog.json').read_text())['strings']), {'base', 'personal', 'upstream'})


class ReleaseTests(unittest.TestCase):
    def test_only_automation_or_documentation_can_skip(self):
        for p in ['CUSTOM.md', '.github/workflows/custom-build.yml', 'docs/readme.md', 'Scripts/custom-merge.py', 'Scripts/custom-scheduler.yml']:
            self.assertFalse(release.affects_app(p), p)
        for p in ['Sources/App/Updater.swift', 'Tests/LocalizationTests.swift', 'project.yml', 'Makefile', 'Package.resolved', 'Scripts/custom-build.sh', 'Scripts/personal-appcast.py', 'new-build-input']:
            self.assertTrue(release.affects_app(p), p)

    def test_existing_release_skips_only_non_app_changes(self):
        releases = [{'tagName': 'codenotcht-v1.23.0-existing', 'isDraft': False}]
        docs = subprocess.CompletedProcess([], 0, 'CUSTOM.md\n.github/workflows/custom-build.yml\nScripts/custom-scheduler.yml\n', '')
        app = subprocess.CompletedProcess([], 0, 'Sources/Notch/NotchViewModel.swift\n', '')
        with patch.object(release.subprocess, 'run', return_value=docs):
            self.assertFalse(release.needed(releases))
        with patch.object(release.subprocess, 'run', return_value=app):
            self.assertTrue(release.needed(releases))

    def test_missing_release_builds(self):
        self.assertTrue(release.needed([]))

    def test_missing_tag_builds_rather_than_skipping(self):
        self.assertTrue(release.needed([{'tagName': 'codenotcht-missing', 'isDraft': False}]))


class WatchdogTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 29, 8, 0, tzinfo=timezone.utc)

    def run_at(self, hours, status="completed", conclusion="success"):
        return {'created_at': (self.now - timedelta(hours=hours)).isoformat(),
                'status': status, 'conclusion': conclusion}

    def test_no_history_recovers(self):
        self.assertTrue(watchdog.is_stale([], self.now))

    def test_four_hour_gap_recovers(self):
        self.assertTrue(watchdog.is_stale([self.run_at(5)], self.now))

    def test_recent_success_or_queued_build_is_not_duplicated(self):
        for status in ['queued', 'in_progress', 'completed']:
            self.assertFalse(watchdog.is_stale([self.run_at(1, status)], self.now))

    def test_real_failure_is_not_retried_repeatedly(self):
        self.assertFalse(watchdog.is_stale([self.run_at(1, conclusion="failure")], self.now))

    def test_newest_time_wins_independent_of_api_order(self):
        self.assertFalse(watchdog.is_stale([self.run_at(8), self.run_at(1)], self.now))


if __name__ == '__main__':
    unittest.main()
