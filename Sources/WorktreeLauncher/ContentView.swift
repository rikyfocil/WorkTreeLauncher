import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var vm = WorktreeListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear {
            let args = CommandLine.arguments
            let path = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath
            vm.load(from: path)
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
                WorktreeRow(worktree: worktree, vm: vm)
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
            vm.load(from: url.path)
        }
    }
}

struct WorktreeRow: View {
    let worktree: WorktreeInfo
    @ObservedObject var vm: WorktreeListViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.accentColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(worktree.displayBranch)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    if worktree.isPrunable {
                        badge("prunable", color: .orange)
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

            Button("Finder") {
                vm.revealInFinder(worktree)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Code") {
                vm.openInCode(worktree)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if worktree.xcodeTarget != nil {
                Button("Xcode") {
                    vm.openInXcode(worktree)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
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
