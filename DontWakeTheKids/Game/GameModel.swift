import Foundation
import SwiftUI

enum GameEvent {
    case softCreak, loudCreak, bark, spoon, taskDone, won, lost
}

struct Toast: Equatable {
    let id: Int
    let text: String
    let isBad: Bool
}

struct GameResult: Equatable {
    let won: Bool
    let title: String
    let text: String
    let stats: String
    let stars: Int
    let score: Int
    let isNewBest: Bool
}

enum Phase: Equatable {
    case intro
    case playing
    case over(GameResult)
}

/// A sleeping kid with a wake meter from 0 (deep sleep) to 100 (awake).
struct Sleeper {
    let id: String
    let name: String
    let x: Double
    let y: Double
    let room: Room
    let sensitivity: Double
    var meter: Double = 0
    var peak: Double = 0
}

/// All of the game's rules. The scene draws this state; SwiftUI shows the HUD.
@MainActor
final class GameModel: ObservableObject {
    // Tuning
    static let startMinute = 30.0          // 5:30 AM
    static let deadlineMinute = 75.0       // 6:15 AM train
    static let gameMinutesPerSecond = 0.5  // whole morning is about 90 seconds
    static let walkSpeed = 5.0             // tiles per second
    static let tiptoeSpeed = 2.2
    static let meterDecayPerSecond = 3.0
    static let stirLevel = 65.0

    // HUD state
    @Published private(set) var phase: Phase = .intro
    @Published private(set) var clockText = GameModel.format(minute: GameModel.startMinute)
    @Published private(set) var meters: [Double] = [0, 0]
    @Published private(set) var completed: Set<ChecklistItem> = []
    @Published private(set) var availableTasks: [MorningTask] = []
    @Published private(set) var activeTask: MorningTask?
    @Published private(set) var activeProgress: Double = 0
    @Published private(set) var toast: Toast?
    @Published var tiptoe = false
    @Published private(set) var bestScore = UserDefaults.standard.integer(forKey: "bestScore")

    // Simulation state the scene reads every frame
    private(set) var posX = Double(House.start.x)
    private(set) var posY = Double(House.start.y)
    private(set) var tile = House.start
    private(set) var path: [Tile] = []
    private(set) var pathVersion = 0
    private(set) var facing = 1.0
    private(set) var sleepers: [Sleeper] = GameModel.freshSleepers()
    private(set) var dogHere = true
    private(set) var dogBarkingFor = 0.0
    private(set) var revealedCreaks: Set<Tile> = []
    private(set) var nearbyStations: [Station] = []

    var isBusy: Bool { busy != nil }

    var onNoise: (@MainActor (Tile, Double) -> Void)?
    var onEvent: (@MainActor (GameEvent) -> Void)?

    private struct Busy {
        let task: MorningTask
        var elapsed = 0.0
        var ringTimer = 0.0
        let dropsSpoon: Bool
        var droppedSpoon = false
    }

    private var elapsed = 0.0
    private var barkCooldown = 0.0
    private var freshCoffee = false
    private var busy: Busy?
    private var toastTimer = 0.0
    private var toastCounter = 0
    private var hudTimer = 0.0

    lazy var scene: HouseScene = HouseScene(model: self)

    private var gameMinute: Double { Self.startMinute + elapsed * Self.gameMinutesPerSecond }

    nonisolated static func freshSleepers() -> [Sleeper] {
        [
            Sleeper(id: "baby", name: "The baby", x: 6.5, y: 1, room: .baby, sensitivity: 1.8),
            Sleeper(id: "maya", name: "Maya", x: 1.5, y: 7, room: .kid, sensitivity: 1.2),
        ]
    }

    nonisolated static func format(minute: Double) -> String {
        let total = Int(minute)
        return String(format: "%d:%02d AM", 5 + total / 60, total % 60)
    }

    // MARK: - Game flow

    func start() {
        posX = Double(House.start.x)
        posY = Double(House.start.y)
        tile = House.start
        path = []
        pathVersion += 1
        facing = 1
        sleepers = Self.freshSleepers()
        dogHere = true
        dogBarkingFor = 0
        barkCooldown = 0
        revealedCreaks = []
        elapsed = 0
        freshCoffee = false
        busy = nil
        activeTask = nil
        activeProgress = 0
        completed = []
        meters = [0, 0]
        clockText = Self.format(minute: Self.startMinute)
        toast = nil
        toastTimer = 0
        scene.resetVisuals()
        phase = .playing
        refreshNearby()
    }

