//
//  AreaSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/20.
//

import SwiftUI
import ScreenCaptureKit

struct DashWindow: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .padding(2)
                        .foregroundColor(.blue.opacity(0.5))
                )
        }
    }
}

struct AreaSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    @State private var start = Date.now
    @State private var counter: Int?
    var screen: SCDisplay!
    
    @AppStorage("frameRate")       private var frameRate: Int = 60
    @AppStorage("videoQuality")    private var videoQuality: Double = 1.0
    @AppStorage("saveDirectory")   private var saveDirectory: String?
    @AppStorage("hideSelf")        private var hideSelf: Bool = false
    @AppStorage("showMouse")       private var showMouse: Bool = true
    @AppStorage("recordMic")       private var recordMic: Bool = false
    @AppStorage("recordWinSound")  private var recordWinSound: Bool = true
    @AppStorage("background")      private var background: BackgroundType = .wallpaper
    //@AppStorage("removeWallpaper") private var removeWallpaper: Bool = false
    @AppStorage("highRes")         private var highRes: Int = 2
    @AppStorage("countdown")      private var countdown: Int = 0
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            VStack(spacing: 15) {
                HStack{
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
                            Divider()
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quality")
                                Text("Background")
                            }.padding(.leading, isMacOS12 ? 0 : 8)
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
                            Divider()
                            VStack(alignment: .leading, spacing: isMacOS12 ? 12 : 3) {
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
                            }.needScale()
                        }
                    }
                    Divider()
                    Spacer()
                    Button(action: {
                        if counter == 0 { startRecording() }
                        if counter != nil { counter = nil } else { counter = countdown; start = Date.now }
                    }, label: {
                        VStack{
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(.red)
                            ZStack{
                                Text("Start")
                                    .foregroundStyle((counter != nil && counter != 0) ? .clear : .secondary)
                                    .font(.system(size: 10))
                                Text((counter != nil && counter != 0) ? "\(counter!)" : "")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 10))
                                    .offset(x: 1)
                            }
                        }
                    })
                    .buttonStyle(.plain)
                    Spacer()
                }
                //.padding(.leading, 10).padding(.trailing, 20)
                Spacer()
            }.padding(.top, -5)
            Button(action: {
                for w in NSApplication.shared.windows.filter({ $0.title == "Area Selector".local || $0.title == "Start Recording".local}) { w.close() }
            }, label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            })
            .buttonStyle(.plain)
            .padding(.top, -9).padding(.leading, 7.5)
        }
        .frame(width: 590, height: 50)
        .onReceive(timer) { t in
            if counter == nil { return }
            if counter! <= 1 { startRecording(); return }
            if t.timeIntervalSince1970 - start.timeIntervalSince1970 >= 1 { counter! -= 1; start = Date.now }
        }
    }
    func startRecording() {
        for w in NSApplication.shared.windows.filter({ $0.title == "Area Selector".local || $0.title == "Start Recording".local}) { w.close() }
        var window = NSWindow()
        let contentView = NSHostingView(rootView: AreaSelector())
        let area = SCContext.screenArea!
        contentView.frame = NSRect(x: Int(area.origin.x - 5), y: Int(area.origin.y - 5), width: Int(area.width + 10), height: Int(area.height + 10))
        window = NSWindow(contentRect: contentView.frame, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.title = "Area Overlayer".local
        window.backgroundColor = NSColor.clear
        window.contentView = NSHostingView(rootView: DashWindow())
        window.orderFront(self)
        appDelegate.prepRecord(type: "area", screens: screen, windows: nil, applications: nil)
    }
}

class ScreenshotOverlayView: NSView {
    var selectionRect: NSRect?
    var initialLocation: NSPoint?
    var maskLayer: CALayer?
    var dragIng: Bool = false
    var activeHandle: ResizeHandle = .none
    var lastMouseLocation: NSPoint?

