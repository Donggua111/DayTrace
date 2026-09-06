import AppKit
import SwiftUI

enum DayTraceDesign {
    static let accent = Color.accentColor
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let secondarySurface = Color(nsColor: .underPageBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let positive = Color(nsColor: .systemGreen)
    static let attention = Color(nsColor: .systemOrange)
    static let subdued = Color(nsColor: .tertiaryLabelColor)

    static let title = Font.system(size: 30, weight: .bold, design: .rounded)
    static let metric = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let metricSmall = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let section = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 12, weight: .regular)

    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24
    static let spaceXL: CGFloat = 32

    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
}