    func tap(_ target: Tile) {
        guard phase == .playing else { return }
        if busy != nil {
            cancelTask()
            showToast("Stopped")
        }

        var goals = Set<Tile>()
        if isWalkable(target) {
            goals.insert(target)
        } else if House.station(at: target) != nil {
            let tiles = House.furnitureIndex[target].map { House.furniture[$0].tiles } ?? [target]
            for t in tiles {
                for n in t.neighbors where isWalkable(n) { goals.insert(n) }
            }
        }
        guard !goals.isEmpty else { return }

        // If we're between tiles, finish the current step first.
        let stepInProgress = path.first
        let origin = stepInProgress ?? tile
        guard let route = findPath(from: origin, to: goals) else { return }
        path = (stepInProgress.map { [$0] } ?? []) + route
        pathVersion += 1
    }

    func perform(_ task: MorningTask) {
        guard phase == .playing, busy == nil else { return }
        if task == .leave {
            guard completed.contains(.dress) else {
                showToast("You can't leave in pajamas", bad: true)
                return
            }
            finish(won: true, wokenID: nil)
            return
        }
        if let item = task.checklistItem, completed.contains(item) {
            showToast("Already done")
            return
        }
        // Stop where you stand.
        path = []
        pathVersion += 1
        posX = Double(tile.x)
        posY = Double(tile.y)
        busy = Busy(task: task, dropsSpoon: task == .lunch && Double.random(in: 0..<1) < 0.4)
        activeTask = task
        activeProgress = 0
    }

    func stopTask() {
        guard busy != nil else { return }
        cancelTask()
        showToast("Stopped")
    }

    // MARK: - Frame update

    func update(_ dt: Double) {
        if toastTimer > 0 {
            toastTimer -= dt
            if toastTimer <= 0 { toast = nil }
        }
        guard phase == .playing else { return }

        elapsed += dt
        barkCooldown -= dt
        dogBarkingFor = max(0, dogBarkingFor - dt)

        if gameMinute >= Self.deadlineMinute {
            finish(won: false, wokenID: nil)
            return
        }

        if var b = busy {
            b.elapsed += dt
            b.ringTimer -= dt
            emit(b.task.noisePerSecond * dt, at: tile)
            if b.ringTimer <= 0 && b.task.noisePerSecond >= 3 {
                onNoise?(tile, b.task.noisePerSecond * 1.4)
                b.ringTimer = 0.5
            }
            if b.dropsSpoon && !b.droppedSpoon && b.elapsed > b.task.duration * 0.5 {
                b.droppedSpoon = true
                emit(40, at: tile)
                onNoise?(tile, 40)
                showToast("CLANG! Dropped a spoon", bad: true)
                onEvent?(.spoon)
            }
            busy = b
            activeProgress = min(1, b.elapsed / b.task.duration)
            if b.elapsed >= b.task.duration { completeTask() }
        } else if let next = path.first {
            let speed = tiptoe ? Self.tiptoeSpeed : Self.walkSpeed
            let dx = Double(next.x) - posX
            let dy = Double(next.y) - posY
            let distance = hypot(dx, dy)
            let step = speed * dt
            if dx != 0 { facing = dx > 0 ? 1 : -1 }
            if step >= distance {
                posX = Double(next.x)
                posY = Double(next.y)
                tile = next
                path.removeFirst()
                pathVersion += 1
                stepped(onto: next)
                refreshNearby()
            } else {
                posX += dx / distance * step
                posY += dy / distance * step
            }
        }

        for i in sleepers.indices {
            sleepers[i].meter = max(0, sleepers[i].meter - Self.meterDecayPerSecond * dt)
            sleepers[i].peak = max(sleepers[i].peak, sleepers[i].meter)
            if sleepers[i].meter >= 100 {
                sleepers[i].meter = 100
                publishHUD()
                finish(won: false, wokenID: sleepers[i].id)
                return
            }
        }

        hudTimer -= dt
        if hudTimer <= 0 {
            hudTimer = 0.1
            publishHUD()
        }
    }

    // MARK: - Rules

    private func isWalkable(_ t: Tile) -> Bool {
        House.isFloor(t) && !(dogHere && t == House.dogBed)
    }

