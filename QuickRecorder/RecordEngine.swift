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
    @objc func prepRecord(type: String, screens: SCDisplay?, windows: [SCWindow]?, applications: [SCRunningApplication]?, fastStart: Bool = false) {
        switch type {
        case "window":  SCContext.streamType = .window
        case "windows":  SCContext.streamType = .windows
        case "display": SCContext.streamType = .screen
        case "application": SCContext.streamType = .application
        case "area": SCContext.streamType = .screenarea
        case "audio":   SCContext.streamType = .systemaudio
            default: return // if we don't even know what to record I don't think we should even try
        }
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        let outputPath = ud.string(forKey: "saveDirectory")!
        if fileManager.fileExists(atPath: outputPath, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                SCContext.streamType = nil
                _ = createAlert(title: "Failed to Record".local, message: "The output path is a file instead of a folder!".local, button1: "OK").runModal()
                return
            }
        } else {
            do {
                try fileManager.createDirectory(atPath: outputPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                SCContext.streamType = nil
                _ = createAlert(title: "Failed to Record".local, message: "Unable to create output folder!".local, button1: "OK").runModal()
                return
            }
        }
        //statusBarItem.menu = nil
        SCContext.updateAudioSettings()
        // file preparation
        if let screens = screens {
            SCContext.screen = SCContext.availableContent!.displays.first(where: { $0 == screens })
        } else { SCContext.streamType = nil; return }
        
        if let windows = windows {
            SCContext.window = SCContext.availableContent!.windows.filter({ windows.contains($0) })
        } else { if SCContext.streamType == .window { SCContext.streamType = nil; return } }
        
        if let applications = applications {
            SCContext.application = SCContext.availableContent!.applications.filter({ applications.contains($0) })
        } else { if SCContext.streamType == .application { SCContext.streamType = nil; return } }
        
        let qrSelf = SCContext.getSelf()
        let qrWindows = SCContext.getSelfWindows()
        let dockApp = SCContext.availableContent!.applications.first(where: { $0.bundleIdentifier.description == "com.apple.dock" })
        let wallpaper = SCContext.availableContent!.windows.filter({
            guard let title = $0.title else { return false }
            return $0.owningApplication?.bundleIdentifier == "com.apple.dock" && title != "LPSpringboard" && title != "Dock"
        })
        let dockWindow = SCContext.availableContent!.windows.filter({
            guard let title = $0.title else { return true }
            return $0.owningApplication?.bundleIdentifier == "com.apple.dock" && title == "Dock"
        })
        let desktopFiles = SCContext.availableContent!.windows.filter({ $0.title == "" && $0.owningApplication?.bundleIdentifier == "com.apple.finder" })
        let mouseWindow = SCContext.availableContent!.windows.filter({ $0.title == "Mouse Pointer".local && $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier })
        let camLayer = SCContext.availableContent!.windows.filter({ $0.title == "Camera Overlayer".local && $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier })
        var appBlackList = [String]()
        if let savedData = ud.data(forKey: "hiddenApps"),
           let decodedApps = try? JSONDecoder().decode([AppInfo].self, from: savedData) {
            appBlackList = (decodedApps as [AppInfo]).map({ $0.bundleID })
        }
        let excliudedApps = SCContext.availableContent!.applications.filter({ appBlackList.contains($0.bundleIdentifier) })
        
        if SCContext.streamType == .window || SCContext.streamType == .windows {
            if var includ = SCContext.window {
                if includ.count > 1 {
                    if ud.bool(forKey: "highlightMouse") { includ += mouseWindow }
                    if ud.string(forKey: "background") == BackgroundType.wallpaper.rawValue { if dockApp != nil { includ += wallpaper }}
                    SCContext.filter = SCContentFilter(display: SCContext.screen ?? SCContext.getSCDisplayWithMouse()!, including: includ + camLayer)
                    if #available(macOS 14.2, *) { SCContext.filter?.includeMenuBar = ud.bool(forKey: "includeMenuBar") }
                } else {
                    SCContext.streamType = .window
                    SCContext.filter = SCContentFilter(desktopIndependentWindow: includ[0])
                }
            }
        } else {
            if SCContext.streamType == .screen || SCContext.streamType == .screenarea || SCContext.streamType == .systemaudio {
                let screen = SCContext.screen ?? SCContext.getSCDisplayWithMouse()!
                if SCContext.streamType == .screenarea {
                    if let area = SCContext.screenArea, let name = screen.nsScreen?.localizedName {
                        let a = ["x": area.origin.x, "y": area.origin.y, "width": area.width, "height": area.height]
                        ud.set([name: a], forKey: "savedArea")
                    }
                }
                var excluded = [SCRunningApplication]()
                var except = [SCWindow]()
                excluded += excliudedApps
                if ud.bool(forKey: "hideSelf") { if let qrWindows = qrWindows { except += qrWindows }}
                if ud.string(forKey: "background") != BackgroundType.wallpaper.rawValue { if dockApp != nil { except += wallpaper}}
                if ud.bool(forKey: "hideDesktopFiles") { except += desktopFiles }
                SCContext.filter = SCContentFilter(display: screen, excludingApplications: excluded, exceptingWindows: except)
                if #available(macOS 14.2, *) { SCContext.filter?.includeMenuBar = ((SCContext.streamType == .screen || SCContext.streamType == .screenarea) && ud.bool(forKey: "includeMenuBar")) }
            }
            if SCContext.streamType == .application {
                var includ = SCContext.application!
                var except = [SCWindow]()
                if let qrSelf = qrSelf { includ.append(qrSelf) }
                let withFinder = includ.map{ $0.bundleIdentifier }.contains("com.apple.finder")
                if withFinder && ud.bool(forKey: "hideDesktopFiles") { except += desktopFiles }
                if ud.bool(forKey: "hideSelf") { if let qrWindows = qrWindows { except += qrWindows }}
                //if ud.bool(forKey: "highlightMouse") { if let qrSelf = qrSelf { includ.append(qrSelf) }}
                if ud.string(forKey: "background") == BackgroundType.wallpaper.rawValue { if let dock = dockApp { includ.append(dock); except += dockWindow}}
                SCContext.filter = SCContentFilter(display: SCContext.screen ?? SCContext.getSCDisplayWithMouse()!, including: includ, exceptingWindows: except)
                if #available(macOS 14.2, *) { SCContext.filter?.includeMenuBar = ud.bool(forKey: "includeMenuBar") }
            }
        }
        if SCContext.streamType == .systemaudio { prepareAudioRecording() }
        Task { await record(audioOnly: SCContext.streamType == .systemaudio, filter: SCContext.filter!, fastStart: fastStart) }
    }

    func record(audioOnly: Bool, filter: SCContentFilter, fastStart: Bool = true) async {
        SCContext.timeOffset = CMTimeMake(value: 0, timescale: 0)
        SCContext.isPaused = false
        SCContext.isResume = false
        
        let recordHDR = ud.bool(forKey: "recordHDR")
        let encoderIsH265 = (ud.string(forKey: "encoder") == Encoder.h265.rawValue) || recordHDR
        
        let conf: SCStreamConfiguration
#if compiler(>=6.0)
        if recordHDR {
            if #available(macOS 15, *) {
                conf = SCStreamConfiguration(preset: .captureHDRStreamLocalDisplay)
            } else { conf = SCStreamConfiguration() }
        } else { conf = SCStreamConfiguration() }
