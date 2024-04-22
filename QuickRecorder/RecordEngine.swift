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
        SCContext.updateAudioSettings()
        // file preparation
        if let screens = screens {
            SCContext.screen = SCContext.availableContent!.displays.first(where: { $0 == screens })
        } else { SCContext.streamType = nil; return }
        if let windows = windows {
            SCContext.window = SCContext.availableContent!.windows.filter({ windows.contains($0) })
        } else { SCContext.streamType = nil; return }
        if let applications = applications {
            SCContext.application = SCContext.availableContent!.applications.filter({ applications.contains($0) })
        } else { SCContext.streamType = nil; return }
        
        let quickrRecorder = SCContext.getSelf()
        let dockApp = SCContext.availableContent!.applications.first(where: { $0.bundleIdentifier.description == "com.apple.dock" })
        let wallpaper = SCContext.availableContent!.windows.filter({ $0.title != "Dock" && $0.owningApplication?.bundleIdentifier == "com.apple.dock" })
        let dockWindow = SCContext.availableContent!.windows.first(where: { $0.title == "Dock" && $0.owningApplication?.bundleIdentifier == "com.apple.dock" })
        let desktopFiles = SCContext.availableContent!.windows.filter({ $0.title == "" && $0.owningApplication?.bundleIdentifier == "com.apple.finder" })
        let mouseWindow = SCContext.availableContent!.windows.filter({ $0.title == "Mouse Pointer".local && $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier })
        
        if SCContext.streamType == .window {
            if var includ = SCContext.window {
                if includ.count > 1 {
                    if ud.bool(forKey: "highlightMouse") { registerGlobalMouseMonitor(); includ += mouseWindow }
                    if ud.string(forKey: "background") == BackgroundType.wallpaper.rawValue { if dockApp != nil { includ += wallpaper }}
                    filter = SCContentFilter(display: SCContext.screen!, including: includ)
                } else {
                    filter = SCContentFilter(desktopIndependentWindow: includ[0])
                }
            }
            
        } else {
            if SCContext.streamType == .screen || SCContext.streamType == .screenarea || SCContext.streamType == .systemaudio {
                if ud.bool(forKey: "highlightMouse") && SCContext.streamType != .systemaudio { registerGlobalMouseMonitor() }
                let excluded = [SCRunningApplication]()
                var except = [SCWindow]()
                //if ud.bool(forKey: "hideSelf") { if let qrSelf = SCContext.getSelf() { excluded.append(qrSelf) }}
                if ud.bool(forKey: "removeWallpaper") { if dockApp != nil { except += wallpaper}}
                if ud.bool(forKey: "hideDesktopFiles") { except += desktopFiles }
                filter = SCContentFilter(display: SCContext.screen ?? SCContext.availableContent!.displays.first!, excludingApplications: excluded, exceptingWindows: except)
            }
            if SCContext.streamType == .application {
                if ud.bool(forKey: "highlightMouse") { registerGlobalMouseMonitor() }
                var includ = SCContext.application!
                var except = [SCWindow]()
                let withFinder = includ.map{ $0.bundleIdentifier }.contains("com.apple.finder")
                if withFinder && ud.bool(forKey: "hideDesktopFiles") { except += desktopFiles }
                if ud.bool(forKey: "highlightMouse") { if let qr = quickrRecorder { includ.append(qr) }}
                if ud.string(forKey: "background") == BackgroundType.wallpaper.rawValue { if let dock = dockApp { includ.append(dock); except.append(dockWindow!)}}
                filter = SCContentFilter(display: SCContext.screen ?? SCContext.availableContent!.displays.first!, including: includ, exceptingWindows: except)
                
            }
        }
        if SCContext.streamType == .systemaudio {
            prepareAudioRecording()
        }
        Task { await record(audioOnly: SCContext.streamType == .systemaudio, filter: filter!) }
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
        conf.sampleRate = SCContext.audioSettings["AVSampleRateKey"] as! Int
        conf.channelCount = SCContext.audioSettings["AVNumberOfChannelsKey"] as! Int

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

        DispatchQueue.main.async { [self] in updateStatusBar() }
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
        SCContext.audioFile = try! AVAudioFile(forWriting: URL(fileURLWithPath: SCContext.filePath), settings: SCContext.audioSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    func getFilePath() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
        return ud.string(forKey: "saveDirectory")! + "/Recording at ".local + dateFormatter.string(from: Date())
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        return deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

extension SCDisplay {
    var nsScreen: NSScreen? {
        return NSScreen.screens.first(where: { $0.displayID == self.displayID })
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
        SCContext.awInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: SCContext.audioSettings)
        SCContext.micInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: SCContext.audioSettings)
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
            SCContext.stopRecording()
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
