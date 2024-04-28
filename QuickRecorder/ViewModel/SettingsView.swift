//
//  SettingsView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/19.
//

import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var userColor: Color = Color.black
    @State private var launchAtLogin = false
    @State private var fakeTrue = true
    @AppStorage("encoder")          private var encoder: Encoder = .h264
    @AppStorage("videoFormat")      private var videoFormat: VideoFormat = .mp4
    @AppStorage("audioFormat")      private var audioFormat: AudioFormat = .aac
    @AppStorage("audioQuality")     private var audioQuality: AudioQuality = .high
    @AppStorage("hideSelf")         private var hideSelf: Bool = true
    @AppStorage("countdown")        private var countdown: Int = 0
    @AppStorage("saveDirectory")    private var saveDirectory: String?
    @AppStorage("highlightMouse")   private var highlightMouse: Bool = false
    @AppStorage("includeMenuBar")   private var includeMenuBar: Bool = false
    @AppStorage("hideDesktopFiles") private var hideDesktopFiles: Bool = false
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 17){
                VStack(alignment: .leading) {
                    GroupBox(label: Text("Video Settings".local).fontWeight(.bold)) {
                        Form() {
                            Picker("Format", selection: $videoFormat) {
                                Text("MOV").tag(VideoFormat.mov)
                                Text("MP4").tag(VideoFormat.mp4)
                            }.padding([.leading, .trailing, .bottom], 11)
                            Picker("Encoder", selection: $encoder) {
                                Text("H.264").tag(Encoder.h264)
                                Text("H.265").tag(Encoder.h265)
                            }.padding([.leading, .trailing], 10)
                        }.frame(maxWidth: .infinity).padding([.top, .bottom], 11)
                    }//.padding(.bottom, 7)
                    GroupBox(label: Text("Audio Settings".local).fontWeight(.bold)) {
                        Form() {
                            Picker("Format", selection: $audioFormat) {
                                Text("AAC").tag(AudioFormat.aac)
                                Text("ALAC (Lossless)").tag(AudioFormat.alac)
                                Text("FLAC (Lossless)").tag(AudioFormat.flac)
                                Text("Opus").tag(AudioFormat.opus)
                            }.padding([.leading, .trailing, .bottom], 11)
                            if #available(macOS 13, *) {
                                Picker("Quality", selection: $audioQuality) {
                                    if audioFormat == .alac || audioFormat == .flac {
                                        Text("Lossless").tag(audioQuality)
                                    }
                                    Text("Normal - 128Kbps").tag(AudioQuality.normal)
                                    Text("Good - 192Kbps").tag(AudioQuality.good)
                                    Text("High - 256Kbps").tag(AudioQuality.high)
                                    Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                                }.padding([.leading, .trailing], 10).disabled(audioFormat == .alac || audioFormat == .flac)
                            }
                        }.frame(maxWidth: .infinity).padding(.top, 11)
                        Text("These settings are also used when recording video. If set to Opus, MP4 will fall back to AAC.")
                            .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing, .bottom], 6).padding(.top, 4).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(width: 270)
                VStack {
                    GroupBox(label: Text("Other Settings".local).fontWeight(.bold)) {
                        VStack(alignment: .leading){
                            Form() {
                                Picker("Recording Delay", selection: $countdown) {
                                    Text("0s").tag(0)
                                    Text("3s").tag(3)
                                    Text("5s").tag(5)
                                    Text("10s").tag(10)
                                }.padding([.leading, .trailing], 10)
                            }.frame(maxWidth: .infinity).padding(.top, 10)
                            ColorPicker("Set custom background color:", selection: $userColor).padding([.leading, .trailing], 10)
                            Toggle(isOn: $hideSelf) { Text("Exclude QuickRecorder itself") }
                                .padding([.leading, .trailing], 10)
                                .padding(.bottom, 9)
                                .toggleStyle(.checkbox)
                            if #available(macOS 14.2, *) {
                                Toggle(isOn: $includeMenuBar) { Text("Include MenuBar") }
                                    .padding([.leading, .trailing], 10)
                                    .toggleStyle(.checkbox)
                                Text("Not available for \"Single Window Capture\"")
                                    .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing], 6).padding(.leading, 24).padding(.top, -7).fixedSize(horizontal: false, vertical: true)
                            } else {
                                Toggle(isOn: $fakeTrue) { Text("Include MenuBar") }
                                    .padding([.leading, .trailing], 10)
                                    .toggleStyle(.checkbox)
                                    .disabled(true)
                                Text("Can only be turned off on macOS 14.2 or later!")
                                    .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing], 6).padding(.leading, 5).padding(.top, -7).fixedSize(horizontal: false, vertical: true).disabled(true)
                            }
                            Toggle(isOn: $highlightMouse) { Text("Highlight the mouse cursor") }
                                .padding([.leading, .trailing], 10)
                                .toggleStyle(.checkbox)
                            //.onChange(of: highlightMouse) {_ in Task { if highlightMouse { hideSelf = false }}}
                            Text("Not available for \"Single Window Capture\"")
                                .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing], 6).padding(.leading, 24).padding(.top, -7).fixedSize(horizontal: false, vertical: true)
                            Toggle(isOn: $hideDesktopFiles) { Text("Exclude the \"Desktop Files\" layer") }
                                .padding([.leading, .trailing], 10)
                                .toggleStyle(.checkbox)
                            Text("If enabled, all files on the Desktop will be hidden from the video when recording.")
                                .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing, .bottom], 6).padding(.leading, 24).padding(.top, -7).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.frame(width: 270)
            }
            HStack(alignment: .top, spacing: 17){
                GroupBox(label: Text("Shortcuts Settings".local).fontWeight(.bold)) {
                    Form(){
                        KeyboardShortcuts.Recorder("Stop Recording", name: .stop)
                        KeyboardShortcuts.Recorder("Pause / Resume", name: .pauseResume)
                        KeyboardShortcuts.Recorder("Record System Audio", name: .startWithAudio)
                        KeyboardShortcuts.Recorder("Record Current Screen", name: .startWithScreen)
                        KeyboardShortcuts.Recorder("Record Topmost Window", name: .startWithWindow)
                        KeyboardShortcuts.Recorder("Save Current Frame", name: .saveFrame)
                        KeyboardShortcuts.Recorder("Toggle Screen Magnifier", name: .screenMagnifier)
                    }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity).padding(6)
                }.frame(width: 320).fixedSize()
                GroupBox(label: Text("Excluded Apps".local).fontWeight(.bold)) {
                    VStack(spacing: 5.5) {
                        BundleSelector()
                        Text("These apps will be excluded when recording \"Screen\" or \"Screen Area\"\n* But if the app is launched after the recording starts, it cannot be excluded.")
                            .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing], 6).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(width: 220)
            }
            Divider()
            HStack {
                HStack(spacing: 10) {
                    Button(action: {
                        updateOutputDirectory()
                    }, label: {
                        Text("Select save folder").padding([.leading, .trailing], 10)
                    })
                    Text(String(format: "Currently set to \"%@\"".local, URL(fileURLWithPath: saveDirectory!).lastPathComponent)).font(.footnote).foregroundColor(Color.gray)
                }.padding(.leading, 0.5)
                Spacer()
                if #available(macOS 13, *) {
                    VStack {
                        HStack(spacing: 15){
                            Toggle(isOn: $launchAtLogin) {}
                                .offset(x: 10)
                                .toggleStyle(.switch)
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
                            Text("Launch at login")
                        }
                    }.padding(.trailing, 14)
                }
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Close").padding([.leading, .trailing], 20)
                }).keyboardShortcut(.defaultAction)
            }.padding(.top, 1.5)
            
                
        }
        .padding([.leading, .trailing], 17).padding([.top, .bottom], 12)
        .onAppear{
            userColor = ud.color(forKey: "userColor") ?? Color.black
            if #available(macOS 13, *) { launchAtLogin = (SMAppService.mainApp.status == .enabled) }
        }
        .onDisappear{ ud.setColor(userColor, forKey: "userColor") }
    }
    
    func updateOutputDirectory() { // todo: re-sandbox
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = false
        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            saveDirectory = openPanel.urls.first?.path
        }
    }
    
    func getVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown".local
    }

    func getBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown".local
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
