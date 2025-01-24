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
        }.frame(width: 600, height: 512)
    }
}

struct GeneralView: View {
    @AppStorage("countdown") private var countdown: Int = 0
    @AppStorage("poSafeDelay") private var poSafeDelay: Int = 1
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = false
    
    @State private var launchAtLogin = false

    var body: some View {
        SForm {
            SGroupBox(label: "Startup") {
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
                    SDivider()
                }
                SToggle("Show QuickRecorder on Dock", isOn: $showOnDock)
                    //.disabled(!showMenubar)
                SDivider()
                SToggle("Show QuickRecorder on Menu Bar", isOn: $showMenubar)
                    //.disabled(!showOnDock)
            }
            SGroupBox(label: "Update") { UpdaterSettingsView(updater: updaterController.updater) }
            VStack(spacing: 8) {
                CheckForUpdatesView(updater: updaterController.updater)
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("QuickRecorder v\(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear{ if #available(macOS 13, *) { launchAtLogin = (SMAppService.mainApp.status == .enabled) }}
        .onChange(of: showMenubar) { _ in updateStatusBar() }
        .onChange(of: showOnDock) { newValue in
            if !newValue {
                NSApp.setActivationPolicy(.accessory)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
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
    @AppStorage("preventSleep")     private var preventSleep: Bool = true
    @AppStorage("showPreview")      private var showPreview: Bool = true
    @AppStorage("hideCCenter")      private var hideCCenter: Bool = false
    
    @State private var userColor: Color = Color.black

    var body: some View {
        SForm(spacing: 10) {
            SGroupBox(label: "Recorder") {
                SSteper("Delay Before Recording", value: $countdown, min: 0, max: 99)
                SDivider()
                if #available(macOS 14, *) {
                    SSteper("Presenter Overlay Delay", value: $poSafeDelay, min: 0, max: 99, tips: "If enabling Presenter Overlay causes recording failure, please increase this value.")
                    SDivider()
                }
                SItem(label: "Custom Background Color") {
                    if #unavailable(macOS 13) {
                        ColorPicker("", selection: $userColor)
                    } else {
                        MatrixColorSelector("", selection: $userColor)
                            .onChange(of: userColor) { userColor in ud.setColor(userColor, forKey: "userColor") }
                    }
                }
            }
            SGroupBox {
                SToggle("Mini size Menu Bar controller", isOn: $miniStatusBar)
                SDivider()
                SToggle("Prevent Mac from sleeping while recording", isOn: $preventSleep)
                SDivider()
                if #available(macOS 13, *) {
                    SToggle("Show floating preview after recording", isOn: $showPreview)
                    SDivider()
                }
                SToggle("Open video trimmer after recording", isOn: $trimAfterRecord)
            }
            SGroupBox {
                SToggle("Exclude QuickRecorder itself", isOn: $hideSelf)
                SDivider()
                if #available (macOS 13, *) {
                    SToggle("Include Menu Bar in Recording", isOn: $includeMenuBar)
                    SDivider()
                }
                SToggle("Hide Control Center Icons", isOn: $hideCCenter, tips: "Hide the clock, Wi-Fi, bluetooth, volume and other system icons in the menu bar.")
                SDivider()
                SToggle("Highlight the Mouse Cursor", isOn: $highlightMouse, tips: "Not available for \"Single Window Capture\"")
                SDivider()
                SToggle("Exclude Files on Desktop", isOn: $hideDesktopFiles, tips: "If enabled, all files on the Desktop will be hidden from the video when recording.")
            }
        }.onAppear{ userColor = ud.color(forKey: "userColor") ?? Color.black }
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
    @AppStorage("AECLevel")         private var AECLevel: String = "mid"
    @AppStorage("withAlpha")        private var withAlpha: Bool = false
    @AppStorage("saveDirectory")    private var saveDirectory: String?

    var body: some View {
        SForm(spacing: 30) {
            SGroupBox(label: "Audio") {
                SPicker("Quality", selection: $audioQuality) {
                    if audioFormat == .alac || audioFormat == .flac {
                        Text("Lossless").tag(audioQuality)
                    }
                    Text("Normal - 128Kbps").tag(AudioQuality.normal)
                    Text("Good - 192Kbps").tag(AudioQuality.good)
                    Text("High - 256Kbps").tag(AudioQuality.high)
                    Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                }.disabled(audioFormat == .alac || audioFormat == .flac)
                SDivider()
                SPicker("Format", selection: $audioFormat) {
                    Text("MP3").tag(AudioFormat.mp3)
                    Text("AAC").tag(AudioFormat.aac)
                    Text("ALAC (Lossless)").tag(AudioFormat.alac)
                    Text("FLAC (Lossless)").tag(AudioFormat.flac)
                    Text("Opus").tag(AudioFormat.opus)
                }
                SDivider()
                if #available(macOS 13, *) {
                    SToggle("Record Microphone to Main Track", isOn: $remuxAudio)
                    SDivider()
                }
                SToggle("Enable Acoustic Echo Cancellation", isOn: $enableAEC)
                if #available(macOS 14, *) {
                    SDivider()
                    SPicker("Audio Ducking Level", selection: $AECLevel) {
                        Text("Min").tag("min")
                        Text("Mid").tag("mid")
                        Text("Max").tag("max")
                    }.disabled(!enableAEC)
                }
            }
            SGroupBox(label: "Video") {
                SPicker("Format", selection: $videoFormat) {
                    Text("MOV").tag(VideoFormat.mov)
                    Text("MP4").tag(VideoFormat.mp4)
                }.disabled(withAlpha)
                SDivider()
                SPicker("Encoder", selection: $encoder) {
                    Text("H.264").tag(Encoder.h264)
                    Text("H.265").tag(Encoder.h265)
                }.disabled(withAlpha)
                SDivider()
                SToggle("Recording with Alpha Channel", isOn: $withAlpha)
            }
            SGroupBox(label: "Save") {
                SItem(label: "Output Folder") {
                    Text(String(format: "Currently set to \"%@\"".local, saveDirectory!.lastPathComponent))
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button("Select...", action: { updateOutputDirectory() })
                }
            }
        }.onChange(of: withAlpha) {alpha in
            if alpha {
                encoder = Encoder.h265; videoFormat = VideoFormat.mov
            } else {
                if background == .clear { background = .wallpaper }
            }
        }
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
        SForm(spacing: 10) {
            SGroupBox(label: "Hotkey") {
                SItem(label: "Open Main Panel") { KeyboardShortcuts.Recorder("", name: .showPanel) }
            }
            SGroupBox {
                SItem(label: "Stop Recording") { KeyboardShortcuts.Recorder("", name: .stop) }
                SDivider()
                SItem(label: "Pause / Resume") { KeyboardShortcuts.Recorder("", name: .pauseResume) }
            }
            SGroupBox {
                SItem(label: "Record System Audio") { KeyboardShortcuts.Recorder("", name: .startWithAudio) }
                SDivider()
                SItem(label: "Record Current Screen") { KeyboardShortcuts.Recorder("", name: .startWithScreen) }
                SDivider()
                SItem(label: "Record Topmost Window") { KeyboardShortcuts.Recorder("", name: .startWithWindow) }
                SDivider()
                SItem(label: "Select Area to Record") { KeyboardShortcuts.Recorder("", name: .startWithArea) }
            }
            SGroupBox {
                SItem(label: "Save Current Frame") { KeyboardShortcuts.Recorder("", name: .saveFrame) }
                SDivider()
                SItem(label: "Toggle Screen Magnifier") {KeyboardShortcuts.Recorder("", name: .screenMagnifier) }
            }
        }
    }
}

struct BlocklistView: View {
    var body: some View {
        SForm(spacing: 0, noSpacer: true) {
            SGroupBox(label: "Blocklist") {
                    BundleSelector()
                    Text("These apps will be excluded when recording \"Screen\" or \"Screen Area\"\nBut if the app is launched after the recording starts, it cannot be excluded.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.secondary)
            }
        }
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
    static let showPanel = Self("showPanel")
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
