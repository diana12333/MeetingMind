import SwiftUI

struct RichSummaryText: View {
    let summary: String
    let references: [AIReference]
    let onSeek: (TimeInterval) -> Void

    @State private var selectedReference: AIReference?

    var body: some View {
        Text(buildAttributedString())
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "meetingmind-ref",
                   let refId = Int(url.host() ?? ""),
                   let ref = references.first(where: { $0.id == refId }) {
                    selectedReference = ref
                    return .handled
                }
                return .systemAction
            })
            .popover(item: $selectedReference) { ref in
                CitationPopover(reference: ref, onSeek: onSeek)
            }
    }

    private func buildAttributedString() -> AttributedString {
        let pattern = /\[(\d+)\]/
        var result = AttributedString()
        var remaining = summary[summary.startIndex...]

        while let match = remaining.firstMatch(of: pattern) {
            let before = remaining[remaining.startIndex..<match.range.lowerBound]
            if !before.isEmpty {
                result.append(AttributedString(String(before)))
            }
            if let refId = Int(match.1) {
                var citation = AttributedString("[\(refId)]")
                citation.foregroundColor = .accentColor
                citation.font = .body.bold()
                citation.link = URL(string: "meetingmind-ref://\(refId)")
                result.append(citation)
            }
            remaining = remaining[match.range.upperBound...]
        }
        if !remaining.isEmpty {
            result.append(AttributedString(String(remaining)))
        }
        return result
    }
}

extension AIReference: Identifiable {}
