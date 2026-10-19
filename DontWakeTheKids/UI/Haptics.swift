import UIKit

/// The game is about silence, so feedback comes through your hand instead of the speaker.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static func play(_ event: GameEvent) {
        switch event {
        case .softCreak:
            light.impactOccurred()
        case .loudCreak, .spoon:
            heavy.impactOccurred()
        case .bark:
            notify.notificationOccurred(.warning)
        case .taskDone:
            light.impactOccurred(intensity: 0.6)
        case .won:
            notify.notificationOccurred(.success)
        case .lost:
            notify.notificationOccurred(.error)
        }
    }
}
