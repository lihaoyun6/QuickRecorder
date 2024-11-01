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
import UserNotifications
import SwiftLAME

class SCContext {
    static var autoStop = 0
    static var recordCam = ""
    static var recordDevice = ""
    static var captureSession: AVCaptureSession!
    static var previewSession: AVCaptureSession!
    static var frameCache: CMSampleBuffer?
    static var filter: SCContentFilter?
    //static var audioSettings: [String : Any]!
    static var isMagnifierEnabled = false
    static var saveFrame = false
    static var isPaused = false
    static var isResume = false
    static var isSkipFrame = false
    static var lastPTS: CMTime?
    static var timeOffset = CMTimeMake(value: 0, timescale: 0)
    static var screenArea: NSRect?
    static let audioEngine = AVAudioEngine()
    static var backgroundColor: CGColor = CGColor.black
    //static var recordMic = false
    static var filePath: String!
    static var filePath1: String!
    static var filePath2: String!
    static var audioFile: AVAudioFile?
    static var audioFile2: AVAudioFile?
    static var vW: AVAssetWriter!
    static var vwInput, awInput, micInput: AVAssetWriterInput!
    //static var vwInputAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    static var startTime: Date?
    static var timePassed: TimeInterval = 0
    static var stream: SCStream!
    static var screen: SCDisplay?
    static var window: [SCWindow]?
    static var application: [SCRunningApplication]?
    static var streamType: StreamType?
    //static var previewType: StreamType?
    static var availableContent: SCShareableContent?
    static let excludedApps = ["", "com.apple.dock", "com.apple.screencaptureui", "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.systemuiserver", "com.apple.WindowManager", "dev.mnpn.Azayaka", "com.gaosun.eul", "com.pointum.hazeover", "net.matthewpalmer.Vanilla", "com.dwarvesv.minimalbar", "com.bjango.istatmenus.status"]
    
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
        return SCContext.availableContent!.applications.first(where: { Bundle.main.bundleIdentifier == $0.bundleIdentifier })
    }
    
    static func getSelfWindows() -> [SCWindow]? {
        return SCContext.availableContent!.windows.filter( {
            guard let title = $0.title else { return false }
            return $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            && title != "Mouse Pointer".local
            && title != "Screen Magnifier".local
            && title != "Camera Overlayer".local
            && title != "iDevice Overlayer".local
        })
    }
    
    static func getApps(isOnScreen: Bool = true, hideSelf: Bool = true) -> [SCRunningApplication] {
        var apps = [SCRunningApplication]()
        for app in getWindows(isOnScreen: isOnScreen, hideSelf: hideSelf).map({ $0.owningApplication }) {
            if !apps.contains(app!) { apps.append(app!) }
        }
        if hideSelf && ud.bool(forKey: "hideSelf") { apps = apps.filter({$0.bundleIdentifier != Bundle.main.bundleIdentifier}) }
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
        if hideSelf && ud.bool(forKey: "hideSelf") { windows = windows.filter({$0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier}) }
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
    
    static func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screenWithMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
        return screenWithMouse
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
    
    /*static func getColorSpace() -> CFString? {
        switch ud.string(forKey: "colorSpace") {
        case ColSpace.srgb.rawValue: return CGColorSpace.sRGB
        case ColSpace.bt709.rawValue: return CGColorSpace.itur_709
        case ColSpace.bt2020.rawValue: return CGColorSpace.itur_2020
        case ColSpace.p3.rawValue: return CGColorSpace.displayP3
        default: return nil
        }
    }
    
    static func getPixelFormat() -> OSType? {
        switch ud.string(forKey: "pixelFormat") {
        case PixFormat.bgra32.rawValue: return kCVPixelFormatType_32BGRA
        case PixFormat.yuv420p8v.rawValue: return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case PixFormat.yuv420p8f.rawValue: return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        case PixFormat.yuv420p10v.rawValue: return kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        case PixFormat.yuv420p10f.rawValue: return kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
        default: return nil
        }
    }*/
    
    static func getFilePath(capture: Bool = false) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
        return ud.string(forKey: "saveDirectory")! + (capture ? "/Capturing at ".local : "/Recording at ".local) + dateFormatter.string(from: Date())
    }
    
    static func updateAudioSettings(format: String = ud.string(forKey: "audioFormat") ?? "", rate: Int = 48000) -> [String : Any] {
        var audioSettings: [String : Any] = [AVSampleRateKey : rate, AVNumberOfChannelsKey : 2] // reset audioSettings
        var bitRate = ud.integer(forKey: "audioQuality") * 1000
        if rate < 44100 { bitRate = min(64000, bitRate / 2) }
        switch format {
        case AudioFormat.mp3.rawValue: fallthrough
        case AudioFormat.aac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] = bitRate
        case AudioFormat.alac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatAppleLossless
            audioSettings[AVEncoderBitDepthHintKey] = 16
        case AudioFormat.flac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatFLAC
        case AudioFormat.opus.rawValue:
            audioSettings[AVFormatIDKey] = ud.string(forKey: "videoFormat") != VideoFormat.mp4.rawValue ? kAudioFormatOpus : kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] =  bitRate
        default:
            assertionFailure("unknown audio format while setting audio settings: ".local + (ud.string(forKey: "audioFormat") ?? "[no defaults]".local))
        }
        return audioSettings
    }
    
    static func getBackgroundColor() -> CGColor {
        let color = ud.string(forKey: "background")
        if color == BackgroundType.wallpaper.rawValue { return CGColor.black }
        switch color {
            case "clear": backgroundColor = CGColor.clear
            case "black": backgroundColor = CGColor.black
            case "white": backgroundColor = CGColor.white
            case "gray": backgroundColor = NSColor.systemGray.cgColor
            case "yellow": backgroundColor = NSColor.systemYellow.cgColor
            case "orange": backgroundColor = NSColor.systemOrange.cgColor
            case "green": backgroundColor = NSColor.systemGreen.cgColor
            case "blue": backgroundColor = NSColor.systemBlue.cgColor
            case "red": backgroundColor = NSColor.systemRed.cgColor
            default: backgroundColor = ud.cgColor(forKey: "userColor") ?? CGColor.black
        }
        return backgroundColor
    }
    
    static func performMicCheck() async {
        guard ud.bool(forKey: "recordMic") == true else { return }
        if await AVCaptureDevice.requestAccess(for: .audio) { return }

        ud.setValue(false, forKey: "recordMic")
        DispatchQueue.main.async {
            let alert = AppDelegate.shared.createAlert(title: "Permission Required",
                                                       message: "QuickRecorder needs permission to record your microphone.",
                                                       button1: "Open Settings",
                                                       button2: "Quit")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
        }
    }
    
    private static func requestPermissions() {
        DispatchQueue.main.async {
            let alert = AppDelegate.shared.createAlert(title: "Permission Required",
                                                       message: "QuickRecorder needs screen recording permissions, even if you only intend on recording audio.",
                                                       button1: "Open Settings",
                                                       button2: "Quit")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
            NSApp.terminate(self)
        }
    }
    
    static func getWallpaper(_ display: SCDisplay) -> NSImage? {
        guard let screen = display.nsScreen else { return nil }
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        do {
            var wallpaper: NSImage?
            try wallpaper = NSImage(data: Data(contentsOf: url))
            if let w = wallpaper { return w }
        } catch {
            print("load wallpaper error: \(error)")
        }
        return nil
    }
    
    static func getRecordingSize() -> String {
        do {
            if let filePath = filePath {
                let fileAttr = try FileManager.default.attributesOfItem(atPath: filePath)
                let byteFormat = ByteCountFormatter()
                byteFormat.allowedUnits = [.useMB]
                byteFormat.countStyle = .file
                return byteFormat.string(fromByteCount: fileAttr[FileAttributeKey.size] as! Int64)
            }
        } catch {
            print(String(format: "failed to fetch file for size indicator: %@".local, error.localizedDescription))
        }
        return "Unknown".local
    }
    
    static func getRecordingLength() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        if isPaused { return formatter.string(from: timePassed) ?? "Unknown".local }
        timePassed = Date.now.timeIntervalSince(startTime ?? Date.now)
        return formatter.string(from: timePassed) ?? "Unknown".local
    }
    
    static func isCameraRunning() -> Bool {
        var preview = false
        var capture = false
        if let session = previewSession { preview = session.isRunning }
        if let session = captureSession { capture = session.isRunning }
        return (preview || capture)
    }
    
    static func pauseRecording() {
        isPaused.toggle()
        if !isPaused {
            isResume = true
            startTime = Date.now.addingTimeInterval(-1) - SCContext.timePassed
        }
    }
    
    static func stopRecording() {
        //statusBarItem.isVisible = false
        autoStop = 0
        lastPTS = nil
        recordCam = ""
        recordDevice = ""
        isMagnifierEnabled = false
        mousePointer.orderOut(nil)
        screenMagnifier.orderOut(nil)
        AppDelegate.shared.stopGlobalMouseMonitor()

        if let w = NSApplication.shared.windows.first(where:  { $0.title == "Area Overlayer".local }) { w.close() }
        
        if stream != nil { stream.stopCapture() }
        stream = nil
        if ud.bool(forKey: "recordMic") {
            if streamType != .systemaudio { micInput.markAsFinished() }
            AudioRecorder.shared.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            DispatchQueue.global().async {
                try? audioEngine.inputNode.setVoiceProcessingEnabled(false)
            }
        }
        if streamType != .systemaudio {
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            vwInput.markAsFinished()
            if #available(macOS 13, *) { awInput.markAsFinished() }
            vW.finishWriting {
                startTime = nil
                if vW.status != .completed {
                    print("Video writing failed with status: \(vW.status), error: \(String(describing: vW.error))")
                    let err = vW.error?.localizedDescription ?? "Unknow Error"
                    showNotification(title: "Failed to save file".local, body: "\(err)", id: "quickrecorder.error.\(UUID().uuidString)")
                } else {
                    if ud.bool(forKey: "recordMic") && ud.bool(forKey: "recordWinSound") && ud.bool(forKey: "remuxAudio") {
                        mixAudioTracks(videoURL: URL(fileURLWithPath: filePath)) { result in
                            switch result {
                            case .success(let url):
                                print("Exported video to \(String(describing: url.path))")
                                showNotification(title: "Recording Completed".local, body: String(format: "File saved to: %@".local, url.path), id: "quickrecorder.completed.\(UUID().uuidString)")
                                if ud.bool(forKey: "trimAfterRecord") {
                                    DispatchQueue.main.async {
                                        AppDelegate.shared.createNewWindow(view: VideoTrimmerView(videoURL: url), title: url.lastPathComponent, only: false)
                                    }
                                }
                            case .failure(let error):
                                print("Failed to export video: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                dispatchGroup.leave()
            }
            dispatchGroup.wait()
        }
        
        DispatchQueue.main.async {
            controlPanel.close()
            if isCameraRunning() {
                if camWindow.isVisible { camWindow.close() }
                if deviceWindow.isVisible { deviceWindow.close() }
                if let preview = previewSession { preview.stopRunning() }
                if let capture = captureSession { capture.stopRunning() }
            }
        }
        
        audioFile = nil // close audio file
        audioFile2 = nil // close audio file2
        if streamType == .systemaudio {
            if ud.string(forKey: "audioFormat") == AudioFormat.mp3.rawValue && !ud.bool(forKey: "recordMic") {
                Task {
                    let outPutUrl = URL(fileURLWithPath: String(filePath.dropLast(4)) + ".mp3")
                    do {
                        let title = "Recording Completed".local
                        let body = String(format: "File saved to: %@".local, outPutUrl.path.removingPercentEncoding!)
                        let id = "quickrecorder.completed.\(UUID().uuidString)"
                        try await m4a2mp3(inputUrl: URL(fileURLWithPath: filePath1), outputUrl: outPutUrl)
                        try? FileManager.default.removeItem(atPath: filePath1)
                        /*if ud.bool(forKey: "recordMic") {
                            let outPutUrl2 = URL(fileURLWithPath: String(filePath2.dropLast(4)) + ".mp3")
                            try await m4a2mp3(inputUrl: URL(fileURLWithPath: filePath2), outputUrl: outPutUrl2)
                            try? FileManager.default.removeItem(atPath: filePath2)
                            body = String(format: "File saved to: %@".local, filePath.removingPercentEncoding!)
                        }*/
                        showNotification(title: title, body: body, id: id)
                    } catch {
                        showNotification(title: "Failed to save file".local, body: "\(error.localizedDescription)", id: "quickrecorder.error.\(UUID().uuidString)")
                    }
                }
            } else {
                let title = "Recording Completed".local
                var body = String(format: "File saved to folder: %@".local, ud.string(forKey: "saveDirectory")!)
                if let filePath = filePath { body = String(format: "File saved to: %@".local, filePath) }
                let id = "quickrecorder.completed.\(UUID().uuidString)"
                showNotification(title: title, body: body, id: id)
                if ud.bool(forKey: "remuxAudio") {
                    let fileURL = URL(fileURLWithPath: filePath)
                    let document = try? qmaPackageHandle.load(from: fileURL)
                    if let document = document {
                        let audioPlayerManager = AudioPlayerManager()
                        audioPlayerManager.loadAudioFiles(format: document.info.format, package: fileURL, encoder: document.info.encoder, saveMP3: document.info.exportMP3)
                        audioPlayerManager.sysVol = document.info.sysVol
                        audioPlayerManager.micVol = document.info.micVol
                        let exportMP3 = document.info.exportMP3
                        let format = exportMP3 ? "mp3" : document.info.format
                        let saveURL = fileURL.deletingPathExtension().appendingPathExtension(format)
                        audioPlayerManager.saveFile(saveURL, saveAsMP3: exportMP3)
                    }
                }
            }
        }
        
        isPaused = false
        hideMousePointer = false
        window = nil
        screen = nil
        startTime = nil
        AppDelegate.shared.presenterType = "OFF"
        AppDelegate.shared.updateStatusBar()
        
        if !(ud.bool(forKey: "recordMic") && ud.bool(forKey: "recordWinSound") && ud.bool(forKey: "remuxAudio")) && streamType != .systemaudio {
            let title = "Recording Completed".local
            var body = String(format: "File saved to folder: %@".local, ud.string(forKey: "saveDirectory")!)
            if let filePath = filePath { body = String(format: "File saved to: %@".local, filePath) }
            let id = "quickrecorder.completed.\(UUID().uuidString)"
            if let vW = vW {
                if vW.status == .completed {
                    showNotification(title: title, body: body, id: id)
                    trimVideo()
                }
            } else {
                showNotification(title: title, body: body, id: id)
                trimVideo()
            }
        }
        
        streamType = nil
    }
    
    static func m4a2mp3(inputUrl: URL, outputUrl: URL) async throws {
        let progress = Progress()
        let lameEncoder = try SwiftLameEncoder(
            sourceUrl: inputUrl,
            configuration: .init(
                sampleRate: .custom(48000),
                bitrateMode: .constant(Int32(ud.integer(forKey: "audioQuality"))),
                quality: .nearBest
            ),
            destinationUrl: outputUrl,
            progress: progress // optional
        )
        try await lameEncoder.encode(priority: .userInitiated)
    }
    
    static func trimVideo() {
        if ud.bool(forKey: "trimAfterRecord") {
            let fileURL = URL(fileURLWithPath: filePath)
            AppDelegate.shared.createNewWindow(view: VideoTrimmerView(videoURL: fileURL), title: fileURL.lastPathComponent, only: false)
        }
    }
    
    static func getCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: .video, position: .unspecified)
        return discoverySession.devices
    }
    
    static func getMicrophone() -> [AVCaptureDevice] {
        var discoverySession: AVCaptureDevice.DiscoverySession
        if #available(macOS 15.0, *) {
            discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .microphone], mediaType: .audio, position: .unspecified)
        } else {
            discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified)
        }
        return discoverySession.devices.filter({ !$0.localizedName.contains("CADefaultDeviceAggregate") })
    }
    
    static func getiDevice() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown], mediaType: .muxed, position: .unspecified)
        return discoverySession.devices
    }
    
    static func getCurrentMic() -> AVCaptureDevice? {
        let deviceName = ud.string(forKey: "micDevice")
        if deviceName == "Default" {
            
        }
        return getMicrophone().first(where: { $0.localizedName == ud.string(forKey: "micDevice") })
    }
    
    static func getSampleRate(for device: AVCaptureDevice) -> Int? {
        let activeFormat = device.activeFormat
        let description = activeFormat.formatDescription
        
        if let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee {
            let sampleRate = audioStreamBasicDescription.mSampleRate
            return Int(sampleRate)
        } else {
            return nil
        }
    }
    
    static func getDefaultSampleRate() -> Int? {
        var deviceID = AudioObjectID(0)
        var propertySize = UInt32(MemoryLayout.size(ofValue: deviceID))
        
        // 获取默认音频输入设备
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            print("Failed to get default audio input device")
            return nil
        }
        
        // 获取采样率
        var sampleRate: Double = 0
        propertySize = UInt32(MemoryLayout.size(ofValue: sampleRate))
        
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let sampleRateStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &sampleRate
        )
        
        guard sampleRateStatus == noErr else {
            print("Failed to get sample rate for the default input device")
            return nil
        }
        
        return Int(sampleRate)
    }
    
    static func adjustTime(sample: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        guard CMSampleBufferGetFormatDescription(sample) != nil else { return nil }
        
        var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: Int(CMSampleBufferGetNumSamples(sample)))
        CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: timingInfo.count, arrayToFill: &timingInfo, entriesNeededOut: nil)
        
        for i in 0..<timingInfo.count {
            timingInfo[i].decodeTimeStamp = CMTimeSubtract(timingInfo[i].decodeTimeStamp, offset)
            timingInfo[i].presentationTimeStamp = CMTimeSubtract(timingInfo[i].presentationTimeStamp, offset)
        }
        
        var outSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: timingInfo.count, sampleTimingArray: &timingInfo, sampleBufferOut: &outSampleBuffer)
        
        return outSampleBuffer
    }
    
    static func showNotification(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Notification failed to send：\(error.localizedDescription)") }
        }
    }
    
    static func mixAudioTracks(videoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        showNotification(title: "Still Processing".local, body: "Mixing audio track...".local, id: "quickrecorder.processing.\(UUID().uuidString)")
        
        let asset = AVAsset(url: videoURL)
        let audioOutputURL = videoURL.deletingPathExtension()
        let outputURL = audioOutputURL.deletingPathExtension()
        let audioOnlyComposition = AVMutableComposition()
        
        let fileEnding = ud.string(forKey: "videoFormat") ?? ""
        var fileType: AVFileType?
        switch fileEnding {
        case VideoFormat.mov.rawValue: fileType = AVFileType.mov
        case VideoFormat.mp4.rawValue: fileType = AVFileType.mp4
        default: assertionFailure("loaded unknown video format".local)
        }
        
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard audioTracks.count > 1 else {
            completion(.failure(NSError(domain: "AudioTrackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough audio tracks found."])))
            return
        }
        
        for audioTrack in audioTracks {
            if let compositionAudioTrack = audioOnlyComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                do {
                    try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
                } catch {
                    completion(.failure(NSError(domain: "AudioTrackInsertionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert audio track: \(error.localizedDescription)"])))
                    return
                }
            }
        }
        
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioTracks.map {
            let parameters = AVMutableAudioMixInputParameters(track: $0)
            parameters.trackID = $0.trackID
            return parameters
        }
        
        guard let audioExportSession = AVAssetExportSession(asset: audioOnlyComposition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "AudioExportSessionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio export session."])))
            return
        }
        audioExportSession.outputURL = audioOutputURL
        audioExportSession.outputFileType = fileType ?? .mp4
        audioExportSession.audioMix = audioMix
        
        audioExportSession.exportAsynchronously {
            /*var exportStatus: AVAssetExportSession.Status = .unknown
            
            // Loop until export session is completed, failed, or cancelled
            while exportStatus != .completed && exportStatus != .failed && exportStatus != .cancelled {
                exportStatus = audioExportSession.status
                Thread.sleep(forTimeInterval: 0.1)
            }*/
            
            switch audioExportSession.status {
            case .completed:
                let audioAsset = AVAsset(url: audioOutputURL)
                let composition = AVMutableComposition()
                
                guard let videoTrack = asset.tracks(withMediaType: .video).first,
                      let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    completion(.failure(NSError(domain: "VideoTrackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get video track."])))
                    return
                }
                
                do {
                    try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
                } catch {
                    completion(.failure(NSError(domain: "VideoTrackInsertionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert video track: \(error.localizedDescription)"])))
                    return
                }
                
                let audioTracks = audioAsset.tracks(withMediaType: .audio)
                guard audioTracks.count >= 1 else {
                    completion(.failure(NSError(domain: "AudioTrackError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not enough audio tracks found."])))
                    return
                }
                
                for audioTrack in audioTracks {
                    if let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        do {
                            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
                        } catch {
                            completion(.failure(NSError(domain: "AudioTrackInsertionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert audio track: \(error.localizedDescription)"])))
                            return
                        }
                    }
                }
                
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
                    completion(.failure(NSError(domain: "ExportSessionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])))
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = fileType ?? .mp4
                exportSession.audioMix = audioMix
                
                exportSession.exportAsynchronously {
                    switch exportSession.status {
                    case .completed:
                        let  fileManager = FileManager.default
                        try? fileManager.removeItem(atPath: filePath)
                        try? fileManager.removeItem(atPath: audioOutputURL.path)
                        completion(.success(outputURL))
                    case .failed:
                        completion(.failure(exportSession.error ?? NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed for an unknown reason."])))
                    case .cancelled:
                        completion(.failure(NSError(domain: "ExportCancelled", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled."])))
                    default:
                        break
                    }
                }
            case .failed:
                completion(.failure(audioExportSession.error ?? NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed for an unknown reason."])))
            case .cancelled:
                completion(.failure(NSError(domain: "ExportCancelled", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled."])))
            default:
                break
            }
        }
    }
}
