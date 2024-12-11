//
//  AppleScript.swift
//  QuickRecorder
//
//  Created by apple on 2024/9/23.
//

import Foundation
import AppKit
import ScreenCaptureKit

class selectScreen: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if SCContext.stream != nil {
            createAlert(title: "Error".local, message: "Already recording!".local, button1: "OK".local).runModal()
            return nil
        }
        SCContext.updateAvailableContent { _ in
            DispatchQueue.main.async {
                closeAllWindow()
                if var index = self.evaluatedArguments!["index"] as? Int {
                    guard let screens = SCContext.availableContent?.displays else { return }
                    index -= 1
                    closeAllWindow()
                    if index >= screens.count || index < 0 {
                        createAlert(title: "Error".local, message: "Invalid screen number!".local, button1: "OK".local).runModal()
                        return
                    } else {
                        let screen = screens[index]
                        AppDelegate.shared.createCountdownPanel(screen: screen) {
                            AppDelegate.shared.prepRecord(type: "display", screens: screen, windows: nil, applications: nil)
                        }
                    }
                } else {
                    closeAllWindow()
                    AppDelegate.shared.createNewWindow(view: ScreenSelector(), title: "Screen Selector".local)
                }
            }
        }
        return nil
    }
}

class selectArea: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if SCContext.stream != nil {
            createAlert(title: "Error".local, message: "Already recording!".local, button1: "OK".local).runModal()
            return nil
        }
        SCContext.updateAvailableContent { _ in
            DispatchQueue.main.async {
                closeAllWindow()
                DispatchQueue.main.async {
                    AppDelegate.shared.showAreaSelector(size: NSSize(width: 600, height: 450))
                    var currentDisplay = SCContext.getSCDisplayWithMouse()
                    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .rightMouseDown, .leftMouseDown, .otherMouseDown]) { event in
                        let display = SCContext.getSCDisplayWithMouse()
                        if display != currentDisplay {
                            currentDisplay = display
                            closeAllWindow()
                            AppDelegate.shared.showAreaSelector(size: NSSize(width: 600, height: 450))
                        }
                    }
                }
            }
        }
        return nil
    }
}

class selectApps: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if SCContext.stream != nil {
            createAlert(title: "Error".local, message: "Already recording!".local, button1: "OK".local).runModal()
            return nil
        }
        SCContext.updateAvailableContent { _ in
            DispatchQueue.main.async {
                closeAllWindow()
                if let name = self.evaluatedArguments!["name"] as? String {
                    guard let app = SCContext.availableContent?.applications.first(where: { $0.applicationName == name }) else {
                        createAlert(title: "Error".local, message: "No such application!".local, button1: "OK".local).runModal()
                        return
                    }
                    closeAllWindow()
                    guard let screens = SCContext.availableContent?.displays else { return }
                    guard let windows = SCContext.availableContent?.windows.filter({
                        guard let title = $0.title else { return false }
                        return !title.contains("Item-0")
                        && title != "Window"
                        && $0.frame.width > 40
                        && $0.frame.height > 40
                    }) else { return }
                    var s = [SCDisplay]()
                    for screen in screens {
                        for w in windows {
                            if NSIntersectsRect(screen.frame, w.frame) { if !s.contains(screen) { s.append(screen) }}
                        }
                    }
                    if s.isEmpty {
                        createAlert(title: "Error".local, message: "This application has no windows!".local, button1: "OK".local).runModal()
                        return
                    }
                    if s.count != 1 {
                        AppDelegate.shared.createNewWindow(view: AppSelector(), title: "App Selector".local)
                        createAlert(title: "Error".local, message: "This app exists in multiple screens, please select it manually!".local, button1: "OK".local).runModal()
                    } else {
                        AppDelegate.shared.createCountdownPanel(screen: s.first!) {
                            AppDelegate.shared.prepRecord(type: "application", screens: s.first!, windows: nil, applications: [app])
                        }
                    }
                } else {
                    closeAllWindow()
                    AppDelegate.shared.createNewWindow(view: AppSelector(), title: "App Selector".local)
                }
            }
        }
        return nil
    }
}

