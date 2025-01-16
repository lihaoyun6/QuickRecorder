import UniformTypeIdentifiers
import UserNotifications
import SwiftUI
import AVKit

class RecorderPlayerModel: NSObject, ObservableObject {
    @Published var playerView: AVPlayerView
    var asset: AVAsset?
    var fileUrl: URL?
    var playerItem: AVPlayerItem!
    var nsWindow: NSWindow?
    
    override init() {
        self.playerView = AVPlayerView()
        super.init()
        self.playerView.player = AVPlayer()
    }
    
    func loadVideo(fromUrl: URL, completion: @escaping () -> Void) {
        fileUrl = fromUrl
        asset = AVAsset(url: fromUrl)
        guard let asset = asset else { return }
        playerItem = AVPlayerItem(asset: asset)
        playerView.player?.replaceCurrentItem(with: playerItem)
        playerView.controlsStyle = .inline
        
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
        
        let checkCanBeginTrimming: () -> Void = {
            if self.playerView.canBeginTrimming {
                completion()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemTimeJumped, object: playerItem, queue: nil) { _ in
            checkCanBeginTrimming()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem, keyPath == #keyPath(AVPlayerItem.status) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if playerItem.status == .readyToPlay {
            let checkCanBeginTrimming: () -> Void = {
                if self.playerView.canBeginTrimming {
                    self.playerView.beginTrimming { result in
                        if result == .okButton {
                            guard let fileUrl = self.fileUrl else { return }
                            let startTime = playerItem.reversePlaybackEndTime
                            let endTime = playerItem.forwardPlaybackEndTime
                            let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
                            guard let asset = self.asset else { return }
                            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
                            let dateFormatter = DateFormatter()
                            let fileEnding = fileUrl.pathExtension.lowercased()
                            var fileType: AVFileType?
                            switch fileEnding {
                                case VideoFormat.mov.rawValue: fileType = AVFileType.mov
                                case VideoFormat.mp4.rawValue: fileType = AVFileType.mp4
                                default: assertionFailure("loaded unknown video format".local)
                            }
                            dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
                            var path: String?
                            path = fileUrl.deletingPathExtension().path
                            guard let path = path else { return }
                            let filePath = path.removingPercentEncoding! + " (Cropped in ".local + "\(dateFormatter.string(from: Date())))." + fileEnding
                            exportSession?.outputURL = filePath.url
                            exportSession?.outputFileType = fileType
                            exportSession?.timeRange = timeRange
                            exportSession?.exportAsynchronously {
                                if let error = exportSession?.error {
                                    print("Error: \(error.localizedDescription)")
                                } else {
                                    print("Trimmed video exported successfully.")
                                    let content = UNMutableNotificationContent()
                                    content.title = "Clip Saved".local
                                    content.body = String(format: "File saved to: %@".local, filePath)
                                    content.sound = UNNotificationSound.default
                                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                                    let request = UNNotificationRequest(identifier: "quickrecorder.completed.\(UUID().uuidString)", content: content, trigger: trigger)
                                    UNUserNotificationCenter.current().add(request) { error in
                                        if let error = error { print("Notification failed to send：\(error.localizedDescription)") }
                                    }
                                }
                            }
                            self.nsWindow?.close()
                        } else {
                            self.nsWindow?.close()
                        }
                    }
                }
            }
            
            checkCanBeginTrimming()

            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
    }
    
    func cleanup() {
        // 移除所有观察者
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        playerView.player?.pause()
        playerView.player = nil // 移除 player 对象
    }
}

struct RecorderPlayerView: NSViewRepresentable {
    typealias NSViewType = AVPlayerView

    var playerView: AVPlayerView

    func makeNSView(context: Context) -> AVPlayerView {
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

}

struct VideoTrimmerView: View {
    let videoURL: URL
    @StateObject var playerViewModel: RecorderPlayerModel = .init()

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "timeline.selection")
                    .font(.system(size: 13, weight: .bold))
                    .offset(y: 0.5)
                Text(videoURL.lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
            }
            ZStack {
                RecorderPlayerView(playerView: playerViewModel.playerView)
                    .onAppear {playerViewModel.loadVideo(fromUrl: videoURL) {}}
                    .padding(4)
                    .background(
                        Rectangle()
                            .foregroundStyle(.black)
                            .cornerRadius(5)
                    )
            }.padding([.bottom, .leading, .trailing])
        }
        .padding(.top, -22)
        .background(WindowAccessor(onWindowOpen: { window in
            playerViewModel.nsWindow = window
            SCContext.trimingList.append(videoURL)
        }, onWindowClose: {
            playerViewModel.playerView.player?.replaceCurrentItem(with: nil)
            playerViewModel.playerView.player = nil
            SCContext.trimingList.removeAll(where: { $0 == videoURL })
        }))
        //.navigationTitle(videoURL.lastPathComponent)
        //.preferredColorScheme(.dark)
    }
}
