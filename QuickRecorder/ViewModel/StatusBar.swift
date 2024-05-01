//
//  StatusBarItem.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI

struct StatusBarItem: View {
    @State private var isPopoverShowing = false
    @State private var recordingLength = "00:00"
    @State private var isPassed = SCContext.isPaused
    @AppStorage("saveDirectory") private var saveDirectory: String?
    @AppStorage("highlightMouse") private var highlightMouse: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(Color.mypurple)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .cornerRadius(4)
                HStack(spacing: 4) {
                    Button(action: {
                        if SCContext.streamType == .idevice {
                            AVOutputClass.shared.stopRecording()
                        } else {
                            SCContext.stopRecording()
                        }
                    }, label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 16, alignment: .center)
                    }).buttonStyle(.plain)
                    if SCContext.streamType != .idevice {
                        Button(action: {
                            SCContext.pauseRecording()
                            isPassed = SCContext.isPaused
                        }, label: {
                            Image(systemName: isPassed ? "play.circle.fill" : "pause.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 16, alignment: .center)
                        }).buttonStyle(.plain)
                    }
                    Text(recordingLength)
                        .foregroundStyle(.white)
                        .font(.system(size: 15).monospaced())
                        .offset(x: 0.5)
                }
            }
            .frame(width: SCContext.streamType == .idevice ? 86 : 106)
            .padding([.leading,.trailing], 4)
            .onReceive(updateTimer) { t in recordingLength = SCContext.getRecordingLength() }
            if SCContext.streamType != .idevice {
                Button(action:{
                    isPopoverShowing.toggle()
                }, label: {
                    ZStack {
                        Rectangle()
                            .fill(SCContext.isCameraRunning() ? Color.mygreen : .gray)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .cornerRadius(4)
                        Image("camera")
                            .foregroundStyle(.white)
                    }.frame(width: 36).padding([.leading,.trailing], 4)
                })
                .buttonStyle(.plain)
                .popover(isPresented: $isPopoverShowing, arrowEdge: .bottom) { CameraPopoverView() }
            } else {
                Button(action:{
                    DispatchQueue.main.async {
                        if camWindow.isVisible { camWindow.close() } else { camWindow.orderFront(nil) }
                    }
                }, label: {
                    ZStack {
                        Rectangle()
                            .fill(camWindow.isVisible ? Color.mypurple : .gray.opacity(0.7))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .cornerRadius(4)
                        Image(systemName: "apps.ipad")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }.frame(width: 36).padding([.leading,.trailing], 4)
                })
                .buttonStyle(.plain)
            }
        }
        .onTapGesture {}
        .onHover { hovering in
            hideMousePointer = hovering
            hideScreenMagnifier = hovering
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func updateStatusBar() {
        if SCContext.streamType == nil { statusBarItem.isVisible = false; return }
        guard let button = statusBarItem.button else { return }
        var padding = -1.0
        var height = 21
        if #available(macOS 14.0, *) {
            padding = -2.0
            height = 22
        }
        let iconView = NSHostingView(rootView: StatusBarItem().padding(.top, padding))
        iconView.frame = NSRect(x: 0, y: 1, width: SCContext.streamType == .idevice ? 138 : 158, height: height)
        button.subviews = [iconView]
        button.frame = iconView.frame
        button.setAccessibilityLabel("QuickRecorder")
        statusBarItem.isVisible = true
    }
}
