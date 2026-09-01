import SwiftUI

struct TypingActivityView: View {
    let snapshot: TypingActivitySnapshot
    let languageRawValue: String

    @State private var explanationPresented = false

    private let topAppLimit = 5

    var body: some View {
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                HStack(alignment: .firstTextBaseline, spacing: DayTraceDesign.spaceS) {
                    DayTraceSectionHeader(title: "typingActivity.title", systemImage: "keyboard")

                    Button {
                        explanationPresented.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help("typingActivity.explanation.action")
                    .popover(isPresented: $explanationPresented, arrowEdge: .top) {
                        explanationView
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
                    Text("typingActivity.typedCharacters")
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.metrics.typedCharacters, format: .number)
                        .font(DayTraceDesign.metric)
                        .monospacedDigit()
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: DayTraceDesign.spaceS
                ) {
                    TypingBreakdownRow(title: "typingActivity.english", value: snapshot.metrics.englishCharacters)
                    TypingBreakdownRow(title: "typingActivity.numbers", value: snapshot.metrics.numberCharacters)
                    TypingBreakdownRow(title: "typingActivity.symbols", value: snapshot.metrics.symbolCharacters)
                    TypingBreakdownRow(title: "typingActivity.spaces", value: snapshot.metrics.spaceCharacters)
                }

                Divider()

                VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
                    TypingDetailRow(
                        title: "typingActivity.estimatedWords",
                        value: {
                            if snapshot.metrics.estimatedEnglishWords > 0 {
                                Text(verbatim: "≈ ")
                                    + Text(snapshot.metrics.estimatedEnglishWords, format: .number)
                                        .bold()
                            } else {
                                Text(verbatim: "—")
                            }
                        }
                    )
                    .help("typingActivity.estimatedWordsHelp")

                    TypingDetailRow(
                        title: "typingActivity.typingSpeed",
                        value: { typingSpeedText }
                    )

                    TypingDetailRow(
                        title: "typingActivity.activeTyping",
                        value: { durationText(snapshot.activeTypingDuration) }
                    )
                    .help("typingActivity.activeTypingHelp")

                    TypingDetailRow(
                        title: "typingActivity.sessions",
                        value: { Text(snapshot.typingSessions, format: .number) }
                    )
                    .help("typingActivity.sessionsHelp")

                    TypingDetailRow(
                        title: "typingActivity.mostTypedInApp",
                        value: { Text(verbatim: snapshot.mostTypedInApp?.displayName ?? "—") }
                    )
                }

                if !topTypedApps.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
                        Text("typingActivity.topApps")
                            .font(DayTraceDesign.bodyMedium)

                        ForEach(topTypedApps, id: \.self) { app in
                            HStack(spacing: DayTraceDesign.spaceS) {
                                Text(verbatim: app.displayName)
                                    .font(DayTraceDesign.body)
                                    .lineLimit(1)
                                Spacer(minLength: DayTraceDesign.spaceS)
                                Text(snapshot.appMetricsByApp[app]?.typedCharacters ?? 0, format: .number)
                                    .font(DayTraceDesign.bodyMedium)
                                    .monospacedDigit()
                                Text("typingActivity.charactersUnit")
                                    .font(DayTraceDesign.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Text("typingActivity.privacy")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var topTypedApps: [AppIdentity] {
        snapshot.appMetricsByApp.keys
            .filter { (snapshot.appMetricsByApp[$0]?.typedCharacters ?? 0) > 0 }
            .sorted {
                let left = snapshot.appMetricsByApp[$0]?.typedCharacters ?? 0
                let right = snapshot.appMetricsByApp[$1]?.typedCharacters ?? 0
                if left == right {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return left > right
            }
            .prefix(topAppLimit)
            .map { $0 }
    }

    private var typingSpeedText: Text {
        guard let charactersPerMinute = snapshot.charactersPerMinute,
              let roundedValue = TypingActivityFormatting.roundedCPM(charactersPerMinute) else {
            return Text(verbatim: "—")
        }

        return Text(roundedValue, format: .number)
            .monospacedDigit()
            .bold()
        + Text(" ")
        + Text("typingActivity.cpmUnit")
            .foregroundColor(.secondary)
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: languageRawValue) ?? .system).locale
    }

    private func durationText(_ duration: TimeInterval) -> Text {
        Text(verbatim: DayTraceDurationFormatter.string(seconds: duration, locale: selectedLocale))
    }

    private var explanationView: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
            Text("typingActivity.explanation.title")
                .font(DayTraceDesign.bodyMedium)

            Text("typingActivity.explanation.body")
                .font(DayTraceDesign.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DayTraceDesign.spaceL)
        .frame(width: 360, alignment: .leading)
    }
}

enum TypingActivityFormatting {
    static func roundedCPM(_ charactersPerMinute: Double?) -> Int? {
        guard let charactersPerMinute, charactersPerMinute.isFinite, charactersPerMinute > 0 else {
            return nil
        }
        return Int(charactersPerMinute.rounded())
    }
}

private struct TypingBreakdownRow: View {
    let title: LocalizedStringKey
    let value: Int

    var body: some View {
        HStack(spacing: DayTraceDesign.spaceS) {
            Text(title)
                .font(DayTraceDesign.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: DayTraceDesign.spaceXS)
            Text(value, format: .number)
                .font(DayTraceDesign.bodyMedium)
                .monospacedDigit()
        }
    }
}

private struct TypingDetailRow<Detail: View>: View {
    let title: LocalizedStringKey
    let value: Detail

    init(title: LocalizedStringKey, @ViewBuilder value: () -> Detail) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DayTraceDesign.spaceM) {
            Text(title)
                .font(DayTraceDesign.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: DayTraceDesign.spaceS)
            value
                .font(DayTraceDesign.bodyMedium)
                .multilineTextAlignment(.trailing)
        }
    }
}
