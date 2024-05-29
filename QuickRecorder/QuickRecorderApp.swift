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
import KeyboardShortcuts
import ServiceManagement
import CoreMediaIO
import Sparkle

var isMacOS12 = true
var isMacOS14 = false
var firstRun = true
let ud = UserDefaults.standard
var statusMenu: NSMenu = NSMenu()
var statusBarItem: NSStatusItem!
var mouseMonitor: Any?
var keyMonitor: Any?
var hideMousePointer = false
var hideScreenMagnifier = false
let info = NSMenuItem(title: "Waiting on update…".local, action: nil, keyEquivalent: "")
let updateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
let mousePointer = NSWindow(contentRect: NSRect(x: -70, y: -70, width: 70, height: 70), styleMask: [.borderless], backing: .buffered, defer: false)
let screenMagnifier = NSWindow(contentRect: NSRect(x: -402, y: -402, width: 402, height: 348), styleMask: [.borderless], backing: .buffered, defer: false)
let camWindow = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 200, height: 200), styleMask: [.fullSizeContentView, .resizable], backing: .buffered, defer: false)
let deviceWindow = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 200, height: 200), styleMask: [.fullSizeContentView, .resizable], backing: .buffered, defer: false)
let controlPanel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10), styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
var updaterController: SPUStandardUpdaterController!

@main
struct QuickRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    //private let updaterController: SPUStandardUpdaterController
        
    init() {
        // If you want to start the updater manually, pass false to startingUpdater and call .startUpdater() later
        // This is where you can also pass an updater delegate if you need one
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("QuickRecorder".local)
                .fixedSize()
                .onAppear { if #available(macOS 14, *) { setMainWindow() }}
        }.commands { CommandGroup(replacing: .newItem) {} }
            .commands {
                CommandGroup(after: .appInfo) {
                    CheckForUpdatesView(updater: updaterController.updater)
                }
            }
        .myWindowIsContentResizable()
        .handlesExternalEvents(matching: [])
        
        Settings {
            SettingsView()
                .fixedSize()
        }
    }
    
    func setMainWindow() {
        for w in NSApplication.shared.windows.filter({ $0.title == "QuickRecorder".local }) {
            w.level = .floating
            w.styleMask = [.fullSizeContentView]
            w.hasShadow = false
            w.isRestorable = false
            w.isMovableByWindowBackground = true
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.isOpaque = false
            w.backgroundColor = .clear
            //w.contentView?.wantsLayer = true
            //w.contentView?.layer?.cornerRadius = 13
            //w.contentView?.layer?.masksToBounds = true
        }
    }
}

