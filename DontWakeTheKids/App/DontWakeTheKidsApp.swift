import SwiftUI

@main
struct DontWakeTheKidsApp: App {
    @State private var gameStarted = false

    var body: some Scene {
        WindowGroup {
            if gameStarted {
                ContentView()
            } else {
                StartScreenView { gameStarted = true }
            }
        }
    }
}
