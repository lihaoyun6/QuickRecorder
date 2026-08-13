//
//  DiskSpace.swift
//  QuickRecorder
//

import Foundation

enum DiskSpace {
    static let startThreshold: Int64 = 2_000_000_000
    static let stopThreshold: Int64 = 500_000_000
    private static let pollInterval: TimeInterval = 5

    private static var timer: Timer?

    static func availableBytes(at path: String) -> Int64? {
        guard let values = try? path.url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let capacity = values.volumeAvailableCapacity else { return nil }
        return Int64(capacity)
    }

    static func fileSize(at path: String) -> Int64? {
        guard let values = try? path.url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return Int64(size)
    }

    static func formatted(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func startMonitoring(_ path: String, onExhausted: @escaping (Int64) -> Void) {
        DispatchQueue.main.async {
            stopMonitoring()
            let poll = Timer(timeInterval: pollInterval, repeats: true) { _ in
                guard let free = availableBytes(at: path), free < stopThreshold else { return }
                stopMonitoring()
                onExhausted(free)
            }
            poll.tolerance = 1
            RunLoop.main.add(poll, forMode: .common) // .default stalls while a menu is tracking
            timer = poll
        }
    }

    static func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
