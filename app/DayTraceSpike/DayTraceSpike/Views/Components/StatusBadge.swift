import SwiftUI

struct DayTraceStatusBadge: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(DayTraceDesign.bodyMedium)
            .foregroundStyle(color)
            .padding(.horizontal, DayTraceDesign.spaceS)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}
