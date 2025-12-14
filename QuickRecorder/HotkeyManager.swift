import Foundation
import AppKit
import KeyboardShortcuts

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var saveReplayHandler: (() -> Void)?
    private var quickClipHandler: (() -> Void)?

    private init() {}

    func registerAllShortcuts(appDelegate: AppDelegate) {
        KeyboardShortcuts.onKeyDown(for: .showPanel) {
            _ = appDelegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true)
            if SCContext.stream == nil { NSApp.activate(ignoringOtherApps: true) }
        }
        KeyboardShortcuts.onKeyDown(for: .saveFrame) { if SCContext.stream != nil { SCContext.saveFrame = true }}
        KeyboardShortcuts.onKeyDown(for: .screenMagnifier) { if SCContext.stream != nil { SCContext.isMagnifierEnabled.toggle() }}
        KeyboardShortcuts.onKeyDown(for: .stop) { if SCContext.stream != nil { SCContext.stopRecording() }}
        KeyboardShortcuts.onKeyDown(for: .pauseResume) { if SCContext.stream != nil { SCContext.pauseRecording() }}

        KeyboardShortcuts.onKeyDown(for: .startWithAudio) {
            if SCContext.streamType != nil { return }
            closeAllWindow()
            appDelegate.prepRecord(type: "audio", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil, fastStart: true)
        }
        KeyboardShortcuts.onKeyDown(for: .startWithScreen) {
            if SCContext.stream != nil { return }
            closeAllWindow()
            appDelegate.prepRecord(type: "display", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil, fastStart: true)
        }
        KeyboardShortcuts.onKeyDown(for: .startWithArea) {
            if SCContext.stream != nil { return }
            closeAllWindow()
            appDelegate.showAreaSelector(size: NSSize(width: 600, height: 450))
        }
        KeyboardShortcuts.onKeyDown(for: .startWithWindow) {
            if SCContext.stream != nil { return }
            closeAllWindow()
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            if let pid = frontmostApp?.processIdentifier {
                guard let scWindow = SCContext.getWindows().first(where: { $0.owningApplication?.processID == pid && $0.title != "" && $0.isOnScreen }) else { return }
                appDelegate.prepRecord(type: "window", screens: SCContext.getSCDisplayWithMouse(), windows: [scWindow], applications: nil, fastStart: true)
                return
            }
        }
    }

    func registerReplayHotkeys(durationProvider: @escaping () -> Double,
                               exporter: ClipExporter = ReplayBufferService.shared.exporter,
                               resultHandler: @escaping (Result<URL, Error>) -> Void,
                               unavailableHandler: (() -> Void)? = nil) {
        saveReplayHandler = { [weak exporter] in
            guard ReplayBufferService.shared.health == .running else {
                unavailableHandler?()
                return
            }
            let seconds = durationProvider()
            exporter?.exportLast(seconds: seconds) { result in
                resultHandler(result)
            }
        }
        quickClipHandler = { [weak exporter] in
            guard ReplayBufferService.shared.health == .running else {
                unavailableHandler?()
                return
            }
            exporter?.quickFive { result in
                resultHandler(result)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .saveReplay) { [weak self] in
            self?.saveReplayHandler?()
        }
        KeyboardShortcuts.onKeyDown(for: .saveReplayQuick) { [weak self] in
            self?.quickClipHandler?()
        }
    }

    // Exposed for tests to simulate repeat presses without macOS event taps
    func triggerSaveReplay() {
        saveReplayHandler?()
    }

    func triggerQuickClip() {
        quickClipHandler?()
    }

#if DEBUG
    func injectHandlersForTesting(save: (() -> Void)?, quick: (() -> Void)?) {
        saveReplayHandler = save
        quickClipHandler = quick
    }
#endif
}
