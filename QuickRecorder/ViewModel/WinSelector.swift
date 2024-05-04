//
//  WinSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/17.
//

import SwiftUI
import Foundation
import AVFoundation
import ScreenCaptureKit

struct WinSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel = WindowSelectorViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var selected = [SCWindow]()
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    @State private var start = Date.now
    @State private var counter: Int?
    
    @AppStorage("frameRate")       private var frameRate: Int = 60
    @AppStorage("videoQuality")    private var videoQuality: Double = 1.0
    @AppStorage("saveDirectory")   private var saveDirectory: String?
    @AppStorage("hideSelf")        private var hideSelf: Bool = false
    @AppStorage("showMouse")       private var showMouse: Bool = true
    @AppStorage("recordMic")       private var recordMic: Bool = false
    @AppStorage("recordWinSound")  private var recordWinSound: Bool = true
    @AppStorage("background")      private var background: BackgroundType = .wallpaper
    @AppStorage("highRes")         private var highRes: Int = 2
    @AppStorage("countdown")      private var countdown: Int = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                Text("Please select the window(s) to record")
                ScrollView(.vertical) {
                    ForEach(0..<viewModel.windowThumbnails.count/4 + 1, id: \.self) { rowIndex in
                        HStack(spacing: 16.5) {
                            ForEach(0..<4, id: \.self) { columnIndex in
                                let index = 4 * rowIndex + columnIndex
                                if index <= viewModel.windowThumbnails.count - 1 {
                                    Button(action: {
                                        if !selected.contains(viewModel.windowThumbnails[index].window) {
                                            selected.append(viewModel.windowThumbnails[index].window)
                                        } else {
                                            selected.removeAll{ $0 == viewModel.windowThumbnails[index].window }
                                        }
                                    }, label: {
                                        VStack(spacing: 1){
                                            ZStack{
                                                if colorScheme == .light {
                                                    Image(nsImage: viewModel.windowThumbnails[index].image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .colorMultiply(.black)
                                                        .blur(radius: 0.5)
                                                        .opacity(1)
                                                        .frame(width: 160, height: 90, alignment: .center)
                                                } else {
                                                    Image(nsImage: viewModel.windowThumbnails[index].image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .colorMultiply(.black)
                                                        .colorInvert()
                                                        .blur(radius: 0.5)
                                                        .opacity(1)
                                                        .frame(width: 160, height: 90, alignment: .center)
                                                }
                                                Image(nsImage: viewModel.windowThumbnails[index].image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 160, height: 90, alignment: .center)
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 31))
                                                    .foregroundStyle(.white)
                                                    .opacity(selected.contains(viewModel.windowThumbnails[index].window) ? 1.0 : 0.0)
                                                    .offset(x: 55, y: 25)
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 27))
                                                    .foregroundStyle(.green)
                                                    .opacity(selected.contains(viewModel.windowThumbnails[index].window) ? 1.0 : 0.0)
                                                    .offset(x: 55, y: 25)
                                                Image(nsImage: SCContext.getAppIcon(viewModel.windowThumbnails[index].window.owningApplication!)!)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 40, height: 40, alignment: .center)
                                                    .offset(y: 35)
                                            }
                                            .padding(5)
                                            .padding([.top, .bottom], 5)
                                            .background(
                                                Rectangle()
                                                    .foregroundStyle(.blue)
                                                    .cornerRadius(5)
                                                    .opacity(selected.contains(viewModel.windowThumbnails[index].window) ? 0.2 : 0.0)
                                            )
                                            Text(viewModel.windowThumbnails[index].window.title!)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(width: 160)
                                        }
                                    }).buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                    }
                }
                .frame(height: 420)
                HStack{
                    Button(action: {
                        self.viewModel.setupStreams()
                        self.selected.removeAll()
                    }, label: {
                        VStack{
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.blue)
                            Text("Refresh")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                        
                    }).buttonStyle(.plain)
                    Spacer()
                    VStack(spacing: 6) {
                        HStack {
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
                            Divider().padding([.top, .bottom], -10)
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
                                    if ud.bool(forKey: "withAlpha") { Text("Transparent").tag(BackgroundType.clear) }
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
                            Divider().padding([.top, .bottom], -10)
                            VStack(alignment: .leading, spacing: 3) {
                                Toggle(isOn: $showMouse) { Text("Record Cursor").padding(.leading, 5) }
                                    .toggleStyle(.checkbox)
                                if #available(macOS 13, *) {
                                    Toggle(isOn: $recordWinSound) { Text("App's Audio").padding(.leading, 5) }
                                        .toggleStyle(.checkbox)
                                }
                                if #available(macOS 14, *) { // apparently they changed onChange in Sonoma
                                    Toggle(isOn: $recordMic) {
                                        Text("Microphone").padding(.leading, 5)
                                    }.toggleStyle(.checkbox).onChange(of: recordMic) {
                                        Task { await SCContext.performMicCheck() }
                                    }
                                } else {
                                    Toggle(isOn: $recordMic) {
                                        Text("Microphone").padding(.leading, 5)
                                    }.toggleStyle(.checkbox).onChange(of: recordMic) { _ in
                                        Task { await SCContext.performMicCheck() }
                                    }
                                }
                            }
                            .scaleEffect(0.8)
                            .padding(.leading, -4)
                        }
                    }
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
                    .buttonStyle(.plain)
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
        if let w = NSApplication.shared.windows.first(where: { $0.title == "Window Selector" }) { w.close() }
        if let screen = SCContext.getSCDisplayWithMouse(){
            appDelegate.prepRecord(type: (selected.count<2 ? "window" : "windows") , screens: screen, windows: selected, applications: nil)
        }
        
    }
}

