//
//  RecordEngine.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/17.
//

import Foundation
import UserNotifications
import ScreenCaptureKit
import AVFoundation
import AVFAudio

extension AppDelegate {
    @objc func prepRecord(type: String, screens: SCDisplay?, windows: [SCWindow]?, applications: [SCRunningApplication]?) {
        switch type {
        case "window":  SCContext.streamType = .window
        case "display": SCContext.streamType = .screen
        case "application": SCContext.streamType = .application
        case "area": SCContext.streamType = .screenarea
        case "audio":   SCContext.streamType = .systemaudio
            default: return // if we don't even know what to record I don't think we should even try
        }
        //statusBarItem.menu = nil
        updateAudioSettings()
        // file preparation
        if let screens = screens {
            SCContext.screen = SCContext.availableContent!.displays.first(where: { $0 == screens })
        }
        if let windows = windows {
            SCContext.window = SCContext.availableContent!.windows.filter({ windows.contains($0) })
        }
        if let applications = applications {
            SCContext.application = SCContext.availableContent!.applications.filter({ applications.contains($0) })
        }
        
        let dockApp = SCContext.availableContent!.applications.first(where: { $0.bundleIdentifier.description == "com.apple.dock" })
        let wallpaper = SCContext.availableContent!.windows.filter({ $0.title != "Dock" && $0.owningApplication?.bundleIdentifier == "com.apple.dock" })
        let dockWindow = SCContext.availableContent!.windows.first(where: { $0.title == "Dock" && $0.owningApplication?.bundleIdentifier == "com.apple.dock" })
        let desktopFiles = SCContext.availableContent!.windows.filter({ $0.title == "" && $0.owningApplication?.bundleIdentifier == "com.apple.finder" })
        
        if SCContext.streamType == .window {
            if let allWindow = SCContext.window {
                var includ = allWindow
                if includ.count > 1 {
                    if ud.string(forKey: "background") == BackgroundType.wallpaper.rawValue { if dockApp != nil { includ += wallpaper }}
                    filter = SCContentFilter(display: SCContext.screen!, including: includ)
                } else {
                    filter = SCContentFilter(desktopIndependentWindow: includ[0])
                }
            }
            
        } else {
            if SCContext.streamType == .screen || SCContext.streamType == .screenarea || SCContext.streamType == .systemaudio {
                var excluded = [SCRunningApplication]()
                var except = [SCWindow]()
                if ud.bool(forKey: "hideSelf") { if let qrSelf = SCContext.getSelf() { excluded.append(qrSelf) }}
                if ud.bool(forKey: "removeWallpaper") { if dockApp != nil { except += wallpaper}}
                if ud.bool(forKey: "hideDesktopFiles") { except += desktopFiles }
                filter = SCContentFilter(display: SCContext.screen ?? SCContext.availableContent!.displays.first!, excludingApplications: excluded, exceptingWindows: except)
            }
            if SCContext.streamType == .application {
                var includ = SCContext.application!
                var except = [SCWindow]()
                let withFinder = includ.map{ $0.bundleIdentifier }.contains("com.apple.finder")
                if withFinder && ud.bool(forKey: "hideDesktopFiles") { except += desktopFiles }
                if ud.string(forKey: "background") == BackgroundType.wallpaper.rawValue { if let dock = dockApp { includ.append(dock); except.append(dockWindow!)}}
                filter = SCContentFilter(display: SCContext.screen ?? SCContext.availableContent!.displays.first!, including: includ, exceptingWindows: except)
                
            }
        }
        if SCContext.streamType == .systemaudio {
            prepareAudioRecording()
        }
        Task { await record(audioOnly: SCContext.streamType == .systemaudio, filter: filter!) }

        // while recording, keep a timer which updates the menu's stats
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateMenu()
        }
        RunLoop.current.add(updateTimer!, forMode: .common) // required to have the menu update while open
        updateTimer?.fire()
    }
    
    func getDesktopName() -> String {
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            do {
                var localizedName: AnyObject?
                try (desktopURL as NSURL).getResourceValue(&localizedName, forKey: .localizedNameKey)
                
                if let localizedNameString = localizedName as? String {
                    return localizedNameString
                }
            } catch {
                print("Error：\(error)")
            }
        }
        return "Desktop"
    }

    func record(audioOnly: Bool, filter: SCContentFilter) async {
        let conf = SCStreamConfiguration()
        conf.width = 2
        conf.height = 2
        
        if !audioOnly {
            conf.width = Int(filter.contentRect.width) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
            conf.height = Int(filter.contentRect.height) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
            if ud.integer(forKey: "highRes") == 0 {
                conf.width = Int(conf.width/2)
                conf.height = Int(conf.height/2)
            }
        }

        conf.minimumFrameInterval = CMTime(value: 1, timescale: audioOnly ? CMTimeScale.max : CMTimeScale(ud.integer(forKey: "frameRate")))
        if ud.string(forKey: "background") != BackgroundType.wallpaper.rawValue {
            conf.backgroundColor = SCContext.getBackgroundColor()
        }
        if SCContext.streamType == .screenarea {
            if let nsRect = SCContext.screenArea {
                let newY = SCContext.screen!.frame.height - nsRect.size.height - nsRect.origin.y
                conf.sourceRect = CGRect(x: nsRect.origin.x, y: newY, width: nsRect.size.width, height: nsRect.size.height)
                conf.width = Int(conf.sourceRect.width) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
                conf.height = Int(conf.sourceRect.height) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
                if ud.integer(forKey: "highRes") == 0 {
                    conf.width = Int(conf.width/2)
                    conf.height = Int(conf.height/2)
                }
            }
        }
        conf.showsCursor = ud.bool(forKey: "showMouse")
        conf.capturesAudio = ud.bool(forKey: "recordWinSound")
        conf.sampleRate = audioSettings["AVSampleRateKey"] as! Int
        conf.channelCount = audioSettings["AVNumberOfChannelsKey"] as! Int

        SCContext.stream = SCStream(filter: filter, configuration: conf, delegate: self)
        do {
            try SCContext.stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            try SCContext.stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            if !audioOnly {
                initVideo(conf: conf)
            } else {
                SCContext.startTime = Date.now
            }
            try await SCContext.stream.startCapture()
        } catch {
            assertionFailure("capture failed".local)
            return
        }

        DispatchQueue.main.async { [self] in
            updateIcon()
            //createMenu()
        }
    }
    
    @objc func pauseRecording() {
        SCContext.isPaused.toggle()
        if !SCContext.isPaused {
            SCContext.startTime = Date.now - SCContext.timePassed
        }
    }

    @objc func stopRecording() {
        //statusBarItem.menu = nil
        if let w = NSApplication.shared.windows.first(where:  { $0.title == "Area Overlayer".local }) { w.close() }
        if SCContext.stream != nil {
            SCContext.stream.stopCapture()
        }
        SCContext.stream = nil
        if SCContext.streamType != .systemaudio {
            closeVideo()
        }
        SCContext.streamType = nil
        SCContext.audioFile = nil // close audio file
        SCContext.window = nil
        SCContext.screen = nil
        SCContext.startTime = nil
        updateTimer?.invalidate()

        DispatchQueue.main.async { [self] in
            updateIcon()
            //createMenu()
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Recording Completed".local
        if let filePath = SCContext.filePath {
            content.body = String(format: "File saved to: %@".local, filePath)
        } else {
            content.body = String(format: "File saved to folder: %@".local, ud.string(forKey: "saveDirectory")!)
        }
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "azayaka.completed.\(Date.now)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Notification failed to send：\(error.localizedDescription)") }
        }
    }

    func updateAudioSettings() {
        audioSettings = [AVSampleRateKey : 48000, AVNumberOfChannelsKey : 2] // reset audioSettings
        switch ud.string(forKey: "audioFormat") {
        case AudioFormat.aac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] = ud.integer(forKey: "audioQuality") * 1000
        case AudioFormat.alac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatAppleLossless
            audioSettings[AVEncoderBitDepthHintKey] = 16
        case AudioFormat.flac.rawValue:
            audioSettings[AVFormatIDKey] = kAudioFormatFLAC
        case AudioFormat.opus.rawValue:
            audioSettings[AVFormatIDKey] = ud.string(forKey: "videoFormat") != VideoFormat.mp4.rawValue ? kAudioFormatOpus : kAudioFormatMPEG4AAC
            audioSettings[AVEncoderBitRateKey] =  ud.integer(forKey: "audioQuality") * 1000
        default:
            assertionFailure("unknown audio format while setting audio settings: ".local + (ud.string(forKey: "audioFormat") ?? "[no defaults]".local))
        }
    }

    func prepareAudioRecording() {
        var fileEnding = ud.string(forKey: "audioFormat") ?? "wat"
        switch fileEnding { // todo: I'd like to store format info differently
            case AudioFormat.aac.rawValue: fallthrough
            case AudioFormat.alac.rawValue: fileEnding = "m4a"
            case AudioFormat.flac.rawValue: fileEnding = "flac"
            case AudioFormat.opus.rawValue: fileEnding = "ogg"
        default: assertionFailure("loaded unknown audio format: ".local + fileEnding)
        }
        SCContext.filePath = "\(getFilePath()).\(fileEnding)"
        SCContext.audioFile = try! AVAudioFile(forWriting: URL(fileURLWithPath: SCContext.filePath), settings: audioSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    func getFilePath() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
        return ud.string(forKey: "saveDirectory")! + "/Recording at ".local + dateFormatter.string(from: Date())
    }

    func getRecordingLength() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        if SCContext.isPaused { return formatter.string(from: SCContext.timePassed) ?? "Unknown".local }
        SCContext.timePassed = Date.now.timeIntervalSince(SCContext.startTime ?? Date.now)
        return formatter.string(from: SCContext.timePassed) ?? "Unknown".local
    }

    func getRecordingSize() -> String {
        do {
            if let filePath = SCContext.filePath {
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
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        return deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

extension AppDelegate {
    func initVideo(conf: SCStreamConfiguration) {
        SCContext.startTime = nil

        let fileEnding = ud.string(forKey: "videoFormat") ?? ""
        var fileType: AVFileType?
        switch fileEnding {
            case VideoFormat.mov.rawValue: fileType = AVFileType.mov
            case VideoFormat.mp4.rawValue: fileType = AVFileType.mp4
        default: assertionFailure("loaded unknown video format".local)
        }

        SCContext.filePath = "\(getFilePath()).\(fileEnding)"
        SCContext.vW = try? AVAssetWriter.init(outputURL: URL(fileURLWithPath: SCContext.filePath), fileType: fileType!)
        let encoderIsH265 = ud.string(forKey: "encoder") == Encoder.h265.rawValue
        let fpsMultiplier: Double = Double(ud.integer(forKey: "frameRate"))/8
        let encoderMultiplier: Double = encoderIsH265 ? 0.5 : 0.9
        let targetBitrate = (Double(conf.width) * Double(conf.height) * fpsMultiplier * encoderMultiplier * ud.double(forKey: "videoQuality"))
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: encoderIsH265 ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
            // yes, not ideal if we want more than these encoders in the future, but it's ok for now
            AVVideoWidthKey: conf.width,
            AVVideoHeightKey: conf.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(targetBitrate),
                AVVideoExpectedSourceFrameRateKey: ud.integer(forKey: "frameRate")
            ] as [String : Any]
        ]
        SCContext.recordMic = ud.bool(forKey: "recordMic")
        SCContext.vwInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        SCContext.awInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        SCContext.micInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        SCContext.vwInput.expectsMediaDataInRealTime = true
        SCContext.awInput.expectsMediaDataInRealTime = true
        SCContext.micInput.expectsMediaDataInRealTime = true

        if SCContext.vW.canAdd(SCContext.vwInput) {
            SCContext.vW.add(SCContext.vwInput)
        }

        if SCContext.vW.canAdd(SCContext.awInput) {
            SCContext.vW.add(SCContext.awInput)
        }

        if SCContext.recordMic {
            if SCContext.vW.canAdd(SCContext.micInput) {
                SCContext.vW.add(SCContext.micInput)
            }

            let input = SCContext.audioEngine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.inputFormat(forBus: 0)) {buffer, time in
                if SCContext.micInput.isReadyForMoreMediaData && SCContext.startTime != nil {
                    SCContext.micInput.append(buffer.asSampleBuffer!)
                }
            }
            try! SCContext.audioEngine.start()
        }
        SCContext.vW.startWriting()
    }

    func closeVideo() {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        SCContext.vwInput.markAsFinished()
        SCContext.awInput.markAsFinished()
        if SCContext.recordMic {
            SCContext.micInput.markAsFinished()
            SCContext.audioEngine.inputNode.removeTap(onBus: 0)
            SCContext.audioEngine.stop()
        }
        SCContext.vW.finishWriting {
            SCContext.startTime = nil
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        if SCContext.isPaused { return }
        guard sampleBuffer.isValid else { return }
        switch outputType {
            case .screen:
            if SCContext.screen == nil && SCContext.window == nil && SCContext.application == nil { break }
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first else { return }
            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue),
                  status == .complete else { return }

            if SCContext.vW != nil && SCContext.vW?.status == .writing, SCContext.startTime == nil {
                SCContext.startTime = Date.now
                SCContext.vW.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }

            if SCContext.vwInput.isReadyForMoreMediaData {
                SCContext.vwInput.append(sampleBuffer)
            }
            break
            case .audio:
            if SCContext.streamType == .systemaudio { // write directly to file if not video recording
                    guard let samples = sampleBuffer.asPCMBuffer else { return }
                    do {
                        try SCContext.audioFile?.write(from: samples)
                    }
                    catch { assertionFailure("audio file writing issue".local) }
                } else { // otherwise send the audio data to AVAssetWriter
                    if SCContext.awInput.isReadyForMoreMediaData {
                        SCContext.awInput.append(sampleBuffer)
                    }
                }
            @unknown default:
            assertionFailure("unknown stream type".local)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { // stream error
        print("closing stream with error:\n".local, error,
              "\nthis might be due to the window closing or the user stopping from the sonoma ui".local)
        DispatchQueue.main.async {
            SCContext.stream = nil
            self.stopRecording()
        }
    }
}

// https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos
// For Sonoma updated to https://developer.apple.com/forums/thread/727709
extension CMSampleBuffer {
    var asPCMBuffer: AVAudioPCMBuffer? {
        try? self.withAudioBufferList { audioBufferList, _ -> AVAudioPCMBuffer? in
            guard let absd = self.formatDescription?.audioStreamBasicDescription else { return nil }
            guard let format = AVAudioFormat(standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame) else { return nil }
            return AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
        }
    }
}

// Based on https://gist.github.com/aibo-cora/c57d1a4125e145e586ecb61ebecff47c
extension AVAudioPCMBuffer {
    var asSampleBuffer: CMSampleBuffer? {
        let asbd = self.format.streamDescription
        var sampleBuffer: CMSampleBuffer? = nil
        var format: CMFormatDescription? = nil

        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        ) == noErr else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(asbd.pointee.mSampleRate)),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: CMItemCount(self.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        ) == noErr else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: self.mutableAudioBufferList
        ) == noErr else { return nil }

        return sampleBuffer
    }
}
