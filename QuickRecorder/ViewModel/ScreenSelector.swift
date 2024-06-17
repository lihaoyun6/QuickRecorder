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
    
    @State private var selected: SCDisplay?
    @State private var isPopoverShowing = false
    @State private var autoStop = 0
    var appDelegate = AppDelegate.shared
    
    @AppStorage("frameRate")       private var frameRate: Int = 60
    @AppStorage("videoQuality")    private var videoQuality: Double = 1.0
    @AppStorage("showMouse")       private var showMouse: Bool = true
    @AppStorage("recordMic")       private var recordMic: Bool = false
    @AppStorage("recordWinSound")  private var recordWinSound: Bool = true
    @AppStorage("background")      private var background: BackgroundType = .wallpaper
    @AppStorage("highRes")         private var highRes: Int = 2
    @AppStorage("recordHDR")       private var recordHDR: Bool = false
    
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
                
                HStack(spacing: 4) {
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
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Resolution")
                                Text("Frame Rate")
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("", selection: $highRes) {
                                    Text("High (auto)").tag(2)
                                    Text("Normal (1x)").tag(1)
                                    //Text("Low (0.5x)").tag(0)
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
                            Divider().frame(height: 50)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Quality")
                                Text("Background")
                            }.padding(.leading, isMacOS12 ? 0 : 8)
                            VStack(alignment: .leading, spacing: 10) {
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
                            Divider().frame(height: 50)
                            VStack(alignment: .leading, spacing: isMacOS12 ? 10 : 2) {
                                Toggle(isOn: $showMouse) {
                                    HStack(spacing:0){
                                        Image(systemName: "cursorarrow").frame(width: 20)
                                        Text("Record Cursor")
                                    }
                                }.toggleStyle(.checkbox)
                                if #available(macOS 13, *) {
                                    Toggle(isOn: $recordWinSound) {
                                        HStack(spacing:0){
                                            Image(systemName: "speaker.wave.1.fill").frame(width: 20)
                                            Text("App's Audio")
                                        }
                                    }.toggleStyle(.checkbox)
                                }
                                if #available(macOS 14, *) { // apparently they changed onChange in Sonoma
                                    Toggle(isOn: $recordMic) {
                                        HStack(spacing:0){
                                            Image(systemName: "mic.fill").frame(width: 20)
                                            Text("Microphone")
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                    .onChange(of: recordMic) {
                                        Task { await SCContext.performMicCheck() }
                                    }
                                } else {
                                    Toggle(isOn: $recordMic) {
                                        HStack(spacing:0){
                                            Image(systemName: "mic.fill").frame(width: 20)
                                            Text("Microphone")
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                    .onChange(of: recordMic) { _ in
                                        Task { await SCContext.performMicCheck() }
                                    }
                                }
                                if #available(macOS 15, *) {
                                    Toggle(isOn: $recordHDR) {
                                        HStack(spacing:0){
                                            Image(systemName: "sparkles.square.filled.on.square").frame(width: 20)
                                            Text("Record HDR")
                                        }
                                    }.toggleStyle(.checkbox)
                                }
                            }.needScale()
                        }
                    }.padding(.leading, 18)
                    Spacer()
                    Button(action: {
                        isPopoverShowing = true
                    }, label: {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.blue)
                    })
                    .buttonStyle(.plain)
                    .padding(.top, 42.5)
                    .popover(isPresented: $isPopoverShowing, arrowEdge: .bottom, content: {
                        HStack {
                            Text(" Stop after".local)
                            TextField("", value: $autoStop, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Stepper("", value: $autoStop)
                                .padding(.leading, -10)
                            Text("minutes ".local)
                        }
                        .fixedSize()
                        .padding()
                    })
                    Button(action: {
                        startRecording()
                    }, label: {
                        VStack{
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.red)
                            Text("Start")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                    })
                    .buttonStyle(.plain)
                    .disabled(selected == nil)
                }.padding([.leading, .trailing], 40)
                Spacer()
            }
            .padding(.top, -5)
        }.frame(width: 780, height:530)
    }
    
    func startRecording() {
        appDelegate.closeAllWindow()
        if let screen = selected {
            appDelegate.createCountdownPanel(screen: screen) {
                SCContext.autoStop = autoStop
                appDelegate.prepRecord(type: "display", screens: screen, windows: nil, applications: nil)
            }
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
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        var nsImage: NSImage?
        if let cgImage = cgImage { nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)) }
        if let index = self.streams.firstIndex(of: stream), index + 1 <= self.allScreens.count {
            if nsImage == nil { nsImage = SCContext.getWallpaper(self.allScreens[index]) ?? NSImage.unknowScreen }
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
    let image: NSImage
    let screen: SCDisplay

    init(image: NSImage, screen: SCDisplay) {
        self.image = image
        self.screen = screen
    }
}
