import SwiftUI

struct UsageCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DayTraceDesign.spaceL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DayTraceDesign.cardBackground, in: RoundedRectangle(cornerRadius: DayTraceDesign.radiusL, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DayTraceDesign.radiusL, style: .continuous)
                    .stroke(DayTraceDesign.separator.opacity(0.45), lineWidth: 0.5)
            }
    }
}
