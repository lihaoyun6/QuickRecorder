import Foundation
import AVFoundation
import ScreenCaptureKit
import AppKit

final class ReplayBufferService: NSObject, SCStreamDelegate, SCStreamOutput {
    enum HealthState: String {
        case running
        case paused
        case error
        case disabled
    }

    static let shared = ReplayBufferService()

    private let captureQueue = DispatchQueue(label: "dev.tnn.replaybuffer.capture")
    private let writerQueue = DispatchQueue(label: "dev.tnn.replaybuffer.writer")

    private var stream: SCStream?
    private var filter: SCContentFilter?
    private var configuration: SCStreamConfiguration?

    private var currentWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var segmentStart: CMTime?

    private var segments = [ReplaySegment]()
    private var failureCount = 0

    var health: HealthState = .paused
    var statusText: String = "Idle".local

    var bufferDuration: TimeInterval {
        max(TimeInterval(UserDefaults.standard.integer(forKey: "replayDuration")), 15)
    }

    var segmentLength: TimeInterval { 10 }

    var captureAudio: Bool {
        UserDefaults.standard.bool(forKey: "replayAudio")
    }

    let exporter = ClipExporter()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displayChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func start() {
        guard health != .disabled else { return }
        guard UserDefaults.standard.bool(forKey: "replayEnabled") else {
            health = .paused
            statusText = "Disabled".local
            return
        }
        if health == .running { return }
        prepareCapture()
    }

    func stop() {
        captureQueue.async {
            self.stream?.stopCapture { _ in }
            self.stream = nil
            self.closeWriter()
            self.health = .paused
            self.statusText = "Stopped".local
        }
    }

    func status() -> (HealthState, String) {
        (health, statusText)
    }

    private func prepareCapture() {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let error = error {
                self.handleError(error)
                return
            }
            guard let display = content?.displays.first else {
                self.handleError(NSError(domain: "ReplayBuffer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display available".local]))
                return
            }
            self.filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int(self.filter?.contentRect.width ?? display.frame.width)
            configuration.height = Int(self.filter?.contentRect.height ?? display.frame.height)
            configuration.showsCursor = false
            configuration.capturesAudio = self.captureAudio
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            configuration.queueDepth = 8
            self.configuration = configuration
            self.startStream(filter: self.filter!, configuration: configuration)
        }
    }

    private func startStream(filter: SCContentFilter, configuration: SCStreamConfiguration) {
        captureQueue.async {
            self.stream?.stopCapture { _ in }
            self.stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            do {
                try self.stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.writerQueue)
                if self.captureAudio {
                    try self.stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.writerQueue)
                }
                try self.stream?.startCapture()
                self.rotateSegment(force: true)
                self.health = .running
                self.statusText = "Running".local
                self.failureCount = 0
            } catch {
                self.handleError(error)
            }
        }
    }

    private func handleError(_ error: Error) {
        print("Replay buffer error", error.localizedDescription)
        failureCount += 1
        health = failureCount > 3 ? .disabled : .error
        statusText = error.localizedDescription
        if health != .disabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.prepareCapture()
            }
        }
    }

    @objc private func willSleep() {
        health = .paused
        statusText = "Paused for sleep".local
        stop()
    }

    @objc private func didWake() {
        if health != .disabled { start() }
    }

    @objc private func displayChanged() {
        if health == .running { restartCapture() }
    }

    func restartCapture() {
        stop()
        start()
    }

    private func rotateSegment(force: Bool = false) {
        writerQueue.async {
            if force { self.finalizeSegment() }
            self.createWriter()
        }
    }

    private func createWriter() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("replay-buffer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("segment-\(UUID().uuidString).mp4")
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let width = configuration?.width ?? 1280
            let height = configuration?.height ?? 720
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: width * height * 6
                ]
            ]
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            writer.add(videoInput)
            var audioInput: AVAssetWriterInput?
            if captureAudio {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 48000,
                    AVEncoderBitRateKey: 128_000
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                input.expectsMediaDataInRealTime = true
                if writer.canAdd(input) { writer.add(input); audioInput = input }
            }
            currentWriter = writer
            self.videoInput = videoInput
            self.audioInput = audioInput
            segmentStart = nil
        } catch {
            handleError(error)
        }
    }

    private func finalizeSegment() {
        guard let writer = currentWriter else { return }
        let semaphore = DispatchSemaphore(value: 0)
        let url = writer.outputURL
        writer.finishWriting {
            let duration = AVAsset(url: url).duration
            let segment = ReplaySegment(url: url, duration: duration)
            self.segments.append(segment)
            self.trimSegmentsIfNeeded()
            semaphore.signal()
        }
        semaphore.wait()
        currentWriter = nil
        videoInput = nil
        audioInput = nil
        segmentStart = nil
    }

    private func closeWriter() {
        writerQueue.sync {
            self.finalizeSegment()
        }
    }

    private func trimSegmentsIfNeeded() {
        let total = segments.reduce(0.0) { $0 + CMTimeGetSeconds($1.duration) }
        if total <= bufferDuration { return }
        var running = total
        while running > bufferDuration, let first = segments.first {
            running -= CMTimeGetSeconds(first.duration)
            segments.removeFirst()
            try? FileManager.default.removeItem(at: first.url)
        }
    }

    private func ensureSegmentBoundary(for sampleBuffer: CMSampleBuffer) {
        if segmentStart == nil {
            segmentStart = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if currentWriter?.status == .unknown {
                currentWriter?.startWriting()
                currentWriter?.startSession(atSourceTime: segmentStart!)
            }
            return
        }
        guard let start = segmentStart else { return }
        let elapsed = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), start)
        if CMTimeGetSeconds(elapsed) >= segmentLength {
            finalizeSegment()
            createWriter()
            segmentStart = nil
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard health == .running else { return }
        guard sampleBuffer.isValid else { return }
        ensureSegmentBoundary(for: sampleBuffer)
        switch outputType {
        case .screen:
            guard let input = videoInput, input.isReadyForMoreMediaData else { return }
            input.append(sampleBuffer)
        case .audio:
            guard let input = audioInput, input.isReadyForMoreMediaData else { return }
            input.append(sampleBuffer)
        @unknown default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        handleError(error)
    }

    func snapshotSegmentsForExport() -> [ReplaySegment] {
        var snapshot = [ReplaySegment]()
        let semaphore = DispatchSemaphore(value: 0)
        writerQueue.async {
            self.finalizeSegment()
            self.createWriter()
            snapshot = self.segments
            semaphore.signal()
        }
        semaphore.wait()
        return snapshot
    }
}