#else
        conf = SCStreamConfiguration()
#endif
        conf.width = 2
        conf.height = 2
        
        if !audioOnly {
            if #available(macOS 14.0, *) {
                conf.width = Int(filter.contentRect.width) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
                conf.height = Int(filter.contentRect.height) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
            } else {
                guard let pointPixelScaleOld = (SCContext.screen ?? SCContext.getSCDisplayWithMouse()!).nsScreen?.backingScaleFactor else { return }
                if SCContext.streamType == .application || SCContext.streamType == .windows || SCContext.streamType == .screen {
                    let frame = (SCContext.screen ?? SCContext.getSCDisplayWithMouse()!).frame
                    conf.width = Int(frame.width)
                    conf.height = Int(frame.height)
                }
                if SCContext.streamType == .window {
                    let frame = SCContext.window![0].frame
                    conf.width = Int(frame.width)
                    conf.height = Int(frame.height)
                }
                if SCContext.streamType == .screenarea {
                    let frame = SCContext.screenArea!
                    conf.width = Int(frame.width)
                    conf.height = Int(frame.height)
                }
                conf.width = conf.width * (ud.integer(forKey: "highRes") == 2 ? Int(pointPixelScaleOld) : 1)
                conf.height = conf.height * (ud.integer(forKey: "highRes") == 2 ? Int(pointPixelScaleOld) : 1)
            }
            /*if ud.integer(forKey: "highRes") == 0 {
                conf.width = Int(conf.width/2)
                conf.height = Int(conf.height/2)
            }*/
            conf.showsCursor = ud.bool(forKey: "showMouse") || fastStart
            if ud.string(forKey: "background") != BackgroundType.wallpaper.rawValue { conf.backgroundColor = SCContext.getBackgroundColor() }
            if !recordHDR {
                if encoderIsH265 {
                    conf.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked
                    conf.colorSpaceName = CGColorSpace.displayP3
                } else {
                    conf.pixelFormat = kCVPixelFormatType_32BGRA
                    conf.colorSpaceName = CGColorSpace.sRGB
                }
                if ud.bool(forKey: "withAlpha") { conf.pixelFormat = kCVPixelFormatType_32BGRA }
            }
            //if let colorSpace = SCContext.getColorSpace(), !ud.bool(forKey: "recordHDR") { conf.colorSpaceName = colorSpace }
        }
        
        if #available(macOS 13, *) {
            conf.capturesAudio = ud.bool(forKey: "recordWinSound") || fastStart || audioOnly
            conf.sampleRate = SCContext.audioSettings["AVSampleRateKey"] as! Int
            conf.channelCount = SCContext.audioSettings["AVNumberOfChannelsKey"] as! Int
        }
        
        conf.minimumFrameInterval = CMTime(value: 1, timescale: audioOnly ? CMTimeScale.max : CMTimeScale(ud.integer(forKey: "frameRate")))

        if SCContext.streamType == .screenarea {
            if let nsRect = SCContext.screenArea {
                let newY = SCContext.screen!.frame.height - nsRect.size.height - nsRect.origin.y
                conf.sourceRect = CGRect(x: nsRect.origin.x, y: newY, width: nsRect.size.width, height: nsRect.size.height)
                if #available(macOS 14.0, *) {
                    conf.width = Int(conf.sourceRect.width) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
                    conf.height = Int(conf.sourceRect.height) * (ud.integer(forKey: "highRes") == 2 ? Int(filter.pointPixelScale) : 1)
                } else {
                    guard let pointPixelScaleOld = (SCContext.screen ?? SCContext.getSCDisplayWithMouse()!).nsScreen?.backingScaleFactor else { return }
                    conf.width = Int(conf.sourceRect.width) * (ud.integer(forKey: "highRes") == 2 ? Int(pointPixelScaleOld) : 1)
                    conf.height = Int(conf.sourceRect.height) * (ud.integer(forKey: "highRes") == 2 ? Int(pointPixelScaleOld) : 1)
                }
                /*if ud.integer(forKey: "highRes") == 0 {
                    conf.width = Int(conf.width/2)
                    conf.height = Int(conf.height/2)
                }*/
            }
        }
        
        SCContext.stream = SCStream(filter: filter, configuration: conf, delegate: self)
        do {
            try SCContext.stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            if #available(macOS 13, *) { try SCContext.stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global()) }
            if !audioOnly {
                initVideo(conf: conf)
            } else {
                SCContext.startTime = Date.now
                if ud.bool(forKey: "recordMic") { startMicRecording() }
            }
            try await SCContext.stream.startCapture()
        } catch {
            assertionFailure("capture failed".local)
            return
        }
        if !audioOnly { registerGlobalMouseMonitor() }
        DispatchQueue.main.async { [self] in updateStatusBar() }
    }

    func prepareAudioRecording() {
        var fileEnding = ud.string(forKey: "audioFormat") ?? "wat"
        let encorder = fileEnding == AudioFormat.mp3.rawValue ? "aac" : fileEnding
        switch fileEnding { // todo: I'd like to store format info differently
            case AudioFormat.mp3.rawValue: fallthrough
            case AudioFormat.aac.rawValue: fallthrough
            case AudioFormat.alac.rawValue: fileEnding = "m4a"
            case AudioFormat.flac.rawValue: fileEnding = "flac"
            case AudioFormat.opus.rawValue: fileEnding = "ogg"
        default: assertionFailure("loaded unknown audio format: ".local + fileEnding)
        }
        let path = SCContext.getFilePath()
        if ud.bool(forKey: "recordMic") && SCContext.streamType == .systemaudio {
            if var settings = SCContext.audioSettings {
                settings[AVNumberOfChannelsKey] = 1
                SCContext.filePath = "\(path).qma"
                SCContext.filePath1 = "\(path).qma/sys.\(fileEnding)"
                SCContext.filePath2 = "\(path).qma/mic.\(fileEnding)"
                let infoJsonURL = URL(fileURLWithPath: "\(path).qma/info.json")
                let jsonString = "{\"format\": \"\(fileEnding)\", \"encoder\": \"\(encorder)\", \"exportMP3\": \(ud.string(forKey: "audioFormat") == AudioFormat.mp3.rawValue), \"sysVol\": 1.0, \"micVol\": 1.0}"
                try? FileManager.default.createDirectory(at: URL(fileURLWithPath: SCContext.filePath), withIntermediateDirectories: true, attributes: nil)
                try? jsonString.write(to: infoJsonURL, atomically: true, encoding: .utf8)
                SCContext.audioFile = try! AVAudioFile(forWriting: URL(fileURLWithPath: SCContext.filePath1), settings: SCContext.audioSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
                SCContext.audioFile2 = try! AVAudioFile(forWriting: URL(fileURLWithPath: SCContext.filePath2), settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            }
        } else {
            SCContext.filePath = "\(path).\(fileEnding)"
            SCContext.filePath1 = SCContext.filePath
            SCContext.audioFile = try! AVAudioFile(forWriting: URL(fileURLWithPath: SCContext.filePath), settings: SCContext.audioSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        }
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
        //SCContext.recordMic = ud.bool(forKey: "recordMic")
        if ud.bool(forKey: "remuxAudio") && ud.bool(forKey: "recordMic") && ud.bool(forKey: "recordWinSound") {
            SCContext.filePath = "\(SCContext.getFilePath()).\(fileEnding).\(fileEnding).\(fileEnding)"
        } else {
            SCContext.filePath = "\(SCContext.getFilePath()).\(fileEnding)"
        }
        SCContext.vW = try? AVAssetWriter.init(outputURL: URL(fileURLWithPath: SCContext.filePath), fileType: fileType!)
        let recordHDR = ud.bool(forKey: "recordHDR")
        let encoderIsH265 = (ud.string(forKey: "encoder") == Encoder.h265.rawValue) || recordHDR
        let fpsMultiplier: Double = Double(ud.integer(forKey: "frameRate"))/8
        let encoderMultiplier: Double = encoderIsH265 ? 0.5 : 0.9
        let resolution = Double(max(600, conf.width)) * Double(max(600, conf.height))
        var qualityMultiplier = 1 - (log10(sqrt(resolution) * fpsMultiplier) / 5)
        switch ud.double(forKey: "videoQuality") {
            case 0.3: qualityMultiplier = max(0.1, qualityMultiplier)
            case 0.7: qualityMultiplier = max(0.4, min(0.6, qualityMultiplier * 3))
            default: qualityMultiplier = 1.0
        }
        let targetBitrate = resolution * fpsMultiplier * encoderMultiplier * qualityMultiplier
        var videoSettings: [String: Any] = [
            AVVideoCodecKey: encoderIsH265 ? ((ud.bool(forKey: "withAlpha") && !recordHDR) ? AVVideoCodecType.hevcWithAlpha : AVVideoCodecType.hevc) : AVVideoCodecType.h264,
            // yes, not ideal if we want more than these encoders in the future, but it's ok for now
            AVVideoWidthKey: conf.width,
            AVVideoHeightKey: conf.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(200000, Int(targetBitrate)),
                AVVideoExpectedSourceFrameRateKey: ud.integer(forKey: "frameRate")
            ] as [String : Any]
        ]
        
        if encoderIsH265 {
            if !recordHDR {
                videoSettings[AVVideoColorPropertiesKey] = [
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2 ] as [String : Any]
            }
        } else {
            videoSettings[AVVideoColorPropertiesKey] = [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2 ] as [String : Any]
        }
        
        
        SCContext.vwInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        //SCContext.vwInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: SCContext.vwInput, sourcePixelBufferAttributes: videoSettings)
        SCContext.micInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: SCContext.audioSettings)
        SCContext.vwInput.expectsMediaDataInRealTime = true
        SCContext.micInput.expectsMediaDataInRealTime = true

        if SCContext.vW.canAdd(SCContext.vwInput) { SCContext.vW.add(SCContext.vwInput) }

        if #available(macOS 13, *) {
            SCContext.awInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: SCContext.audioSettings)
            SCContext.awInput.expectsMediaDataInRealTime = true
            if SCContext.vW.canAdd(SCContext.awInput) { SCContext.vW.add(SCContext.awInput) }
        }

        if ud.bool(forKey: "recordMic") {
            if SCContext.vW.canAdd(SCContext.micInput) { SCContext.vW.add(SCContext.micInput) }
            startMicRecording()
        }
        SCContext.vW.startWriting()
    }
    
    func startMicRecording() {
        if ud.string(forKey: "micDevice") == "default" {
            let input = SCContext.audioEngine.inputNode
            if ud.bool(forKey: "enableAEC") {
                try? input.setVoiceProcessingEnabled(true)
                if #available(macOS 14, *) { input.voiceProcessingOtherAudioDuckingConfiguration.duckingLevel = .min }
            }
            let inputFormat = input.inputFormat(forBus: 0)
            let monoFormat = AVAudioFormat(commonFormat: inputFormat.commonFormat,
                                           sampleRate: inputFormat.sampleRate,
                                           channels: 1, interleaved: inputFormat.isInterleaved) ?? inputFormat
            input.installTap(onBus: 0, bufferSize: 1024, format: monoFormat) {buffer, time in
                if SCContext.isPaused || SCContext.startTime == nil { return }
                if SCContext.streamType == .systemaudio {
                    do { try SCContext.audioFile2?.write(from: buffer) }
                    catch { assertionFailure("audio file writing issue".local) }
                } else {
                    if SCContext.micInput.isReadyForMoreMediaData {
                        SCContext.micInput.append(buffer.asSampleBuffer!)
                    }
                }
            }
            try! SCContext.audioEngine.start()
        } else {
            AudioRecorder.shared.setupAudioCapture()
            AudioRecorder.shared.start()
        }
    }
    
    func outputVideoEffectDidStart(for stream: SCStream) {
        DispatchQueue.main.async { camWindow.close() }
        print("[Presenter Overlay ON]")
        isPresenterON = true
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(ud.integer(forKey: "poSafeDelay"))) {
            self.isCameraReady = true
        }
    }
    
    func outputVideoEffectDidStop(for stream: SCStream) {
        print("[Presenter Overlay OFF]")
        presenterType = "OFF"
        isPresenterON = false
        isCameraReady = false
        DispatchQueue.main.async {
            if SCContext.stream != nil { camWindow.orderFront(self) }
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        if SCContext.saveFrame && sampleBuffer.imageBuffer != nil {
            SCContext.saveFrame = false
            if #available(macOS 13.0, *) {
                let url = URL(filePath: "\(SCContext.getFilePath(capture: true)).png")
                sampleBuffer.nsImage?.saveToFile(url)
            } else {
                let url = URL(fileURLWithPath: "\(SCContext.getFilePath(capture: true)).png")
                sampleBuffer.nsImage?.saveToFile(url)
            }
        }
        if SCContext.isPaused { return }
        guard sampleBuffer.isValid else { return }
        var SampleBuffer = sampleBuffer
        if SCContext.isResume {
            SCContext.isResume = false
            var pts = CMSampleBufferGetPresentationTimeStamp(SampleBuffer)
            guard let last = SCContext.lastPTS else { return }
            if last.flags.contains(CMTimeFlags.valid) {
                if SCContext.timeOffset.flags.contains(CMTimeFlags.valid) { pts = CMTimeSubtract(pts, SCContext.timeOffset) }
                let off = CMTimeSubtract(pts, last)
                print("adding \(CMTimeGetSeconds(off)) to \(CMTimeGetSeconds(SCContext.timeOffset)) (pts \(CMTimeGetSeconds(SCContext.timeOffset)))")
                if SCContext.timeOffset.value == 0 { SCContext.timeOffset = off } else { SCContext.timeOffset = CMTimeAdd(SCContext.timeOffset, off) }
            }
            SCContext.lastPTS?.flags = []
        }
        switch outputType {
        case .screen:
            if (SCContext.screen == nil && SCContext.window == nil && SCContext.application == nil) || SCContext.streamType == .systemaudio { break }
            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(SampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachments = attachmentsArray.first else { return }
            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRawValue),
                  status == .complete else { return }
            
            if SCContext.vW != nil && SCContext.vW?.status == .writing, SCContext.startTime == nil {
                SCContext.startTime = Date.now
                SCContext.vW.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(SampleBuffer))
            }
            if (SCContext.timeOffset.value > 0) { SampleBuffer = SCContext.adjustTime(sample: SampleBuffer, by: SCContext.timeOffset) ?? sampleBuffer }
            var pts = CMSampleBufferGetPresentationTimeStamp(SampleBuffer)
            let dur = CMSampleBufferGetDuration(SampleBuffer)
            if (dur.value > 0) { pts = CMTimeAdd(pts, dur) }
            if frameQueue.getArray().contains(where: { $0 >= pts }) { print("Skip this frame"); return } else { frameQueue.append(pts) }
            SCContext.lastPTS = pts
            if SCContext.vwInput.isReadyForMoreMediaData {
                if #available(macOS 14.2, *) {
                    if let rect = attachments[.presenterOverlayContentRect] as? [String: Any]{
                        var type = "np"
                        let off = (rect["X"] as! CGFloat == .infinity)
                        let small = (rect["X"] as! CGFloat == 0.0)
                        let big = (!off && !small)
                        if off { type = "OFF" } else if small { type = "Small" } else if big { type = "Big" }
                        if type != presenterType {
                            print("Presenter Overlay set to \"\(type)\"!")
                            isCameraReady = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(ud.integer(forKey: "poSafeDelay"))) {
                                self.isCameraReady = true
                            }
                            presenterType = type
                        }
                    }
                }
                if isPresenterON && !isCameraReady { break }
                SCContext.vwInput.append(SampleBuffer)
            }
            break
        case .audio:
            if SCContext.streamType == .systemaudio { // write directly to file if not video recording
                hideMousePointer = true
                guard let samples = SampleBuffer.asPCMBuffer else { return }
                do { try SCContext.audioFile?.write(from: samples) }
                catch { assertionFailure("audio file writing issue".local) }
            } else {
                if SCContext.lastPTS == nil { return }
                if SCContext.awInput.isReadyForMoreMediaData { SCContext.awInput.append(SampleBuffer) }
            }
