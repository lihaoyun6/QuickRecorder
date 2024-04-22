//
//  StatusBarItem.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI

struct StatusBarItem: View {
    @State private var recordingLength = "00:00"
    @State private var isPassed = SCContext.isPaused
    @AppStorage("saveDirectory") private var saveDirectory: String?
    @AppStorage("highlightMouse") private var highlightMouse: Bool = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.mypurple)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .cornerRadius(4)
            HStack(spacing: 4) {
                Button(action: {
                    SCContext.stopRecording()
                }, label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 16, alignment: .center)
                }).buttonStyle(PlainButtonStyle())
                Button(action: {
                    SCContext.pauseRecording()
                    isPassed = SCContext.isPaused
                }, label: {
                    Image(systemName: isPassed ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 16, alignment: .center)
                }).buttonStyle(PlainButtonStyle())
                Spacer().frame(width: 0)
                Text(recordingLength)
                    .foregroundStyle(.white)
                    .font(.system(size: 15).monospaced())
                    .offset(x: 0.5)
            }
        }.onTapGesture {}
        .padding([.leading,.trailing], 4).padding(.top, -2)
        .onReceive(updateTimer) { t in recordingLength = SCContext.getRecordingLength() }
        .onHover { hovering in hideMousePointer = hovering }
    }
}

extension AppDelegate: NSMenuDelegate {
    func updateStatusBar() {
        if SCContext.streamType == nil { statusBarItem.isVisible = false; return }
        guard let button = statusBarItem.button else { return }
        let iconView = NSHostingView(rootView: StatusBarItem())
        iconView.frame = NSRect(x: 0, y: 1, width: 116, height: 22)
        button.subviews = [iconView]
        button.frame = iconView.frame
        button.setAccessibilityLabel("QuickRecorder")
        statusBarItem.isVisible = true
    }
}
