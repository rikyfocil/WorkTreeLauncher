import Foundation
import AppKit

@MainActor
class WorktreeListViewModel: ObservableObject {
    @Published var worktrees: [WorktreeInfo] = []
    @Published var repoPath: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(from path: String) {
        let resolved = (path as NSString).expandingTildeInPath
        isLoading = true
        errorMessage = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", resolved, "worktree", "list", "--porcelain"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            errorMessage = "Failed to run git: \(error.localizedDescription)"
            isLoading = false
            return
        }

        guard process.terminationStatus == 0 else {
            errorMessage = "Not a git repository: \(resolved)"
            isLoading = false
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        worktrees = parsePorcelain(output)
        repoPath = resolved
        UserDefaults.standard.set(resolved, forKey: "lastRepoPath")
        isLoading = false
    }

    func refresh() {
        guard !repoPath.isEmpty else { return }
        load(from: repoPath)
    }

    func openInCode(_ worktree: WorktreeInfo) {
        let folderURL = URL(fileURLWithPath: worktree.path)
        // Prefer bundle lookup — works regardless of GUI app PATH stripping
        for bundleId in ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"] {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.open([folderURL], withApplicationAt: appURL,
                                        configuration: .init(), completionHandler: nil)
                return
            }
        }
        // Fallback: known binary locations for shells that symlink code
        for bin in ["/usr/local/bin/code", "/opt/homebrew/bin/code"] {
            if FileManager.default.fileExists(atPath: bin) {
                run(bin, worktree.path)
                return
            }
        }
    }

    func openInXcode(_ worktree: WorktreeInfo) {
        guard let target = worktree.xcodeTarget else { return }
        run("/usr/bin/open", target)
    }

    func revealInFinder(_ worktree: WorktreeInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: worktree.path))
    }

    func openInTerminal(_ worktree: WorktreeInfo) {
        let path = worktree.path.replacingOccurrences(of: "'", with: "\\'")
        let ws = NSWorkspace.shared
        if ws.urlForApplication(withBundleIdentifier: "dev.warp.Warp-Stable") != nil {
            run("/usr/bin/open", "-a", "Warp", worktree.path)
        } else if ws.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil {
            runAppleScript("tell application \"iTerm\" to create window with default profile command \"cd '\(path)'\"")
        } else {
            runAppleScript("tell application \"Terminal\" to do script \"cd '\(path)'\"")
        }
    }

    private func runAppleScript(_ script: String) {
        run("/usr/bin/osascript", "-e", script)
    }

    // Prunes stale admin reference for a prunable worktree (directory already gone).
    func pruneWorktree(_ worktree: WorktreeInfo) {
        runGitSync("worktree", "prune")
        refresh()
    }

    // Permanently removes the worktree directory and its admin reference.
    func deleteWorktree(_ worktree: WorktreeInfo) {
        if !runGitSync("worktree", "remove", "--force", worktree.path) {
            errorMessage = "Failed to remove worktree at \(worktree.name)."
        }
        refresh()
    }

    @discardableResult
    private func runGitSync(_ args: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repoPath] + args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }
        return process.terminationStatus == 0
    }

    private func run(_ executable: String, _ args: String...) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        try? process.run()
    }

    private func parsePorcelain(_ output: String) -> [WorktreeInfo] {
        var result: [WorktreeInfo] = []
        var path: String?
        var commit: String?
        var branch: String?
        var isPrunable = false
        var isLocked = false

        func flush() {
            guard let p = path, let c = commit else { return }
            let branchName = branch?
                .replacingOccurrences(of: "refs/heads/", with: "")
            result.append(WorktreeInfo(
                path: p,
                commit: String(c.prefix(7)),
                branch: branchName ?? c,
                isPrunable: isPrunable,
                isLocked: isLocked,
                isDetached: branch == nil,
                isMain: result.isEmpty
            ))
        }

        for line in output.components(separatedBy: "\n") {
            if line.isEmpty {
                flush()
                path = nil; commit = nil; branch = nil
                isPrunable = false; isLocked = false
            } else if line.hasPrefix("worktree ") {
                path = String(line.dropFirst(9))
            } else if line.hasPrefix("HEAD ") {
                commit = String(line.dropFirst(5))
            } else if line.hasPrefix("branch ") {
                branch = String(line.dropFirst(7))
            } else if line == "prunable" || line.hasPrefix("prunable ") {
                isPrunable = true
            } else if line == "locked" || line.hasPrefix("locked ") {
                isLocked = true
            }
        }
        flush()
        return result
    }
}
