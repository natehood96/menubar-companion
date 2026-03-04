import SwiftUI

struct PopoverView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var navigationPath = NavigationPath()

    init(notificationManager: NotificationManager) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(notificationManager: notificationManager))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            chatScreen
                .navigationDestination(for: String.self) { destination in
                    if destination == "allSkills" {
                        SkillsListView()
                            .environmentObject(viewModel)
                    }
                }
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

    // MARK: - Chat Screen

    private var chatScreen: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.last?.content) { _ in
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 18, height: 18)
            Text("MenuBar Companion")
                .font(.headline)
            Spacer()

            // Menu button
            Menu {
                Button {
                    navigationPath.append("allSkills")
                } label: {
                    Label("All Skills (\(viewModel.allSkills.count))", systemImage: "square.grid.2x2")
                }

                if !viewModel.starredSkills.isEmpty {
                    Menu("Starred Skills") {
                        ForEach(viewModel.starredSkills) { skill in
                            Button {
                                navigationPath.append(skill)
                            } label: {
                                Label(skill.name, systemImage: skill.icon ?? "star.fill")
                            }
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.clearHistory()
                } label: {
                    Label("Clear Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            statusBadge
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onSubmit { viewModel.sendMessage() }

            if viewModel.isRunning {
                Button {
                    viewModel.cancel()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .secondary : .accentColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 40, height: 40)
                .opacity(0.5)
            Text("What can I help with?")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Type a message or run a skill from the menu.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Status Badge

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
