# CodenotchT

基于上游 Codenotch 1.6.0 的独立定制版。本地目录：`~/Documents/Xcode/codenotch`。

## 外观和操作

- 在「设置 → 外观 → 整体大小」选择 50%～125%，默认 70%，立即生效并保存；详情文字保留最小可读字号，收起胶囊和真实硬件刘海不随比例缩放。
- 胶囊展开后，首次连续悬停同一图标约 2 秒显示详情；移开或换图标重新计时，首次显示后及固定展开时无需等待。
- 在「设置 → 外观 → 图标下方百分比」切换已用／剩余，选择自动保存；圆环仍表示已用额度。
- 收起为 10×40 pt、72% 不透明度的黑色胶囊，悬停展开。
- 设置页面、菜单操作和首次更新介绍使用中文；第三方返回的原始诊断、模型名称可能保留原文。
- 保留上游 Option（⌥）＋拖动及位置记忆，沿当前屏幕边缘移动。
- 定制版停止官方自动更新，防止个人功能被覆盖。

## 与官方版共存

应用为 `CodenotchT.app`，标识为 `com.shaoyou11.codenotcht`；官方版保留 `Codenotch.app` 及其原标识。
首次运行可复制原版已有偏好，后续分别保存；登录项和应用配置独立。二者仍读取同一批工具的已登录账号。

下次更新先备份被替换的版本。构建脚本只生成安装包，不安装应用、不删除文件。

## 构建与下载

```sh
bash Scripts/custom-build.sh
```

成品：`build/custom/CodenotchT-<上游版本号>.zip`。解压后把 `CodenotchT.app` 放进「应用程序」。

正式下载入口在个人仓库的 Releases。现在由 GitHub Actions 自动同步、测试、编译并发布，无需本机开机或安装 Xcode。

- 每天北京时间 09:23 检查上游 main（GitHub 调度可能延迟）；推送定制分支或在 Actions 手动运行也会触发。
- 无新代码且已有对应正式 Release 时跳过编译。版本号从 project.yml 读取，发布标签附带源码提交号，区分同版本的多次定制。
- 合并冲突、测试失败、编译失败时停止；通过验证后才保存合并结果，资产上传完成后才公开 Release。修复失败原因后可手动重新运行。
- Actions 产物保留 30 天，正式 Release 安装包长期保留。失败记录在 Actions 查看，通知取决于 GitHub 个人通知设置。
- 仍需自行下载、备份旧版并安装；这不是应用内自动更新。
- GitHub 对长期无活动的公共仓库可能暂停定时任务，届时在 Actions 重新启用。


使用本地临时签名，无需付费开发者账号，未做 Apple 公证。自用构建关闭该应用的 Hardened Runtime 以兼容内嵌组件签名，不改变系统安全设置。

## 同步上游

`origin` 是自己的 fork，`upstream` 是原作者仓库；`main` 保留上游代码及定时工作流入口，个人修改位于 `custom/compact-draggable`。

日常无需运行以下命令；如需本机手动同步，先拉取云端已验证的定制分支：

```sh
git pull --ff-only origin custom/compact-draggable
bash Scripts/custom-sync.sh
bash Scripts/custom-build.sh
git push origin HEAD
```

冲突时停止，不自动覆盖。上游支持所需功能后，可退出 CodenotchT，改用官方 Codenotch；无需删除账号资料。
