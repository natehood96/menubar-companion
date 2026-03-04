import SwiftUI

struct SkillsListView: View {
    @EnvironmentObject var viewModel: PopoverViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 10)

            Text("All Skills")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 4)

            List {
                ForEach(viewModel.allSkills) { skill in
                    NavigationLink(value: skill) {
                        SkillRowView(skill: skill, isStarred: viewModel.isStarred(skill)) {
                            viewModel.toggleStar(skill)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .overlay {
            if viewModel.allSkills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Skills Found")
                        .font(.headline)
                    Text("Add .json skill files to\n~/Library/Application Support/MenuBot/skills/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

struct SkillRowView: View {
    let skill: Skill
    let isStarred: Bool
    let onToggleStar: () -> Void

    var body: some View {
        HStack {
            if let icon = skill.icon {
                Image(systemName: icon)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.headline)
                Text(skill.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button(action: onToggleStar) {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .foregroundStyle(isStarred ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
