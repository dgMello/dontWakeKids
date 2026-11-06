import Foundation
import SwiftUI

enum GameEvent {
    case softCreak, loudCreak, bark, spoon, taskDone, won
    /// `wokenID` is the sleeper who woke up, or nil if time ran out.
    case lost(wokenID: String?)
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
    let spec: SleeperSpec
    var meter: Double = 0
    var peak: Double = 0

    var id: String { spec.id }
    var name: String { spec.name }
    var x: Double { spec.x }
    var y: Double { spec.y }
    var room: Room { spec.room }
    var sensitivity: Double { spec.sensitivity }

    init(_ spec: SleeperSpec) {
        self.spec = spec
    }
}

/// All of the game's rules. The scene draws this state; SwiftUI shows the HUD.
@MainActor
final class GameModel: ObservableObject {
    // Tuning. Per-level settings (clock, sleepers, map) live in `LevelDefinition`.
    static let walkSpeed = 5.0             // tiles per second
    static let tiptoeSpeed = 2.2
    static let meterDecayPerSecond = 3.0
    static let stirLevel = 65.0

    // HUD state
    @Published private(set) var phase: Phase = .intro
    @Published private(set) var clockText: String
    @Published private(set) var meters: [Double]
    @Published private(set) var completed: Set<ChecklistItem> = []
    @Published private(set) var availableTasks: [MorningTask] = []
    @Published private(set) var activeTask: MorningTask?
    @Published private(set) var activeProgress: Double = 0
    @Published private(set) var toast: Toast?
    @Published var tiptoe = false
    @Published private(set) var bestScore: Int

    let level: LevelDefinition
    let progress: ProgressStore
    /// The rule systems this level switches on.
    let mechanics: [Mechanic]

    // Simulation state the scene reads every frame
    private(set) var posX: Double
    private(set) var posY: Double
    private(set) var tile: Tile
    private(set) var path: [Tile] = []
    private(set) var pathVersion = 0
    private(set) var facing = 1.0
    private(set) var sleepers: [Sleeper]
    private(set) var dogHere: Bool
    private(set) var dogBarkingFor = 0.0
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

    init(level: LevelDefinition = .classicMorning, progress: ProgressStore = .shared) {
        self.level = level
        self.progress = progress
        mechanics = level.mechanics.map { $0.make() }
        bestScore = progress.progress(for: level.id).bestScore
        posX = Double(level.start.x)
        posY = Double(level.start.y)
        tile = level.start
        sleepers = level.sleepers.map(Sleeper.init)
        meters = level.sleepers.map { _ in 0 }
        dogHere = level.dog != nil
        clockText = level.clock.map { Self.format(minute: $0.startMinute) } ?? ""
        for m in mechanics { m.reset(model: self) }
    }

    /// The first mechanic of a given type, if this level uses it.
    func mechanic<M: Mechanic>(_ type: M.Type) -> M? {
        mechanics.lazy.compactMap { $0 as? M }.first
    }

    private var gameMinute: Double {
        guard let clock = level.clock else { return 0 }
        return clock.startMinute + elapsed * clock.minutesPerSecond
    }

    nonisolated static func format(minute: Double) -> String {
        let total = Int(minute)
        return String(format: "%d:%02d AM", 5 + total / 60, total % 60)
    }

    // MARK: - Game flow

    /// Starts or restarts the level.
    func start() {
        posX = Double(level.start.x)
        posY = Double(level.start.y)
        tile = level.start
        path = []
        pathVersion += 1
        facing = 1
        sleepers = level.sleepers.map(Sleeper.init)
        dogHere = level.dog != nil
        dogBarkingFor = 0
        barkCooldown = 0
        elapsed = 0
        freshCoffee = false
        busy = nil
        activeTask = nil
        activeProgress = 0
        completed = []
        meters = level.sleepers.map { _ in 0 }
        clockText = level.clock.map { Self.format(minute: $0.startMinute) } ?? ""
        toast = nil
        toastTimer = 0
        for m in mechanics { m.reset(model: self) }
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
        } else if level.station(at: target) != nil {
            let tiles = level.furnitureIndex[target].map { level.furniture[$0].tiles } ?? [target]
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
            if let requirement = level.leaveRequirement, !completed.contains(requirement.item) {
                showToast(requirement.message, bad: true)
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

        if let clock = level.clock, gameMinute >= clock.deadlineMinute {
            finish(won: false, wokenID: nil)
            return
        }

        for m in mechanics { m.update(dt, model: self) }
        guard phase == .playing else { return }

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
        } else if let next = path.first, mechanics.allSatisfy({ $0.canMove(model: self) }) {
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

    func isWalkable(_ t: Tile) -> Bool {
        level.isFloor(t) && !(dogHere && t == level.dog?.bed)
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
    func emit(_ amount: Double, at t: Tile) {
        let x = Double(t.x)
        let y = Double(t.y)
        let source = level.room(at: t)
        for i in sleepers.indices {
            let s = sleepers[i]
            let distance = hypot(x - s.x, y - s.y)
            sleepers[i].meter += amount * level.attenuation(from: source, to: s.room) / (1 + distance * 0.12) * s.sensitivity
        }
    }

    private func stepped(onto t: Tile) {
        var noise = tiptoe ? 0.6 : 2.5
        for m in mechanics { m.playerStepped(onto: t, noise: &noise, model: self) }
        emit(noise, at: t)

        if dogHere, barkCooldown <= 0, let bed = level.dog?.bed {
            let d = max(abs(t.x - bed.x), abs(t.y - bed.y))
            let startled = (!tiptoe && d <= 2) || (noise >= 12 && d <= 4)
            if startled { bark() }
        }
    }

    private func bark() {
        guard let dog = level.dog else { return }
        barkCooldown = 5
        dogBarkingFor = 2.5
        emit(45, at: dog.bed)
        onNoise?(dog.bed, 45)
        showToast("\(dog.name) barks! WOOF!", bad: true)
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
            showToast("\(level.dog?.name ?? "The dog") trots outside")
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
            if let s = level.station(at: n), !stations.contains(s) { stations.append(s) }
        }
        if !dogHere { stations.removeAll { $0 == .dog } }
        nearbyStations = stations
        availableTasks = stations.flatMap { MorningTask.tasks(for: $0) }.filter { task in
            guard let item = task.checklistItem else { return true }
            return !completed.contains(item)
        }
    }

    func showToast(_ text: String, bad: Bool = false) {
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
        let minutesLeft = level.clock.map { max(0, Int($0.deadlineMinute - gameMinute)) } ?? 0
        let peak = Int((sleepers.map(\.peak).max() ?? 0).rounded())
        let total = level.checklist.count

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
        } else if let wokenID, let spec = level.sleepers.first(where: { $0.id == wokenID }) {
            title = spec.wokeTitle
            text = spec.wokeText
            stats = "Tasks done: \(tasksDone) of \(total)"
        } else {
            title = level.clock?.missedTitle ?? "Out of time"
            text = level.clock?.missedText ?? "Time ran out."
            stats = "Tasks done: \(tasksDone) of \(total)"
        }

        let isNewBest = won && progress.recordWin(level.id, stars: stars, score: score)
        if isNewBest { bestScore = score }

        phase = .over(GameResult(won: won, title: title, text: text, stats: stats,
                                 stars: stars, score: score, isNewBest: isNewBest))
        onEvent?(won ? .won : .lost(wokenID: wokenID))
    }
}