extension Scene {
    func myWindowIsContentResizable() -> some Scene {
        if #available(macOS 13.0, *) {
            return self.windowResizability(.contentSize)
        }
        else {
            return self
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, SCStreamDelegate, SCStreamOutput, AVCaptureVideoDataOutputSampleBufferDelegate  {
    static let shared = AppDelegate()
    var filter: SCContentFilter?
    var isCameraReady = false
    var isPresenterON = false
    var presenterType = "OFF"
    //var lastTime = CMTime(value: 0, timescale: 600)
    
    func mousePointerReLocation(event: NSEvent) {
        if event.type == .scrollWheel { return }
        if !ud.bool(forKey: "highlightMouse")
            || hideMousePointer
            || SCContext.stream == nil
            || SCContext.streamType == .window
        { mousePointer.orderOut(nil); return }
        let mouseLocation = event.locationInWindow
        var windowFrame = mousePointer.frame
        windowFrame.origin = NSPoint(x: mouseLocation.x - windowFrame.width / 2, y: mouseLocation.y - windowFrame.height / 2)
        mousePointer.contentView = NSHostingView(rootView: MousePointerView(event: event))
        mousePointer.setFrameOrigin(windowFrame.origin)
        mousePointer.orderFront(nil)
    }
    
    func screenMagnifierReLocation(event: NSEvent) {
        if !SCContext.isMagnifierEnabled || hideScreenMagnifier { screenMagnifier.orderOut(nil); return }
        let mouseLocation = event.locationInWindow
        var windowFrame = screenMagnifier.frame
        windowFrame.origin = NSPoint(x: mouseLocation.x - windowFrame.width / 2, y: mouseLocation.y - windowFrame.height / 2)
        guard let image = NSImage.createScreenShot() else { return }
        let rect = NSRect(x: mouseLocation.x - 67, y: mouseLocation.y - 58, width: 134, height: 116)
        let croppedImage = image.trim(rect: rect)
        screenMagnifier.contentView = NSHostingView(rootView: ScreenMagnifier(screenShot: croppedImage, event: event))
        screenMagnifier.setFrameOrigin(windowFrame.origin)
        screenMagnifier.orderFront(nil)
    }
    
    func registerGlobalMouseMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .mouseMoved, .rightMouseUp, .rightMouseDown, .rightMouseDragged, .leftMouseUp,  .leftMouseDown, .leftMouseDragged, .otherMouseUp, .otherMouseDown, .otherMouseDragged]) { event in
            self.mousePointerReLocation(event: event)
            self.screenMagnifierReLocation(event: event)
        }
    }
        
    func stopGlobalMouseMonitor() {
        mousePointer.orderOut(nil)
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor); mouseMonitor = nil }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if SCContext.stream != nil { SCContext.stopRecording() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if SCContext.stream == nil { return true }
        return false
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            createNewWindow(view: VideoTrimmerView(videoURL: url), title: url.lastPathComponent, random: true)
            //closeMainWindow()
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let process = NSWorkspace.shared.runningApplications.filter({ $0.bundleIdentifier == "com.lihaoyun6.QuickRecorder" })
        if process.count > 1 {
            DispatchQueue.main.async {
                let button = self.createAlert(title: "QuickRecorder is Running".local, message: "Please do not run multiple instances!".local, button1: "Quit".local).runModal()
                if button == .alertFirstButtonReturn { NSApp.terminate(self) }
            }
        }
        
        lazy var userDesktop = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first!
        //let saveDirectory = (UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") ?? userDesktop) as NSString
        
        ud.register( // default defaults (used if not set)
            defaults: [
                "audioFormat": AudioFormat.aac.rawValue,
                "audioQuality": AudioQuality.high.rawValue,
                "background": BackgroundType.wallpaper.rawValue,
                "frameRate": 60,
                "highRes": 2,
                "hideSelf": true,
                "highlightMouse" : false,
                "hideDesktopFiles": false,
                "includeMenuBar": true,
                "videoQuality": 1.0,
                "videoFormat": VideoFormat.mp4.rawValue,
                "pixelFormat": PixFormat.delault.rawValue,
                "colorSpace": ColSpace.srgb.rawValue,
                "encoder": Encoder.h264.rawValue,
                "poSafeDelay": 1,
                "saveDirectory": userDesktop as NSString,
                "showMouse": true,
                "recordMic": false,
                "remuxAudio": true,
                "recordWinSound": true,
                "trimAfterRecord": false,
                "showOnDock": true,
                "showMenubar": false,
                "enableAEC": false,
                "savedArea": [String: [String: CGFloat]]()
            ]
        )
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("Notification authorization denied: \(error.localizedDescription)") }
        }
        
        SCContext.updateAvailableContent{
            print("available content has been updated")
            let os = ProcessInfo.processInfo.operatingSystemVersion
            if "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)" == "12.7.4" {
                DispatchQueue.main.async {
                    _ = AppDelegate.shared.createAlert(
                        title: "Compatibility Warning".local,
                        message: "You are using macOS 12.7.4\nOutput files will be randomly corrupted on this version of macOS!\n\nPlease upgrade to 12.7.5 to solve it.".local,
                        button1: "OK".local).runModal()
                }
            }
        }
        
        if #available(macOS 13, *) { isMacOS12 = false }
        if #available(macOS 14, *) { isMacOS14 = true }
        
        if !ud.bool(forKey: "showOnDock") { NSApp.setActivationPolicy(.accessory) }
        
        var allow : UInt32 = 1
        let dataSize : UInt32 = 4
        let zero : UInt32 = 0
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, zero, nil, dataSize, &allow)
        
        statusMenu.delegate = self
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.menu = statusMenu
        
        mousePointer.title = "Mouse Pointer".local
        mousePointer.level = .screenSaver
        mousePointer.ignoresMouseEvents = true
        mousePointer.isReleasedWhenClosed = false
        mousePointer.backgroundColor = NSColor.clear
        
        screenMagnifier.title = "Screen Magnifier".local
        screenMagnifier.level = .floating
        screenMagnifier.ignoresMouseEvents = true
        screenMagnifier.isReleasedWhenClosed = false
        screenMagnifier.backgroundColor = NSColor.clear
        
        camWindow.title = "Camera Overlayer".local
        camWindow.level = .floating
        camWindow.isReleasedWhenClosed = false
        camWindow.isMovableByWindowBackground = true
        camWindow.backgroundColor = NSColor.clear
        
        deviceWindow.title = "iDevice Overlayer".local
        deviceWindow.level = .floating
        deviceWindow.isReleasedWhenClosed = false
        deviceWindow.isMovableByWindowBackground = true
        deviceWindow.backgroundColor = NSColor.clear
        
        controlPanel.title = "Recording Controller".local
        controlPanel.level = .floating
        controlPanel.titleVisibility = .hidden
        controlPanel.backgroundColor = NSColor.clear
        controlPanel.isReleasedWhenClosed = false
        controlPanel.titlebarAppearsTransparent = true
        controlPanel.isMovableByWindowBackground = true
        
        KeyboardShortcuts.onKeyDown(for: .saveFrame) { if SCContext.stream != nil { SCContext.saveFrame = true }}
        KeyboardShortcuts.onKeyDown(for: .screenMagnifier) { if SCContext.stream != nil { SCContext.isMagnifierEnabled.toggle() }}
        KeyboardShortcuts.onKeyDown(for: .stop) { if SCContext.stream != nil { SCContext.stopRecording() }}
        KeyboardShortcuts.onKeyDown(for: .pauseResume) { if SCContext.stream != nil { SCContext.pauseRecording() }}
        KeyboardShortcuts.onKeyDown(for: .startWithAudio) {[self] in
            if SCContext.streamType != nil { return }
            closeAllWindow()
            prepRecord(type: "audio", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil, fastStart: true)
        }
        KeyboardShortcuts.onKeyDown(for: .startWithScreen) {[self] in
            if SCContext.stream != nil { return }
            closeAllWindow()
            prepRecord(type: "display", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil, fastStart: true)
        }
        KeyboardShortcuts.onKeyDown(for: .startWithArea) {[self] in
            if SCContext.stream != nil { return }
            closeAllWindow()
            showAreaSelector()
        }
        KeyboardShortcuts.onKeyDown(for: .startWithWindow) { [self] in
            if SCContext.stream != nil { return }
            closeAllWindow()
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            if let pid = frontmostApp?.processIdentifier {
                let options: CGWindowListOption = .optionOnScreenOnly
                let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                if let infoList = windowListInfo as? [[String: AnyObject]] {
                    for info in infoList {
                        if let windowPID = info[kCGWindowOwnerPID as String] as? pid_t, windowPID == pid {
                            if let windowNumber = info[kCGWindowNumber as String] as? CGWindowID {
                                guard let scWindow = SCContext.getWindows().first(where: { $0.windowID == windowNumber }) else { return }
                                prepRecord(type: "window", screens: SCContext.getSCDisplayWithMouse(), windows: [scWindow], applications: nil, fastStart: true)
                                return
                            }
                        }
                    }
                }
            }
        }
        
        updateStatusBar()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if #available(macOS 13, *) {
            if firstRun && (SMAppService.mainApp.status == .enabled) {
                firstRun = false
                closeAllWindow()
            }
        }
    }
    
    func openSettingPanel() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.mainMenu?.items.first?.submenu?.item(at: 3)?.performAction()
        }else if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}


