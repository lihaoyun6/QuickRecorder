//
//  QuickRecorderApp.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import AppKit
import SwiftUI
import AVFAudio
import AVFoundation
import ScreenCaptureKit
import UserNotifications

var statusMenu: NSMenu = NSMenu()
var statusBarItem: NSStatusItem!
let info = NSMenuItem(title: "Waiting on update…".local, action: nil, keyEquivalent: "")
class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}
@main
struct QuickRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("Main Window".local)
                .fixedSize()
                .onAppear { setMainWindow() }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
                .fixedSize()
        }
    }
    
    func setMainWindow() {
        for w in NSApplication.shared.windows.filter({ $0.title == "Main Window".local }) {
            w.level = .floating
            w.styleMask = [.fullSizeContentView]
            w.isMovableByWindowBackground = true
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.backgroundColor = NSColor.clear
            w.contentView?.wantsLayer = true
            w.contentView?.layer?.cornerRadius = 13
            w.contentView?.layer?.masksToBounds = true
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, SCStreamDelegate, SCStreamOutput  {
    
    var audioSettings: [String : Any]!
    var filter: SCContentFilter?
    var updateTimer: Timer?
    let ud = UserDefaults.standard
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if SCContext.stream != nil { stopRecording() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if SCContext.streamType == nil { return true }
        return false
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SCContext.updateAvailableContent{ print("available content has been updated") }
        statusMenu.delegate = self
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.menu = statusMenu
        updateIcon()
        lazy var userDesktop = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first!
        let saveDirectory = (UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") ?? userDesktop) as NSString
        
        ud.register( // default defaults (used if not set)
            defaults: [
                "audioFormat": AudioFormat.aac.rawValue,
                "audioQuality": AudioQuality.high.rawValue,
                "background": BackgroundType.wallpaper.rawValue,
                "frameRate": 60,
                "highRes": 2,
                "hideSelf": true,
                "hideDesktopFiles": false,
                "videoQuality": 1.0,
                "videoFormat": VideoFormat.mp4.rawValue,
                "encoder": Encoder.h264.rawValue,
                "saveDirectory": saveDirectory,
                //"screenArea": [100, 100, 600, 450],
                "showMouse": true,
                "recordMic": false,
                "recordWinSound": true
            ]
        )
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("Notification authorization denied: \(error.localizedDescription)") }
        }
    }
}

extension String {
    var local: String { return NSLocalizedString(self, comment: "") }
}

enum AudioQuality: Int {
    case normal = 128, good = 192, high = 256, extreme = 320
}

enum AudioFormat: String {
    case aac, alac, flac, opus
}

enum VideoFormat: String {
    case mov, mp4
}

enum Encoder: String {
    case h264, h265
}

enum StreamType: Int {
    case screen, window, application, screenarea, systemaudio
}

enum BackgroundType: String {
    case wallpaper, black, white, red, green, yellow, orange, gray, blue, custom
}
