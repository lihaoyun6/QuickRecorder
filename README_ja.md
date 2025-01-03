#
<p align="center">
<img src="./QuickRecorder/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="200" height="200" />
<h1 align="center">QuickRecorder</h1>
<h3 align="center">軽量で高性能なmacOS用スクリーンレコーダー<br><a href="./README_zh.md">[中文版本]</a><br><a href="./README.md">[English Version]</a><br><a href="https://lihaoyun6.github.io/quickrecorder/">[ランディングページ]</a>
</p>

## スクリーンショット
<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./img/preview_en_dark.png">
  <source media="(prefers-color-scheme: light)" srcset="./img/preview_en.png">
  <img alt="QuickRecorder Screenshots" src="./img/preview_en.png" width="840"/>
</picture>
</p>

## インストールと使用方法
### システム要件:
- macOS 12.3以降

### インストール:
最新のインストールファイルを[こちら](../../releases/latest)からダウンロードするか、Homebrewを使用してインストールしてください:

```bash
brew install lihaoyun6/tap/quickrecorder
```

### 特徴/使用方法:
- QuickRecorderを使用して、画面/ウィンドウ/アプリケーション/モバイルデバイスなどを録画できます。

- QuickRecorderは、ドライバ不要のオーディオループバック録音、マウスハイライト、スクリーン拡大鏡など、多くの便利な機能をサポートしています。  
- macOS 14の新機能である**"[Presenter Overlay](https://support.apple.com/guide/facetime/presenter-overlay-video-conferencing-fctm6333f4bd/mac)"**を完全にサポートしており、録画中にリアルタイムでカメラをオーバーレイできます（macOS 12/13ではカメラのフローティングウィンドウのみ使用可能）。  
- QuickRecorderは、アルファチャンネルを含む`HEVC with Alpha`ビデオ形式を録画することができます（現在、この機能をサポートしているの���iMovieとFCPXのみです）。  

## Q&A
**1. メインパネルを閉じた後、どこで再度開くことができますか？**
> QuickRecorderのDockタイルまたはメニューバーアイコンをクリックして、いつでもメインパネルを再度開くことができます。

**2. なぜQuickRecorderはサンドボックスアプリではないのですか？**
> QuickRecorderはApp Storeにアップロードする予定がないため、サンドボックスアプリとして設計する必要はありません。  

**3. 他のビデオエディタでシステムサウンドとマイクからの音声の音量を独立して制御するにはどうすればよいですか？**
> QuickRecorderはデフォルトで録画後にマイクからの音声をメインオーディオトラックにマージします。ビデオを編集する必要がある場合は、設定パネルで「マイクからのトラックをミックスダウンする」オプションをオフにすることができます。オフにすると、システムサウンドとマイクからの音声は2つのオーディオトラックに録音され、独立して編集できます。  

## 寄付
<img src="./img/donate.png" width="350"/>

## 感謝
[Azayaka](https://github.com/Mnpn/Azayaka) @Mnpn
> インスピレーションの源であり、画面録画エンジンの一部のコードはAzayakaプロジェクトから来ており、私もこのプロジェクトのコード貢献者の一人です

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) @sindresorhus  
> QuickRecorderはこのswiftライブラリを使用してショートカットキーイベントを処理します  

[SwiftLAME](https://github.com/hidden-spectrum/SwiftLAME) @Hidden Spectrum
> QuickRecorderはこのswiftライブラリを使用してMP3出力を処理します

[ChatGPT](https://chat.openai.com) @OpenAI
> 注: このプロジェクトの一部のコードはChatGPTを使用して生成またはリファクタリングされました。
