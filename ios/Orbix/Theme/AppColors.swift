import SwiftUI

enum AppColors {
    static let groupedBg = Color(hex: "#F2F2F7")
    static let mainBg = Color(hex: "#F2F2F7")
    static let plainBg = Color(hex: "#FFFFFF")
    static let card = Color(hex: "#FFFFFF")
    static let elevated = Color(hex: "#F2F2F7")

    static let label = Color(hex: "#1C1C1E")
    static let secondaryLabel = Color(hex: "#6E6E73")
    static let tertiaryLabel = Color(hex: "#AEAEB2")

    static let separator = Color(hex: "#E5E5EA")
    static let placeholder = Color(hex: "#C7C7CC")

    static let accent = Color(hex: "#366EF6")
    static let accentDark = Color(hex: "#0E52BA")
    static let accentSoftBg = Color(hex: "#EBF0FF")

    static let success = Color(hex: "#34C759")
    static let warning = Color(hex: "#FF9500")
    static let danger = Color(hex: "#FF3B30")

    static let skeletonBase = Color(hex: "#E5E5EA")
    static let skeletonHighlight = Color(hex: "#D1D1D6")

    static let logoGradient = LinearGradient(
        colors: [accent, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassBorder = Color.black.opacity(0.06)
}

enum AppRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

struct TeslaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .fill(AppColors.card.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .stroke(AppColors.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func teslaCard() -> some View {
        modifier(TeslaCard())
    }
}
