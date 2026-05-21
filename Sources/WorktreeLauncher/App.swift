import SwiftUI

@main
struct WorktreeLauncherApp: App {
    var body: some Scene {
        WindowGroup("Worktree Launcher") {
            ContentView()
                .frame(minWidth: 640, minHeight: 280)
        }
        .defaultSize(width: 720, height: 420)
        .handlesExternalEvents(matching: Set(["worktree-launcher"]))
    }
}
