<div align="center">

<img src="icon1024.png" width="128" alt="TextGrab">

# TextGrab

**按一下快捷键，框选屏幕，文字就在剪贴板里了。**

一个轻量的 macOS 菜单栏 OCR 工具，完全本地识别，不联网、不收集任何数据。

[![Release](https://img.shields.io/github/v/release/245678000000/TextGrab?style=flat-square&color=dc3826)](https://github.com/245678000000/TextGrab/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-13%2B-1c1a1a?style=flat-square&logo=apple)](https://github.com/245678000000/TextGrab/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-single%20file-f05138?style=flat-square&logo=swift&logoColor=white)](main.swift)
[![License](https://img.shields.io/badge/license-MIT-3d7a4f?style=flat-square)](LICENSE)

[**下载最新版**](https://github.com/245678000000/TextGrab/releases/latest) · [使用方法](#使用方法) · [从源码构建](#从源码构建)

</div>

---

## 特性

| | |
|---|---|
| ⌨️ **一键识别** | 按 `⇧⌘2` 框选任意区域，结果自动复制，`⌘V` 直接粘贴 |
| 🔒 **完全离线** | 基于 Apple Vision 框架，图片不离开你的电脑 |
| 🀄 **中英混排** | 简体中文、繁体中文、英文同时识别 |
| 🔳 **二维码 / 条形码** | 框住码即可读出内容 |
| ↩️ **换行可选** | 保留原始换行，或合并成一段（中文之间不插空格） |
| 🪶 **小而轻** | 单个 Swift 文件，安装包不到 400 KB，常驻菜单栏 |

## 安装

1. 从 [Releases](https://github.com/245678000000/TextGrab/releases/latest) 下载 `TextGrab-x.x.zip`
2. 解压，把 `TextGrab.app` 拖进「应用程序」
3. 首次打开：应用未经 Apple 公证，会被系统拦截。**右键 → 打开** 即可，或在终端执行：
   ```sh
   xattr -cr /Applications/TextGrab.app
   ```
4. 在 **系统设置 → 隐私与安全性 → 屏幕录制** 中允许 TextGrab，然后重新打开应用

> 支持 macOS 13 Ventura 及以上，Apple Silicon 与 Intel 通用。

## 使用方法

| 操作 | 说明 |
|---|---|
| `⇧⌘2` | 开始框选，松开鼠标即识别并复制 |
| `Esc` | 取消框选 |
| 菜单栏图标 | 切换「保留换行」「开机启动」，或退出 |

识别成功时屏幕底部会短暂出现「✓ 已复制」。

## 常见问题

<details>
<summary><b>框选后提示「未识别到文字」？</b></summary>

先确认已授予屏幕录制权限——未授权时截图只有桌面壁纸。若授权后仍出现，请查看 `~/Library/Logs/TextGrab.log` 并提 Issue。
</details>

<details>
<summary><b>第一次识别比较慢？</b></summary>

macOS 需要加载识别模型。TextGrab 启动时会在后台预热，开启「开机启动」后基本感觉不到。
</details>

<details>
<summary><b>快捷键没反应？</b></summary>

可能被其他应用占用（例如同样使用 `⇧⌘2` 的截图/OCR 工具），请关闭冲突的应用后重启 TextGrab。
</details>

## 从源码构建

只需要 Xcode Command Line Tools，无需打开 Xcode。

```sh
git clone https://github.com/245678000000/TextGrab.git
cd TextGrab
./build.sh            # 编译并安装到 ~/Applications/TextGrab.app
```

> **提示：** 默认使用临时签名，每次重新编译后都需要重新授权屏幕录制。
> 用固定证书签名可以避免：`SIGN_ID=<证书 SHA1> ./build.sh`
> （查看可用证书：`security find-identity -v -p codesigning`）

### 项目结构

```
main.swift       全部源码：菜单栏、全局快捷键、截图、识别、提示浮窗
makeicon.swift   用代码绘制应用图标
build.sh         编译 → 打包 .app → 签名 → 安装
```

## 许可证

[MIT](LICENSE) © 2026
