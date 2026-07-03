//
//  CameraOverlayer.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/29.
//

import SwiftUI
import AppKit
import Foundation
import AVFoundation

private let cameraWindowDelegate = CameraWindowDelegate()

private class CameraWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard notification.object as? NSWindow == camWindow else { return }
        AppDelegate.shared.keepCameraOverlayerOnScreen()
        AppDelegate.shared.saveCameraOverlayerPosition()
    }
}

extension AppDelegate {
    func startCameraOverlayer(size: NSSize? = nil, showsControls: Bool = true){
        guard let screen = SCContext.getScreenWithMouse() else { return }
        let savedWidth = ud.double(forKey: "cameraOverlayWidth")
        let width = size?.width ?? (savedWidth > 0 ? savedWidth : 200)
        let height = size?.height ?? width
        let size = NSSize(width: width, height: height)
        camWindow.contentView = NSHostingView(rootView: SwiftCameraView(type: .camera, showsControls: showsControls))
        let savedX = ud.object(forKey: "cameraOverlayX") as? Double
        let savedY = ud.object(forKey: "cameraOverlayY") as? Double
        let origin = NSPoint(
            x: savedX ?? (screen.visibleFrame.width-size.width)/2+screen.frame.minX,
            y: savedY ?? (screen.visibleFrame.height-size.height)/2+screen.frame.minY
        )
        let frame = NSRect(origin: origin, size: size)
        camWindow.setFrame(frame, display: true)
        camWindow.delegate = cameraWindowDelegate
        //camWindow.setFrameOrigin(NSPoint(x: screen.visibleFrame.width/2-100, y: screen.visibleFrame.height/2-100))
        camWindow.contentView?.wantsLayer = true
        camWindow.contentView?.layer?.cornerRadius = size.width / 2
        camWindow.contentView?.layer?.masksToBounds = true
        camWindow.level = ud.bool(forKey: "recordCameraEnabled") ? .screenSaver : .floating
        camWindow.orderFront(self)
        keepCameraOverlayerOnScreen()
    }

    func resizeCameraOverlayer(width: Double) {
        guard camWindow.isVisible else { return }
        let screen = cameraOverlayerScreen(for: camWindow.frame)
        let frame = clampedCameraOverlayerFrame(
            NSRect(x: camWindow.frame.origin.x, y: camWindow.frame.origin.y, width: width, height: width),
            on: screen
        )
        camWindow.setFrame(frame, display: true)
        camWindow.contentView?.layer?.cornerRadius = width / 2
        saveCameraOverlayerPosition()
    }

    func saveCameraOverlayerPosition() {
        guard camWindow.isVisible else { return }
        ud.set(camWindow.frame.origin.x, forKey: "cameraOverlayX")
        ud.set(camWindow.frame.origin.y, forKey: "cameraOverlayY")
    }

    func keepCameraOverlayerOnScreen() {
        guard camWindow.isVisible else { return }
        let frame = camWindow.frame
        let clampedFrame = clampedCameraOverlayerFrame(frame, on: cameraOverlayerScreen(for: frame))
        if clampedFrame.origin != frame.origin || clampedFrame.size != frame.size {
            camWindow.setFrame(clampedFrame, display: true)
        }
    }

    private func cameraOverlayerScreen(for frame: NSRect) -> NSScreen? {
        if let screen = camWindow.screen { return screen }
        let anchor = NSPoint(x: frame.minX + 1, y: frame.midY)
        return NSScreen.screens.first(where: { $0.visibleFrame.contains(anchor) })
            ?? NSScreen.screens.first(where: { $0.frame.contains(anchor) })
            ?? NSScreen.screens.max { lhs, rhs in
                lhs.visibleFrame.intersection(frame).area < rhs.visibleFrame.intersection(frame).area
            }
            ?? SCContext.getScreenWithMouse()
    }

