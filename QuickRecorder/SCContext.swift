//
//  SCContext.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/16.
//

import AVFAudio
import AVFoundation
import Foundation
import ScreenCaptureKit

class SCContext {
    static var isPaused = false
    static var screenArea: NSRect?
    static let audioEngine = AVAudioEngine()
    static var backgroundColor: CGColor = CGColor.black
    static var recordMic = false
    static var filePath: String!
    static var audioFile: AVAudioFile?
    static var vW: AVAssetWriter!
    static var vwInput, awInput, micInput: AVAssetWriterInput!
    static var startTime: Date?
    static var timePassed: TimeInterval = 0
    static var stream: SCStream!
    static var screen: SCDisplay?
    static var window: [SCWindow]?
    static var application: [SCRunningApplication]?
    static var streamType: StreamType?
    static var availableContent: SCShareableContent?
    static let excludedApps = ["", "com.apple.dock", "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.systemuiserver", "com.apple.WindowManager", "dev.mnpn.Azayaka", "com.gaosun.eul", "com.pointum.hazeover", "net.matthewpalmer.Vanilla", "com.dwarvesv.minimalbar", "com.bjango.istatmenus.status"]
    
    static func updateAvailableContent(completion: @escaping () -> Void) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            if let error = error {
                switch error {
                case SCStreamError.userDeclined: requestPermissions()
                default: print("Error: failed to fetch available content: ".local, error.localizedDescription)
                }
                return
            }
            availableContent = content
            assert(availableContent?.displays.isEmpty != nil, "There needs to be at least one display connected!".local)
            completion()
        }
    }
    
    static func getSelf() -> SCRunningApplication? {
        return getApps(isOnScreen: false, hideSelf: false).first(where: { Bundle.main.bundleIdentifier == $0.bundleIdentifier })
    }
    
    static func getApps(isOnScreen: Bool = true, hideSelf: Bool = true) -> [SCRunningApplication] {
        var apps = [SCRunningApplication]()
        for app in getWindows(isOnScreen: isOnScreen, hideSelf: hideSelf).map({ $0.owningApplication }) {
            if !apps.contains(app!) { apps.append(app!) }
        }
        if hideSelf && UserDefaults.standard.bool(forKey: "hideSelf") { apps = apps.filter({$0.bundleIdentifier != Bundle.main.bundleIdentifier}) }
        return apps
    }
    
    static func getWindows(isOnScreen: Bool = true, hideSelf: Bool = true) -> [SCWindow] {
        var windows = [SCWindow]()
        windows = availableContent!.windows.filter {
            guard let app =  $0.owningApplication,
                  let title = $0.title else {//, !title.isEmpty else {
                return false
            }
            return !excludedApps.contains(app.bundleIdentifier)
            && !title.contains("Item-0")
            && title != "Window"
            && $0.frame.width > 40
            && $0.frame.height > 40
        }
        if isOnScreen { windows = windows.filter({$0.isOnScreen == true}) }
        if hideSelf && UserDefaults.standard.bool(forKey: "hideSelf") { windows = windows.filter({$0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier}) }
        return windows
    }
    
    static func getAppIcon(_ app: SCRunningApplication) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 69, height: 69)
            return icon
        }
        let icon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "blank icon")
        icon!.size = NSSize(width: 69, height: 69)
        return icon
    }
    
    static func getSCDisplayWithMouse() -> SCDisplay? {
        if let displays = availableContent?.displays {
            for display in displays {
                if let currentDisplayID = getScreenWithMouse()?.displayID {
                    if display.displayID == currentDisplayID {
                        return display
                    }
                }
            }
        }
        return nil
    }
    
    static func getBackgroundColor() -> CGColor {
        let color = UserDefaults.standard.string(forKey: "background")
        if color == BackgroundType.wallpaper.rawValue { return CGColor.black }
        switch color {
        case "black": backgroundColor = CGColor.black
        case "white": backgroundColor = CGColor.white
        case "gray": backgroundColor = NSColor.systemGray.cgColor
        case "yellow": backgroundColor = NSColor.systemYellow.cgColor
        case "orange": backgroundColor = NSColor.systemOrange.cgColor
        case "green": backgroundColor = NSColor.systemGreen.cgColor
        case "blue": backgroundColor = NSColor.systemBlue.cgColor
        case "red": backgroundColor = NSColor.systemRed.cgColor
        default: backgroundColor = UserDefaults.standard.cgColor(forKey: "userColor") ?? CGColor.black
        }
        return backgroundColor
    }
    
    static func performMicCheck() async {
        guard UserDefaults.standard.bool(forKey: "recordMic") == true else { return }
        if await AVCaptureDevice.requestAccess(for: .audio) { return }

        UserDefaults.standard.setValue(false, forKey: "recordMic")
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permission Required".local
            alert.informativeText = "QuickRecorder needs permission to record your microphone.".local
            alert.addButton(withTitle: "Open Settings".local)
            alert.addButton(withTitle: "Quit".local)
            alert.alertStyle = .critical
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
        }
    }
    
    static func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
        return screenWithMouse
    }
    
    private static func requestPermissions() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permission Required".local
            alert.informativeText = "QuickRecorder needs screen recording permissions, even if you only intend on recording audio.".local
            alert.addButton(withTitle: "Open Settings".local)
            alert.addButton(withTitle: "Quit".local)
            alert.alertStyle = .critical
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
            NSApp.terminate(self)
        }
    }
    
}
