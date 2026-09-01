import AppKit
import SwiftUI

struct AppUsageRow: View {
    let app: AppIdentity
    let duration: Text

    var body: some View {
        HStack(spacing: DayTraceDesign.spaceM) {
            AppIconView(app: app)

            Text(app.displayName)
                .font(DayTraceDesign.body)
                .lineLimit(1)

            Spacer(minLength: DayTraceDesign.spaceS)

            duration
                .font(DayTraceDesign.bodyMedium)
                .monospacedDigit()
        }
        .frame(minHeight: 36)
    }
}

struct WebsiteUsageRow: View {
    let domain: String
    let duration: Text

    var body: some View {
        HStack(spacing: DayTraceDesign.spaceM) {
            Image(systemName: "globe")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(domain)
                .font(DayTraceDesign.body)
                .lineLimit(1)

            Spacer(minLength: DayTraceDesign.spaceS)

            duration
                .font(DayTraceDesign.bodyMedium)
                .monospacedDigit()
        }
        .frame(minHeight: 34)
    }
}

private struct AppIconView: View {
    let app: AppIdentity

    var body: some View {
        Group {
            if let icon = applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: DayTraceDesign.radiusS, style: .continuous))
    }

    private var applicationIcon: NSImage? {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: applicationURL.path)
    }
}