    private func clampedCameraOverlayerFrame(_ frame: NSRect, on screen: NSScreen?) -> NSRect {
        guard let screen else { return frame }
        let visibleFrame = screen.visibleFrame
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        let x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

private extension NSRect {
    var area: CGFloat {
        guard width > 0, height > 0 else { return 0 }
        return width * height
    }
}

struct CameraView: NSViewRepresentable {
    var type: StreamType!
    var isMirrored = true

    func makeNSView(context: Context) -> CameraNSView {
        let cameraView = CameraNSView(frame: .zero, type: type)
        cameraView.setMirrored(isMirrored)
        return cameraView
    }

    func updateNSView(_ nsView: CameraNSView, context: Context) {
        nsView.setMirrored(isMirrored)
    }
}

class CameraNSView: NSView {
    let type: StreamType
    var session = SCContext.captureSession
    var previewLayer: AVCaptureVideoPreviewLayer? = nil
    
    init(frame frameRect: NSRect, type: StreamType) {
        self.type = type
        super.init(frame: frameRect)
        wantsLayer = true
        setupCaptureSession()
    }
        
    required init?(coder decoder: NSCoder) {
        // 如果您的类型不是一个可选类型，您可以将其设置为一个默认值
        self.type = .camera
        super.init(coder: decoder)
        wantsLayer = true
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        if type == .idevice { session = SCContext.previewSession }
        guard let session = session else { return }
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer!.frame = bounds
        if type == .idevice {
            previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
        }
        if type == .camera {
            previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
        layer?.addSublayer(previewLayer!)
    }

    func setMirrored(_ isMirrored: Bool) {
        guard type == .camera else { return }
        previewLayer?.setAffineTransform(isMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
    }
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}

struct SwiftCameraView: View {
    var type: StreamType!
    var showsControls = true
    @AppStorage("cameraMirrored") private var cameraMirrored = true
    @State private var hover = false
    @State private var isFlipped = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if type == .idevice {
                    Color.black
                    Text("Please unlock!")
                        .foregroundStyle(.white)
                }
                ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                    CameraView(type: type, isMirrored: cameraMirrored)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    if showsControls {
                        Button(action: {
                            if type == .idevice {
                                for w in NSApp.windows.filter({ $0.title == "iDevice Overlayer".local }) { w.close() }
                            } else {
                                isFlipped.toggle()
                            }
                        }, label: {
                            ZStack {
                                Circle().frame(width: 30)
                                    .foregroundStyle(hover ? .blue : .gray)
                                if type == .idevice {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.white)
                                } else {
                                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                                        .foregroundStyle(.white)
                                        .offset(y: -1)
                                }
                            }
                            .opacity(hover ? 0.8 : 0.2)
                            .onHover{ hovering in hover = hovering }
                        }).buttonStyle(.plain).padding(10)
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height)
                if SCContext.streamType == .window {
                    Text("Unable to use camera overlayer when recording a single window!".local
                         + (isMacOS14 ? " Please use \"Presenter Overlay\"".local : "")
                    )
                    .padding()
                    .colorInvert()
                    .background(.secondary)
                }
            }
        }
        .frame(minWidth: 100, minHeight: 100)
        .onHover { hovering in
            hideMousePointer = hovering
            hideScreenMagnifier = hovering
        }
    }
}


