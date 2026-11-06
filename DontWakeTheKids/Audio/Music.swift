import AVFoundation

/// Music, kept separate from sound effects so each can be switched off on its own.
/// Files live in `Audio/Music/`; original recordings are in `SoundSources/`.
@MainActor
enum Music {
    private static var player: AVAudioPlayer?
    private static let volume: Float = 0.8

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "musicOn") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "musicOn")
            if !newValue { stop() }
        }
    }

    /// The title jingle, played on the start screen. Restarts from the top if it's already playing.
    static func playTheme() {
        guard isEnabled else { return }
        SoundEffects.preload() // sets up the shared audio session
        if player == nil, let url = Bundle.main.url(forResource: "theme", withExtension: "m4a") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        }
        guard let player else { return }
        player.currentTime = 0
        player.volume = volume
        player.play()
    }

    /// Fades the music out, e.g. when leaving the start screen.
    static func stop(fade: TimeInterval = 0.4) {
        guard let player, player.isPlaying else { return }
        player.setVolume(0, fadeDuration: fade)
        DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.05) {
            if player.volume == 0 { player.stop() }
        }
    }
}
