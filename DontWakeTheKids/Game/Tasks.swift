import Foundation

/// The items on the sticky note.
enum ChecklistItem: String, CaseIterable, Identifiable {
    case dress, teeth, shower, coffee, lunch, dog
    case decoy, swap, book

    static let morningRoutine: [ChecklistItem] = [.dress, .teeth, .shower, .coffee, .lunch, .dog]

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dress: return "Get dressed"
        case .teeth: return "Teeth"
        case .shower: return "Shower"
        case .coffee: return "Coffee"
        case .lunch: return "Lunches"
        case .dog: return "Dog out"
        case .decoy: return "Get a decoy"
        case .swap: return "Swap the bunny"
        case .book: return "Library book"
        }
    }
}

/// What you can leave on the bed in place of the bunny.
enum Decoy {
    case towel, socks, beanbag
}

/// Something you do while standing at a station. Coffee has two ways to do it.
enum MorningTask: String, Identifiable {
    case dress, teeth, shower, grind, instant, lunch, dog, leave
    case pickTowel, pickSocks, pickBeanbag, swap, book

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
        case .pickTowel: return "Rolled towel"
        case .pickSocks: return "Sock bundle"
        case .pickBeanbag: return "Beanbag"
        case .swap: return "Swap the bunny"
        case .book: return "Take the book"
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
        case .pickTowel: return "Hardly weighs a thing"
        case .pickSocks: return "About as heavy as a bunny"
        case .pickBeanbag: return "Really heavy"
        case .swap: return "Steady hands"
        case .book: return "Slide it out slowly"
        }
    }

    /// Seconds of real time.
    var duration: Double {
        switch self {
        case .dress, .teeth, .instant: return 3
        case .shower: return 6
        case .grind, .dog, .swap, .book: return 2
        case .pickTowel, .pickSocks, .pickBeanbag: return 1
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
        case .instant, .swap, .book: return 2
        case .pickTowel, .pickSocks, .pickBeanbag: return 1
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
        case .pickTowel, .pickSocks, .pickBeanbag: return .decoy
        case .swap: return .swap
        case .book: return .book
        }
    }

    var decoy: Decoy? {
        switch self {
        case .pickTowel: return .towel
        case .pickSocks: return .socks
        case .pickBeanbag: return .beanbag
        default: return nil
        }
    }

    /// What must be done first, with the message shown if it isn't.
    var prerequisite: (item: ChecklistItem, message: String)? {
        self == .swap ? (.decoy, "Get a decoy from the shelf first") : nil
    }

    /// The toast when the task finishes.
    var doneMessage: String {
        if decoy != nil { return "Got the \(name.lowercased())" }
        switch self {
        case .swap: return "Got the bunny! Now get out!"
        case .book: return "Got the book"
        default: return "\(name) done"
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
        case .shelf: return [.pickTowel, .pickSocks, .pickBeanbag]
        case .swap: return [.swap]
        case .book: return [.book]
        }
    }
}