struct CameraPopoverView: View {
    var closePopover: () -> Void
    @State private var cameras = SCContext.getCameras()
    @State private var devices = SCContext.getiDevice()
    @State private var hoverIndex = -1
    @State private var hoverIndex2 = -1
    @State private var disabled = false
    @AppStorage("recordCameraEnabled") private var recordCameraEnabled = false
    @AppStorage("cameraOverlayWidth") private var cameraOverlayWidth = 200.0
    //@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        VStack( alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(
                get: { recordCameraEnabled },
                set: { enabled in
                    recordCameraEnabled = enabled
                    if enabled {
                        startSelectedCamera()
                    } else {
                        SCContext.recordCam = ""
                        appDelegate.closeCamera()
                    }
                }
            )) {
                Text("Record Camera".local)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .disabled(cameras.isEmpty)

            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Size".local + ": \(Int(cameraOverlayWidth))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $cameraOverlayWidth, in: 120...480, step: 10)
                    .onChange(of: cameraOverlayWidth) { newValue in
                        appDelegate.resizeCameraOverlayer(width: newValue)
                    }
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 6)
            .disabled(!recordCameraEnabled)

            Divider().padding(.vertical, 4)

            if cameras.count < 1 {
                HStack {
                    ZStack {
                        Circle().frame(width: 26)
                            .foregroundStyle(.primary)
                            .opacity(0.2)
                        Image(systemName:"video.slash.fill")
                            .foregroundStyle(.primary)
                            .font(.system(size: 12))
                    }.padding(.leading, 9)
                    Text("No Cameras Found!".local)
                        .padding(.vertical, 8).padding(.trailing, 10)
                }.frame(maxWidth: .infinity)
            }
            ForEach(cameras.indices, id: \.self) { index in
                Button(action: {
                    closePopover()
                    if SCContext.recordCam == cameras[index].localizedName {
                        SCContext.recordCam = ""
                        recordCameraEnabled = false
                        appDelegate.closeCamera()
                        return
                    }
                    recordCameraEnabled = true
                    SCContext.recordCam = cameras[index].localizedName
                    ud.set(cameras[index].uniqueID, forKey: "recordCameraDevice")
                    appDelegate.closeCamera()
                    appDelegate.recordingCamera(with: cameras[index])
                }, label: {
                    HStack {
                        ZStack {
                            Circle().frame(width: 26)
                                .foregroundStyle(SCContext.recordCam == cameras[index].localizedName ? .blue : .primary)
                                .opacity(SCContext.recordCam == cameras[index].localizedName ? 1.0 : 0.2)
                            Image(systemName: "video.fill")
                                .foregroundStyle(SCContext.recordCam == cameras[index].localizedName ? .white : .primary)
                                .font(.system(size: 12))
                        }.padding(.leading, 9)
                        Text(cameras[index].localizedName)
                            .padding(.vertical, 8).padding(.trailing, 10)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .foregroundStyle(.primary)
                            .opacity(hoverIndex == index ? 0.2 : 0.0)
                    )
                    .onHover{ hovering in
                        if hoverIndex != index { hoverIndex = index }
                        if !hovering { hoverIndex = -1 }
                    }
                }).buttonStyle(.plain)
            }
            if SCContext.streamType != .window {
                if !devices.isEmpty { Divider().padding(.vertical, 4) }
                ForEach(devices.indices, id: \.self) { index in
                    Button(action: {
                        closePopover()
                        if SCContext.recordDevice == devices[index].localizedName {
                            SCContext.recordDevice = ""
                            AVOutputClass.shared.closePreview()
                            return
                        }
                        SCContext.recordDevice = devices[index].localizedName
                        AVOutputClass.shared.closePreview()
                        DispatchQueue.global().async {
                            AVOutputClass.shared.startRecording(with: devices[index], mute: true, didOutput: false)
                        }
                    }, label: {
                        HStack {
                            ZStack {
                                Circle().frame(width: 26)
                                    .foregroundStyle(SCContext.recordDevice == devices[index].localizedName ? .blue : .primary)
                                    .opacity(SCContext.recordDevice == devices[index].localizedName ? 1.0 : 0.2)
                                Image(systemName:"apple.logo")
                                    .foregroundStyle(SCContext.recordDevice == devices[index].localizedName ? .white : .primary)
                                    .font(.system(size: 12))
                            }.padding(.leading, 9)
                            Text(devices[index].localizedName)
                                .padding(.vertical, 8).padding(.trailing, 10)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .foregroundStyle(.primary)
                                .opacity(hoverIndex2 == index ? 0.2 : 0.0)
                        )
                        .onHover{ hovering in
                            if hoverIndex2 != index { hoverIndex2 = index }
                            if !hovering { hoverIndex2 = -1 }
                        }
                    }).buttonStyle(.plain)
                }
            }
        }.padding(5)
    }

    private func startSelectedCamera() {
        guard let camera = cameras.first(where: { $0.localizedName == SCContext.recordCam }) ?? cameras.first else {
            recordCameraEnabled = false
            return
        }
        SCContext.recordCam = camera.localizedName
        ud.set(camera.uniqueID, forKey: "recordCameraDevice")
        appDelegate.closeCamera()
        appDelegate.recordingCamera(with: camera)
    }
}

struct CameraOptionToggle: View {
    var disabled = false
    @AppStorage("recordCameraEnabled") private var recordCameraEnabled = false

    var body: some View {
        Toggle(isOn: Binding(
            get: { recordCameraEnabled },
            set: { enabled in
                recordCameraEnabled = enabled
                if enabled {
                    AppDelegate.shared.ensureRecordingCameraRunning(showOverlay: false)
                } else {
                    SCContext.recordCam = ""
                    AppDelegate.shared.closeCamera()
                }
            }
        )) {
            HStack(spacing: 0) {
                Image(systemName: "camera.fill")
                    .font(isMacOS12 ? .body : .subheadline)
                    .frame(width: isMacOS12 ? 20 : 16)
                Text("Enable Camera")
                    .font(isMacOS12 ? .body : .subheadline)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(disabled)
        .help(disabled ? "Unable to use camera overlayer when recording a single window!".local : "Enable Camera".local)
    }
}

struct CameraSelectionPreviewOverlay: View {
    @AppStorage("recordCameraEnabled") private var recordCameraEnabled = false
    var diameter: CGFloat

    var body: some View {
        if recordCameraEnabled && SCContext.isCameraRunning() {
            SwiftCameraView(type: .camera)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .shadow(radius: 8)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2))
                .allowsHitTesting(false)
        }
    }
}
