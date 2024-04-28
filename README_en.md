#
<p align="center">
<img src="./QuickRecorder/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="200" height="200" />
<h1 align="center">QuickRecorder</h1>
<h3 align="center">A lightweight and high-performance screen recorder for macOS<br><a href="./README.md">[中文版本]</a>
</p>

## Screenshot
<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./img/preview_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="./img/preview.png">
  <img alt="QuickRecorder Screenshots" src="./img/preview.png" width="840"/>
</picture>
</p>

## Installation and Usage
### System Requirements:
- macOS 13.0 and Later

### Install:
Download the latest installation file [here](../../releases/latest) or install via Homebrew:

```bash
brew install lihaoyun6/tap/quickrecorder
```

### Features/Usage:
- Written using SwiftUI, it is small and lightweight. The software is only about 4MB in size and does not have any redundant functions.

- Supports window recording, App recording and other modes; supports internal sound recording, mouse highlighting, hiding desktop files and other features.  
- QuickRecorder will display the main panel after startup. And you can click the Dock bar icon to call it out any time.
- After starting recording, QuickRecorder will display a recording indicator in the menu bar, and you can pause or check the recording duration at any time.
- More features are being developed...

## Q&A
**1. Where can I reopen the main panel after closing it?**
> Click the Dock icon of QuickRecorder to reopen the main function panel at any time.

**2. Why does QuickRecorder not a sandbox app?**
> Apple's sandbox permission management mechanism is relatively complex and cumbersome to use. In addition, QuickRecorder has no plans to be put on the App Store, so it has not been made into a sandbox app.

**3. Why can’t I hear my voice in the video even though the “recording microphone” is turned on?**
> QuickRecorder will record the audio input from the microphone to the second audio track by default. The reason why you cannot hear it is because some video players do not support the simultaneous playback of multiple audio tracks. It does not mean that the recording is lost. Just use QuickTime to play it.

## Thanks
[Azayaka](https://github.com/Mnpn/Azayaka) @Mnpn
> The source of inspiration and part of the code of the screen recording engine comes from the Azayaka project, and I am also one of the code contributors to this project

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) @sindresorhus  
> QuickRecorder uses this swift library to handle shortcut key events    

[ChatGPT](https://chat.openai.com) @OpenAI
> Note: Part of the code in this project was generated or refactored using ChatGPT.
