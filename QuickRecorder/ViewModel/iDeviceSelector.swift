//
//  iDeviceSelector.swift
//  QuickRecorder
//
//  Created by apple on 2024/5/1.
//

import SwiftUI
import AVFoundation

extension AppDelegate {
    func startDeviceOverlayer(size: NSSize = NSSize(width: 200, height: 200)){
        guard let screen = SCContext.getScreenWithMouse() else { return }
        let frame = NSRect(x: (screen.visibleFrame.width-size.width)/2+screen.frame.minX, y: (screen.visibleFrame.height-size.height)/2+screen.frame.minY, width: size.width, height: size.height)
        deviceWindow.contentView = NSHostingView(rootView: SwiftCameraView(type: .idevice))
        deviceWindow.setFrame(frame, display: true)
        deviceWindow.contentView?.wantsLayer = true
        deviceWindow.contentView?.layer?.cornerRadius = 5
        deviceWindow.contentView?.layer?.masksToBounds = true
        deviceWindow.orderFront(self)
    }
}

struct iDevicePopoverView: View {
    var closePopover: () -> Void
    @State private var devices = SCContext.getiDevice()
    @State private var hoverIndex = -1
    @State private var mute = false
    @State private var preset = AVCaptureSession.Preset.high
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some View {
        VStack( alignment: .center, spacing: 0) {
            if devices.count < 1 {
                HStack {
                    ZStack {
                        Circle().frame(width: 26)
                            .foregroundStyle(.primary)
                            .opacity(0.2)
                        Image(systemName:"iphone.slash")
                            .foregroundStyle(.primary)
                            .font(.system(size: 12))
                    }.padding(.leading, 9)
                    Text("No Devices Found!")
                        .padding([.top, .bottom], 8).padding(.trailing, 10)
                }
                .frame(maxWidth: .infinity)
                Divider().padding([.top, .bottom], 5)
                Text("Connect your device via USB")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 1)
            } else {
                ForEach(devices.indices, id: \.self) { index in
                    Button(action: {
                        closePopover()
                        appDelegate.closeAllWindow()
                        DispatchQueue.global().async {
                            AVOutputClass.shared.startRecording(with: devices[index], mute: mute, preset: preset)
                        }
                    }, label: {
                        HStack {
                            ZStack {
                                Circle().frame(width: 26)
                                    .foregroundStyle(.primary)
                                    .opacity(0.2)
                                Image(systemName:"apple.logo")
                                    .foregroundStyle(.primary)
                                    .font(.system(size: 12))
                                    .offset(x: -0.5, y:  -0.5)
                            }.padding(.leading, 9)
                            Text(devices[index].localizedName)
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
                Divider().padding(.top, 5)
                HStack(spacing: 0) {
                    Text("Mute").font(.system(size: 10)).foregroundStyle(.secondary).padding(.trailing, 6)
                    Toggle(isOn: $mute) {}
                        .toggleStyle(.checkbox)
                        .scaleEffect(0.83)
                    Spacer()
                    Text("Preset").font(.system(size: 10)).foregroundStyle(.secondary).padding(.trailing, -10)
                    Picker("", selection: $preset) {
                        Text("Low".local).tag(AVCaptureSession.Preset.low)
                        Text("Medium".local).tag(AVCaptureSession.Preset.medium)
                        Text("High".local).tag(AVCaptureSession.Preset.high)
                    }
                    .buttonStyle(.borderless)
                    .scaleEffect(0.7)
                    .offset(y: -0.5)
                }.padding([.top, .bottom], 4).padding(.leading, 10)
                Text("If you are on a call, enable \"Mute\"")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 1)
            }
        }.padding(5)
    }
}

struct ActivityIndicator: View {
    
    @State var currentDegrees = 0.0
    
    let colorGradient = LinearGradient(gradient: Gradient(colors: [
        .secondary, .secondary.opacity(0.75), .secondary.opacity(0.5), .secondary.opacity(0.2), .clear
    ]), startPoint: .leading, endPoint: .trailing)
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.85)
            .stroke(colorGradient, style: StrokeStyle(lineWidth: 3))
            .frame(width: 20, height: 20)
            .rotationEffect(Angle(degrees: currentDegrees))
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    withAnimation {
                        self.currentDegrees += 10
                    }
                }
            }
    }
}


