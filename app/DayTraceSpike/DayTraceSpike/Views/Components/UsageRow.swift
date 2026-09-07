import AppKit
import SwiftUI

struct AppUsageRow: View {
    let app: AppIdentity
    let duration: Text
    var title: String?

    var body: some View {
        HStack(spacing: DayTraceDesign.spaceM) {
            AppIconView(app: app)

            Text(title ?? app.displayName)
                .font(DayTraceDesign.body)
                .lineLimit(1)

            Spacer(minLength: DayTraceDesign.spaceS)

            duration
                .font(DayTraceDesign.bodyMedium)
                .monospacedDigit()
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title ?? app.displayName))
        .accessibilityValue(duration)
    }
}

struct WebsiteUsageRow: View {
    let domain: String
    let duration: Text
    var title: String?

    var body: some View {
        HStack(spacing: DayTraceDesign.spaceM) {
            Image(systemName: "globe")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title ?? domain)
                .font(DayTraceDesign.body)
                .lineLimit(1)

            Spacer(minLength: DayTraceDesign.spaceS)

            duration
                .font(DayTraceDesign.bodyMedium)
                .monospacedDigit()
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title ?? domain))
        .accessibilityValue(duration)
    }
}

private enum AppIconCache {
    static let images = NSCache<NSString, NSImage>()
}

struct AppIconView: View {
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
        let cacheKey = app.bundleIdentifier as NSString
        if let cached = AppIconCache.images.object(forKey: cacheKey) {
            return cached
        }
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        AppIconCache.images.setObject(icon, forKey: cacheKey)
        return icon
    }
}
