# Campaign Plan: 8 Levels

This plan turns *Don't Wake the Kids* from one morning into an 8-level campaign. Each level teaches one new mechanic. The finale uses all of them.

It builds on the game we already have. Today's game is a single level: a full morning routine with creaky boards, a noise system, two sleepers and a dog. That is most of the finale (Level 8). So the work is:

1. Turn the hard-coded house into level data.
2. Add one new mechanic per level.

---

## 1. Where the code is today

| What exists | Where | Used later for |
|---|---|---|
| Tile grid, walls, furniture, stations | `House.swift` (all `static`) | Every level's map |
| Noise travels through rooms (`emit`, `attenuation`) | `GameModel.swift`, `House.swift` | Noise meter in every level |
| Creaky boards, revealed once stepped on | `House.creakyBoards`, `GameModel.stepped` | L1 pressure plates |
| Wake meters, sensitivity, decay | `Sleeper`, `GameModel.update` | L4 ripples and every level |
| Dog that barks when startled | `GameModel.bark`, `dogBed` | L6 dog AI |
| Timed tasks with progress ring | `Busy`, `MorningTask` | L7 defusal, L8 routine |
| Darkness vignette texture | `HouseScene.makeDarknessTexture` | Night-mode flashlight cone |
| Stars and best score | `GameModel.finish` | Silent / Close Call ratings |

**The main problem:** `House` is a static enum and `GameModel` reads it directly. There is no concept of a "level". Phase 0 fixes that before any new level is built.

---

## 2. Architecture changes (Phase 0)

### 2.1 `LevelDefinition` replaces the static `House`

```swift
struct LevelDefinition: Identifiable {
    let id: LevelID                  // .lostNap, .cookieJob, ...
    let title: String                // "Raiders of the Lost Nap"
    let tagline: String              // intro card text
    let layout: [String]             // same ASCII format as today
    let furniture: [Furniture]
    let roomMap: [Character: Room]?  // optional: room letters instead of hard-coded ranges
    let start: Tile
    let exits: [Tile]
    let sleepers: [SleeperSpec]
    let pressurePlates: Set<Tile>    // today's creakyBoards
    let objectives: [Objective]
    let mechanics: [MechanicSpec]    // what's switched on for this level
    let timeLimit: Double?           // seconds, nil = none
    let collectibles: [Collectible]
    let starRules: StarRules
}
```

