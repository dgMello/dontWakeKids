import AVFoundation

/// Sound effects for game events and tasks, played alongside haptics.
///
/// Uses the ambient audio session, so it mixes with whatever the player is listening to
/// and stays quiet when the ring/silent switch is set to silent.
/// Sounds live in `Audio/Sounds/` as `.caf` files; raw recordings and how they were
/// processed are in `SoundSources/`.
@MainActor
enum SoundEffects {
    /// One sound the game can play. Some have several recordings; one is picked at random each time.
    private enum Sound: CaseIterable {
        case creak, water, drawer, doorClose

        var files: [String] {
            switch self {
            case .creak: return ["creak", "creak2"]
            case .water: return ["water"]
            case .drawer: return ["drawer"]
            case .doorClose: return ["doorClose"]
            }
        }
    }

    /// How a task sounds while you do it.
    private struct TaskSound {
        let sound: Sound
        let volume: Float
        var rate: Float = 1
        var loops = 0
    }

    /// A few players per file so quick repeats can overlap instead of cutting each other off.
    private static let playersPerFile = 3
    private static let fadeOut: TimeInterval = 0.2
    private static var players: [String: [AVAudioPlayer]] = [:]
    private static var isLoaded = false
    private static var taskPlayer: AVAudioPlayer?

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
        for file in Sound.allCases.flatMap(\.files) {
            players[file] = (0..<playersPerFile).compactMap { _ in makePlayer(file) }
        }
    }

    static func play(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .softCreak:
            play(.creak, volume: 0.35)
        case .loudCreak:
            play(.creak, volume: 1.0)
        case .won:
            stopTaskSound()
            play(.doorClose, volume: 0.9, varySpeed: false)
        case .lost:
            stopTaskSound()
        case .bark, .spoon, .taskDone:
            break // No recordings yet.
        }
    }

    /// Call whenever the task in progress changes. Starts its sound, or fades out the last one.
    static func taskChanged(to task: MorningTask?) {
        stopTaskSound()
        guard isEnabled, let task, let taskSound = sound(for: task) else { return }
        guard let player = freePlayer(for: taskSound.sound) else { return }
        player.currentTime = 0
        player.volume = taskSound.volume
        player.rate = taskSound.rate
        player.numberOfLoops = taskSound.loops
        player.play()
        taskPlayer = player
    }

    /// Fades out the task sound, e.g. when the task finishes or is interrupted.
    static func stopTaskSound() {
        guard let player = taskPlayer else { return }
        taskPlayer = nil
        player.setVolume(0, fadeDuration: fadeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut + 0.05) {
            // Only stop it if it hasn't been picked up again for a new sound since.
            if player !== taskPlayer, player.volume == 0 {
                player.stop()
                player.numberOfLoops = 0
            }
        }
    }

    private static func sound(for task: MorningTask) -> TaskSound? {
        switch task {
        case .dress: return TaskSound(sound: .drawer, volume: 0.7)
        case .teeth: return TaskSound(sound: .water, volume: 0.6)
        // The shower reuses the water, slowed down for a deeper sound and looped to last 6 seconds.
        case .shower: return TaskSound(sound: .water, volume: 1.0, rate: 0.8, loops: 1)
        case .grind, .instant, .lunch, .dog, .leave: return nil // No recordings yet.
        }
    }

    private static func play(_ sound: Sound, volume: Float, varySpeed: Bool = true) {
        guard let player = freePlayer(for: sound) else { return }
        player.currentTime = 0
        player.volume = volume
        player.numberOfLoops = 0
        // Small random speed change so repeats don't sound identical.
        player.rate = varySpeed ? Float.random(in: 0.92...1.08) : 1
        player.play()
    }

    /// A player for one of the sound's recordings, picked at random, that isn't busy.
    private static func freePlayer(for sound: Sound) -> AVAudioPlayer? {
        preload()
        guard let file = sound.files.randomElement(), let pool = players[file] else { return nil }
        return pool.first { !$0.isPlaying && $0 !== taskPlayer } ?? pool.first { $0 !== taskPlayer }
    }

    private static func makePlayer(_ file: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: file, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.enableRate = true
        player.prepareToPlay()
        return player
    }
}
