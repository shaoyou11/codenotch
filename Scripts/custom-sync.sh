#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(git branch --show-current)" = custom/compact-draggable ] || {
  echo '请先切换到 custom/compact-draggable 分支。'; exit 1;
}
[ -z "$(git status --porcelain)" ] || {
  echo '工作区有未提交修改，请先处理后再同步。'; exit 1;
}
git fetch upstream
# Stop at any conflict; never overwrite custom changes or force-push.
git merge -m '同步：合并上游 main 更新并保留个人定制' upstream/main
printf '%s\n' '上游已合并。运行 bash Scripts/custom-build.sh 验证，再 git push origin HEAD。'