    let controlPointSize: CGFloat = 10.0
    let controlPointColor: NSColor = NSColor.systemYellow
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        selectionRect = NSRect(x: (self.frame.width - 600) / 2, y: (self.frame.height - 450) / 2 + 70, width: 600, height: 450)
        SCContext.screenArea = selectionRect
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.black.withAlphaComponent(0.5).setFill()
        dirtyRect.fill()
        
        // Draw selection rectangle
        if let rect = selectionRect {
            let dashPattern: [CGFloat] = [4.0, 4.0]
            let dashedBorder = NSBezierPath(rect: rect)
            dashedBorder.lineWidth = 4.0
            dashedBorder.setLineDash(dashPattern, count: 2, phase: 0.0)
            NSColor.white.setStroke()
            dashedBorder.stroke()
            NSColor.init(white: 1, alpha: 0.01).setFill()
            __NSRectFill(rect)
            // Draw control points
            for handle in ResizeHandle.allCases {
                if let point = controlPointForHandle(handle, inRect: rect) {
                    let controlPointRect = NSRect(origin: point, size: CGSize(width: controlPointSize, height: controlPointSize))
                    let controlPointPath = NSBezierPath(ovalIn: controlPointRect)
                    controlPointColor.setFill()
                    controlPointPath.fill()
                }
            }
        }
    }
    
    func handleForPoint(_ point: NSPoint) -> ResizeHandle {
        guard let rect = selectionRect else { return .none }
        
        for handle in ResizeHandle.allCases {
            if let controlPoint = controlPointForHandle(handle, inRect: rect), NSRect(origin: controlPoint, size: CGSize(width: controlPointSize, height: controlPointSize)).contains(point) {
                return handle
            }
        }
        return .none
    }
    
    func controlPointForHandle(_ handle: ResizeHandle, inRect rect: NSRect) -> NSPoint? {
        switch handle {
        case .topLeft:
            return NSPoint(x: rect.minX - controlPointSize / 2 - 1, y: rect.maxY - controlPointSize / 2 + 1)
        case .top:
            return NSPoint(x: rect.midX - controlPointSize / 2, y: rect.maxY - controlPointSize / 2 + 1)
        case .topRight:
            return NSPoint(x: rect.maxX - controlPointSize / 2 + 1, y: rect.maxY - controlPointSize / 2 + 1)
        case .right:
            return NSPoint(x: rect.maxX - controlPointSize / 2 + 1, y: rect.midY - controlPointSize / 2)
        case .bottomRight:
            return NSPoint(x: rect.maxX - controlPointSize / 2 + 1, y: rect.minY - controlPointSize / 2 - 1)
        case .bottom:
            return NSPoint(x: rect.midX - controlPointSize / 2, y: rect.minY - controlPointSize / 2 - 1)
        case .bottomLeft:
            return NSPoint(x: rect.minX - controlPointSize / 2 - 1, y: rect.minY - controlPointSize / 2 - 1)
        case .left:
            return NSPoint(x: rect.minX - controlPointSize / 2 - 1, y: rect.midY - controlPointSize / 2)
        case .none:
            return nil
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        initialLocation = location
        lastMouseLocation = location
        activeHandle = handleForPoint(location)
        if let rect = selectionRect, NSPointInRect(location, rect) { dragIng = true }
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard var initialLocation = initialLocation else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        if activeHandle != .none {
            
            // Calculate new rectangle size and position
            var newRect = selectionRect ?? CGRect.zero
            
            // Get last mouse location
            let lastLocation = lastMouseLocation ?? currentLocation
            
            let deltaX = currentLocation.x - lastLocation.x
            let deltaY = currentLocation.y - lastLocation.y

            switch activeHandle {
            case .topLeft:
                newRect.origin.x = min(newRect.origin.x + newRect.size.width - 20, newRect.origin.x + deltaX)
                newRect.size.width = max(20, newRect.size.width - deltaX)
                newRect.size.height = max(20, newRect.size.height + deltaY)
            case .top:
                newRect.size.height = max(20, newRect.size.height + deltaY)
            case .topRight:
                newRect.size.width = max(20, newRect.size.width + deltaX)
                newRect.size.height = max(20, newRect.size.height + deltaY)
            case .right:
                newRect.size.width = max(20, newRect.size.width + deltaX)
            case .bottomRight:
                newRect.origin.y = min(newRect.origin.y + newRect.size.height - 20, newRect.origin.y + deltaY)
                newRect.size.width = max(20, newRect.size.width + deltaX)
                newRect.size.height = max(20, newRect.size.height - deltaY)
            case .bottom:
                newRect.origin.y = min(newRect.origin.y + newRect.size.height - 20, newRect.origin.y + deltaY)
                newRect.size.height = max(20, newRect.size.height - deltaY)
            case .bottomLeft:
                newRect.origin.y = min(newRect.origin.y + newRect.size.height - 20, newRect.origin.y + deltaY)
                newRect.origin.x = min(newRect.origin.x + newRect.size.width - 20, newRect.origin.x + deltaX)
                newRect.size.width = max(20, newRect.size.width - deltaX)
                newRect.size.height = max(20, newRect.size.height - deltaY)
            case .left:
                newRect.origin.x = min(newRect.origin.x + newRect.size.width - 20, newRect.origin.x + deltaX)
                newRect.size.width = max(20, newRect.size.width - deltaX)
            default:
                break
            }
            self.selectionRect = newRect
            initialLocation = currentLocation // Update initial location for continuous dragging
            lastMouseLocation = currentLocation // Update last mouse location
        } else {
            if dragIng {
                dragIng = true
                // 计算移动偏移量
                let deltaX = currentLocation.x - initialLocation.x
                let deltaY = currentLocation.y - initialLocation.y
                
                // 更新矩形位置
                let x = self.selectionRect?.origin.x
                let y = self.selectionRect?.origin.y
                let w = self.selectionRect?.size.width
                let h = self.selectionRect?.size.height
                self.selectionRect?.origin.x = min(max(0.0, x! + deltaX), self.frame.width - w!)
                self.selectionRect?.origin.y = min(max(0.0, y! + deltaY), self.frame.height - h!)
                initialLocation = currentLocation
            } else {
                //dragIng = false
                // 创建新矩形
                let origin = NSPoint(x: min(initialLocation.x, currentLocation.x), y: min(initialLocation.y, currentLocation.y))
                let size = NSSize(width: abs(currentLocation.x - initialLocation.x), height: abs(currentLocation.y - initialLocation.y))
                self.selectionRect = NSRect(origin: origin, size: size)
                //initialLocation = currentLocation
            }
            self.initialLocation = initialLocation
        }
        lastMouseLocation = currentLocation
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        initialLocation = nil
        activeHandle = .none
        dragIng = false
        if let rect = selectionRect {
            SCContext.screenArea = rect
            //let rectArray = [Int(rect.origin.x), Int(rect.origin.y), Int(rect.size.width), Int(rect.size.height)]
            //ud.setValue(rectArray, forKey: "screenArea")
        }
    }
}

class ScreenshotWindow: NSWindow {
    let overlayView = ScreenshotOverlayView()
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        
        self.isOpaque = false
        self.level = .statusBar
        self.backgroundColor = NSColor.clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        self.isReleasedWhenClosed = false
        self.contentView = overlayView
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
        
    }

    func myKeyDownEvent(event: NSEvent) -> NSEvent {
        if event.keyCode == 53 {
            self.close()
            for w in NSApplication.shared.windows.filter({ $0.title == "Start Recording".local }) { w.close() }
        }
        return event
    }
}

enum ResizeHandle: CaseIterable {
    case none
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    
    static var allCases: [ResizeHandle] {
        return [.none, .topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left]
    }
}
