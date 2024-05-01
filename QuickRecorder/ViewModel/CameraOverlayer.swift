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
    func startCameraOverlayer(size: NSSize = NSSize(width: 100, height: 100)){
        guard let screen = SCContext.getScreenWithMouse() else { return }
        camWindow.contentView = NSHostingView(rootView: SwiftCameraView())
        let frame = NSRect(x: screen.visibleFrame.width/2-size.width, y: screen.visibleFrame.height/2-size.height, width: size.width, height: size.height)
        camWindow.setFrame(frame, display: true)
        //camWindow.setFrameOrigin(NSPoint(x: screen.visibleFrame.width/2-100, y: screen.visibleFrame.height/2-100))
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
    let session = SCContext.previewSession
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
        if SCContext.streamType == .idevice {
            previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
        } else {
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
    @State var hover = false
    @State var isFlipped = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if SCContext.streamType == .idevice {
                    Color.black
                    Text("Please unlock!")
                        .foregroundStyle(.white)
                }
                ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                    CameraView()
                        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    Button(action: {
                        if SCContext.streamType == .idevice {
                            for w in NSApplication.shared.windows.filter({ $0.title == "Camera Overlayer".local }) { w.close() }
                        } else {
                            isFlipped.toggle()
                        }
                    }, label: {
                        ZStack {
                            Circle().frame(width: 30)
                                .foregroundStyle(hover ? .blue : .gray)
                            if SCContext.streamType == .idevice {
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
                    Text("Unable to use camera overlayer when recording a single window, please use \"Presenter Overlay\"")
                        .padding()
                        .colorInvert()
                        .background(.secondary)
                }
            }
        }
        //.frame(minWidth: 100, minHeight: 100)
    }
}


struct CameraPopoverView: View {
    @State private var cameras = SCContext.getCameras()
    @State private var hoverIndex = -1
    @State private var disabled = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some View {
        VStack( alignment: .leading, spacing: 0) {
            Button(action: {
                SCContext.recordCam = "Disabled".local
                appDelegate.closeCamera()
            }, label: {
                HStack {
                    ZStack {
                        Circle().frame(width: 26)
                            .foregroundStyle(SCContext.recordCam == "Disabled".local ? .blue : .primary)
                            .opacity(SCContext.recordCam == "Disabled".local ? 1.0 : 0.2)
                        Image(systemName:"video.slash.fill")
                            .foregroundStyle(SCContext.recordCam == "Disabled".local ? .white : .primary)
                            .font(.system(size: 12))
                    }.padding(.leading, 9)
                    Text("Disabled".local)
                        .padding([.top, .bottom], 8).padding(.trailing, 10)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundStyle(.primary)
                        .opacity(disabled ? 0.2 : 0.0)
                )
                .onHover{ hovering in disabled = hovering }
            }).buttonStyle(.plain)
            ForEach(cameras.indices, id: \.self) { index in
                Button(action: {
                    if SCContext.recordCam == cameras[index].localizedName { return }
                    SCContext.recordCam = cameras[index].localizedName
                    appDelegate.closeCamera()
                    appDelegate.recordingCamera(withDevice: cameras[index])
                }, label: {
                    HStack {
                        ZStack {
                            Circle().frame(width: 26)
                                .foregroundStyle(SCContext.recordCam == cameras[index].localizedName ? .blue : .primary)
                                .opacity(SCContext.recordCam == cameras[index].localizedName ? 1.0 : 0.2)
                            Image(systemName:cameras[index].localizedName == "Disabled".local ? "video.slash.fill" : "video.fill")
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
        }.padding(5)
    }
}
