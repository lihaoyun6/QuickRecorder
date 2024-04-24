//
//  SettingsView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/19.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var userColor: Color = Color.black
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    @AppStorage("audioFormat")   private var audioFormat: AudioFormat = .aac
    @AppStorage("audioQuality")  private var audioQuality: AudioQuality = .high
    @AppStorage("videoFormat")   private var videoFormat: VideoFormat = .mp4
    @AppStorage("encoder")       private var encoder: Encoder = .h264
    @AppStorage("hideSelf")      private var hideSelf: Bool = true
    @AppStorage("countdown")     private var countdown: Int = 0
    @AppStorage("saveDirectory") private var saveDirectory: String?
    @AppStorage("hideDesktopFiles") private var hideDesktopFiles: Bool = false
    @AppStorage("highlightMouse")   private var highlightMouse: Bool = false
    @AppStorage("includeMenuBar")   private var includeMenuBar: Bool = false
    
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                GroupBox(label: Text("Video Settings".local).fontWeight(.bold)) {
                    Form() {
                        Picker("Format", selection: $videoFormat) {
                            Text("MOV").tag(VideoFormat.mov)
                            Text("MP4").tag(VideoFormat.mp4)
                        }.padding([.leading, .trailing], 10)
                        Picker("Encoder", selection: $encoder) {
                            Text("H.264").tag(Encoder.h264)
                            Text("H.265").tag(Encoder.h265)
                        }.padding([.leading, .trailing], 10)
                    }.frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 7)
                }
                GroupBox(label: Text("Audio Settings".local).fontWeight(.bold)) {
                    Form() {
                        Picker("Format", selection: $audioFormat) {
                            Text("AAC").tag(AudioFormat.aac)
                            Text("ALAC (Lossless)").tag(AudioFormat.alac)
                            Text("FLAC (Lossless)").tag(AudioFormat.flac)
                            Text("Opus").tag(AudioFormat.opus)
                        }.padding([.leading, .trailing], 10)
                        Picker("Quality", selection: $audioQuality) {
                            if audioFormat == .alac || audioFormat == .flac {
                                Text("Lossless").tag(audioQuality)
                            }
                            Text("Normal - 128Kbps").tag(AudioQuality.normal)
                            Text("Good - 192Kbps").tag(AudioQuality.good)
                            Text("High - 256Kbps").tag(AudioQuality.high)
                            Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                        }.padding([.leading, .trailing], 10).disabled(audioFormat == .alac || audioFormat == .flac)
                    }.frame(maxWidth: .infinity).padding(.top, 10)
                    Text("These settings are also used when recording video. If set to Opus, MP4 will fall back to AAC.")
                        .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing, .bottom], 6).padding(.top, 1).fixedSize(horizontal: false, vertical: true)
                }
                GroupBox(label: Text("Other Settings".local).fontWeight(.bold)) {
                    Form() {
                        Picker("Recording Delay", selection: $countdown) {
                            Text("0s").tag(0)
                            Text("3s").tag(3)
                            Text("5s").tag(5)
                            Text("10s").tag(10)
                        }.padding([.leading, .trailing], 10)
                    }.frame(maxWidth: .infinity).padding(.top, 10)
                    ColorPicker("Set custom background color", selection: $userColor)
                    Toggle(isOn: $hideSelf) {
                        Text("Exclude QuickRecorder itself")
                    }
                    .padding(.bottom, 7)
                    .toggleStyle(CheckboxToggleStyle())
                    //.onChange(of: hideSelf) {_ in Task { if hideSelf { highlightMouse = false }}}
                    if #available(macOS 14.2, *) {
                        Toggle(isOn: $includeMenuBar) {
                            Text("Include MenuBar")
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        Text("Not available for \"Single Window Capture\"")
                            .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing], 6).fixedSize(horizontal: false, vertical: true)
                    }
                    Toggle(isOn: $highlightMouse) {
                        Text("Highlight the mouse cursor")
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    //.onChange(of: highlightMouse) {_ in Task { if highlightMouse { hideSelf = false }}}
                    Text("Not available for \"Single Window Capture\"")
                        .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing], 6).fixedSize(horizontal: false, vertical: true)
                    Toggle(isOn: $hideDesktopFiles) {
                        Text("Exclude the \"Desktop Files\" layer")
                    }.toggleStyle(CheckboxToggleStyle())
                    Text("If enabled, all files on the Desktop will be hidden from the video when recording Screen or Finder.")
                        .font(.footnote).foregroundColor(Color.gray).padding([.leading,.trailing, .bottom], 6).fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 2) {
                    Button(action: {
                        updateOutputDirectory()
                    }, label: {
                        Text("Select output directory").padding([.leading, .trailing], 10)
                    })
                    Text(String(format: "Currently set to \"%@\"".local, URL(fileURLWithPath: saveDirectory!).lastPathComponent)).font(.footnote).foregroundColor(Color.gray)
                }.frame(maxWidth: .infinity).padding(.top, 1)
                Divider()
                HStack {
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
                    }.padding(.leading, -10)
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Text("Close").padding([.leading, .trailing], 20)
                    }).keyboardShortcut(.defaultAction)
                }.padding(.top, 1.5)
            }.frame(width: 260).padding([.leading, .trailing], 16).padding([.top, .bottom], 13)
        }
        .onAppear{ userColor = ud.color(forKey: "userColor") ?? Color.black }
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

extension AppDelegate {
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
