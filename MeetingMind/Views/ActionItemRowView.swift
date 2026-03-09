import SwiftUI

struct ActionItemRowView: View {
    let item: ActionItem
    var onSeek: ((TimeInterval) -> Void)? = nil
    let onExport: () -> Void

    var body: some View {
        HStack {
            Image(systemName: item.type.iconName)
                .foregroundStyle(item.type.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Theme.spacing4) {
                Text(item.title)
                    .font(Theme.subheadlineFont)

                if let dueDate = item.dueDate {
                    Text(dueDate, style: .date)
                        .font(Theme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.isExported {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.successCheck)
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
        case .calendarEvent: Theme.actionCalendar
        case .reminder: Theme.actionReminder
        case .task: Theme.actionTask
        }
    }
}
