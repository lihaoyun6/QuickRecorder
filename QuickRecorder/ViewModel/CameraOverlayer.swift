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
    func startCameraOverlayer(){
        guard let screen = SCContext.getScreenWithMouse() else { return }
        //camWindow.contentViewController = CameraVC()
        camWindow.contentView = NSHostingView(rootView: SwiftCameraView())
        camWindow.setFrameOrigin(NSPoint(x: screen.visibleFrame.width/2-100, y: screen.visibleFrame.height/2-100))
        //camWindow.minSize = NSSize(width: 100, height: 100)
        camWindow.title = "Camera Overlayer".local
        camWindow.isMovableByWindowBackground = true
        camWindow.isReleasedWhenClosed = false
        camWindow.hasShadow = true
        camWindow.backgroundColor = NSColor.clear
        camWindow.level = .floating
        camWindow.contentView?.wantsLayer = true
        camWindow.contentView?.layer?.cornerRadius = 5
        camWindow.contentView?.layer?.masksToBounds = true
        camWindow.orderFront(self)
    }
}

struct CameraView: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraNSView {
        let cameraView = CameraNSView()
        return cameraView
    }

    func updateNSView(_ nsView: CameraNSView, context: Context) {
        // Update the view
    }
}

class CameraNSView: NSView {
    let session = SCContext.captureSession
    var previewLayer: AVCaptureVideoPreviewLayer? = nil
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupCaptureSession()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        wantsLayer = true
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        guard let session = session else { return }
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer!.frame = bounds
        previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer!.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        layer?.addSublayer(previewLayer!)
    }
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}

struct SwiftCameraView: View {
    @State var hover = false
    @State var isFlipped = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                    CameraView()
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    Button(action: {
                        isFlipped.toggle()
                    }, label: {
                        ZStack {
                            Circle().frame(width: 30)
                                .foregroundStyle(hover ? .blue : .gray)
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                                .foregroundStyle(.white)
                                .offset(y: -1)
                        }
                        .opacity(hover ? 0.8 : 0.2)
                        .padding(10)
                        .onHover{ hovering in hover = hovering }
                    }).buttonStyle(.plain)
                }.frame(width: geometry.size.width, height: geometry.size.height)
                if SCContext.streamType == .window {
                    Text("Unable to use camera overlayer when recording a single window, please use \"Presenter Overlay\"")
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
    @State private var cameras = SCContext.getCameras()
    @State private var hoverIndex = -1
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some View {
        VStack( alignment: .leading, spacing: 0) {
            ForEach(cameras.indices, id: \.self) { index in
                Button(action: {
                    if SCContext.recordCam == cameras[index] { return }
                    SCContext.recordCam = cameras[index]
                    appDelegate.closeCamera()
                    if SCContext.recordCam != "Disabled".local {
                        appDelegate.recordingCamera(withName: SCContext.recordCam)
                    }
                }, label: {
                    HStack {
                        ZStack {
                            Circle().frame(width: 26)
                                .foregroundStyle(SCContext.recordCam == cameras[index] ? .blue : .primary)
                                .opacity(SCContext.recordCam == cameras[index] ? 1.0 : 0.2)
                            Image(systemName:cameras[index] == "Disabled".local ? "video.slash.fill" : "video.fill")
                                .foregroundStyle(SCContext.recordCam == cameras[index] ? .white : .primary)
                                .font(.system(size: 12))
                        }.padding(.leading, 9)
                        Text(cameras[index])
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
        }.padding(5)
    }
}
