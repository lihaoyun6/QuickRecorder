//
//  AppSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI
import Combine
import ScreenCaptureKit

struct AppSelector: View {
    @StateObject var viewModel = AppSelectorViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var selected = [SCRunningApplication]()
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    @State private var start = Date.now
    @State private var counter: Int?
    
    @AppStorage("frameRate")      private var frameRate: Int = 60
    @AppStorage("videoQuality")   private var videoQuality: Double = 1.0
    @AppStorage("saveDirectory")  private var saveDirectory: String?
    @AppStorage("hideSelf")       private var hideSelf: Bool = false
    @AppStorage("showMouse")      private var showMouse: Bool = true
    @AppStorage("recordMic")      private var recordMic: Bool = false
    @AppStorage("recordWinSound") private var recordWinSound: Bool = true
    @AppStorage("background")     private var background: BackgroundType = .wallpaper
    @AppStorage("highRes")        private var highRes: Int = 2
    @AppStorage("countdown")      private var countdown: Int = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                Text("Please select the App(s) to record")
                ScrollView(.vertical) {
                    VStack(spacing: 14) {
                        ForEach(0..<viewModel.allApps.count/5 + 1, id: \.self) { rowIndex in
                            HStack(spacing: 20) {
                                ForEach(0..<5, id: \.self) { columnIndex in
                                    let index = 5 * rowIndex + columnIndex
                                    if index <= viewModel.allApps.count - 1 {
                                        Button(action: {
                                            if !selected.contains(viewModel.allApps[index]) {
                                                selected.append(viewModel.allApps[index])
                                            } else {
                                                selected.removeAll{ $0 == viewModel.allApps[index] }
                                            }
                                        }, label: {
                                            ZStack {
                                                VStack {
                                                    Image(nsImage: SCContext.getAppIcon(viewModel.allApps[index])!)
                                                    let appName = viewModel.allApps[index].applicationName
                                                    let appID = viewModel.allApps[index].bundleIdentifier
                                                    Text(appName != "" ? appName : appID)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                }
                                                .frame(width: 110, height: 94)
                                                .padding(10)
                                                .background(
                                                    Rectangle()
                                                        .foregroundStyle(.blue)
                                                        .cornerRadius(5)
                                                        .opacity(selected.contains(viewModel.allApps[index]) ? 0.2 : 0.0)
                                                )
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 31))
                                                    .foregroundStyle(.white)
                                                    .opacity(selected.contains(viewModel.allApps[index]) ? 1.0 : 0.0)
                                                    .offset(x: 20, y: 10)
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 27))
                                                    .foregroundStyle(.green)
                                                    .opacity(selected.contains(viewModel.allApps[index]) ? 1.0 : 0.0)
                                                    .offset(x: 20, y: 10)
                                            }
                                        }).buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 25)
                        }
                    }
                }
                .frame(height: 420)
                
                HStack{
                    Button(action: {
                        viewModel.updateAppList()
                    }, label: {
                        VStack{
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.blue)
                            Text("Refresh")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                        
                    }).buttonStyle(PlainButtonStyle())
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Definition")
                        Text("Frame rate")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $highRes) {
                            Text("Auto").tag(2)
                            Text("Low (1x)").tag(1)
                            Text("Low (0.5x)").tag(0)
                        }.buttonStyle(.borderless)
                        Picker("", selection: $frameRate) {
                            Text("240 FPS").tag(240)
                            Text("144 FPS").tag(144)
                            Text("120 FPS").tag(120)
                            Text("90 FPS").tag(90)
                            Text("60 FPS").tag(60)
                            Text("30 FPS").tag(30)
                            Text("24 FPS").tag(24)
                            Text("15 FPS").tag(15)
                            Text("10 FPS").tag(10)
                        }.buttonStyle(.borderless)
                    }.scaledToFit()
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quality")
                        Text("Background")
                    }.padding(.leading, 8)
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $videoQuality) {
                            Text("Low").tag(0.3)
                            Text("Medium").tag(0.7)
                            Text("High").tag(1.0)
                        }.buttonStyle(.borderless)
                        Picker("", selection: $background) {
                            Text("Wallpaper").tag(BackgroundType.wallpaper)
                            Text("Black").tag(BackgroundType.black)
                            Text("White").tag(BackgroundType.white)
                            Text("Gray").tag(BackgroundType.gray)
                            Text("Yellow").tag(BackgroundType.yellow)
                            Text("Orange").tag(BackgroundType.orange)
                            Text("Green").tag(BackgroundType.green)
                            Text("Blue").tag(BackgroundType.blue)
                            Text("Red").tag(BackgroundType.red)
                            Text("Custom").tag(BackgroundType.custom)
                        }.buttonStyle(.borderless)
                    }.scaledToFit()
                    Divider()
                    VStack(alignment: .leading, spacing: 3) {
                        Toggle(isOn: $showMouse) { Text("Record Cursor").padding(.leading, 5) }
                            .toggleStyle(CheckboxToggleStyle())
                        Toggle(isOn: $recordWinSound) { Text("Record App Sound").padding(.leading, 5) }
                            .toggleStyle(CheckboxToggleStyle())
                        if #available(macOS 14, *) { // apparently they changed onChange in Sonoma
                            Toggle(isOn: $recordMic) {
                                Text("Record Microphone").padding(.leading, 5)
                            }.toggleStyle(CheckboxToggleStyle()).onChange(of: recordMic) {
                                Task { await SCContext.performMicCheck() }
                            }
                        } else {
                            Toggle(isOn: $recordMic) {
                                Text("Record Microphone").padding(.leading, 5)
                            }.toggleStyle(CheckboxToggleStyle()).onChange(of: recordMic) { _ in
                                Task { await SCContext.performMicCheck() }
                            }
                        }
                    }
                    .scaleEffect(0.8)
                    .padding(.leading, -4)
                    Spacer()
                    Button(action: {
                        if counter == 0 { startRecording() }
                        if counter != nil { counter = nil } else { counter = countdown; start = Date.now }
                    }, label: {
                        VStack{
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.red)
                            ZStack{
                                Text("Start")
                                    .foregroundStyle((counter != nil && counter != 0) ? .clear : .secondary)
                                    .font(.system(size: 12))
                                Text((counter != nil && counter != 0) ? "\(counter!)" : "")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 12))
                                    .offset(x: 1)
                            }
                        }
                    })
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selected.count < 1)
                }
                .padding([.leading, .trailing], 50)
                Spacer()
            }
            .padding(.top, -5)
        }
        .frame(width: 780, height:530)
        .onReceive(timer) { t in
            if counter == nil { return }
            if counter! <= 1 { startRecording(); return }
            if t.timeIntervalSince1970 - start.timeIntervalSince1970 >= 1 { counter! -= 1; start = Date.now }
        }
    }
    
    func startRecording() {
        if let w = NSApplication.shared.windows.first(where: { $0.title == "App Selector" }) { w.close() }
        if let screen = SCContext.getSCDisplayWithMouse(){
            appDelegate.prepRecord(type: "application", screens: screen, windows: nil, applications: selected)
        }
    }
}

class AppSelectorViewModel: ObservableObject {
    @Published var allApps = [SCRunningApplication]()
    
    init() {
        updateAppList()
    }
    
    func updateAppList() {
        SCContext.updateAvailableContent{
            DispatchQueue.main.async {
                self.allApps = SCContext.getApps().filter({ $0.bundleIdentifier != Bundle.main.bundleIdentifier })
            }
        }
    }
}
