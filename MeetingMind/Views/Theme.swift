import SwiftUI
import UIKit

enum Theme {
    // MARK: - Spacing Scale (8pt grid)

    static let spacing4: CGFloat = 4
    static let spacing6: CGFloat = 6
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 14

    // MARK: - Typography Scale

    static let titleFont: Font = .system(.title2, design: .rounded, weight: .bold)
    static let headlineFont: Font = .system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont: Font = .system(.body, design: .rounded)
    static let subheadlineFont: Font = .system(.subheadline, design: .rounded, weight: .medium)
    static let captionFont: Font = .system(.caption, design: .rounded)
    static let captionBoldFont: Font = .system(.caption, design: .rounded, weight: .semibold)
    static let badgeFont: Font = .system(.caption2, design: .rounded, weight: .semibold)
    static let sectionHeaderFont: Font = .system(.subheadline, design: .rounded, weight: .bold)
    static let timerFont: Font = .system(size: 64, weight: .thin, design: .rounded)

    // MARK: - Palette

    static let teal600 = Color(red: 13/255, green: 148/255, blue: 136/255)   // #0D9488
    static let teal500 = Color(red: 20/255, green: 184/255, blue: 166/255)   // #14B8A6
    static let orange500 = Color(red: 249/255, green: 115/255, blue: 22/255) // #F97316
    static let coral = Color(red: 239/255, green: 68/255, blue: 68/255)      // #EF4444

    // MARK: - Semantic: Status

    static let statusRecording = coral
    static let statusTranscribing = orange500
    static let statusAnalyzing = teal500
    static let statusComplete = Color(red: 16/255, green: 185/255, blue: 129/255) // #10B981
    static let statusFailed = coral
    static let statusDiarizing = teal500

    // MARK: - Speaker Colors
    static let speakerColors: [Color] = [
        teal600,
        orange500,
        Color(red: 139/255, green: 92/255, blue: 246/255),  // purple
        coral,
        Color(red: 59/255, green: 130/255, blue: 246/255),   // blue
        Color(red: 234/255, green: 179/255, blue: 8/255),     // yellow
    ]

    static func speakerColor(for index: Int) -> Color {
        speakerColors[index % speakerColors.count]
    }

    // MARK: - Semantic: Action Item Types

    static let actionCalendar = teal600
    static let actionReminder = orange500
    static let actionTask = Color(red: 139/255, green: 92/255, blue: 246/255) // #8B5CF6

    // MARK: - Semantic: UI Elements

    static let insightBadge = orange500
    static let successCheck = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let warningIndicator = orange500
    static let inactiveControl = Color(UIColor.tertiaryLabel)

    // MARK: - Standardized Opacity

    static let badgeBackgroundOpacity: Double = 0.12

    // MARK: - Colors

    static let subtleAccent = Color.accentColor.opacity(0.10)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // MARK: - Tinted Surface Colors

    static let surfaceDefault = cardBackground

    static let surfaceTeal = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 13/255, green: 148/255, blue: 136/255, alpha: 0.10)
            : UIColor(red: 240/255, green: 253/255, blue: 250/255, alpha: 1.0) // #F0FDFA
    })

    static let surfaceOrange = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 0.10)
            : UIColor(red: 255/255, green: 247/255, blue: 237/255, alpha: 1.0) // #FFF7ED
    })

    static let surfacePurple = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 0.10)
            : UIColor(red: 245/255, green: 243/255, blue: 255/255, alpha: 1.0) // #F5F3FF
    })

    static let surfaceCoral = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 0.10)
            : UIColor(red: 254/255, green: 242/255, blue: 242/255, alpha: 1.0) // #FEF2F2
    })

    // MARK: - Flat Design Constants

    static let accentBarWidth: CGFloat = 3
    static let accentBarCornerRadius: CGFloat = 1.5
    static let pillPaddingH: CGFloat = 10
    static let pillPaddingV: CGFloat = 5

    // MARK: - Waveform Colors (solid flat design)

    static let waveformColor = teal500
    static let waveformRecordingColor = coral
}
