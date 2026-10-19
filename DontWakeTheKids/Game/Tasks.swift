import Foundation

/// The items on the sticky note.
enum ChecklistItem: String, CaseIterable, Identifiable {
    case dress, teeth, shower, coffee, lunch, dog

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dress: return "Get dressed"
        case .teeth: return "Teeth"
        case .shower: return "Shower"
        case .coffee: return "Coffee"
        case .lunch: return "Lunches"
        case .dog: return "Dog out"
        }
    }
}

/// Something you do while standing at a station. Coffee has two ways to do it.
enum MorningTask: String, Identifiable {
    case dress, teeth, shower, grind, instant, lunch, dog, leave

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dress: return "Get dressed"
        case .teeth: return "Brush teeth"
        case .shower: return "Shower"
        case .grind: return "Grind fresh beans"
        case .instant: return "Instant coffee"
        case .lunch: return "Pack lunches"
        case .dog: return "Let Pickles out"
        case .leave: return "Leave for work"
        }
    }

    var detail: String {
        switch self {
        case .dress: return "Hangers rattle"
        case .teeth: return "Quiet-ish"
        case .shower: return "Pipes are loud"
        case .grind: return "Very loud, better coffee"
        case .instant: return "Quiet, tastes sad"
        case .lunch: return "Fridge, foil, spoons"
        case .dog: return "Back door squeaks"
        case .leave: return "Front door"
        }
    }

    /// Seconds of real time.
    var duration: Double {
        switch self {
        case .dress, .teeth, .instant: return 3
        case .shower: return 6
        case .grind, .dog: return 2
        case .lunch: return 4
        case .leave: return 0
        }
    }

    /// Noise made each second while doing the task.
    var noisePerSecond: Double {
        switch self {
        case .dress: return 3
        case .teeth: return 4
        case .shower: return 9
        case .grind: return 55
        case .instant: return 2
        case .lunch: return 6
        case .dog: return 8
        case .leave: return 0
        }
    }

    var isLoud: Bool { self == .shower || self == .grind }

    var checklistItem: ChecklistItem? {
        switch self {
        case .dress: return .dress
        case .teeth: return .teeth
        case .shower: return .shower
        case .grind, .instant: return .coffee
        case .lunch: return .lunch
        case .dog: return .dog
        case .leave: return nil
        }
    }

    static func tasks(for station: Station) -> [MorningTask] {
        switch station {
        case .dress: return [.dress]
        case .teeth: return [.teeth]
        case .shower: return [.shower]
        case .coffee: return [.grind, .instant]
        case .lunch: return [.lunch]
        case .dog: return [.dog]
        case .leave: return [.leave]
        }
    }
}
