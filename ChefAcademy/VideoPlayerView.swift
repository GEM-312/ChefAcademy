//
//  VideoPlayerView.swift
//  ChefAcademy
//
//  A reusable component for playing looping MP4 videos.
//  NO controls - just pure seamless animation!
//
//  SWIFTUI LESSON: Using AVPlayerLayer
//  ------------------------------------
//  AVPlayerViewController has built-in controls we don't want.
//  Instead, we use AVPlayerLayer directly - it's just the video, nothing else.
//  This makes our character videos look like animations, not video players.
//

import SwiftUI
import AVKit
import AVFoundation

// MARK: - Video Player View
//
// A SwiftUI view that plays a looping video with NO controls.
// Usage: VideoPlayerView(videoName: "pip_waving")
//

struct VideoPlayerView: View {
    /// The name of the video file (without extension)
    let videoName: String

    /// File extension (default: mp4)
    var fileExtension: String = "mp4"

    /// Size of the video player
    var size: CGFloat = 200

    /// Whether to show in a circular frame
    var circular: Bool = true

    /// Border color (uses AppTheme.sage by default)
    var borderColor: Color = Color.AppTheme.sage

    /// Border width
    var borderWidth: CGFloat = 4

    var body: some View {
        ZStack {
            // Background
            if circular {
                Circle()
                    .fill(Color.AppTheme.warmCream)
                    .frame(width: size, height: size)
            }

            // Video player - NO CONTROLS, just the video
            LoopingVideoPlayer(videoName: videoName, fileExtension: fileExtension)
                .frame(width: size - borderWidth * 2, height: size - borderWidth * 2)
                .clipShape(circular ? AnyShape(Circle()) : AnyShape(Rectangle()))

            // Border
            if circular {
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - AnyShape Helper

struct AnyShape: Shape, @unchecked Sendable {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Looping Video Player (NO CONTROLS)
//
// Uses AVPlayerLayer directly - NO AVPlayerViewController.
// This means NO controls, NO play button, just pure video.
//

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let fileExtension: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView()
        view.configure(videoName: videoName, fileExtension: fileExtension)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        // Nothing to update
    }
}

// MARK: - Custom UIView with AVPlayerLayer
//
// This UIView contains just the AVPlayerLayer - no controls at all!
//

class LoopingPlayerUIView: UIView {
    private var player: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    func configure(videoName: String, fileExtension: String) {
        // Find the video file
        guard let url = Bundle.main.url(forResource: videoName, withExtension: fileExtension) else {
            print("⚠️ Video file not found: \(videoName).\(fileExtension)")
            print("   Make sure the file is added to the project bundle (not just Assets)")
            return
        }

        // Create the player item
        let playerItem = AVPlayerItem(url: url)

        // Create queue player (required for AVPlayerLooper)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        self.player = queuePlayer

        // Create looper - this makes the video repeat forever seamlessly
        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

        // Create player layer - this is what displays the video
        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspectFill  // Fill the frame, crop if needed
        layer.backgroundColor = UIColor.clear.cgColor
        self.playerLayer = layer

        // Add the layer to our view
        self.layer.addSublayer(layer)

        // Mute the video (it's just an animation)
        queuePlayer.isMuted = true

        // START PLAYING IMMEDIATELY!
        queuePlayer.play()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Make sure the player layer fills the entire view
        playerLayer?.frame = bounds
    }

    // Clean up when view is removed
    deinit {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
    }
}

// MARK: - Video Player with Fallback
//
// Shows a static image if video fails to load
//

struct VideoPlayerWithFallback: View {
    let videoName: String
    let fallbackImage: String
    var size: CGFloat = 200
    var circular: Bool = true
    var borderColor: Color = Color.AppTheme.sage
    var borderWidth: CGFloat = 4

    // Check if video exists in bundle
    private var videoExists: Bool {
        Bundle.main.url(forResource: videoName, withExtension: "mp4") != nil
    }

    var body: some View {
        Group {
            if videoExists {
                // Play the video!
                VideoPlayerView(
                    videoName: videoName,
                    size: size,
                    circular: circular,
                    borderColor: borderColor,
                    borderWidth: borderWidth
                )
            } else {
                // Fallback to static image
                ZStack {
                    if circular {
                        Circle()
                            .fill(Color.AppTheme.warmCream)
                            .frame(width: size, height: size)
                    }

                    Image(fallbackImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size - borderWidth * 2, height: size - borderWidth * 2)
                        .clipShape(Circle())

                    if circular {
                        Circle()
                            .stroke(borderColor, lineWidth: borderWidth)
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Video Player") {
    VStack(spacing: 20) {
        VideoPlayerView(videoName: "pip_waving", size: 200)

        Text("Pip is waving!")
            .font(.AppTheme.headline)
            .foregroundColor(Color.AppTheme.darkBrown)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.AppTheme.cream)
}

#Preview("With Fallback") {
    VideoPlayerWithFallback(
        videoName: "pip_waving",
        fallbackImage: "pip_waving",
        size: 200
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.AppTheme.cream)
}
