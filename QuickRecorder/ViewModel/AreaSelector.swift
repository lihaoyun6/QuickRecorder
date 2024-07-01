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

struct resizeView: View {
    private enum Field: Int, Hashable { case width, height }
    @FocusState private var focusedField: Field?
    
    @AppStorage("areaWidth")  private var areaWidth: Int = 600
    @AppStorage("areaHeight") private var areaHeight: Int = 450
    @AppStorage("highRes")    private var highRes: Int = 2
    
    var appDelegate = AppDelegate.shared
    var screen: SCDisplay!
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("Area Size:")
                TextField("", value: $areaWidth, formatter: NumberFormatter())
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .width)
                    .onChange(of: areaWidth) { newValue in
                        if !appDelegate.isResizing {
                            areaWidth = min(max(newValue, 1), screen.width)
                            resize()
                        }
                    }
                Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
                TextField("", value: $areaHeight, formatter: NumberFormatter())
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .height)
                    .onChange(of: areaHeight) { newValue in
                        if !appDelegate.isResizing {
                            areaHeight = min(max(newValue, 1), screen.height)
                            resize()
                        }
                    }
            }
            HStack(spacing: 4) {
                Text("Output Size:")
                let scale = Int(screen.nsScreen!.backingScaleFactor)
                Text(" \(highRes == 2 ? areaWidth * scale : areaWidth) x \(highRes == 2 ? areaHeight * scale : areaHeight)")
                Spacer()
            }
        }.onAppear{ focusedField = .width }
    }
    
    func resize() {
        appDelegate.closeAllWindow(except: "Start Recording".local)
        AppDelegate.shared.showAreaSelector(size: NSSize(width: areaWidth, height: areaHeight), noPanel: true)
    }
}

struct AreaSelector: View {
    @State private var isPopoverShowing = false
    @State private var resizePopoverShowing = false
    @State private var autoStop = 0
    
    var screen: SCDisplay!
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        ZStack {
            Color(nsColor: NSColor.windowBackgroundColor)
                .cornerRadius(10)
            VStack {
                HStack(spacing: 4) {
                    Spacer()
                    Button(action: {
                        resizePopoverShowing = true
                    }, label: {
                        VStack{
                            Image(systemName: "viewfinder.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.blue)
                            Text("Resize")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                    })
                    .buttonStyle(.plain)
                    .sheet(isPresented: $resizePopoverShowing, content: {
                        HStack(spacing: 10) {
                            Button(action: {
                                resizePopoverShowing = false
                            }, label: {
                                VStack{
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.secondary)
                                    Text("Back")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 12))
                                }
                                
                            }).buttonStyle(.plain)
                            resizeView(screen: screen)
                        }.padding()
                    })
                    Spacer()
                    OptionsView().padding(.leading, 18)
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
                    }).buttonStyle(.plain)
                    Spacer()
                }
            }
            Button(action: {
                for w in NSApplication.shared.windows.filter({ $0.title == "Area Selector".local || $0.title == "Start Recording".local}) { w.close() }
                appDelegate.stopGlobalMouseMonitor()
            }, label: {
                Image(systemName: "x.circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            })
            .buttonStyle(.plain)
            .padding(.leading, -354).padding(.top, -39)
        }.frame(width: 720, height: 90)
    }
    
    func startRecording() {
        appDelegate.closeAllWindow()
        appDelegate.stopGlobalMouseMonitor()
        var window = NSWindow()
        let area = SCContext.screenArea!
        guard let nsScreen = screen.nsScreen else { return }
        let frame = NSRect(x: Int(area.origin.x + nsScreen.frame.minX - 5), y: Int(area.origin.y + nsScreen.frame.minY - 5), width: Int(area.width + 10), height: Int(area.height + 10))
        window = NSWindow(contentRect: frame, styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.title = "Area Overlayer".local
        window.backgroundColor = NSColor.clear
        window.contentView = NSHostingView(rootView: DashWindow())
        window.orderFront(self)
        appDelegate.createCountdownPanel(screen: screen) {
            SCContext.autoStop = autoStop
            appDelegate.prepRecord(type: "area", screens: screen, windows: nil, applications: nil)
        }
    }
}

class ScreenshotOverlayView: NSView {
    @AppStorage("areaWidth") private var areaWidth: Int = 600
    @AppStorage("areaHeight") private var areaHeight: Int = 450
    
    var selectionRect: NSRect?
    var initialLocation: NSPoint?
    var maskLayer: CALayer?
    var dragIng: Bool = false
    var activeHandle: ResizeHandle = .none
    var lastMouseLocation: NSPoint?
    var maxFrame: NSRect?
    var size: NSSize
    var force: Bool

    let controlPointSize: CGFloat = 10.0
    let controlPointColor: NSColor = NSColor.systemYellow
    
    init(frame: CGRect, size: NSSize, force: Bool) {
        self.size = size
        self.force = force
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        selectionRect = NSRect(x: (self.frame.width - size.width) / 2, y: (self.frame.height - size.height) / 2, width: size.width, height:size.height)
        if !force {
            let savedArea = ud.object(forKey: "savedArea") as! [String: [String: CGFloat]]
            if let name = self.window?.screen?.localizedName { if let area = savedArea[name] {
                selectionRect = NSRect(x: area["x"]!, y: area["y"]!, width: area["width"]!, height: area["height"]!)
            }}
        }
        if self.window != nil {
            areaWidth = Int(selectionRect!.width)
            areaHeight = Int(selectionRect!.height)
            SCContext.screenArea = selectionRect
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        maxFrame = dirtyRect
        
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
        AppDelegate.shared.isResizing = true
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
            areaWidth = Int(selectionRect!.width)
            areaHeight = Int(selectionRect!.height)
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
                guard let maxFrame = maxFrame else { return }
                let origin = NSPoint(x: max(maxFrame.origin.x, min(initialLocation.x, currentLocation.x)), y: max(maxFrame.origin.y, min(initialLocation.y, currentLocation.y)))
                var maxH = abs(currentLocation.y - initialLocation.y)
                var maxW = abs(currentLocation.x - initialLocation.x)
                if currentLocation.y < maxFrame.origin.y { maxH = initialLocation.y }
                if currentLocation.x < maxFrame.origin.x { maxW = initialLocation.x }
                let size = NSSize(width: maxW, height: maxH)
                self.selectionRect = NSIntersectionRect(maxFrame, NSRect(origin: origin, size: size))
                areaWidth = Int(selectionRect!.width)
                areaHeight = Int(selectionRect!.height)
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
        AppDelegate.shared.isResizing = false
        if let rect = selectionRect {
            SCContext.screenArea = rect
            //let rectArray = [Int(rect.origin.x), Int(rect.origin.y), Int(rect.size.width), Int(rect.size.height)]
            //ud.setValue(rectArray, forKey: "screenArea")
        }
    }
}

class ScreenshotWindow: NSWindow {
    
    init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing bufferingType: NSWindow.BackingStoreType, defer flag: Bool, size: NSSize, force: Bool = false) {
        let overlayView = ScreenshotOverlayView(frame: contentRect, size:size, force: force)
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        self.isOpaque = false
        self.level = .statusBar
        self.backgroundColor = NSColor.clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        self.isReleasedWhenClosed = false
        self.contentView = overlayView
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func myKeyDownEvent(event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 && !event.isARepeat {
            self.close()
            for w in NSApplication.shared.windows.filter({ $0.title == "Start Recording".local }) { w.close() }
            AppDelegate.shared.stopGlobalMouseMonitor()
            return nil
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
