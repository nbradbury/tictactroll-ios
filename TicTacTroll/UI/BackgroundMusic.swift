import AVFoundation

/// Loops the background music while enabled and the app is active.
@MainActor
final class BackgroundMusic {
    private let player: AVAudioPlayer?

    init(resource: String, volume: Float = 0.6) {
        player = Bundle.main.url(forResource: resource, withExtension: "mp3").flatMap { try? AVAudioPlayer(contentsOf: $0) }
        player?.numberOfLoops = -1
        player?.volume = volume
    }

    func update(playing: Bool) {
        guard let player else { return }
        if playing {
            if !player.isPlaying { player.play() }
        } else if player.isPlaying {
            player.pause()
        }
    }
}