class selectWindows: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if SCContext.stream != nil {
            createAlert(title: "Error".local, message: "Already recording!".local, button1: "OK".local).runModal()
            return nil
        }
        SCContext.updateAvailableContent { _ in
            DispatchQueue.main.async {
                closeAllWindow()
                if let title = self.evaluatedArguments!["title"] as? String {
                    var windows = [SCWindow]()
                    guard let w = SCContext.availableContent?.windows.filter({ $0.title == title }) else { return }
                    windows = w
                    if let app = self.evaluatedArguments!["app"] as? String {
                        guard let w = SCContext.availableContent?.windows.filter({ $0.title == title && $0.owningApplication?.applicationName == app }) else { return }
                        windows = w
                    }
                    closeAllWindow()
                    if windows.isEmpty {
                        createAlert(title: "Error".local, message: "No such window!".local, button1: "OK".local).runModal()
                        return
                    }
                    if windows.count > 1 {
                        AppDelegate.shared.createNewWindow(view: WinSelector(), title: "Window Selector".local)
                        createAlert(title: "Error".local, message: "Duplicate window exists, please select it manually!".local, button1: "OK".local).runModal()
                        return
                    }
                    let window = windows.first!
                    guard let screens = SCContext.availableContent?.displays else { return }
                    var s = [SCDisplay]()
                    for screen in screens {
                        if NSIntersectsRect(screen.frame, window.frame) { if !s.contains(screen) { s.append(screen) }}
                    }
                    if s.isEmpty {
                        createAlert(title: "Error".local, message: "Unable to find the screen this window belongs to!".local, button1: "OK".local).runModal()
                        return
                    }
                    if let display = SCContext.getSCDisplayWithMouse() {
                        if s.contains(display) {
                            AppDelegate.shared.createCountdownPanel(screen: display) {
                                AppDelegate.shared.prepRecord(type: "window" , screens: s.first!, windows: [window], applications: nil)
                            }
                        } else {
                            AppDelegate.shared.createCountdownPanel(screen: s.first!) {
                                AppDelegate.shared.prepRecord(type: "window" , screens: s.first!, windows: [window], applications: nil)
                            }
                        }
                    }
                } else {
                    closeAllWindow()
                    AppDelegate.shared.createNewWindow(view: WinSelector(), title: "Window Selector".local)
                }
            }
        }
        return nil
    }
}

class recordAudio: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if SCContext.stream != nil {
            createAlert(title: "Error".local, message: "Already recording!".local, button1: "OK".local).runModal()
            return nil
        }
        SCContext.updateAvailableContent { _ in
            DispatchQueue.main.async {
                let m = UserDefaults.standard.bool(forKey: "recordMic")
                if let mic = self.evaluatedArguments!["mic"] as? Bool {
                    UserDefaults.standard.set(mic, forKey: "recordMic")
                }
                closeAllWindow()
                AppDelegate.shared.prepRecord(type: "audio", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil)
                UserDefaults.standard.set(m, forKey: "recordMic")
            }
        }
        return nil
    }
}

class setPreferences: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if SCContext.stream != nil {
            createAlert(title: "Error".local, message: "Already recording!".local, button1: "OK".local).runModal()
            return nil
        }
        if let hires = self.evaluatedArguments!["hires"] as? Bool { UserDefaults.standard.set(hires, forKey: "highRes") }
        if let fps = self.evaluatedArguments!["fps"] as? Int { UserDefaults.standard.set(fps, forKey: "frameRate") }
        if let cursor = self.evaluatedArguments!["cursor"] as? Bool { UserDefaults.standard.set(cursor, forKey: "showMouse") }
        if let sound = self.evaluatedArguments!["sound"] as? Bool { UserDefaults.standard.set(sound, forKey: "recordWinSound") }
        if let microphone = self.evaluatedArguments!["microphone"] as? Bool { UserDefaults.standard.set(microphone, forKey: "recordMic") }
        if let quality = self.evaluatedArguments!["quality"] as? Int {
            if [1,2,3].contains(quality) {
                switch quality {
                    case 1: UserDefaults.standard.set(0.3, forKey: "videoQuality")
                    case 2: UserDefaults.standard.set(0.7, forKey: "videoQuality")
                    default: UserDefaults.standard.set(1.0, forKey: "videoQuality")
                }
            }
        }
        if let micname = self.evaluatedArguments!["micname"] as? String {
            if SCContext.getMicrophone().map({$0.localizedName}).contains(micname) || micname == "default" {
                UserDefaults.standard.set(micname, forKey: "micDevice")
            }
        }
        if let hdr = self.evaluatedArguments!["hdr"] as? Bool {
            if #available(macOS 15.0, *) {
                UserDefaults.standard.set(hdr, forKey: "recordHDR")
            }
        }
        return nil
    }
}
