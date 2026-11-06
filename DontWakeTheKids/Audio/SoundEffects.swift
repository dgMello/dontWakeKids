import AVFoundation

/// Short sound effects for game events, played alongside haptics.
///
/// Uses the ambient audio session, so it mixes with whatever the player is listening to
/// and stays quiet when the ring/silent switch is set to silent.
/// Sounds live in `Audio/Sounds/` as `.caf` files; raw recordings are kept in `SoundSources/`.
@MainActor
enum SoundEffects {
    private enum Sound: String, CaseIterable {
        case creak
    }

    /// A few players per sound so quick repeats can overlap instead of cutting each other off.
    private static let playersPerSound = 3
    private static var players: [Sound: [AVAudioPlayer]] = [:]
    private static var isLoaded = false

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEffectsOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEffectsOn") }
    }

    /// Sets up the audio session and loads every sound. Safe to call more than once.
    static func preload() {
        guard !isLoaded else { return }
        isLoaded = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient)
        try? session.setActive(true)
        for sound in Sound.allCases {
            players[sound] = (0..<playersPerSound).compactMap { _ in makePlayer(sound) }
        }
    }

    static func play(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .softCreak:
            play(.creak, volume: 0.35)
        case .loudCreak:
            play(.creak, volume: 1.0)
        case .bark, .spoon, .taskDone, .won, .lost:
            break // No recordings yet.
        }
    }

    private static func play(_ sound: Sound, volume: Float) {
        preload()
        guard let pool = players[sound],
              let player = pool.first(where: { !$0.isPlaying }) ?? pool.first else { return }
        player.currentTime = 0
        player.volume = volume
        // Small random speed change so the same creak doesn't sound identical every time.
        player.rate = Float.random(in: 0.92...1.08)
        player.play()
    }

    private static func makePlayer(_ sound: Sound) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.enableRate = true
        player.prepareToPlay()
        return player
    }
}
