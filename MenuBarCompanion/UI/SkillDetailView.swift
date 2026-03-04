import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var extraInstructions: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back button
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)

            if let icon = skill.icon {
                Image(systemName: icon).font(.largeTitle)
            }
            Text(skill.name).font(.title2).bold()
            Text(skill.description).foregroundStyle(.secondary)

            if let category = skill.category {
                Text(category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Divider()

            Text("Extra Instructions (optional)").font(.subheadline).bold()
            TextField("Add context or instructions...", text: $extraInstructions, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Button(action: {
                viewModel.runSkill(skill, extraInstructions: extraInstructions)
                dismiss()
            }) {
                Label("Run Skill", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRunning)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
