import XCTest
import AVFoundation
@testable import QuickRecorder

final class ReplayBufferTests: XCTestCase {
    func testClipSelectionCoversRequestedDuration() {
        let exporter = ClipExporter()
        let durations: [CMTime] = [CMTime(seconds: 8, preferredTimescale: 600), CMTime(seconds: 8, preferredTimescale: 600), CMTime(seconds: 8, preferredTimescale: 600)]
        let segments = durations.enumerated().map { index, time in
            ReplaySegment(url: URL(fileURLWithPath: "/tmp/segment\(index).mp4"), duration: time)
        }
        let slice = exporter.slice(segments: segments, seconds: 20)
        let total = slice.reduce(0.0) { $0 + CMTimeGetSeconds($1.duration) }
        XCTAssertGreaterThanOrEqual(total, 20)
        XCTAssertEqual(slice.count, 3)
    }

    func testRepeatedHotkeyPressesTriggerHandlers() {
        let manager = HotkeyManager.shared
        let expectationSave = expectation(description: "save called twice")
        expectationSave.expectedFulfillmentCount = 2
        #if DEBUG
        manager.injectHandlersForTesting(save: {
            expectationSave.fulfill()
        }, quick: nil)
        #endif
        manager.triggerSaveReplay()
        manager.triggerSaveReplay()
        wait(for: [expectationSave], timeout: 1.0)
    }

    func testBufferDurationRespondsToChanges() {
        let defaults = UserDefaults.standard
        defaults.set(120, forKey: "replayDuration")
        XCTAssertEqual(ReplayBufferService.shared.bufferDuration, 120)
        defaults.set(10, forKey: "replayDuration")
        XCTAssertEqual(ReplayBufferService.shared.bufferDuration, 15)
    }

    func testCaptureAudioFlagMatchesDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "replayAudio")
        XCTAssertTrue(ReplayBufferService.shared.captureAudio)
        defaults.set(false, forKey: "replayAudio")
        XCTAssertFalse(ReplayBufferService.shared.captureAudio)
    }

    func testHealthEscalatesAfterRepeatedFailures() {
        let service = ReplayBufferService.shared
        service.health = .running
        service.updateHealthAfterFailure()
        service.updateHealthAfterFailure()
        service.updateHealthAfterFailure()
        service.updateHealthAfterFailure()
        XCTAssertEqual(service.health, .disabled)
    }
}
