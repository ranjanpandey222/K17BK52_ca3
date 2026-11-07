import SwiftUI
import EbbCore

/// Rounded lavender card used throughout the app.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.spacing
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }
}

/// Full-width filled button.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Theme.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}

/// Full-width outlined button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Theme.accentSoft.opacity(configuration.isPressed ? 0.6 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}

/// Selectable pill.
struct Chip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.subheadline)
                }
                Text(title).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
            .background(isSelected ? Theme.accent : Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Wrapping horizontal layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// None / Mild / Moderate / Severe selector.
struct SeveritySelector: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Severity.allCases, id: \.rawValue) { severity in
                let selected = value == severity.rawValue
                Button {
                    value = severity.rawValue
                } label: {
                    Text(severity.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selected ? (severity == .none ? Theme.textPrimary : .white) : Theme.textSecondary)
                        .background(
                            selected ? Theme.severityColor(severity.rawValue == 0 ? 0 : max(severity.rawValue, 2)) : Theme.background,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? Color.clear : Theme.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(severity.title)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

/// Small header used above groups of content.
struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Round icon badge.
struct IconBadge: View {
    let systemImage: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .frame(width: size, height: size)
            .background(Theme.accentSoft, in: Circle())
    }
}

/// Friendly empty / locked state.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(systemImage: systemImage, size: 56)
            Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// The Ebb wordmark with its wave mark.
struct EbbLogo: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(light: 0x9B7FC9, dark: 0x9B7FC9), Color(light: 0x6A4A9E, dark: 0x6A4A9E)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Image(systemName: "water.waves")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Standard screen background.
    func ebbScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// Medical disclaimer shown in onboarding, settings and the report.
enum Disclaimer {
    static let short = "Ebb is for tracking and education. It doesn't diagnose or treat any condition and isn't a substitute for professional medical advice."
    static let emergency = "If you have severe symptoms or think you may have a medical emergency, call 911 or your local emergency number."
}
