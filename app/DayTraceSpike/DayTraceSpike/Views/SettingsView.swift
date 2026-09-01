import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String
    @State private var diagnosticsExpanded = false

    var body: some View {
        Form {
            Section("settings.general") {
                Picker("language.menu", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.localizationKey))
                            .tag(language.rawValue)
                    }
                }
            }

            Section("settings.tracking") {
                HStack {
                    Label("settings.trackingState", systemImage: model.foregroundTracker.isTracking ? "record.circle.fill" : "pause.circle.fill")
                    Spacer()
                    Text(LocalizedStringKey(model.foregroundTracker.isTracking ? "status.running" : "status.paused"))
                        .foregroundStyle(.secondary)
                }

                Button {
                    if model.foregroundTracker.isTracking {
                        model.foregroundTracker.pause()
                    } else {
                        model.foregroundTracker.resume()
                    }
                } label: {
                    Label(
                        model.foregroundTracker.isTracking ? "tracking.pause" : "tracking.resume",
                        systemImage: model.foregroundTracker.isTracking ? "pause.fill" : "play.fill"
                    )
                }
            }

            Section("settings.privacy") {
                HStack(alignment: .firstTextBaseline) {
                    Label("settings.inputMonitoring", systemImage: "keyboard")
                    Spacer()
                    Text(LocalizedStringKey(model.typingCounter.permissionStatus.localizationKey))
                        .foregroundStyle(.secondary)
                }

                Text("settings.privacyNote")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if model.typingCounter.permissionStatus != .granted {
                    HStack(spacing: DayTraceDesign.spaceS) {
                        Button {
                            model.typingCounter.requestPermission()
                        } label: {
                            Label(
                                model.typingCounter.permissionStatus == .requesting
                                    ? "action.waitingForInputMonitoring"
                                    : "action.requestInputMonitoring",
                                systemImage: model.typingCounter.permissionStatus == .requesting
                                    ? "hourglass"
                                    : "lock.shield"
                            )
                        }
                        .disabled(model.typingCounter.permissionStatus == .requesting)

                        Button {
                            openInputMonitoringSettings()
                        } label: {
                            Label("action.openSystemSettings", systemImage: "gearshape")
                        }
                    }
                }
            }

            Section("settings.advanced") {
                DisclosureGroup(isExpanded: $diagnosticsExpanded) {
                    VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
                        diagnosticRow(
                            "diagnostics.inputMonitoring",
                            Text(LocalizedStringKey(model.typingCounter.permissionStatus.localizationKey))
                        )
                        diagnosticRow("diagnostics.eventTap", eventTapText)
                        diagnosticRow(
                            "diagnostics.cgPreflight",
                            Text(LocalizedStringKey(localizedBooleanKey(model.typingCounter.cgPreflightListenAccess)))
                        )
                        diagnosticRow(
                            "diagnostics.iohid",
                            Text(LocalizedStringKey(model.typingCounter.iohidListenAccess.localizationKey))
                        )
                        diagnosticRow(
                            "diagnostics.ipc",
                            Text(LocalizedStringKey(model.socketBridge.status.localizationKey))
                        )
                        diagnosticRow("diagnostics.nativeMessagingHost", Text(verbatim: "com.daytrace.spike"))
                        diagnosticRow(
                            "diagnostics.bundleID",
                            Text(verbatim: Bundle.main.bundleIdentifier ?? "—")
                        )
                        diagnosticRow(
                            "diagnostics.currentAppBundleID",
                            Text(verbatim: model.foregroundTracker.currentApp?.bundleIdentifier ?? "—")
                        )
                        diagnosticRow("diagnostics.currentDomain", Text(verbatim: model.domainTracker.currentDomain))
                        diagnosticRow("diagnostics.lastTypingEvent", timestampText(model.typingCounter.lastTypingEventAt))
                        diagnosticRow("diagnostics.lastDomainEvent", timestampText(model.domainTracker.lastDomainEventAt))
                        diagnosticRow("diagnostics.lastForegroundEvent", timestampText(model.foregroundTracker.lastForegroundEventAt))
                    }
                    .padding(.top, DayTraceDesign.spaceS)

                } label: {
                    Label("diagnostics.title", systemImage: "stethoscope")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 540)
        .padding(DayTraceDesign.spaceS)
    }

    private var eventTapText: Text {
        switch model.typingCounter.eventTapStatus {
        case "Not started": return Text("status.listenerNotStarted")
        case "Waiting for Input Monitoring authorization": return Text("status.listenerWaiting")
        case "Creating listen-only event tap": return Text("status.listenerCreating")
        case "Input Monitoring authorization not requested": return Text("status.listenerNotRequested")
        case "Input Monitoring permission required in System Settings": return Text("status.listenerSystemSettings")
        case "Input Monitoring preflight not granted": return Text("status.listenerPreflightNotGranted")
        case "Running": return Text("status.listenerRunning")
        case "Stopped": return Text("status.listenerStopped")
        case "Input Monitoring permission required": return Text("status.listenerPermissionRequired")
        case "Input Monitoring request denied": return Text("status.listenerPermissionDenied")
        case "Unable to create event tap": return Text("status.listenerFailed")
        default: return Text(verbatim: model.typingCounter.eventTapStatus)
        }
    }

    private func diagnosticRow(_ label: LocalizedStringKey, _ value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DayTraceDesign.spaceM) {
            Text(label)
                .font(DayTraceDesign.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: DayTraceDesign.spaceS)
            value
                .font(DayTraceDesign.caption)
                .multilineTextAlignment(.trailing)
        }
    }

    private func localizedBooleanKey(_ value: Bool) -> String {
        value ? "diagnostic.true" : "diagnostic.false"
    }

    private func timestampText(_ date: Date?) -> Text {
        guard let date else { return Text("—") }
        return Text(date, format: .dateTime.hour().minute().second())
    }

    private func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