    private func findPath(from start: Tile, to goals: Set<Tile>) -> [Tile]? {
        if goals.contains(start) { return [] }
        var previous: [Tile: Tile] = [:]
        var visited: Set<Tile> = [start]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for n in current.neighbors where !visited.contains(n) && isWalkable(n) {
                visited.insert(n)
                previous[n] = current
                if goals.contains(n) {
                    var route = [n]
                    var step = current
                    while step != start {
                        route.append(step)
                        guard let back = previous[step] else { break }
                        step = back
                    }
                    return route.reversed()
                }
                queue.append(n)
            }
        }
        return nil
    }

    /// Sound spreads to each kid, softened by distance and walls.
    private func emit(_ amount: Double, at t: Tile) {
        let x = Double(t.x)
        let y = Double(t.y)
        let source = House.room(x: x, y: y)
        for i in sleepers.indices {
            let s = sleepers[i]
            let distance = hypot(x - s.x, y - s.y)
            sleepers[i].meter += amount * House.attenuation(from: source, to: s.room) / (1 + distance * 0.12) * s.sensitivity
        }
    }

    private func stepped(onto t: Tile) {
        var noise = tiptoe ? 0.6 : 2.5
        if House.creakyBoards.contains(t) {
            revealedCreaks.insert(t)
            noise = tiptoe ? 12 : 32
            showToast(tiptoe ? "creak…" : "CREEEAK!", bad: !tiptoe)
            onNoise?(t, noise)
            onEvent?(tiptoe ? .softCreak : .loudCreak)
        }
        emit(noise, at: t)

        if dogHere && barkCooldown <= 0 {
            let d = max(abs(t.x - House.dogBed.x), abs(t.y - House.dogBed.y))
            let startled = (!tiptoe && d <= 2) || (noise >= 12 && d <= 4)
            if startled { bark() }
        }
    }

    private func bark() {
        barkCooldown = 5
        dogBarkingFor = 2.5
        emit(45, at: House.dogBed)
        onNoise?(House.dogBed, 45)
        showToast("Pickles barks! WOOF!", bad: true)
        onEvent?(.bark)
    }

    private func completeTask() {
        guard let b = busy else { return }
        busy = nil
        activeTask = nil
        activeProgress = 0
        if let item = b.task.checklistItem { completed.insert(item) }
        if b.task == .grind { freshCoffee = true }
        if b.task == .dog {
            dogHere = false
            showToast("Pickles trots outside")
        } else {
            showToast("\(b.task.name) done")
        }
        onEvent?(.taskDone)
        refreshNearby()
    }

    private func cancelTask() {
        busy = nil
        activeTask = nil
        activeProgress = 0
    }

    private func refreshNearby() {
        var stations: [Station] = []
        for n in tile.neighbors {
            if let s = House.station(at: n), !stations.contains(s) { stations.append(s) }
        }
        if !dogHere { stations.removeAll { $0 == .dog } }
        nearbyStations = stations
        availableTasks = stations.flatMap { MorningTask.tasks(for: $0) }.filter { task in
            guard let item = task.checklistItem else { return true }
            return !completed.contains(item)
        }
    }

    private func showToast(_ text: String, bad: Bool = false) {
        toastCounter += 1
        toast = Toast(id: toastCounter, text: text, isBad: bad)
        toastTimer = 1.8
    }

    private func publishHUD() {
        meters = sleepers.map { min(100, $0.meter) }
        let newClock = Self.format(minute: gameMinute)
        if newClock != clockText { clockText = newClock }
    }

    private func finish(won: Bool, wokenID: String?) {
        busy = nil
        activeTask = nil
        activeProgress = 0
        path = []
        pathVersion += 1

        let tasksDone = completed.count
        let minutesLeft = max(0, Int(Self.deadlineMinute - gameMinute))
        let peak = Int((sleepers.map(\.peak).max() ?? 0).rounded())
        let total = ChecklistItem.allCases.count

        var stars = 0
        var score = 0
        let title: String
        var text: String
        let stats: String

        if won {
            stars = (tasksDone == total && peak < 60) ? 3 : (tasksDone >= 4 ? 2 : 1)
            score = tasksDone * 100 + (freshCoffee ? 50 : 0) + minutesLeft * 10 + max(0, 100 - peak)
            title = stars == 3 ? "Clean getaway" : "Out the door"
            text = tasksDone == total
                ? "Every task done and the house is still silent."
                : "You made it out with \(tasksDone) of \(total) tasks done."
            if freshCoffee {
                text += " Fresh coffee, too."
            } else if completed.contains(.coffee) {
                text += " Instant coffee. It counts."
            } else {
                text += " No coffee. Brave."
            }
            stats = "Score \(score) · \(minutesLeft) min to spare · closest call \(peak)%"
        } else if let wokenID {
            title = wokenID == "baby" ? "The baby is up" : "Maya is up"
            text = wokenID == "baby"
                ? "A wail echoes down the hall. Morning over."
                : "\u{201C}Daddy? Is it morning?\u{201D} Morning over."
            stats = "Tasks done: \(tasksDone) of \(total)"
        } else {
            title = "Missed the train"
            text = "The 6:15 pulls away without you."
            stats = "Tasks done: \(tasksDone) of \(total)"
        }

        let isNewBest = won && score > bestScore
        if isNewBest {
            bestScore = score
            UserDefaults.standard.set(score, forKey: "bestScore")
        }

        phase = .over(GameResult(won: won, title: title, text: text, stats: stats,
                                 stars: stars, score: score, isNewBest: isNewBest))
        onEvent?(won ? .won : .lost)
    }
}
