import SwiftUI

// MARK: - Horizontal Scroll Chips (for RecordingView)

struct TemplateChipPicker: View {
    @Binding var selectedTemplateId: String
    let templates: [MeetingTemplate]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing8) {
                ForEach(templates) { template in
                    TemplateChipView(
                        template: template,
                        isSelected: selectedTemplateId == template.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTemplateId = template.id
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TemplateChipView: View {
    let template: MeetingTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing4) {
                Image(systemName: template.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(template.name)
                    .font(Theme.captionBoldFont)
            }
            .padding(.horizontal, Theme.pillPaddingH)
            .padding(.vertical, Theme.pillPaddingV)
            .background(isSelected ? Theme.teal600.opacity(Theme.badgeBackgroundOpacity) : Theme.surfaceDefault)
            .foregroundStyle(isSelected ? Theme.teal600 : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Theme.teal600 : .clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name) template")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Grid Picker Sheet (for MeetingDetailView)

struct TemplatePickerSheet: View {
    let templates: [MeetingTemplate]
    let onSelect: (MeetingTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: Theme.spacing16),
        GridItem(.flexible(), spacing: Theme.spacing16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.spacing16) {
                    ForEach(templates) { template in
                        TemplateCardView(template: template) {
                            onSelect(template)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityLabel("Choose a meeting template")
    }
}

struct TemplateCardView: View {
    let template: MeetingTemplate
    let action: () -> Void

    private var surfaceColor: Color {
        switch template.id {
        case "standup", "client-call": return Theme.surfaceTeal
        case "one-on-one", "interview": return Theme.surfacePurple
        case "brainstorm": return Theme.surfaceOrange
        default: return Theme.surfaceDefault
        }
    }

    private var accentColor: Color {
        switch template.id {
        case "standup", "client-call": return Theme.teal600
        case "one-on-one", "interview": return Color(red: 139/255, green: 92/255, blue: 246/255)
        case "brainstorm": return Theme.orange500
        default: return Theme.teal600
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.spacing8) {
                Image(systemName: template.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(accentColor)
                Text(template.name)
                    .font(Theme.captionBoldFont)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(surfaceColor, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name) template")
    }
}
