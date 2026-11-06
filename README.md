# Don't Wake the Kids

A native iOS stealth game in SwiftUI + SpriteKit. It's 5:30 AM: get dressed, shower, make coffee, pack lunches, let the dog out, and leave by 6:15 without waking the baby or Maya.

## Run it

1. You need a Mac with **Xcode 16 or newer** (the project uses Xcode 16's folder-synced format).
2. Double-click `DontWakeTheKids.xcodeproj`.
3. Select the **DontWakeTheKids** target → **Signing & Capabilities**:
   - Pick your **Team** (your Apple ID works for running on your own phone).
   - Change the **Bundle Identifier** from `com.example.DontWakeTheKids` to something you own, e.g. `com.yourname.dontwakethekids`.
4. Choose an iPhone simulator (or your plugged-in iPhone) and press **⌘R**.

Running on a real phone is worth it: creaks, barks and dropped spoons are felt as haptics.

If the project won't open, regenerate it: `brew install xcodegen && xcodegen generate`.

## How the code is laid out

| File | What it does |
|---|---|
| `Game/LevelDefinition.swift` | What a level is: map, room map, sleepers, dog, creaky boards, clock, which mechanics are on |
| `Game/Levels/` | One file per level, data only. `ClassicMorning.swift` is the original game |
| `Game/Map.swift` | Basic types: tiles, rooms, stations, furniture |
| `Game/Tasks.swift` | Checklist items and tasks: names, durations, noise per second |
| `Game/GameModel.swift` | Core rules: movement, pathfinding, noise, wake meters, dog, scoring. Tuning constants are at the top |
| `Game/Mechanics/` | One rule system per file (`Mechanic` protocol). `PressurePlates.swift` is the creaky boards |
| `Game/Progress/ProgressStore.swift` | Saves stars, best score and unlocks per level |
| `Game/HouseScene.swift` | SpriteKit scene. Draws any level each frame and turns taps into tiles |
| `UI/LevelSelectView.swift` | The level list |
| `UI/ContentView.swift` | SwiftUI screen: clock, meters, sticky note, the board, task buttons, intro/end overlays |
| `UI/Components.swift` | Meter bars, sticky note, buttons |
| `UI/Haptics.swift` | Haptic feedback for game events |
| `Audio/SoundEffects.swift` | Sound effects for game events. Sounds are `.caf` files in `Audio/Sounds/`; original recordings are in `SoundSources/` |
| `UI/Palette.swift` | Colors and fonts |
| `DontWakeTheKidsTests/` | Unit tests for levels, rules and saved progress. Run with **⌘U** |

## Adding a level

1. Add a case to `LevelID` and a file in `Game/Levels/` with a `static let` for the level.
2. Add it to `LevelDefinition.all` in play order. It unlocks when the level before it is cleared.
3. New rules go in a new `Mechanic` in `Game/Mechanics/`, with a `MechanicKind` case so levels can switch it on.

## Tuning

Everything that changes difficulty lives in a few places:

- `GameModel` constants: game speed, walk vs. tiptoe speed, how fast kids settle back down.
- Per level, in `Game/Levels/`: sleeper sensitivity (the baby is 1.8, Maya is 1.2), the clock, creaky boards and which rooms share walls.
- `MorningTask.noisePerSecond` and `duration` in `Tasks.swift`.

## Getting to the App Store

1. Join the Apple Developer Program (paid, yearly) at developer.apple.com.
2. In App Store Connect, create an app record with your bundle ID.
3. In Xcode: **Product → Archive**, then **Distribute App** → **TestFlight & App Store**.
4. Test via TestFlight, add screenshots and a privacy label (this app collects no data), then submit for review.

## Ideas for next versions

- Sound design: a soft ambient room tone with your own footsteps, very quiet.
- More levels: a travel day, holiday morning with relatives on the couch.
- Game Center leaderboard for best score.
- Kids who roll over and change sensitivity mid-level.
