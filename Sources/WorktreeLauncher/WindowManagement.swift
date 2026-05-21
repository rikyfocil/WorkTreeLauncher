import AppKit
import SwiftUI

// Maps normalized repo paths to their open NSWindows so duplicate launches can focus
// the existing window instead of creating a new one.
final class WindowRegistry {
    static let shared = WindowRegistry()
    private var map: [String: NSWindow] = [:]
    private init() {}

    func register(path: String, window: NSWindow) {
        // Drop any previous path entry for this window (path changed).
        map = map.filter { $0.value !== window }
        // Only claim the path if no other visible window already holds it.
        // This prevents a newly-created orphan window (loaded via onAppear's lastRepoPath)
        // from overwriting the real window's entry before onOpenURL can redirect.
        if map[path].map({ !$0.isVisible }) ?? true {
            map[path] = window
        }
    }

    // Focuses the window for path if it exists and is still visible. Returns true on success.
    @discardableResult
    func focus(path: String) -> Bool {
        guard let window = map[path] else { return false }
        guard window.isVisible else { map.removeValue(forKey: path); return false }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func window(for path: String) -> NSWindow? {
        guard let window = map[path] else { return nil }
        if !window.isVisible { map.removeValue(forKey: path); return nil }
        return window
    }
}

// Captures the NSWindow that hosts a SwiftUI view hierarchy via viewDidMoveToWindow.
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowFinderView {
        let v = WindowFinderView()
        v.callback = callback
        return v
    }

    func updateNSView(_ v: WindowFinderView, context: Context) {}
}

final class WindowFinderView: NSView {
    var callback: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        if let w = window { callback?(w) }
    }
}
