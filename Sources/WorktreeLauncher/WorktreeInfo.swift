import Foundation

struct WorktreeInfo: Identifiable {
    let id = UUID()
    let path: String
    let commit: String
    let branch: String
    let isPrunable: Bool
    let isLocked: Bool
    let isDetached: Bool
    let isMain: Bool

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var displayBranch: String {
        isDetached ? "(detached \(commit))" : branch
    }

    // Finds the best Xcode target to open in the worktree root.
    // Prefers a standalone .xcworkspace, falls back to .xcodeproj/project.xcworkspace.
    var xcodeTarget: String? {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return nil }

        for item in items where item.pathExtension == "xcworkspace" {
            return item.path
        }
        for item in items where item.pathExtension == "xcodeproj" {
            let workspace = item.appendingPathComponent("project.xcworkspace")
            if fm.fileExists(atPath: workspace.path) {
                return workspace.path
            }
        }
        return nil
    }
}
