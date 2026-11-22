# TextGrab

macOS 菜单栏小工具：按快捷键框选屏幕区域，自动识别文字并复制到剪贴板。

- 快捷键 **⇧⌘2**，框选后识别结果直接进剪贴板
- 基于 Apple Vision 本地识别，不联网；支持简体中文、繁体中文、英文
- 识别二维码 / 条形码
- 可选「保留换行」或合并为一段（中文之间不加空格）
- 支持开机启动

## 构建

需要 Xcode Command Line Tools（macOS 13+，Apple Silicon）。

```sh
./build.sh                    # 编译并安装到 ~/Applications/TextGrab.app
SIGN_ID=<证书SHA1> ./build.sh  # 用固定证书签名，重新编译后无需再次授权屏幕录制
```

首次运行需要在 **系统设置 → 隐私与安全性 → 屏幕录制** 中允许 TextGrab。

## 文件

- `main.swift` — 全部源码
- `makeicon.swift` — 生成应用图标（`icon1024.png` → `AppIcon.icns`）
- `build.sh` — 编译、打包、签名、安装

日志：`~/Library/Logs/TextGrab.log`
