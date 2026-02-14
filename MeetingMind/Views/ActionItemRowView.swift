import SwiftUI

struct ActionItemRowView: View {
    let item: ActionItem
    let onExport: () -> Void

    var body: some View {
        HStack {
            Image(systemName: item.type.iconName)
                .foregroundStyle(item.type.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)

                if let dueDate = item.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.isExported {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Export", action: onExport)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

extension ActionItemType {
    var iconName: String {
        switch self {
        case .calendarEvent: "calendar"
        case .reminder: "bell"
        case .task: "checklist"
        }
    }

    var iconColor: Color {
        switch self {
        case .calendarEvent: .blue
        case .reminder: .orange
        case .task: .purple
        }
    }
}