extension String {
    var local: String { return NSLocalizedString(self, comment: "") }
}

extension NSMenuItem {
    func performAction() {
        guard let menu else {
            return
        }
        menu.performActionForItem(at: menu.index(of: self))
    }
}

extension NSImage {
    static func createScreenShot() -> NSImage? {
        let excludedAppBundleIDs = ["com.lihaoyun6.QuickRecorder"]
        var exclusionPIDs = [Int]()
        for app in NSWorkspace.shared.runningApplications {
            if excludedAppBundleIDs.contains(app.bundleIdentifier ?? "") {
                exclusionPIDs.append(Int(app.processIdentifier))
            }
        }
        
        let windowDescriptions = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        var windowIDs = [CGWindowID]()
        for windowDict in windowDescriptions {
            if let windowProcessID = windowDict[kCGWindowOwnerPID as String] as? Int,
               !exclusionPIDs.contains(windowProcessID),
               let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID {
                windowIDs.append(windowID)
            }
        }
        let pointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: windowIDs.count)
        for (index, window) in windowIDs.enumerated() { pointer[index] = UnsafeRawPointer(bitPattern: UInt(window)) }
        let cWindowIDArray: CFArray = CFArrayCreate(kCFAllocatorDefault, pointer, windowIDs.count, nil)