- `House` becomes `LevelDefinition.morning` (today's map), so the current game keeps working through the refactor.
- `House.room(x:y:)` is hard-coded by coordinates. Replace it with a per-level room map (a second ASCII grid of room letters) so new maps don't need new code.

### 2.2 Mechanics as small systems

Each new mechanic is its own type, not more code in `GameModel`:

```swift
@MainActor protocol Mechanic: AnyObject {
    func reset(level: LevelDefinition, model: GameModel)
    func update(_ dt: Double, model: GameModel)        // per frame
    func playerStepped(onto: Tile, model: GameModel)   // per tile
    func canMove(model: GameModel) -> Bool             // freezes, sightlines
    func draw(in scene: HouseScene)                    // scene layer
}
```

| System | Level | Files |
|---|---|---|
| `PressurePlateSystem` (move existing creak logic here) | L1 | `Game/Mechanics/PressurePlates.swift` |
| `ChaseSystem` (rolling ball) | L1 | `Game/Mechanics/Chase.swift` |
| `SightlineSystem` (sweeping camera cone) | L2 | `Game/Mechanics/Sightline.swift` |
| `RopeSystem` (harness, sway) | L3 | `Game/Mechanics/Rope.swift` + `RopeScene.swift` |
| `RippleSystem` (freeze) | L4 | `Game/Mechanics/Ripples.swift` |
| `HazardFieldSystem` (hidden bricks, scan, sweep) | L5 | `Game/Mechanics/Bricks.swift` |
| `DogAISystem` (move dog, treats) | L6 | `Game/Mechanics/Dog.swift` |
| `CountdownSystem` (defusal steps) | L7 | `Game/Mechanics/Countdown.swift` |

`GameModel` keeps movement, pathfinding, noise and scoring. It asks every active mechanic before moving (`canMove`) and tells each one about steps and frames.

### 2.3 Objectives

Today a win is "checklist done + leave". Levels need more kinds:

```swift
enum Objective {
    case swapItem(target: Tile, correctDecoy: DecoyID)   // L1
    case pickUp(station: Station)                         // L2 cookie, L3 phone
    case reachExit                                        // most levels
    case completeChecklist([ChecklistItem])              // L8
    case survive(seconds: Double)                         // L4
    case disarm                                           // L7
}
```

The HUD sticky note shows the level's objectives instead of the fixed morning checklist.

### 2.4 Progress and level select

- `ProgressStore` (Codable JSON in UserDefaults): per level, best stars, best score, collectibles found, night mode unlocked.
- New `LevelSelectView` between `StartScreenView` and `ContentView`: 8 cards, locked until the previous level is cleared.
- `GameModel` gets `load(level:)`. `start()` becomes "restart current level".

### 2.5 Tests

There is no test target yet. Add `DontWakeTheKidsTests` (in `project.yml` too) and test the rules without the scene:

- noise falloff and attenuation
- each mechanic's state changes (camera sweeps, ripple freeze breaks, brick hit, dog follows treat)
- each level can be finished (a scripted path wins)

**Phase 0 done when:** today's game plays exactly the same, but it loads from `LevelDefinition.morning`, creaks run through `PressurePlateSystem`, and a level select screen shows one card.

### 2.6 Phase 0 status: built

Decisions taken: L3 prototyped alone with a top-down fallback; L2 uses a "parent watching" meter; every level fits one screen; today's game stays as **Classic Morning**.

What was built, and where it differs from the sketch above:

- The level is `LevelDefinition.classicMorning` (in `Game/Levels/ClassicMorning.swift`), not `.morning`.
- Rooms come from a `roomLayout` grid of letters. A test checks it matches the old hard-coded rules tile by tile.
- `Mechanic` has `reset`, `update`, `playerStepped(onto:noise:)`, `canMove`, `buildVisuals` and `syncVisuals`. Mechanics own their scene layers, so the scene knows nothing about creaks any more.
- Instead of `GameModel.load(level:)`, each level gets a fresh `GameModel` (the screen is rebuilt per level). Simpler, and no leftover state between levels.
- `Objective`, `collectibles` and `StarRules` are not in `LevelDefinition` yet. They arrive with the first level that needs them (L1), so they're shaped by a real use.
- `ProgressStore` carries over the old single best score into Classic Morning.
- The start screen's button now says **Play** and opens the level list.

---

## 3. The levels

Shared rules for every level:

- **Noise meter:** the existing wake meters. Hitting 100 fails the level.
- **Rating** (replaces the current 1–3 stars):
  - **Silent** (3 stars): the loudest moment stayed under 35%.
  - **Close Call** (2 stars): finished, but a meter went over 35%.
  - **Woke Them** (0 stars): failed. Shows a "they woke up" card.
  - 1 star is kept for "finished, but missed the optional goal" (e.g. no collectible, slow time) so a clear always feels earned.
- **Collectibles:** 1 lost sock and 1 pacifier per level, placed off the main path.

### L1 · "Raiders of the Lost Nap" (temple, tutorial)
**Teaches:** pressure plates (creaky boards) and the noise meter.

- **Goal:** take the toddler's stuffed animal from the bed and leave a decoy of the right weight.
- **Decoy choice:** three decoys on a shelf (rolled towel, sock bundle, beanbag). The wrong weight makes the toddler shift in their sleep (meter spike), not instant failure. The shelf shows a hint ("feels about as heavy as a bunny").
- **Pressure plates:** creaky boards start hidden. A soft shimmer shows them in this level only, as a tutorial. From L2 on they're hidden until you step on them, like today.
- **Escape:** once you swap, a toy ball starts rolling down the hallway (`ChaseSystem`). The ball moves along a fixed path at a set speed. If it reaches the door first it bumps the door and makes a big noise. You need to walk (not tiptoe) to beat it, so you must pick a route around the creaks.
- **Teaching beats:** step 1, the meter on its own; step 2, one creak right in your path; step 3, the swap; step 4, the chase.
- **Tuning:** ball speed (start at 3.5 tiles/s, between tiptoe 2.2 and walk 5.0), decoy weight tolerance.
- **Size:** M

### L2 · "The Cookie Job" (heist)
**Teaches:** sightlines.

- **Goal:** get the cookie jar from the high shelf and get out.
- **Camera:** a baby monitor sweeps a cone across the room on a fixed rhythm (e.g. 4 s left, 1 s pause, 4 s right). Drawn as a soft cone in `HouseScene`.
- **Caught on camera:** being in the cone doesn't fail the level. It wakes the *parent on the other end* (a second meter that fills fast while you're visible). Fits the theme, and it keeps the noise meter as the core idea.
- **High shelf:** need to drag a step stool (a new "push furniture" action: one tile per tap, makes noise).
- **Cover:** furniture blocks the cone (raycast on the grid).
- **Tuning:** sweep speed, pause length, cone width and range.
- **Size:** M

