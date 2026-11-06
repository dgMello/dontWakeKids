import Foundation

extension LevelDefinition {
    /// The original game: the whole morning routine, out the door by 6:15.
    /// Later this map becomes the base for the finale.
    static let classicMorning = LevelDefinition(
        id: .classicMorning,
        title: "Classic Morning",
        subtitle: "The whole routine. Out the door by 6:15.",
        intro: LevelIntro(
            title: "5:30 AM. Shhh.",
            text: "Get through your morning and out the front door by 6:15 without waking the baby or Maya.",
            hint: "Tap the floor to walk. Stand next to the closet, sink, shower, coffee, fridge or back door to do a task. Tiptoe is quiet but slow. Some floorboards creak, and Pickles the dog barks if you stomp past.",
            startButton: "Start my morning"
        ),
        layout: [
            "##############",
            "#....#....#..#",
            "#....#....#..#",
            "#....#....#..#",
            "##.#####.##.##",
            "#............#",
            "###.####.#####",
            "#.....#......#",
            "#.....#......#",
            "#.....#......G",
            "#######......#",
            "#............#",
            "#.....#......#",
            "#.....#......#",
            "####F#########",
        ],
        // M your room, B nursery, T bath, H hall, K Maya's room, C kitchen, L living room
        roomLayout: [
            "CCCCCCCCCCCCCC",
            "MMMMMCBBBBCTTT",
            "MMMMMCBBBBCTTT",
            "MMMMMCBBBBCTTT",
            "HHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHH",
            "HHHHHHHHHHHHHH",
            "KKKKKKCCCCCCCC",
            "KKKKKKCCCCCCCC",
            "KKKKKKCCCCCCCC",
            "CCCCCCCCCCCCCC",
            "LLLLLLCCCCCCCC",
            "LLLLLLCCCCCCCC",
            "LLLLLLCCCCCCCC",
            "LLLLLLCCCCCCCC",
        ],
        furniture: [
            Furniture(x: 1, y: 1, w: 2, h: 2, label: "Bed", station: nil, kind: .bed, colorHex: 0x3C4677),
            Furniture(x: 4, y: 1, w: 1, h: 1, label: "Closet", station: .dress, kind: .plain, colorHex: 0x4A3F6B),
            Furniture(x: 6, y: 1, w: 2, h: 1, label: "", station: nil, kind: .crib, colorHex: 0x3D4A7A),
            Furniture(x: 11, y: 1, w: 1, h: 1, label: "Sink", station: .teeth, kind: .plain, colorHex: 0x3F6A88),
            Furniture(x: 12, y: 1, w: 1, h: 2, label: "Shower", station: .shower, kind: .plain, colorHex: 0x35607E),
            Furniture(x: 1, y: 7, w: 2, h: 1, label: "", station: nil, kind: .kidBed, colorHex: 0x5A3F6E),
            Furniture(x: 9, y: 7, w: 2, h: 1, label: "Coffee", station: .coffee, kind: .plain, colorHex: 0x5A4A3A),
            Furniture(x: 12, y: 7, w: 1, h: 1, label: "Fridge", station: .lunch, kind: .plain, colorHex: 0x6C7186),
            Furniture(x: 9, y: 10, w: 2, h: 2, label: "Table", station: nil, kind: .plain, colorHex: 0x4D3E34),
            Furniture(x: 1, y: 11, w: 1, h: 3, label: "Couch", station: nil, kind: .plain, colorHex: 0x3A4A6A),
        ],
        roomLabels: [
            RoomLabel(text: "Your room", x: 2.0, y: 3.1), RoomLabel(text: "Nursery", x: 7.5, y: 2.1),
            RoomLabel(text: "Bath", x: 11.0, y: 3.1), RoomLabel(text: "Hall", x: 5.5, y: 5.0),
            RoomLabel(text: "Maya's room", x: 3.0, y: 8.8), RoomLabel(text: "Kitchen", x: 9.5, y: 12.2),
            RoomLabel(text: "Living room", x: 3.0, y: 10.7), RoomLabel(text: "Front door", x: 4.0, y: 13.1),
        ],
        start: Tile(x: 3, y: 2),
        sleepers: [
            SleeperSpec(id: "baby", name: "The baby", meterLabel: "Baby", x: 6.5, y: 1, room: .baby,
                        sensitivity: 1.8, wokeTitle: "The baby is up",
                        wokeText: "A wail echoes down the hall. Morning over."),
            SleeperSpec(id: "maya", name: "Maya", meterLabel: "Maya, 8", x: 1.5, y: 7, room: .kid,
                        sensitivity: 1.2, wokeTitle: "Maya is up",
                        wokeText: "\u{201C}Daddy? Is it morning?\u{201D} Morning over."),
        ],
        dog: DogSpec(name: "Pickles", bed: Tile(x: 3, y: 12)),
        pressurePlates: [
            Tile(x: 3, y: 3), Tile(x: 4, y: 5), Tile(x: 7, y: 5), Tile(x: 10, y: 5), Tile(x: 3, y: 6),
            Tile(x: 10, y: 8), Tile(x: 8, y: 11), Tile(x: 5, y: 12), Tile(x: 2, y: 9),
        ],
        adjacentRooms: [
            (.hall, .master), (.baby, .hall), (.bath, .hall), (.hall, .kid), (.hall, .kitchen),
            (.kitchen, .living), (.baby, .master), (.baby, .bath), (.kid, .living), (.kid, .kitchen),
        ],
        checklist: ChecklistItem.morningRoutine,
        leaveRequirement: (item: .dress, message: "You can't leave in pajamas"),
        clock: LevelClock(
            startMinute: 30,      // 5:30 AM
            deadlineMinute: 75,   // 6:15 AM train
            minutesPerSecond: 0.5, // whole morning is about 90 seconds
            deadlineLabel: "TRAIN AT 6:15",
            missedTitle: "Missed the train",
            missedText: "The 6:15 pulls away without you."
        ),
        mechanics: [.pressurePlates]
    )
}
