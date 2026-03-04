import SwiftUI

struct PopoverView: View {
    @StateObject private var viewModel: PopoverViewModel
    @State private var navigationPath = NavigationPath()

    init(notificationManager: NotificationManager) {
        _viewModel = StateObject(wrappedValue: PopoverViewModel(notificationManager: notificationManager))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationDestination(for: Skill.self) { skill in
                    SkillDetailView(skill: skill)
                        .environmentObject(viewModel)
                }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            viewModel.rescanSkills()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image("MenuBarIcon")
                    .resizable()
                    .frame(width: 18, height: 18)
                Text("MenuBar Companion")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            .padding(.bottom, 4)

            // Starred Skills
            if !viewModel.starredSkills.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starred Skills")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.starredSkills) { skill in
                        Button {
                            navigationPath.append(skill)
                        } label: {
                            HStack(spacing: 6) {
                                if let icon = skill.icon {
                                    Image(systemName: icon)
                                        .font(.caption)
                                }
                                Text(skill.name)
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack {
                    Text("No starred skills yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // All Skills button
            Button {
                navigationPath.append("allSkills")
            } label: {
                HStack {
                    Label("All Skills", systemImage: "square.grid.2x2")
                    Spacer()
                    Text("\(viewModel.allSkills.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Divider()

            // Input row
            HStack(spacing: 8) {
                TextField("Ask or command…", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.run() }

                if viewModel.isRunning {
                    Button("Cancel") { viewModel.cancel() }
                        .tint(.red)
                } else {
                    Button("Run") { viewModel.run() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            // Output area
            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.output.isEmpty ? "Output will appear here…" : viewModel.output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(viewModel.output.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .id("output-bottom")
                }
                .onChange(of: viewModel.output) { _ in
                    proxy.scrollTo("output-bottom", anchor: .bottom)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)

            // Toolbar
            HStack {
                Button {
                    viewModel.clearOutput()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.output.isEmpty)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.output, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.output.isEmpty)

                Spacer()

                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Running…")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
        .navigationDestination(for: String.self) { destination in
            if destination == "allSkills" {
                SkillsListView()
                    .environmentObject(viewModel)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.claudeDetected {
            Label("Claude CLI", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Label("Stub Mode", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