### L3 · "Mission: Coffee" (spy)
**Teaches:** balance and timing.

- **Goal:** lower yourself on a harness made of belts to grab your phone from its charger without touching the toys below.
- **Different view:** this is the one level that isn't top-down. Use a separate `RopeScene` (side view): hold to lower, release to stop, tilt or drag to steer. The rope sways like a pendulum. Moving fast increases the sway.
- **Hazard:** toys stacked below (tower of blocks, a squeaky duck). If the sway touches one, it falls and makes noise.
- **Belt knots:** at set lengths the rope jerks slightly (a knot slipping), which adds sway. You learn to slow down before each one.
- **Fallback if it isn't fun:** a top-down version where you place the harness anchor and "reach" over toy tiles. Decide after the prototype.
- **Tuning:** pendulum damping, lowering speed, knot positions.
- **Size:** L (new scene and controls)

### L4 · "Ripples" (monster movie)
**Teaches:** freezing.

- **Goal:** cross a kid's room to get something (e.g. the library book due today) and get out.
- **Ripples:** a glass of water on the nightstand shows ripples when the kid starts to stir. This is a warning, a short time before the kid's sensitivity jumps.
- **Freeze:** when the ripples start, stop completely. Any step or task while the glass ripples adds a large amount to the meter. After the kid settles (2–4 s, random), the ripples stop and you can move again.
- **Tells:** ripple animation on the glass, a soft rumble haptic, and a short sound. Make it readable with the sound off.
- **Rhythm:** stirs come at uneven intervals, with one fake early on (the glass shakes because a truck drives by, no stir) to teach watching closely.
- **Tuning:** warning lead time (start at 0.8 s), stir length, penalty for moving.
- **Size:** S–M. Most of this is a timer plus a `canMove` gate.

### L5 · "Brick Field" (minefield)
**Teaches:** path planning.

- **Goal:** cross the living room to the TV remote (or the front door).
- **Bricks:** the floor has hidden building bricks. Stepping on one makes you yelp (big noise).
- **Scan:** a "look" action reveals bricks within 2 tiles, but costs 2 seconds of game time. Teaches planning vs. time.
- **Sweeper:** pick up a slipper. Use it to sweep one tile ahead, which clears any bricks there with a soft clatter (small noise). Limited uses (e.g. 5).
- **Pathfinding:** tap-to-walk must not route through revealed bricks. Unrevealed ones are fair game, so long taps across unknown floor are risky. That is the lesson.
- **Tuning:** brick density, scan radius, sweeper uses.
- **Size:** M

### L6 · "The Great Escape" (prison break)
**Teaches:** distractions.

- **Goal:** bedroom to front door without the dog barking.
- **Dog AI:** the dog moves between spots on a patrol. It notices you within a radius, more if you walk than tiptoe (extends the current bark rule).
- **Treats:** pick up a treat bag (3 treats). Tap a tile to throw. The dog goes to that tile and eats for a few seconds. The treat landing makes a small noise at that spot, so throwing near a sleeper's room is risky.
- **Tuning:** dog speed, notice radius, eating time, landing noise.
- **Size:** M

### L7 · "Zero Hour" (bomb defusal)
**Teaches:** speed under pressure.

