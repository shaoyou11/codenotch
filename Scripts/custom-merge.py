#!/usr/bin/env python3
"""Deterministic merge drivers for personal build metadata and translations.

No whole-file ours/theirs fallback: code conflicts stay unresolved. Only the
personal build counter and overlapping Simplified Chinese translations have
an explicit preference, so other upstream changes remain visible.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

MISSING = object()


class Conflict(Exception):
    pass


def merge_value(base, ours, theirs, path=()):
    if ours == theirs:
        return ours
    if ours == base:
        return theirs
    if theirs == base:
        return ours
    # The personal Chinese wording is deliberate. Other locales and catalog
    # metadata use a true three-way merge, failing on a semantic collision.
    if 'zh-Hans' in path and ours is not MISSING:
        return ours
    if all(isinstance(x, dict) or x is MISSING for x in (base, ours, theirs)):
        if ours is MISSING or theirs is MISSING:
            raise Conflict('/'.join(path))
        b = {} if base is MISSING else base
        result = {}
        for key in dict.fromkeys([*theirs, *ours, *b]):
            value = merge_value(b.get(key, MISSING), ours.get(key, MISSING),
                                theirs.get(key, MISSING), path + (key,))
            if value is not MISSING:
                result[key] = value
        return result
    raise Conflict('/'.join(path))


def catalog(base, ours, theirs):
    result = merge_value(json.loads(base), json.loads(ours), json.loads(theirs))
    return json.dumps(result, ensure_ascii=False, indent=2) + '\n'


BUILD = re.compile(r'(?m)^(\s*CURRENT_PROJECT_VERSION:\s*)"(\d+)"(\s*)$')


def project(base, ours, theirs):
    numbers = [BUILD.findall(text) for text in (base, ours, theirs)]
    if any(len(matches) != 1 for matches in numbers):
        raise Conflict('project.yml/CURRENT_PROJECT_VERSION schema changed')
    own_number = numbers[1][0][1]
    # Ignore only the counter while merging. Version, dependencies, build
    # settings, identity and every other line still use Git's three-way merge.
    directory = Path(tempfile.mkdtemp(prefix='codenotcht-merge-'))
    paths = []
    for name, text in zip(('base', 'ours', 'theirs'), (base, ours, theirs)):
        p = directory / name
        p.write_text(BUILD.sub(lambda m: m[1] + '"0"' + m[3], text))
        paths.append(str(p))
    run = subprocess.run(['git', 'merge-file', '-p', '--diff3', '-L', 'personal',
                          '-L', 'base', '-L', 'upstream', paths[1], paths[0], paths[2]],
                         text=True, capture_output=True)
    # Leave the small diagnostic files in the OS temporary directory.
    if run.returncode != 0:
        raise Conflict('project.yml has changes beyond the build counter')
    return BUILD.sub(lambda m: m[1] + '"' + own_number + '"' + m[3], run.stdout)


def configure():
    for kind in ('catalog', 'project'):
        subprocess.run(['git', 'config', '--local', f'merge.codenotcht-{kind}.name',
                        f'CodenotchT {kind} three-way merge'], check=True)
        subprocess.run(['git', 'config', '--local', f'merge.codenotcht-{kind}.driver',
                        f'python3 Scripts/custom-merge.py {kind} "%O" "%A" "%B"'], check=True)


def main():
    if sys.argv[1:] == ['configure']:
        configure()
        return 0
    kind, base, ours, theirs = sys.argv[1:]
    try:
        result = {'catalog': catalog, 'project': project}[kind](
            Path(base).read_text(), Path(ours).read_text(), Path(theirs).read_text())
        Path(ours).write_text(result)
        return 0
    except (Conflict, ValueError, KeyError) as error:
        print(f'个人版合并停止：{error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