class WindowSelectorViewModel: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var windowThumbnails = [WindowThumbnail]()
    private var allWindows = [SCWindow]()
    private var streams = [SCStream]()
    
    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupStreams()
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        let nsImage: NSImage
        if let cgImage = cgImage {
            nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } else {
            nsImage = NSImage.unknowScreen
        }
        if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allWindows.count {
            let currentWindow = self.allWindows[index]
            let thumbnail = WindowThumbnail(image: nsImage, window: currentWindow)
            DispatchQueue.main.async {
                if !self.windowThumbnails.contains(where: { $0.window == currentWindow }) { self.windowThumbnails.append(thumbnail) }
            }
            self.streams[index].stopCapture()
        }
    }

    func setupStreams() {
        SCContext.updateAvailableContent{
            Task {
                do {
                    self.streams.removeAll()
                    DispatchQueue.main.async { self.windowThumbnails.removeAll() }
                    self.allWindows = SCContext.getWindows().filter({
                        !($0.title == "" && $0.owningApplication?.bundleIdentifier == "com.apple.finder")
                        && $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                        && $0.owningApplication?.applicationName != ""
                    })
                    let contentFilters = self.allWindows.map { SCContentFilter(desktopIndependentWindow: $0) }
                    for (index, contentFilter) in contentFilters.enumerated() {
                        let streamConfiguration = SCStreamConfiguration()
                        let width = self.allWindows[index].frame.width
                        let height = self.allWindows[index].frame.height
                        var factor = 0.5
                        if width < 200 && height < 200 { factor = 1.0 }
                        streamConfiguration.width = Int(width * factor)
                        streamConfiguration.height = Int(height * factor)
                        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(1))
                        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
                        if #available(macOS 13, *) { streamConfiguration.capturesAudio = false }
                        streamConfiguration.showsCursor = false
                        streamConfiguration.scalesToFit = true
                        streamConfiguration.queueDepth = 3
                        let stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
                        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                        try await stream.startCapture()
                        self.streams.append(stream)
                    }
                } catch {
                    print("Get windowshot error：\(error)")
                }
            }
        }
    }
}

class WindowThumbnail {
    let id = UUID()
    let image: NSImage
    let window: SCWindow

    init(image: NSImage, window: SCWindow) {
        self.image = image
        self.window = window
    }
}
