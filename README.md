# 
<p align="center">
<img src="./QuickRecorder/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="200" height="200" />
<h1 align="center">QuickRecorder</h1>
<h3 align="center">多功能、轻量化、高性能的 macOS 屏幕录制工具<br><a href="./README_en.md">[English Version]</a> 
</p>

## 运行截图
<p align="center">
<img src="./img/preview.png" width="699"/> 
</p>

## 安装与使用
### 系统版本要求:
- macOS 13.0 及更高版本  

### 安装:
可[点此前往](../../releases/latest)下载最新版安装文件. 或使用homebrew安装:  

```bash
brew install lihaoyun6/tap/quickrecorder
```

### 特色 / 使用:
- 使用 SwiftUI 编写, 体积小巧轻量化. 软件大小仅 4MB 左右, 无任何累赘功能. 

- 支持 ScreenCapture Kit 诸多特性: 单/多窗口追踪录制, App 录制, 最高 240FPS 等.  
- QuickRecorder 启动后直接显示主功能面板, 关闭后可以点击 Dock 栏图标再次呼出. 
- 开始录制后 QuickRecorder 会在菜单栏显示录制指示器, 可随时暂停或查看录制时长.  
- 更多功能陆续开发中...  

## 常见问题
**1. 主面板关闭之后在哪里重新打开?**  
> 单击 QuickRecorder 的 Dock 栏图标即可随时重新呼出主功能面板.  

**2. 为什么 QuickRecorder 不是沙盒 App?**  
> 苹果沙盒权限管理机制比较复杂, 使用起来麻烦. 加之 QuickRecorder 并没有上架 App Store的打算, 故没有做成沙盒 App.

**3. 为什么开启了"录制麦克风", 视频里却听不到我讲话的声音?**
> QuickRecorder 默认会将麦克风输入的音频录制到第二条音轨上, 听不到是因为部分视频播放器不支持多条音轨同时播放, 并不是录音丢失. 使用 QuickTime 播放即可. 

## 赞助
<img src="./img/donate.png" width="352"/>

## 致谢
[Azayaka](https://github.com/Mnpn/Azayaka) @Mnpn  
> 灵感来源以及屏幕录制引擎的部分代码来自于 Azayaka 项目, 同时我也是此项目的代码贡献者之一   

[ChatGPT](https://chat.openai.com) @OpenAI  
> 注: 本项目部分代码使用 ChatGPT 生成或重构整理