#if compiler(>=6.0)
        case .microphone:
            break
#endif
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

class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    static let shared = AudioRecorder()
    private var captureSession: AVCaptureSession!
    private var audioInput: AVCaptureDeviceInput!
    private var audioDataOutput: AVCaptureAudioDataOutput!

    func setupAudioCapture() {
        captureSession = AVCaptureSession()

        // Get the default audio device (microphone)
        guard let audioDevice = SCContext.getMicrophone().first(where: { $0.localizedName == ud.string(forKey: "micDevice") }) else {
            print("Unable to access microphone")
            return
        }
        let channels = audioDevice.formats.first?.formatDescription.audioChannelLayout?.numberOfChannels ?? 0
        if channels < 1 { return }
        if channels != 1 {
            SCContext.updateAudioSettings()
            if var settings = SCContext.audioSettings {
                settings[AVNumberOfChannelsKey] = channels
                SCContext.audioFile2 = try! AVAudioFile(forWriting: URL(fileURLWithPath: SCContext.filePath2), settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            }
        }
        //print(audioDevice.localizedName)
        // Create audio input
        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
        } catch {
            print("Unable to create audio input: \(error)")
            return
        }
        
        // Add audio input to capture session
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        } else {
            print("Unable to add audio input to capture session")
            return
        }

        // Create audio data output
        audioDataOutput = AVCaptureAudioDataOutput()
        let audioQueue = DispatchQueue(label: "audioQueue")
        audioDataOutput.setSampleBufferDelegate(self, queue: audioQueue)
        
        // Add audio data output to capture session
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
        } else {
            print("Unable to add audio data output to capture session")
            return
        }
    }
    
    func start() {
        if let session = captureSession {
            session.startRunning()
        }
    }
    
    func stop() {
        if let session = captureSession {
            if session.isRunning { session.stopRunning() }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if SCContext.isPaused || SCContext.startTime == nil { return }
        if SCContext.streamType == .systemaudio {
            guard let samples = sampleBuffer.asPCMBuffer else { return }
            do { try SCContext.audioFile2?.write(from: samples) }
            catch { assertionFailure("Audio file writing issue: \(error.localizedDescription)") }
        } else {
            if SCContext.micInput.isReadyForMoreMediaData {
                SCContext.micInput.append(sampleBuffer)
            }
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
    
    var nsImage: NSImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return NSImage(cgImage: cgImage, size: NSSize.zero)
        }
        return nil
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
