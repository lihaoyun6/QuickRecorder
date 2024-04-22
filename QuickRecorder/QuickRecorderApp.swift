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

let ud = UserDefaults.standard
var statusMenu: NSMenu = NSMenu()
var statusBarItem: NSStatusItem!
var mouseMonitor: Any?
var hideMousePointer = false
let info = NSMenuItem(title: "Waiting on update…".local, action: nil, keyEquivalent: "")
let mousePointer = NSWindow(contentRect: NSRect(x: -70, y: -70, width: 70, height: 70), styleMask: [.borderless], backing: .buffered, defer: false)
let updateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
    var filter: SCContentFilter?
    
    func mousePointerReLocation(event: NSEvent) {
        if hideMousePointer { mousePointer.orderOut(nil); return }
        let mouseLocation = event.locationInWindow
        var windowFrame = mousePointer.frame
        if SCContext.stream != nil && !hideMousePointer { mousePointer.orderFront(nil) } //mousePointer.orderOut(nil)
        windowFrame.origin = NSPoint(x: mouseLocation.x - windowFrame.width / 2, y: mouseLocation.y - windowFrame.height / 2)
        mousePointer.contentView = NSHostingView(rootView: MousePointerView(event: event))
        mousePointer.setFrameOrigin(windowFrame.origin)
    }
    
    func registerGlobalMouseMonitor() {
        // 注册全局鼠标监听器
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .rightMouseUp, .rightMouseDown, .rightMouseDragged, .leftMouseUp,  .leftMouseDown, .leftMouseDragged, .otherMouseUp, .otherMouseDown, .otherMouseDragged]) { event in
            // 处理鼠标事件
            self.mousePointerReLocation(event: event)
        }
    }
        
    func stopGlobalMouseMonitor() {
        // 停止全局鼠标监听器
        mousePointer.orderOut(nil)
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if SCContext.stream != nil { SCContext.stopRecording() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if SCContext.streamType == nil { return true }
        return false
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SCContext.updateAvailableContent{ print("available content has been updated") }
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
                "showMouse": true,
                "recordMic": false,
                "recordWinSound": true,
                "highlightMouse" : true
            ]
        )
        
        statusMenu.delegate = self
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.menu = statusMenu
        mousePointer.title = "Mouse Pointer".local
        mousePointer.level = .screenSaver
        mousePointer.ignoresMouseEvents = true
        mousePointer.isReleasedWhenClosed = false
        mousePointer.backgroundColor = NSColor.clear
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("Notification authorization denied: \(error.localizedDescription)") }
        }
    }
}

extension String {
    var local: String { return NSLocalizedString(self, comment: "") }
}

enum AudioQuality: Int { case normal = 128, good = 192, high = 256, extreme = 320 }

enum AudioFormat: String { case aac, alac, flac, opus }

enum VideoFormat: String { case mov, mp4 }

enum Encoder: String { case h264, h265 }

enum StreamType: Int { case screen, window, application, screenarea, systemaudio }

enum BackgroundType: String { case wallpaper, black, white, red, green, yellow, orange, gray, blue, custom }
