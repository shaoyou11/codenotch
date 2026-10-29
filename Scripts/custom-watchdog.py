#!/usr/bin/env python3
"""Recover a missing scheduler run without retrying real build failures."""
from datetime import datetime, timezone, timedelta
import json
import os
import subprocess


def is_stale(runs, now, hours=4):
    # Check invocation times, not success times: a recent failed build needs
    # a fix, not another automatic retry. Queued/running jobs also count.
    times = [datetime.fromisoformat(r['created_at'].replace('Z', '+00:00')) for r in runs]
    return not times or now - max(times) > timedelta(hours=hours)


def main():
    repo = os.environ['GH_REPO']
    data = json.loads(subprocess.check_output([
        'gh', 'api', f'repos/{repo}/actions/workflows/custom-build.yml/runs',
        '--method', 'GET', '-f', 'branch=custom/compact-draggable', '-f', 'per_page=5']))
    if os.environ.get('WATCHDOG_FORCE') != 'true' and not is_stale(data['workflow_runs'], datetime.now(timezone.utc)):
        print('近期已有同步任务，无需补触发。')
        return
    # workflow_dispatch can be triggered by the repository token. Enable is
    # idempotent; it recovers a disabled primary entry without weakening tests.
    subprocess.run(['gh', 'workflow', 'enable', 'custom-build.yml', '--repo', repo], check=True)
    subprocess.run(['gh', 'workflow', 'run', 'custom-build.yml', '--repo', repo, '--ref', 'main'],
                   check=True, stdout=subprocess.DEVNULL)
    print('已补触发主调度入口；仍执行合并、测试和签名检查。')


if __name__ == '__main__':
    main()