- **Goal:** turn off a loud toy before its song plays.
- **Countdown:** big on-screen timer (e.g. 45 s). If it hits 0, the toy plays a song (huge noise, level fails unless the meters are near 0).
- **Defusal steps:** find the toy (it's in one of a few spots, it beeps faintly), find the tiny screwdriver (junk drawer), then a close-up view: unscrew 2 screws (circle gestures), open the battery hatch, pull the batteries. Each step has a chance of a small noise if rushed.
- **Tension vs. noise:** rushing (walking, fast unscrewing) is louder; going slow risks the timer.
- **Tuning:** timer length, screw turns, noise when rushed.
- **Size:** M (needs a small close-up overlay view)

### L8 · "The Final Temple" (finale)
**Teaches:** nothing new; tests everything.

- **Goal:** the full morning routine: coffee, keys, lunchbox, out the door.
- **Starts from today's map** (`LevelDefinition.morning`) with every mechanic layered in:
  - creaky boards (L1)
  - baby monitor in the nursery hallway (L2)
  - a glass of water in Maya's room (L4)
  - bricks in the living room (L5)
  - patrolling dog with treats (L6)
  - a toy on a timer somewhere in the house (L7)
  - L3's harness can be a short optional shortcut to the keys on top of the fridge
- **Ending:** win card, then credits roll... then, after a pause, a baby cries. Card: "Credits roll... then the baby cries." A button: "Do it all again tomorrow" (restart in night mode).
- **Size:** M, mostly level design and tuning since the systems already exist.

### Why this order works
- L1–L4 each add one sense: sound, sight, touch, then reading the kid.
- L5–L7 add planning, distraction and time pressure.
- L8 tests all of it, so the player feels they've mastered something.

---

## 4. Replay hooks

| Hook | How | Size |
|---|---|---|
| **Silent / Close Call / Woke Them** | Replace star logic in `finish()` with `StarRules` per level; show on level cards | S |
| **Collectibles** (socks, pacifiers) | `Collectible` tiles in level data; picked up by stepping on them; counted in `ProgressStore`; a tally on the level select screen | S |
| **Night mode** | Unlocks after a Silent clear. Reuse `makeDarknessTexture` as a full-screen dark layer with a cone cut out in the player's facing direction. Creaks, bricks and toys are only visible in the cone | M |
| Best time per level | Store on clear | S |

---

## 5. Order of work

Build L1 and L4 first. If the noise loop and the freeze loop aren't fun, the rest won't be either, and it costs little to find out.

| Phase | Work | Done when |
|---|---|---|
| **0. Refactor** | `LevelDefinition`, room map, `Mechanic` protocol, move creaks into `PressurePlateSystem`, `ProgressStore`, level select with 1 card, test target | Today's game plays exactly the same from level data |
| **1. Prototype L1 + L4** | `ChaseSystem`, decoy swap, `RippleSystem`, two grey-box maps | Both levels playable start to finish |
| **Playtest gate** | 5+ people play L1 and L4 cold | Do they understand creaks with no text? Do they freeze on ripples without being told twice? Do they want to retry for Silent? If not, tune or redesign before going on |
| **2. Core levels** | L2 sightlines, L5 bricks, L6 dog, L7 countdown (in that order, cheapest to riskiest) | Each level playable, rated, with collectibles |
| **3. L3 prototype** | `RopeScene` side view; decide on side view vs. top-down fallback | One version is fun |
| **4. Finale** | L8 built on the morning map with all systems; credits gag | Whole campaign beatable in order |
| **5. Replay** | Ratings UI, collectibles UI, night mode | All hooks live |
| **6. Art, sound, polish** | Real art per level theme, sound design, haptics per mechanic, App Store screenshots | Ready for TestFlight |

Art waits until after the playtest gate, so nothing gets drawn for a level that later changes.

---

## 6. File plan

```
DontWakeTheKids/
  Game/
    LevelDefinition.swift      new: data types (Objective, SleeperSpec, StarRules, ...)
    Levels/
      Level1_LostNap.swift     one file per level, data only
      ...
      Level8_FinalTemple.swift
      Morning.swift            today's House, kept as data
    Mechanics/
      Mechanic.swift           protocol
      PressurePlates.swift, Chase.swift, Sightline.swift, Rope.swift,
      Ripples.swift, Bricks.swift, Dog.swift, Countdown.swift
    GameModel.swift            slimmer: movement, noise, objectives, scoring
    HouseScene.swift           draws any level; mechanics add their own layers
    RopeScene.swift            L3 side view
    ProgressStore.swift
  UI/
    LevelSelectView.swift      new
    DefuseView.swift           new: L7 close-up
    ContentView.swift          objectives on sticky note, level intro cards
DontWakeTheKidsTests/          new test target
```

---

## 7. Risks and open questions

1. **L3 is a different game.** A side view with its own controls is the most expensive level. Prototype it alone; the top-down fallback keeps the campaign moving.
2. **L2's fail state.** Does being seen fill a "parent watching" meter (proposed), or is it instant failure? A meter is kinder and fits the noise-meter idea.
3. **Map size.** Today's map is 14×15 on a phone in portrait. Levels like L5 may want more room; decide whether the camera scrolls or every level fits one screen (simpler; recommended for now).
4. **Tutorial text.** Each level gets one intro card and one in-level hint. Keep text short; the riff is that the mechanics teach themselves.
5. **Theme references.** Level names riff on film genres. Keep the art generic (a dusty "temple" made of pillows, not a copy of any film's look) so the game stays its own thing.
6. **Keep the current mode?** Recommend keeping today's morning as "Classic Morning" on the level select, unlocked from the start, so existing players don't lose it.
