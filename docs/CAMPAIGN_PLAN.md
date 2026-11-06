# Campaign Plan: 8 Levels + a Bonus

This plan turns *Don't Wake the Kids* from one morning into an 8-level campaign, plus a bonus level. Each level teaches one new mechanic. The finale uses all of them.

It builds on the game we already have. Today's game is a single level: a full morning routine with creaky boards, a noise system, two sleepers and a dog. That is most of the finale (Level 8). So the work is:

1. Turn the hard-coded house into level data.
2. Add one new mechanic per level.

---

## 0. Homage, not copy

Every level riffs on a film genre and one famous kind of scene. None of them copies a film. The joke is the scale shift: a big-screen moment played out with household things at 5:30 AM.

**Never use:**
- character names, faces or look-alikes, or signature outfits (no hat-and-whip adventurer, no tuxedo spy)
- dialogue, catchphrases or famous lines
- film music, or music that sounds like it
- logos, title fonts or posters
- recreated sets, shots or famous props (no golden idol, no staff with a headpiece, no miniature city model)
- a film's exact title (puns are fine)

**Always:**
- **Swap the props for household ones.** A stuffed bunny, not an idol. A suncatcher, not a staff.
- **Change the stakes and the ending.** Every scene ends in a parenting joke, not the film's ending.
- **Use our own art style.** A "temple" is pillows, blankets and nightlight glow, not a stone tomb.
- **Use original music and sounds.**

**The check:** every level design lists what it riffs on and what makes it ours. If the "ours" column is thin, redesign it.

