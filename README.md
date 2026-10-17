# 📸 晾图架 · ClipLine

**先晾起来，需要时再一起收下。**

macOS 上的小型可视化截图与文字暂存架：截图像照片一样被衣夹挂起，文字像便签一样被晾起。全部收集完成后，再一次拖入聊天框、复制文字或导出文件，不必在来源页面和目标窗口之间反复切换。

> **状态：V0.1 原生 macOS MVP。** 本仓库包含真实 SwiftUI/AppKit 实现，不只是概念图。只支持 **macOS 13+**；Windows、Linux 和手机不支持运行桌面 App。

## ✨ 当前功能

- ✅ 监听新建的桌面截图文件（常见中文、英文系统截图文件名）；也可自定义监听文件夹
- ✅ 识别剪贴板中的图片并自动加入暂存架
- ✅ 可选自动捕获复制的文字；**默认关闭，防止无意保存敏感文字**
- ✅ SwiftUI 悬浮式窗口、晾衣绳卡片、图片缩略图、文字便签、勾选与取下
- ✅ 拖动蓝色的 **「拖出 N 张图片」** 区域，把多张图片一次拖入兼容多文件上传的应用
- ✅ 复制多张图片的文件引用（目标软件需支持文件粘贴）；合并复制文字；按时间顺序导出图片与 `.txt` 文档到 Finder
- ✅ 本地 JSON 索引、图片文件持久化；菜单栏快捷打开和暂停收集
- ✅ 自动保留最近 80 项，可一键清空本地副本

## 📥 在 Mac 上安装

### 方法一：GitHub Actions（不用配 Xcode 工程）

1. 打开仓库的 **Actions → macOS build**，等待 workflow 成功（只有 Mac runner 才能编译运行原生 App）。
2. 在运行记录的 **Artifacts** 里下载 `ClipLine-macos`。
3. 解压后将 `ClipLine.app` 放到 **应用程序** 文件夹，打开即可。
4. 这是开发版的临时签名应用，没有 Apple Developer ID 公证。macOS 可能要求你在「系统设置 → 隐私与安全性」中手动允许打开。只运行你信任的构建。

### 方法二：Mac 终端构建

确保安装 Xcode Command Line Tools，Swift 5.9+：

```bash
git clone https://github.com/asdffgdghdfh-art/clipline.git
cd clipline
swift test
bash scripts/build_app.sh
open dist/ClipLine.app
```

> 如果代码尚在 `feat/macos-mvp` 分支，请先运行 `git switch feat/macos-mvp`，或直接从 Pull Request 的 Actions 下载构建产物。

## 🪢 怎么用

1. **打开 ClipLine**。它会显示桌面悬浮晾衣绳窗口，关闭窗口后仍可从 Mac 菜单栏再次打开。
2. 在网页里按 **⇧⌘4** 截图：当系统把新截图保存到桌面时，ClipLine 会自动添加缩略图。若截图存储路径不同，在「ClipLine → 设置」中更改监听文件夹。
3. 使用 **⌃⇧⌘4** 把截图直接复制到剪贴板，ClipLine 也能捕获图片。你也可以点击「添加图片」手动批量导入。
4. 复制文字要先在设置中启用 **「自动收集复制的文字」**；也可以点「文字便签」手动添加，或者把文字拖入窗口。
5. 点击卡片可以选择/取消选择。所有内容收集完后：
   - **批量传图**：按住蓝色「拖出 N 张图片」区域，拖到 ChatGPT、邮件等支持一次接受多文件的上传区域；
   - **复制图片文件**：复制多张图片文件引用，再到支持文件粘贴的目标应用按 ⌘V；
   - **复制文字**：把选中的多段文本合并到剪贴板；
   - **导出全部**：把选中的图片和文字分别保存到一个目录，然后从 Finder 拖出。

## ⚠️ MVP 边界（不夸大能力）

- **不保证所有第三方聊天框都支持“一次粘贴多图+文字”**。macOS 和网页对文件粘贴/拖放的处理各不相同。当前最稳妥的操作是 **多图同时拖入 + 文字单独复制**。未做未经用户授权的模拟键盘输入。
- 晾衣绳窗口默认是普通桌面窗口，**尚未实现真正贴在所有应用上方的可折叠桌面悬浮条**；这将是 V0.2 的重点。
- 截图目录检测目前采用 **每秒轮询 + 常见截图前缀识别**，不是系统级截图事件；Mac 更改了截图文件名或者截图文件夹时，需要在设置调整，或者手动导入。
- 初次访问桌面文件夹可能触发 macOS 的隐私访问授权。未授权时请在系统设置允许 ClipLine 访问相关文件。
- 文字自动收集默认关闭，暂时不支持排除特定 App、敏感字段检测、快捷键自定义或 OCR。

## 🔒 数据与隐私

全部数据都在本机：`~/Library/Application Support/ClipLine/`（`records.json` + `images/`）。没有账号、云同步、遥测或外部 API。点击清空只删除 ClipLine 保存的副本，不会影响桌面原图。启用自动复制文字时，请注意密码、验证码和个人信息也可能进入暂存；遇到敏感任务请点击 **暂停收集**。

## 🧱 技术架构

```text
SwiftUI window / macOS MenuBarExtra
          |
          v
     ClipStore (@MainActor)
        /          \
NSPasteboard       Screenshot folder polling
   image/text      ⇧⌘3 / ⇧⌘4 saved files
        \          /
       JSON + local PNG
             |
       NSDraggingSession
       multiple file URLs
```

- macOS 13+ / Swift 5.9 / SwiftUI / AppKit / UniformTypeIdentifiers
- Swift Package Manager，无第三方依赖
- `scripts/build_app.sh` 把 Swift 可执行文件打包成可打开的 `.app`
- `.github/workflows/macos-build.yml` 自动编译、测试、打包构建产物

## 🗺️ Roadmap

| 版本 | 目标 | 进度 |
| --- | --- | --- |
| V0.1 | 真实截图与文字收集、桌面晾衣绳、批量拖图、导出 | 开发版 |
| V0.2 | 贴边自动折叠浮窗、全局快捷键、拖拽排序、文件监视改用 FSEvents | 待开发 |
| V0.3 | 可选分组、排除 App/敏感信息、OCR、更多目标应用兼容 | 待开发 |

欢迎通过 Issues 反馈 macOS 版本、截图命名格式、目标聊天应用和操作问题。
