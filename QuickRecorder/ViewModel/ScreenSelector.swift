//
//  ScreenSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/18.
//

import SwiftUI
import ScreenCaptureKit

struct ScreenSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel = ScreenSelectorViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var selected: SCDisplay?
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
    @AppStorage("removeWallpaper") private var removeWallpaper: Bool = false
    @AppStorage("highRes")         private var highRes: Int = 2
    @AppStorage("countdown")      private var countdown: Int = 0
    @State private var recordCam = "Disabled".local
    @State private var cameras = SCContext.getCameras()
    
    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                Text("Please select the screen to record")
                let count = viewModel.screenThumbnails.count
                ScrollView(.vertical) {
                    VStack(spacing: 14){
                        ForEach(0..<viewModel.screenThumbnails.count/2 + 1, id: \.self) { rowIndex in
                            HStack(spacing: 40) {
                                ForEach(0..<2, id: \.self) { columnIndex in
                                    let index = 2 * rowIndex + columnIndex
                                    if index <= viewModel.screenThumbnails.count - 1 {
                                        Button(action: {
                                            selected = viewModel.screenThumbnails[index].screen
                                        }, label: {
                                            ZStack {
                                                VStack(spacing: 4) {
                                                    ZStack{
                                                        if colorScheme == .light {
                                                            Image(nsImage: viewModel.screenThumbnails[index].image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .colorMultiply(.black)
                                                                .blur(radius: 0.5)
                                                                .opacity(1)
                                                        } else {
                                                            Image(nsImage: viewModel.screenThumbnails[index].image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fit)
                                                                .colorMultiply(.black)
                                                                .colorInvert()
                                                                .blur(radius: 0.5)
                                                                .opacity(1)
                                                        }
                                                        Image(nsImage: viewModel.screenThumbnails[index].image)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                    }.frame(width: count == 1 ? 640 : 288, height: count == 1 ? 360 : 162, alignment: .center)
                                                    let screenName = NSScreen.screens.first(where: { $0.displayID == viewModel.screenThumbnails[index].screen.displayID })?.localizedName ?? "Display ".local + "\(viewModel.screenThumbnails[index].screen.displayID)"
                                                    Text(screenName)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .offset(y:count == 1 ? 5 : 2)
                                                }
                                                .padding(count == 1 ? 19 : 10)
                                                .background(
                                                    Rectangle()
                                                        .foregroundStyle(.blue)
                                                        .cornerRadius(5)
                                                        .opacity((selected == viewModel.screenThumbnails[index].screen) ? 0.2 : 0.0)
                                                )
                                                Group {
                                                    Image(systemName: "circle.fill")
                                                        .font(.system(size: count == 1 ? 62 : 31))
                                                        .foregroundStyle(.white)
                                                        .opacity((selected == viewModel.screenThumbnails[index].screen) ? 1.0 : 0.0)
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: count == 1 ? 54 : 27))
                                                        .foregroundStyle(.green)
                                                        .opacity((selected == viewModel.screenThumbnails[index].screen) ? 1.0 : 0.0)
                                                }.offset(x: count == 1 ? 270 : 120, y: count == 1 ? 130 : 50)
                                            }
                                        }).buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, count == 1 ? 51 : 61)
                        }
                    }
                }
                .frame(height: 420)
                
                HStack{
                    Button(action: {
                        viewModel.setupStreams()
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
                        if #available(macOS 14.2, *) {
                            Picker("Presenter Overlay Camera:", selection: $recordCam) {
                                ForEach(cameras, id: \.self) { cameraName in
                                    Text(cameraName)
                                }
                            }
                            .buttonStyle(.borderless)
                            .onDisappear{ SCContext.recordCam = recordCam }
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
                    .disabled(selected == nil)
                }
                .padding([.leading, .trailing], 50).padding(.top, isSonoma ? -6 : 0)
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
        /*.onAppear{
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if viewModel.screenThumbnails.count == 1 { selected = viewModel.screenThumbnails[0].screen }
            }
        }*/
    }
    
    func startRecording() {
        if let w = NSApplication.shared.windows.first(where: { $0.title == "Screen Selector".local }) { w.close() }
        if let screen = selected {
            appDelegate.prepRecord(type: "display", screens: screen, windows: nil, applications: nil)
        }
    }
}

class ScreenSelectorViewModel: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    @Published var screenThumbnails = [ScreenThumbnail]()
    private var allScreens = [SCDisplay]()
    private var streams = [SCStream]()
    
    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupStreams()
        }
    }
    
    func getWallpaper(_ display: SCDisplay) -> NSImage {
        guard let screen = display.nsScreen else { return NSImage.unknowScreen }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return NSImage.unknowScreen }
        do {
            var wallpaper: NSImage?
            try wallpaper = NSImage(data: Data(contentsOf: url))
            if let w = wallpaper { return w }
        } catch {
            print("load wallpaper error: \(error)")
        }
        return NSImage.unknowScreen
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        var nsImage: NSImage?
        if let cgImage = cgImage { nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)) }
        if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allScreens.count {
            if nsImage == nil { nsImage = self.getWallpaper(self.allScreens[index]) }
            let currentScreen = self.allScreens[index]
            let thumbnail = ScreenThumbnail(image: nsImage!, screen: currentScreen)
            DispatchQueue.main.async {
                if !self.screenThumbnails.contains(where: { $0.screen == currentScreen }) { self.screenThumbnails.append(thumbnail) }
            }
            self.streams[index].stopCapture()
        }
    }

    func setupStreams() {
        SCContext.updateAvailableContent{
            Task {
                do {
                    self.streams.removeAll()
                    DispatchQueue.main.async { self.screenThumbnails.removeAll() }
                    guard let screens = SCContext.availableContent?.displays else { return }
                    self.allScreens = screens
                    let qrSelf = SCContext.getSelf()
                    let contentFilters = self.allScreens.map { SCContentFilter(display: $0, excludingApplications: qrSelf != nil ? [qrSelf!] : [], exceptingWindows: []) }
                    for (index, contentFilter) in contentFilters.enumerated() {
                        let streamConfiguration = SCStreamConfiguration()
                        streamConfiguration.width = Int(self.allScreens[index].frame.width)
                        streamConfiguration.height = Int(self.allScreens[index].frame.height)
                        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(1))
                        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
                        if #available(macOS 13, *) { streamConfiguration.capturesAudio = false }
                        streamConfiguration.showsCursor = false
                        streamConfiguration.queueDepth = 3
                        let stream = SCStream(filter: contentFilter, configuration: streamConfiguration, delegate: self)
                        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                        try await stream.startCapture()
                        self.streams.append(stream)
                    }
                } catch {
                    print("Get screenshot error：\(error)")
                }
            }
        }
    }
}

class ScreenThumbnail {
    let id = UUID()
    let image: NSImage
    let screen: SCDisplay

    init(image: NSImage, screen: SCDisplay) {
        self.image = image
        self.screen = screen
    }
}
