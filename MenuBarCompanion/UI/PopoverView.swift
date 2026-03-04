import SwiftUI

struct PopoverView: View {
    @StateObject private var viewModel = PopoverViewModel()

    var body: some View {
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

            // Input row
            HStack(spacing: 8) {
                TextField("Enter command…", text: $viewModel.inputText)
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
        .frame(width: 480, height: 520)
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
