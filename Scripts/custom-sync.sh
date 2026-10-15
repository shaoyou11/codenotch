#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(git branch --show-current)" = custom/compact-draggable ] || {
  echo '请先切换到 custom/compact-draggable 分支。'; exit 1;
}
[ -z "$(git status --porcelain)" ] || {
  echo '工作区有未提交修改，请先处理后再同步。'; exit 1;
}
python3 Scripts/custom-merge.py configure
git fetch upstream
# Resolve catalog/build-counter conflicts structurally; stop on code conflicts.
git -c merge.renormalize=true merge -m '同步：合并上游 main 更新并保留个人定制' upstream/main
printf '%s\n' '上游已合并。运行 bash Scripts/custom-build.sh 验证，再 git push origin HEAD。'
