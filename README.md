# 君圣截图 · Windows 成品

本仓库是**公开成品仓库**：只放可直接运行的程序与官网页面，源码另行维护。官网由仓库 `docs/` 目录通过 GitHub Pages 托管，下载地址 `https://xianguigit.github.io/junsheng-screenshot/`。

## 下载与运行

官网首页的「下载」按钮会自动扫描本仓库根目录与 `历史/` 里的 exe，取最新版本号，下载走 `raw.githubusercontent.com` 直链；也可以直接在仓库根目录点开 `君圣截图-vX.Y.Z.exe` 下载。版本号与软件「关于」里显示的一致。

**以后发版不用发 Release、不用改页面**：把新的 `君圣截图-vX.Y.Z.exe` 推到仓库根目录，官网会自动更新版本号、体积和版本历史。如果另外发了带 exe 附件的 Release，官网也会优先采用它。

如果双击没反应，用附带的 `启动君圣截图.bat` 启动（脚本会带上正确的启动参数）。

**无需安装，无需 .NET / VC++ 运行库。** 系统要求 Windows 10 / 11（依赖系统自带 WebView2 与 Media Foundation）。

## 功能

- 区域截图 + 标注（矩形、箭头、画笔、文字、马赛克）
- 贴图钉在桌面最上层
- 屏幕录制（MP4）、GIF 导出
- 可选录制鼠标指针
- 全局快捷键、托盘常驻

## 文件说明

```
君圣截图-vX.Y.Z.exe    主程序（当前版本，官网从这里取）
启动君圣截图.bat        启动脚本（自动指向当前版本）
历史/                   旧版本归档，只保留最近 3 个版本号
docs/index.html         官网单页（GitHub Pages 从 main /docs 发布）
```

每次出包会自动把上一版收进 `历史/`，更旧的移到工作区回收站，不会直接删。

## 官网配置

仓库 Settings → Pages → Build and deployment：Source 选 `Deploy from a branch`，Branch 选 `main`、目录选 `/docs`。仓库需为 **Public**，否则匿名读不到文件列表、下载直链也会被拦。页面里要换仓库只改 `docs/index.html` 顶部的 `REPO` / `BRANCH` 两个常量。

## 数据目录

程序首次运行会在同目录生成 `data/`，存放：

- `settings.json` 配置（含截图保存路径、快捷键）
- `debug.log` 运行日志（仅 `JSHENG_DEBUG=1` 时产生）
- `webview2/` 界面缓存
- `screenshots/`、临时录像

**`data/` 不会随仓库分发**（已在 `.gitignore` 中），删掉不影响使用，下次启动会重建。

## 注意

- 截图保存路径是**绝对路径**，如果你把程序换了个目录，记得在设置里重新选一次，否则会存到不存在的路径。
- 录屏依赖显卡编码器，独显 / 集显都能用；极少数老机器上会回退到软件编码，CPU 占用会高一些。

## 许可

未声明开源许可证，默认保留所有权利。
