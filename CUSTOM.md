# CodenotchT

基于上游 Codenotch 1.6.0 的独立定制版。本地目录：`~/Documents/Xcode/codenotch`。

## 外观和操作

- 展开面板为上游尺寸的 75%；详情文字至少 11 pt，提示卡片宽度至少 220 pt。
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

成品：`build/custom/CodenotchT-1.6.0.zip`。解压后把 `CodenotchT.app` 放进「应用程序」。

正式下载入口在个人仓库的 Releases。推送定制分支会触发 GitHub Actions 云端编译，其 Artifacts 保留 30 天；Releases 安装包另行发布。两者都不是应用内自动更新。

使用本地临时签名，无需付费开发者账号，未做 Apple 公证。自用构建关闭该应用的 Hardened Runtime 以兼容内嵌组件签名，不改变系统安全设置。

## 同步上游

`origin` 是自己的 fork，`upstream` 是原作者仓库；`main` 保留上游基线，个人修改位于 `custom/compact-draggable`。

```sh
bash Scripts/custom-sync.sh
bash Scripts/custom-build.sh
git push origin HEAD
```

冲突时停止，不自动覆盖。上游支持所需功能后，可退出 CodenotchT，改用官方 Codenotch；无需删除账号资料。
