import SwiftUI

@main
struct DontWakeTheKidsApp: App {
    private enum Screen: Equatable {
        case start
        case levels
        case playing(LevelID)
    }

    @State private var screen = Screen.start
    @StateObject private var progress = ProgressStore.shared

    var body: some Scene {
        WindowGroup {
            switch screen {
            case .start:
                StartScreenView { screen = .levels }
            case .levels:
                LevelSelectView(progress: progress,
                                onBack: { screen = .start },
                                onPlay: { screen = .playing($0.id) })
            case .playing(let id):
                ContentView(level: .level(id)) { screen = .levels }
                    .id(id)
            }
        }
    }
}
