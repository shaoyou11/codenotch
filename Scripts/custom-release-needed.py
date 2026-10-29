#!/usr/bin/env python3
"""Skip documentation/automation-only commits, not application inputs."""
import json
import subprocess
import sys

# Include the complete source, tests, project settings, dependency lock and
# packaging inputs. Unknown root inputs fail open (build), never skip silently.
IGNORED_PREFIXES = ('.github/', 'docs/', 'site/', 'windows/')
IGNORED_FILES = {'.gitattributes', '.gitignore', 'CUSTOM.md', 'README.md',
                 'CONTRIBUTING.md', 'LICENSE', 'TASKS.md',
                 'Scripts/custom-merge.py', 'Scripts/custom-release-needed.py',
                 'Scripts/custom-sync.sh', 'Scripts/custom-scheduler.yml',
                 'Scripts/custom-watchdog.py', 'Scripts/custom-watchdog.yml'}


def affects_app(path):
    return not (path in IGNORED_FILES or path.startswith(IGNORED_PREFIXES)
                or path.startswith('Scripts/custom_tests/'))


def needed(releases):
    personal = next((r for r in releases if not r.get('isDraft')
                     and r['tagName'].startswith('codenotcht-')), None)
    if personal is None:
        return True
    tag = personal['tagName']
    # A tag missing locally (or an unexpected Git error) must cause a build.
    result = subprocess.run(['git', 'diff', '--name-only', f'{tag}^{{commit}}', 'HEAD'],
                            capture_output=True, text=True)
    if result.returncode:
        return True
    return any(affects_app(p) for p in result.stdout.splitlines())


if __name__ == '__main__':
    print('true' if needed(json.load(open(sys.argv[1]))) else 'false')