struct ReplaySegment {
    let url: URL
    let duration: CMTime
}

final class ClipExporter {
    func exportLast(seconds: TimeInterval, service: ReplayBufferService = .shared, completion: @escaping (Result<URL, Error>) -> Void) {
        let segments = service.snapshotSegmentsForExport()
        let requested = max(seconds, 1)
        let selected = slice(segments: segments, seconds: requested)
        guard !selected.isEmpty else {
            completion(.failure(NSError(domain: "ReplayBuffer", code: -2, userInfo: [NSLocalizedDescriptionKey: "No buffered content".local])))
            return
        }
        Task.detached {
            do {
                let url = try await self.buildExport(from: selected, totalDuration: requested)
                DispatchQueue.main.async { completion(.success(url)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func quickFive(service: ReplayBufferService = .shared, completion: @escaping (Result<URL, Error>) -> Void) {
        exportLast(seconds: 5, service: service, completion: completion)
    }

    private func slice(segments: [ReplaySegment], seconds: TimeInterval) -> [ReplaySegment] {
        var remaining = seconds
        var picked = [ReplaySegment]()
        for segment in segments.reversed() {
            picked.insert(segment, at: 0)
            remaining -= CMTimeGetSeconds(segment.duration)
            if remaining <= 0 { break }
        }
        return picked
    }

    private func buildExport(from segments: [ReplaySegment], totalDuration: TimeInterval) async throws -> URL {
        guard !segments.isEmpty else {
            throw NSError(domain: "ReplayBuffer", code: -3, userInfo: [NSLocalizedDescriptionKey: "Nothing to export".local])
        }
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for segment in segments {
            let asset = AVAsset(url: segment.url)
            if let track = asset.tracks(withMediaType: .video).first {
                try videoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: track, at: cursor)
            }
            if let track = asset.tracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: track, at: cursor)
            }
            cursor = CMTimeAdd(cursor, asset.duration)
        }
        let trimmedDuration = CMTime(seconds: totalDuration, preferredTimescale: 600)
        if cursor > trimmedDuration {
            let extra = CMTimeSubtract(cursor, trimmedDuration)
            composition.removeTimeRange(CMTimeRange(start: .zero, duration: extra))
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "y-MM-dd HH.mm.ss"
        let directory = (UserDefaults.standard.string(forKey: "saveDirectory") ?? FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!.path)
        let url = URL(fileURLWithPath: directory).appendingPathComponent("Clip \(formatter.string(from: Date())).mp4")
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) ?? AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
        export.outputURL = url
        export.outputFileType = .mp4
        return try await withCheckedThrowingContinuation { continuation in
            export.exportAsynchronously {
                if let error = export.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: url)
                }
            }
        }
    }
}