        guard let imageRef = CGImage(windowListFromArrayScreenBounds: CGRect.infinite, windowArray: cWindowIDArray, imageOption: []) else {
            print("No image available")
            return nil
        }
        let factor = SCContext.getScreenWithMouse()?.backingScaleFactor ?? 1.0
        return NSImage(cgImage: imageRef, size: NSSize(width: CGFloat(imageRef.width)/factor, height: CGFloat(imageRef.height)/factor))
    }
    
    static func screenshot() -> NSImage? {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else { return nil }
        let frame = screen.frame
        let image = CGDisplayCreateImage(CGMainDisplayID(), rect: frame)!
        return NSImage(cgImage: image, size: frame.size)
    }
    
    func saveToFile(_ url: URL) {
        if let tiffData = self.tiffRepresentation,
           let imageRep = NSBitmapImageRep(data: tiffData) {
            let pngData = imageRep.representation(using: .png, properties: [:])
            do {
                try pngData?.write(to: url)
            } catch {
                print("Error saving image: \(error.localizedDescription)")
            }
        }
    }
    
    func trim(rect: CGRect) -> NSImage {
        let result = NSImage(size: rect.size)
        result.lockFocus()

        let destRect = CGRect(origin: .zero, size: result.size)
        self.draw(in: destRect, from: rect, operation: .copy, fraction: 1.0)

        result.unlockFocus()
        return result
    }
}

enum AudioQuality: Int { case normal = 128, good = 192, high = 256, extreme = 320 }

enum AudioFormat: String { case aac, alac, flac, opus, mp3 }

enum VideoFormat: String { case mov, mp4 }

enum PixFormat: String { case delault, yuv420p8v, yuv420p8f, yuv420p10v, yuv420p10f, bgra32 }

enum ColSpace: String { case delault, srgb, p3, bt709, bt2020 }

enum Encoder: String { case h264, h265 }

enum StreamType: Int { case screen, window, windows, application, screenarea, systemaudio, idevice, camera }

enum BackgroundType: String { case wallpaper, clear, black, white, red, green, yellow, orange, gray, blue, custom }
