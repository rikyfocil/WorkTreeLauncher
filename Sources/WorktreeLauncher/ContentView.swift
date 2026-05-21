import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var vm = WorktreeListViewModel()
    @State private var worktreeToDelete: WorktreeInfo?
    @State private var initialized = false
    @State private var currentWindow: NSWindow?

    // Ensures only the first window ever opened consumes the CLI argument.
    private static var cliArgConsumed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(WindowAccessor { window in
            currentWindow = window
            if !vm.repoPath.isEmpty {
                WindowRegistry.shared.register(path: vm.repoPath, window: window)
            }
        })
        .onChange(of: vm.repoPath) { newPath in
            if let window = currentWindow, !newPath.isEmpty {
                WindowRegistry.shared.register(path: newPath, window: window)
            }
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true

            let args = CommandLine.arguments
            if args.count > 1, !ContentView.cliArgConsumed {
                ContentView.cliArgConsumed = true
                vm.load(from: args[1])
            } else if let saved = UserDefaults.standard.string(forKey: "lastRepoPath") {
                vm.load(from: saved)
            }
        }
        .onOpenURL { url in
            let path = (url.path as NSString).expandingTildeInPath
            if let existing = WindowRegistry.shared.window(for: path) {
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                // Close this window — it was created solely to handle the URL event
                // but the path is already open elsewhere.
                if existing !== currentWindow {
                    let orphan = currentWindow
                    DispatchQueue.main.async { orphan?.close() }
                }
            } else {
                // Register synchronously before vm.load() so a rapid second wl call
                // for the same path can find this window immediately — onChange fires
                // after the next render which is too late.
                if let window = currentWindow {
                    WindowRegistry.shared.register(path: path, window: window)
                }
                currentWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                vm.load(from: url.path)
            }
        }
        .handlesExternalEvents(preferring: [], allowing: [])
        .alert("Delete Worktree?", isPresented: Binding(
            get: { worktreeToDelete != nil },
            set: { if !$0 { worktreeToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let wt = worktreeToDelete {
                    vm.deleteWorktree(wt)
                    worktreeToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { worktreeToDelete = nil }
        } message: {
            if let wt = worktreeToDelete {
                Text("This will permanently delete the worktree at:\n\(wt.path)\n\nAny uncommitted changes will be lost.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text(error)
                    .foregroundColor(.secondary)
                Button("Choose Folder") { chooseFolder() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.worktrees.isEmpty {
            Text("No worktrees found.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(vm.worktrees) { worktree in
                WorktreeRow(worktree: worktree, vm: vm, onRequestDelete: { worktreeToDelete = $0 })
                    .listRowSeparator(.visible)
            }
            .listStyle(.inset)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.repoPath.isEmpty ? "No repository" : URL(fileURLWithPath: vm.repoPath).lastPathComponent)
                    .font(.headline)
                if !vm.repoPath.isEmpty {
                    Text(vm.repoPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            Button(action: chooseFolder) {
                Label("Open…", systemImage: "folder")
            }
            Button(action: vm.refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(vm.repoPath.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select a git repository"
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            let normalized = (url.path as NSString).expandingTildeInPath

            if normalized == vm.repoPath {
                vm.refresh()
                return
            }

            // Focus an existing window that already has this path.
            if WindowRegistry.shared.focus(path: normalized) { return }

            // No existing window — open a new one by sending a URL event to ourselves.
            var comps = URLComponents()
            comps.scheme = "worktree-launcher"
            comps.path = normalized
            if let launchURL = comps.url {
                NSWorkspace.shared.open(launchURL)
            }
        }
    }
}

struct WorktreeRow: View {
    let worktree: WorktreeInfo
    @ObservedObject var vm: WorktreeListViewModel
    let onRequestDelete: (WorktreeInfo) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: worktree.isMain ? "house" : "arrow.triangle.branch")
                .foregroundColor(.accentColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(worktree.displayBranch)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .onTapGesture {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(worktree.displayBranch, forType: .string)
                        }
                        .help("Click to copy branch name")
                    if worktree.isPrunable {
                        Button(action: { vm.pruneWorktree(worktree) }) {
                            badge("prunable", color: .orange)
                        }
                        .buttonStyle(.plain)
                        .help("Prune stale reference (working directory is gone)")
                    }
                    if worktree.isLocked {
                        badge("locked", color: .blue)
                    }
                }
                Text(worktree.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(worktree.commit)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Button("Finder") { vm.revealInFinder(worktree) }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button { vm.openInTerminal(worktree) } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open in Terminal")

            Button("Code") { vm.openInCode(worktree) }
                .buttonStyle(.bordered)
                .controlSize(.small)

            if worktree.xcodeTarget != nil {
                Button("Xcode") { vm.openInXcode(worktree) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            if !worktree.isMain {
                Button(role: .destructive) { onRequestDelete(worktree) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding(.vertical, 5)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
