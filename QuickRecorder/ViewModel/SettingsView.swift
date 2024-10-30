//
//  SettingsView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/19.
//

import SwiftUI
import Sparkle
import ServiceManagement
import KeyboardShortcuts
import MatrixColorSelector

struct SettingsView: View {
    @State private var selectedItem: String? = "General"
    
    var body: some View {
        NavigationView {
            List(selection: $selectedItem) {
                NavigationLink(destination: GeneralView(), tag: "General", selection: $selectedItem) {
                    Label("General", image: "gear")
                }
                NavigationLink(destination: RecorderView(), tag: "Recorder", selection: $selectedItem) {
                    Label("Recorder", image: "record")
                }
                NavigationLink(destination: OutputView(), tag: "Output", selection: $selectedItem) {
                    Label("Output", image: "film")
                }
                NavigationLink(destination: HotkeyView(), tag: "Hotkey", selection: $selectedItem) {
                    Label("Hotkey", image: "hotkey")
                }
                NavigationLink(destination: BlocklistView(), tag: "Blaoklist", selection: $selectedItem) {
                    Label("Blocklist", image: "blacklist")
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        }
        .frame(width: 600, height: 430)
    }
}

struct GeneralView: View {
    @AppStorage("countdown") private var countdown: Int = 0
    @AppStorage("poSafeDelay") private var poSafeDelay: Int = 1
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = false
    
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 30) {
            GroupBox(label: Text("Startup").font(.headline)) {
                VStack(spacing: 10) {
                    if #available(macOS 13, *) {
                        SToggle("Launch at Login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                do {
                                    if newValue {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                }catch{
                                    print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                                }
                            }
                        Divider().opacity(0.5)
                        SToggle("Show QuickRecorder on Dock", isOn: $showOnDock)
                            .disabled(!showMenubar)
                            .onChange(of: showOnDock) { newValue in
                                if !newValue { NSApp.setActivationPolicy(.accessory) } else { NSApp.setActivationPolicy(.regular) }
                            }
                        Divider().opacity(0.5)
                        SToggle("Show QuickRecorder on Menu Bar", isOn: $showMenubar)
                            .disabled(!showOnDock)
                            .onChange(of: showMenubar) { _ in AppDelegate.shared.updateStatusBar() }
                    }
                    
                }.padding(5)
            }
            GroupBox(label: Text("Update").font(.headline)) {
                VStack(spacing: 10) {
                    UpdaterSettingsView(updater: updaterController.updater)
                }.padding(5)
            }
            VStack(spacing: 8) {
                CheckForUpdatesView(updater: updaterController.updater)
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("QuickRecorder v\(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer().frame(minHeight: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onAppear{ if #available(macOS 13, *) { launchAtLogin = (SMAppService.mainApp.status == .enabled) }}
    }
}

struct RecorderView: View {
    @AppStorage("countdown")        private var countdown: Int = 0
    @AppStorage("poSafeDelay")      private var poSafeDelay: Int = 1
    @AppStorage("highlightMouse")   private var highlightMouse: Bool = false
    @AppStorage("includeMenuBar")   private var includeMenuBar: Bool = true
    @AppStorage("hideDesktopFiles") private var hideDesktopFiles: Bool = false
    @AppStorage("trimAfterRecord")  private var trimAfterRecord: Bool = false
    @AppStorage("miniStatusBar")    private var miniStatusBar: Bool = false
    @AppStorage("hideSelf")         private var hideSelf: Bool = true
    
    @State private var userColor: Color = Color.black

    var body: some View {
        VStack(spacing: 10) {
            GroupBox(label: Text("Recorder").font(.headline)) {
                VStack(spacing: 10) {
                    SSteper("Delay Before Recording", value: $countdown, min: 0, max: 99)
                    Divider().opacity(0.5)
                    if #available(macOS 14, *) {
                        SSteper("Presenter Overlay Delay", value: $poSafeDelay, min: 0, max: 99, tips: "If enabling Presenter Overlay causes recording failure, please increase this value.")
                        Divider().opacity(0.5)
                    }
                    HStack {
                        Text("Custom Background Color")
                        Spacer()
                        MatrixColorSelector("", selection: $userColor, sheetMode: true)
                            .onChange(of: userColor) { userColor in ud.setColor(userColor, forKey: "userColor") }
                    }.frame(height: 16)
                }.padding(5)
            }
            GroupBox {
                VStack(spacing: 10) {
                    SToggle("Open video trimmer after recording", isOn: $trimAfterRecord)
                    Divider().opacity(0.5)
                    SToggle("Exclude QuickRecorder itself", isOn: $hideSelf)
                    Divider().opacity(0.5)
                    if #available (macOS 13, *) {
                        SToggle("Include MenuBar in Recording", isOn: $includeMenuBar)
                        Divider().opacity(0.5)
                    }
                    SToggle("Highlight the Mouse Cursor", isOn: $highlightMouse, tips: "Not available for \"Single Window Capture\"")
                    Divider().opacity(0.5)
                    SToggle("Exclude the \"Desktop Files\" layer", isOn: $hideDesktopFiles, tips: "If enabled, all files on the Desktop will be hidden from the video when recording.")
                }.padding(5)
            }
            GroupBox {
                VStack(spacing: 10) {
                    SToggle("Mini size Menu Bar controller", isOn: $miniStatusBar)
                }.padding(5)
            }
            Spacer().frame(minHeight: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onAppear{ userColor = ud.color(forKey: "userColor") ?? Color.black }
    }
}

struct OutputView: View {
    @AppStorage("encoder")          private var encoder: Encoder = .h264
    @AppStorage("videoFormat")      private var videoFormat: VideoFormat = .mp4
    @AppStorage("audioFormat")      private var audioFormat: AudioFormat = .aac
    @AppStorage("audioQuality")     private var audioQuality: AudioQuality = .high
    @AppStorage("pixelFormat")      private var pixelFormat: PixFormat = .delault
    @AppStorage("background")       private var background: BackgroundType = .wallpaper
    @AppStorage("remuxAudio")       private var remuxAudio: Bool = true
    @AppStorage("enableAEC")        private var enableAEC: Bool = false
    @AppStorage("withAlpha")        private var withAlpha: Bool = false
    @AppStorage("saveDirectory")    private var saveDirectory: String?

    var body: some View {
        VStack(spacing: 30) {
            GroupBox(label: Text("Audio").font(.headline)) {
                VStack(spacing: 10) {
                    SPicker("Quality", selection: $audioQuality) {
                        if audioFormat == .alac || audioFormat == .flac {
                            Text("Lossless").tag(audioQuality)
                        }
                        Text("Normal - 128Kbps").tag(AudioQuality.normal)
                        Text("Good - 192Kbps").tag(AudioQuality.good)
                        Text("High - 256Kbps").tag(AudioQuality.high)
                        Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                    }.disabled(audioFormat == .alac || audioFormat == .flac)
                    Divider().opacity(0.5)
                    SPicker("Format", selection: $audioFormat) {
                        Text("MP3").tag(AudioFormat.mp3)
                        Text("AAC").tag(AudioFormat.aac)
                        Text("ALAC (Lossless)").tag(AudioFormat.alac)
                        Text("FLAC (Lossless)").tag(AudioFormat.flac)
                        Text("Opus").tag(AudioFormat.opus)
                    }
                    Divider().opacity(0.5)
                    if #available(macOS 13, *) {
                        SToggle("Record Microphone to Main Track", isOn: $remuxAudio)
                        Divider().opacity(0.5)
                    }
                    SToggle("Enable Acoustic Echo Cancellation", isOn: $enableAEC)
                }.padding(5)
            }
            GroupBox(label: Text("Video").font(.headline)) {
                VStack(spacing: 10) {
                    SPicker("Format", selection: $videoFormat) {
                        Text("MOV").tag(VideoFormat.mov)
                        Text("MP4").tag(VideoFormat.mp4)
                    }.disabled(withAlpha)
                    Divider().opacity(0.5)
                    SPicker("Encoder", selection: $encoder) {
                        Text("H.264 + sRGB").tag(Encoder.h264)
                        Text("H.265 + P3").tag(Encoder.h265)
                    }.disabled(withAlpha)
                    Divider().opacity(0.5)
                    SToggle("Recording with Alpha Channel", isOn: $withAlpha)
                        .onChange(of: withAlpha) {alpha in
                            if alpha {
                                encoder = Encoder.h265; videoFormat = VideoFormat.mov
                            } else {
                                if background == .clear { background = .wallpaper }
                            }}
                }.padding(5)
            }
            GroupBox {
                VStack(spacing: 10) {
                    HStack {
                        Text("Output Folder")
                        Spacer()
                        Text(String(format: "Currently set to \"%@\"".local, URL(fileURLWithPath: saveDirectory!).lastPathComponent))
                            .font(.footnote)
                            .foregroundColor(Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Button("Select...", action: { updateOutputDirectory() })
                    }.frame(height: 16)
                }.padding(5)
            }
            Spacer().frame(minHeight: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .padding(.bottom, -23)
    }
    
    func updateOutputDirectory() { // todo: re-sandbox
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = false
        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            if let path = openPanel.urls.first?.path { saveDirectory = path }
        }
    }
}

struct HotkeyView: View {
    var body: some View {
        VStack(spacing: 10) {
            GroupBox(label: Text("Hotkey").font(.headline)) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Stop Recording")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .stop)
                    }.frame(height: 16)
                    Divider().opacity(0.5)
                    HStack {
                        Text("Pause / Resume")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .pauseResume)
                    }.frame(height: 16)
                }.padding(5)
            }
            GroupBox {
                VStack(spacing: 10) {
                    HStack {
                        Text("Record System Audio")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .startWithAudio)
                    }.frame(height: 16)
                    Divider().opacity(0.5)
                    HStack {
                        Text("Record Current Screen")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .startWithScreen)
                    }.frame(height: 16)
                    Divider().opacity(0.5)
                    HStack {
                        Text("Record Topmost Window")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .startWithWindow)
                    }.frame(height: 16)
                    Divider().opacity(0.5)
                    HStack {
                        Text("Select Area to Record")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .startWithArea)
                    }.frame(height: 16)
                }.padding(5)
            }
            GroupBox {
                VStack(spacing: 10) {
                    HStack {
                        Text("Save Current Frame")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .saveFrame)
                    }.frame(height: 16)
                    Divider().opacity(0.5)
                    HStack {
                        Text("Toggle Screen Magnifier")
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .screenMagnifier)
                    }.frame(height: 16)
                }.padding(5)
            }
            Spacer().frame(minHeight: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct BlocklistView: View {
    var body: some View {
        VStack(spacing: 30) {
            GroupBox(label: Text("Blocklist").font(.headline)) {
                VStack(spacing: 10) {
                    BundleSelector()
                    Text("These apps will be excluded when recording \"Screen\" or \"Screen Area\"\nBut if the app is launched after the recording starts, it cannot be excluded.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.secondary)
                }.padding(5)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

extension UserDefaults {
    func setColor(_ color: Color?, forKey key: String) {
        guard let color = color else {
            removeObject(forKey: key)
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: NSColor(color), requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            print("Error archiving color:", error)
        }
    }
    
    func color(forKey key: String) -> Color? {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return Color(nsColor)
    }
    
    func cgColor(forKey key: String) -> CGColor? {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return nsColor.cgColor
    }
}

extension KeyboardShortcuts.Name {
    static let startWithAudio = Self("startWithAudio")
    static let startWithScreen = Self("startWithScreen")
    static let startWithWindow = Self("startWithWindow")
    static let startWithArea = Self("startWithArea")
    static let screenMagnifier = Self("screenMagnifier")
    static let saveFrame = Self("saveFrame")
    static let pauseResume = Self("pauseResume")
    static let stop = Self("stop")
}

extension AppDelegate {
    @available(macOS 13.0, *)
    @objc func setLoginItem(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            if sender.state == .off { try SMAppService.mainApp.unregister() }
        }catch{
            print("Failed to \(sender.state == .on ? "enable" : "disable") launch at login: \(error.localizedDescription)")
        }
    }
}
