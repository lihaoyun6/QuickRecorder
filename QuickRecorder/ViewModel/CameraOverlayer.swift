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

extension AppDelegate {
    func startCameraOverlayer(size: NSSize = NSSize(width: 200, height: 200)){
        guard let screen = SCContext.getScreenWithMouse() else { return }
        camWindow.contentView = NSHostingView(rootView: SwiftCameraView(type: .camera))
        let frame = NSRect(x: (screen.visibleFrame.width-size.width)/2+screen.frame.minX, y: (screen.visibleFrame.height-size.height)/2+screen.frame.minY, width: size.width, height: size.height)
        camWindow.setFrame(frame, display: true)
        //camWindow.setFrameOrigin(NSPoint(x: screen.visibleFrame.width/2-100, y: screen.visibleFrame.height/2-100))
        camWindow.contentView?.wantsLayer = true
        camWindow.contentView?.layer?.cornerRadius = 5
        camWindow.contentView?.layer?.masksToBounds = true
        camWindow.orderFront(self)
    }
}

struct CameraView: NSViewRepresentable {
    var type: StreamType!
    func makeNSView(context: Context) -> CameraNSView {
        let cameraView = CameraNSView(frame: .zero, type: type)
        return cameraView
    }

    func updateNSView(_ nsView: CameraNSView, context: Context) {
        // Update the view
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
            previewLayer!.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        }
        layer?.addSublayer(previewLayer!)
    }
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}

struct SwiftCameraView: View {
    var type: StreamType!
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
                    CameraView(type: type)
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    Button(action: {
                        if type == .idevice {
                            for w in NSApplication.shared.windows.filter({ $0.title == "iDevice Overlayer".local }) { w.close() }
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
    }
}


struct CameraPopoverView: View {
    var closePopover: () -> Void
    @State private var cameras = SCContext.getCameras()
    @State private var devices = SCContext.getiDevice()
    @State private var hoverIndex = -1
    @State private var hoverIndex2 = -1
    @State private var disabled = false
    //@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var appDelegate = AppDelegate.shared
    
    var body: some View {
        VStack( alignment: .leading, spacing: 0) {
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
                        .padding([.top, .bottom], 8).padding(.trailing, 10)
                }.frame(maxWidth: .infinity)
            }
            ForEach(cameras.indices, id: \.self) { index in
                Button(action: {
                    closePopover()
                    if SCContext.recordCam == cameras[index].localizedName {
                        SCContext.recordCam = ""
                        appDelegate.closeCamera()
                        return
                    }
                    SCContext.recordCam = cameras[index].localizedName
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
                            .padding([.top, .bottom], 8).padding(.trailing, 10)
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
                if !devices.isEmpty { Divider().padding([.top, .bottom], 4) }
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
                                .padding([.top, .bottom], 8).padding(.trailing, 10)
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
}