| Level | Riffs on | What makes it ours |
|---|---|---|
| L1 Raiders of the Lost Nap | Temple adventure: a treasure swap, a trap-filled floor, a chase | A stuffed bunny and a rolled-towel decoy; a cracked bedroom door for light; toys on the floor; a toddler's ball rolling down the hall |
| Bonus: The Sunbeam | Adventure: light through an object reveals a hidden spot | A toddler's crayon "treasure map", a suncatcher, window blinds, car keys in the toy box, a kid asleep on the couch |
| L2 The Cookie Job | Heist: dodging a sweeping camera | A baby monitor, a cookie jar, a step stool; the "guard" is a half-asleep parent |
| L3 Mission: Coffee | Spy: lowered from the ceiling on a wire | Belts tied together, a phone on its charger, a tower of blocks |
| L4 Ripples | Monster film: trembling water as a warning | A kid stirring in bed, a library book, a passing truck as a fake-out |
| L5 Brick Field | War film: a minefield | Building bricks, a slipper as a sweeper |
| L6 The Pawshank Redemption | Prison break | The family dog, treats that make noise when they land |
| L7 Zero Hour | Bomb defusal | A singing toy, a battery hatch, a tiny screwdriver |
| L8 The Final Temple | Finale that calls back to L1 | The whole morning routine; "credits roll... then the baby cries" |

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
| `FloorHazardSystem` (today's creaky boards, grown into creaky boards, toys and bricks; each hidden always or shown when lit) | L1, L5 | `Game/Mechanics/PressurePlates.swift` → `FloorHazards.swift` |
| `LightSystem` (light cones blocked by walls and furniture; reveals hazards; light on a sleeper's face raises their meter; light sources can move) | L1, Bonus | `Game/Mechanics/Light.swift` |
| `ChaseSystem` (rolling ball) | L1 | `Game/Mechanics/Chase.swift` |
| `SightlineSystem` (sweeping camera cone; reuses `LightSystem`'s "what can this cone see" code) | L2 | `Game/Mechanics/Sightline.swift` |
| `RopeSystem` (harness, sway) | L3 | `Game/Mechanics/Rope.swift` + `RopeScene.swift` |
| `RippleSystem` (freeze) | L4 | `Game/Mechanics/Ripples.swift` |
| Scan and sweep actions for hidden hazards | L5 | in `FloorHazards.swift` |
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

### 2.7 Phase 1 status: L4 built, L1 partly built

L1 and L4 are playable start to finish on grey-box maps (`Game/Levels/Level1_LostNap.swift`, `Level4_Ripples.swift`). Level select order is L1, L4, Classic Morning. Classic Morning is always open; L4 unlocks when L1 is cleared.

Where the build differs from the plans below:

- **No hard freeze in L4.** `canMove` stays true during a stir. Moving is allowed and very loud, because choosing to stop is the skill. Tap-to-walk had no way to stop, so L4 has a **Freeze** button (`GameModel.stopWalking()`).
- **Objectives are still the checklist plus `leaveRequirement`.** Both levels fit that, so the `Objective` enum isn't built yet. `MorningTask.prerequisite` covers "decoy before swap".
- **`StarRules` has two cases.** `.morningRoutine` keeps Classic Morning's old rules; `.quiet(under:outro:)` gives 3 stars under 35% and 2 otherwise. 1 star waits for collectibles.
- **The ball waits 0.8 s after the swap** so the swap toast can be read and the player can react.
- **Wrong decoy:** the sock bundle is correct; the others add a spike of about 45% in-room noise. The choice can't be changed once made.
- **The truck** shakes the glass sideways with no rings and shows a toast. Moving during it is free.
- **No ripple sound yet.** The tells are the rings, a haptic and a one-time toast. `SoundEffects` has no recording for `.rumble` or `.thud`, so the ripples, truck and ball are silent for now.

**L1 was built before the L1 redesign in section 3 and doesn't match it yet.** Built: visible creaks, a tap to swap, and the sock bundle as the right decoy. Not built: `LightSystem`, `FloorHazardSystem` and toys, the door crack and nightlight, the rolled towel as the right decoy, weight bars, and the timed hold swap. The ball chase and L4 match the current spec, apart from the freeze change above.

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
**Teaches:** the noise meter, and that light shows you the danger on the floor.

Four steps, each building on the last.

**1. Light: crack the door**
- The toddler's room starts dark (the existing darkness layer). You stand at the door with the hall light behind you.
- Choose how far to open the door: a crack, halfway or wide. Light comes in as a wedge.
- Wider shows more floor, but wide open puts the light on the toddler's face. Their meter rises as long as it stays there: light is a second kind of noise.
- Halfway lights the near half of the room and stays off the bed. That's the answer, but the far half stays dark.
- A nightlight on the dresser lights the last stretch. Turning it on makes a small click (a little noise).

**2. Dodge the toys**
- Toys are scattered on the floor: a squeaky duck, a rattle, a xylophone, a bead maze. Stepping on one makes noise, and louder toys are worse.
- Toys are only visible where the light falls. In the dark you can't see them, so step 1 matters.
- One toy sits right where a player would walk without looking, so the lesson lands early.

**3. The swap: match the weight**
- The bunny is tucked under the toddler's arm. Three decoys on a shelf: a sock ball (too light), a rolled towel (right), a beanbag frog (too heavy, and it rattles).
- Clue: you can't weigh the bunny, but you can see how deep it presses into the pillow. Picking up a decoy shows its weight as a small bar to compare.
- The swap is a hold. Too slow and the toddler feels the missing weight (meter climbs during the gap); too fast and you jostle them (spike).
- A wrong decoy makes the toddler shift in their sleep (a meter spike), not an instant fail, so players learn by trying.

**4. Escape: the ball**
- Taking the bunny knocks a toy ball loose. It rolls down the hall along a fixed path (`ChaseSystem`). If it reaches the door first it bumps it: a big noise.
- You have to walk, not tiptoe, to beat it, across the floor you lit earlier. Steps 1 and 2 pay off here.

- **Tuning:** door-light angles, light-on-face rate, toy noise levels, decoy weights and tolerance, swap timing window, ball speed (start at 3.5 tiles/s, between tiptoe 2.2 and walk 5.0).
- **If it's too much for a first level:** cut the nightlight, so halfway open lights the whole path.
- **Size:** M–L (the light system is new, but L2 and the bonus reuse it)

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
**Teaches:** path planning. This is the hard version of L1's toys: in L1 you see the hazards once they're lit and walk around them. Here they're hidden, and you need tools to find them.

- **Goal:** cross the living room to the TV remote (or the front door).
- **Bricks:** the floor has hidden building bricks. Stepping on one makes you yelp (big noise).
- **Scan:** a "look" action reveals bricks within 2 tiles, but costs 2 seconds of game time. Teaches planning vs. time.
- **Sweeper:** pick up a slipper. Use it to sweep one tile ahead, which clears any bricks there with a soft clatter (small noise). Limited uses (e.g. 5).
- **Pathfinding:** tap-to-walk must not route through revealed bricks. Unrevealed ones are fair game, so long taps across unknown floor are risky. That is the lesson.
- **Tuning:** brick density, scan radius, sweeper uses.
- **Size:** M

### L6 · "The Pawshank Redemption" (prison break)
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
  - creaky boards and toys on the floor (L1)
  - baby monitor in the nursery hallway (L2)
  - a glass of water in Maya's room (L4)
  - bricks in the living room (L5)
  - patrolling dog with treats (L6)
  - a toy on a timer somewhere in the house (L7)
  - L3's harness can be a short optional shortcut to the keys on top of the fridge
- **Ending:** win card, then credits roll... then, after a pause, a baby cries. Card: "Credits roll... then the baby cries." A button: "Do it all again tomorrow" (restart in night mode).
- **Size:** M, mostly level design and tuning since the systems already exist.

### Bonus · "The Sunbeam" (adventure)
**Unlocks:** after collecting every pacifier across the campaign.
**Teaches:** aiming light and timing, building on L1's light.

- **Goal:** the toddler hid your car keys, and you're already late.
- **The clue:** the toddler's crayon "treasure map" is taped to the fridge. It's vague: a sun, a window, a squiggle and an X.
- **The puzzle:** a crystal suncatcher hangs in the living-room window. When the sun comes up, light through it makes a bright spot on the floor. You set two things: which hook it hangs from (3 heights) and how far the blinds are open. Together they decide where the spot lands. The map has a hint for each (two dots by the window; the blinds drawn half shaded).
- **The timing:** the sun keeps rising, so the spot crawls across the floor over about 20 seconds. For a moment it passes over the hiding place (a couch cushion, the toy box, a rain boot). Be standing there, ready. Miss it and you wait for the next pass, which costs time.
- **The risk:** an older kid fell asleep on the couch. Wide-open blinds make the spot easy to see but put sunlight on their face (the same rule as L1).
- **Searching:** hold to search gently (slow), or tap to dig fast (noisy).
- **Reuses:** `LightSystem` and floor toys from L1. New: a light source that moves over time, and the hook and blind settings that aim it.
- **Size:** S–M

### Why this order works
- L1–L4 each add one sense: sound, sight, touch, then reading the kid.
- L5–L7 add planning, distraction and time pressure.
- L8 tests all of it, so the player feels they've mastered something.

---

## 4. Replay hooks

| Hook | How | Size |
|---|---|---|
| **Silent / Close Call / Woke Them** | Replace star logic in `finish()` with `StarRules` per level; show on level cards | S |
| **Collectibles** (socks, pacifiers) | `Collectible` tiles in level data; picked up by stepping on them; counted in `ProgressStore`; a tally on the level select screen. Every pacifier unlocks the bonus level | S |
| **Night mode** | Unlocks after a Silent clear. Reuse `makeDarknessTexture` as a full-screen dark layer with a cone cut out in the player's facing direction. Creaks, bricks and toys are only visible in the cone | M |
| Best time per level | Store on clear | S |

---

## 5. Order of work

Build L1 and L4 first. If the noise loop and the freeze loop aren't fun, the rest won't be either, and it costs little to find out.

| Phase | Work | Done when |
|---|---|---|
| **0. Refactor** | `LevelDefinition`, room map, `Mechanic` protocol, move creaks into `PressurePlateSystem`, `ProgressStore`, level select with 1 card, test target | Today's game plays exactly the same from level data |
| **1. Prototype L1 + L4** | `LightSystem`, `FloorHazardSystem` (toys), decoy swap, `ChaseSystem`, `RippleSystem`, two grey-box maps | Both levels playable start to finish |
| **Playtest gate** | 5+ people play L1 and L4 cold | Do they crack the door just enough, and avoid the toys, with no text? Do they freeze on ripples without being told twice? Do they want to retry for Silent? If not, tune or redesign before going on |
| **2. Core levels** | L2 sightlines, L5 bricks, L6 dog, L7 countdown (in that order, cheapest to riskiest) | Each level playable, rated, with collectibles |
| **3. L3 prototype** | `RopeScene` side view; decide on side view vs. top-down fallback | One version is fun |
| **4. Finale** | L8 built on the morning map with all systems; credits gag | Whole campaign beatable in order |
| **5. Replay** | Ratings UI, collectibles UI, night mode, bonus level "The Sunbeam" | All hooks live; bonus unlocks from pacifiers |
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
5. **Theme references.** Every level must pass the "homage, not copy" rules in section 0, from design through art and sound.
6. **Keep the current mode?** Recommend keeping today's morning as "Classic Morning" on the level select, unlocked from the start, so existing players don't lose it.
