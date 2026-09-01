import SwiftUI

struct DayTraceSectionHeader: View {
    let title: LocalizedStringKey
    let systemImage: String
    var subtitle: LocalizedStringKey?

    init(title: LocalizedStringKey, systemImage: String, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DayTraceDesign.spaceS) {
            Label(title, systemImage: systemImage)
                .font(DayTraceDesign.section)

            Spacer(minLength: DayTraceDesign.spaceS)

            if let subtitle {
                Text(subtitle)
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
