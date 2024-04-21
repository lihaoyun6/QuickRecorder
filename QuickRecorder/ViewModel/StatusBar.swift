//
//  StatusBarItem.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import SwiftUI

struct StatusBarItem: View {
    @State var isRecording: Bool!
    @State var recordingLength = "00:00"
    var body: some View {
        ZStack {
            if isRecording {
                Rectangle()
                    .cornerRadius(3)
                    .opacity(0.1)
            }
            HStack(spacing: 3) {
                if isRecording {
                    Image(systemName: SCContext.isPaused ? "pause.fill" : "record.circle.fill")
                        .foregroundStyle(.red)
                        .frame(width: 13, alignment: .center)
                    Text(recordingLength)
                        .font(.system(.body, design: .monospaced))
                        .offset(y: -0.5)
                } else {
                    Image(systemName: "record.circle")
                }
            }
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func createMenu() {
        statusMenu.removeAllItems()
        statusMenu.delegate = self
        if SCContext.streamType != nil { // recording?
            var typeText = ""
            if SCContext.window != nil {
                if SCContext.window?.count == 1 { typeText = SCContext.window?[0].owningApplication?.applicationName ?? "A Window".local }
                if SCContext.window!.count > 1 { typeText = "Multiple Windows".local }
            } else if SCContext.application != nil {
                if SCContext.application?.count == 1 { typeText = SCContext.application?[0].applicationName ?? "Unknown App".local }
                if SCContext.application!.count > 1 { typeText = "Multiple Apps".local }
            } else if SCContext.screen != nil {
                let screenName = NSScreen.screens.first(where: { $0.displayID == SCContext.screen?.displayID })?.localizedName ?? "Display ".local + String((SCContext.availableContent?.displays.firstIndex(where: { $0.displayID == SCContext.screen?.displayID }))!+1)
                typeText = screenName
            } else {
                typeText = "System Audio ".local
            }
            statusMenu.addItem(header("Recording: ".local + typeText, size: 12))
            statusMenu.addItem(info)
            info.attributedTitle = NSAttributedString(string: String(format: "File size: %@".local,  getRecordingSize()))
            statusMenu.addItem(NSMenuItem.separator())
            statusMenu.addItem(NSMenuItem(title: SCContext.isPaused ? "Resume".local : "Pause".local, action: #selector(pauseRecording), keyEquivalent: ""))
            statusMenu.addItem(NSMenuItem(title: "Stop Recording".local, action: #selector(stopRecording), keyEquivalent: ""))
            statusMenu.addItem(NSMenuItem.separator())
            statusMenu.addItem(NSMenuItem(title: "Preferences…".local, action: #selector(openPreferences), keyEquivalent: ","))
            statusMenu.addItem(NSMenuItem(title: "Quit QuickRecorder".local, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusBarItem.menu = statusMenu
        }
        
    }
    
    func updateMenu() {
        if SCContext.streamType != nil { // recording?
            updateIcon()
            info.attributedTitle = NSAttributedString(string: String(format: "File size: %@".local, getRecordingSize()))
        }
    }
    
    func updateIcon() {
        if SCContext.streamType == nil { statusBarItem.isVisible = false; return }
        statusBarItem.isVisible = true
        if let button = statusBarItem.button {
            let iconView = NSHostingView(rootView: StatusBarItem(isRecording: SCContext.streamType != nil, recordingLength: getRecordingLength()))
            iconView.frame = NSRect(x: 0, y: 1, width: SCContext.streamType != nil ? 72 : 33, height: 20)
            //let iconView = NSHostingView(rootView: StatusBarItem(isRecording: false, recordingLength: "00:10"))
            //iconView.frame = NSRect(x: 0, y: 1, width: nil != nil ? 72 : 33, height: 20)
            button.subviews = [iconView]
            button.frame = iconView.frame
            button.setAccessibilityLabel("QuickRecorder")
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        createMenu()
    }
    
    func header(_ title: String, size: CGFloat = 10) -> NSMenuItem {
        let headerItem: NSMenuItem
        if #available(macOS 14.0, *) {
            headerItem = NSMenuItem.sectionHeader(title: title)
        } else {
            headerItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            headerItem.attributedTitle = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .heavy)])
        }
        return headerItem
    }
}

extension NSMenuItem {
    func performAction() {
        guard let menu else {
            return
        }
        menu.performActionForItem(at: menu.index(of: self))
    }
}
