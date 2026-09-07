import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String
    @State private var diagnosticsExpanded = false
    @State private var deleteConfirmationPresented = false
    @State private var actionMessage: LocalizedStringKey?
    @State private var backupMessage: LocalizedStringKey?
    @State private var newCategory = ""
    @State private var renamingCategory: String?
    @State private var categoryDraft = ""
    @State private var ruleTarget = ""
    @State private var ruleCategory = ""
    @State private var deleteTimelineConfirmationPresented = false
    @State private var includeDetailedTimelineInExport = false
    @State private var pendingRestoreData: Data?
    @State private var pendingRestoreSummary = ""
    @State private var restoreConfirmationPresented = false
    @State private var deleteActivityConfirmationPresented = false
    @State private var deleteStart = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var deleteEnd = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var deleteAppUsage = true
    @State private var deleteTyping = false
    @State private var deleteTimeline = false
    @State private var deleteBackground = false
    @State private var integrityReport: IntegrityReport?

    var body: some View {
        Form {
            Section("settings.general") {
                Picker("language.menu", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.localizationKey))
                            .tag(language.rawValue)
                    }
                }

                Toggle(
                    "settings.launchAtLogin",
                    isOn: Binding(
                        get: { model.launchAtLogin.isEnabled },
                        set: { model.launchAtLogin.setEnabled($0) }
                    )
                )
                HStack {
                    Text("settings.launchAtLoginStatus")
                    Spacer()
                    Text(LocalizedStringKey(model.launchAtLogin.statusLocalizationKey))
                        .foregroundStyle(.secondary)
                }
            }

            Section("settings.health") {
                healthRow("health.tracking", value: model.foregroundTracker.isTracking ? "status.running" : "status.paused", icon: "record.circle")
                healthRow("health.chrome", value: model.socketBridge.status.localizationKey, icon: "globe")
                healthRow("health.persistence", value: persistenceHealthKey, icon: "externaldrive")
                HStack {
                    Text("health.lastCheckpoint")
                    Spacer()
                    timestampText(model.usageStore.lastCheckpointAt).foregroundStyle(.secondary)
                }
                HStack {
                    Text("health.daysTrackedLast30Days")
                    Spacer()
                    Text(String(model.history(for: .last30Days).dailyTotals.count)).monospacedDigit()
                }
                HStack {
                    Text("health.appsSeenLast30Days")
                    Spacer()
                    Text(String(model.history(for: .last30Days).appUsageByApp.count)).monospacedDigit()
                }
                HStack {
                    Text("health.websitesSeenLast30Days")
                    Spacer()
                    Text(String(model.history(for: .last30Days).websiteUsageByDomain.count)).monospacedDigit()
                }
            }

            Section("settings.menuBar") {
                Picker("settings.menuBarDisplay", selection: menuBarDisplayBinding) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.localizationKey)).tag(mode.rawValue)
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

                Toggle("settings.exportDetailedTimeline", isOn: $includeDetailedTimelineInExport)
                Button("settings.exportData", action: exportData)
                Button("settings.deleteData", role: .destructive) {
                    deleteConfirmationPresented = true
                }
                if let actionMessage {
                    Text(actionMessage)
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("settings.data") {
                Toggle("settings.automaticBackups", isOn: Binding(
                    get: { model.backupManager.isEnabled },
                    set: { model.backupManager.isEnabled = $0 }
                ))
                Button("settings.backupNow") {
                    backupMessage = model.createBackup() == nil ? "settings.backupFailed" : "settings.backupSucceeded"
                }
                Button("settings.showDataLocation", action: showDataLocation)
                Button("settings.restoreFromBackup", action: chooseRestoreFile)
                Button("settings.exportDiagnosticReport", action: exportDiagnosticReport)
                if let backupMessage {
                    Text(backupMessage).font(DayTraceDesign.caption).foregroundStyle(.secondary)
                }
                Text("settings.dataWarning")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("settings.dataControl") {
                DatePicker("settings.delete.start", selection: $deleteStart, displayedComponents: .date)
                DatePicker("settings.delete.end", selection: $deleteEnd, displayedComponents: .date)
                Toggle("settings.delete.appUsage", isOn: $deleteAppUsage)
                Toggle("settings.delete.typing", isOn: $deleteTyping)
                Toggle("settings.delete.timeline", isOn: $deleteTimeline)
                Toggle("settings.delete.background", isOn: $deleteBackground)
                Button("settings.deleteActivity", role: .destructive) {
                    deleteActivityConfirmationPresented = true
                }
                Button("settings.integrity.run") {
                    integrityReport = model.integrityReport()
                }
                if let report = integrityReport {
                    HStack {
                        Label(
                            report.isHealthy ? "settings.integrity.healthy" : "settings.integrity.issues",
                            systemImage: report.isHealthy ? "checkmark.seal" : "exclamationmark.triangle"
                        )
                        Spacer()
                        Text(report.recordsScanned, format: .number).monospacedDigit()
                    }
                    if !report.isHealthy {
                        Button("settings.integrity.repair") {
                            _ = model.repairIntegrity()
                            integrityReport = model.integrityReport()
                        }
                    }
                }
            }

            Section("settings.timeline") {
                Toggle("settings.timeline.enabled", isOn: Binding(
                    get: { model.timelineEnabled },
                    set: { _ = model.setTimelineEnabled($0) }
                ))
                Text("settings.timeline.note")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                let stats = model.timelineStatistics()
                HStack {
                    Text("settings.timeline.appIntervals")
                    Spacer()
                    Text(stats.appIntervalCount, format: .number).monospacedDigit()
                }
                HStack {
                    Text("settings.timeline.websiteIntervals")
                    Spacer()
                    Text(stats.websiteIntervalCount, format: .number).monospacedDigit()
                }
                Button("settings.timeline.delete") { deleteTimelineConfirmationPresented = true }
                    .foregroundStyle(.red)
            }

            Section("background.settings.title") {
                BackgroundActivitySettingsContent(model: model)
            }

            Section("metadata.categories") {
                HStack {
                    TextField("metadata.newCategory", text: $newCategory)
                    Button("metadata.addCategory") {
                        model.metadataStore.addCategory(newCategory)
                        newCategory = ""
                    }
                    .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(model.metadataStore.customCategories, id: \.self) { category in
                    HStack {
                        if renamingCategory == category {
                            TextField(category, text: $categoryDraft)
                                .onSubmit { finishRenaming(category) }
                            Button { finishRenaming(category) } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Text(category)
                        }
                        Spacer()
                        if renamingCategory != category {
                            Button {
                                renamingCategory = category
                                categoryDraft = category
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("metadata.renameCategory")
                        }
                        Button("metadata.deleteCategory", role: .destructive) {
                            model.metadataStore.deleteCategory(category)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Text("metadata.categoryNote").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("metadata.ruleTarget", text: $ruleTarget)
                    TextField("metadata.ruleCategory", text: $ruleCategory)
                    Button("metadata.addRule") {
                        model.metadataStore.addRule(targetKind: .app, target: ruleTarget, category: ruleCategory)
                        ruleTarget = ""
                        ruleCategory = ""
                    }
                    .disabled(ruleTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ruleCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(model.metadataStore.categoryRules) { rule in
                    HStack {
                        Label(rule.target, systemImage: rule.targetKind == .app ? "macwindow" : "globe")
                        Spacer()
                        Text(rule.category).foregroundStyle(.secondary)
                        Button { model.metadataStore.deleteRule(rule) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Text("metadata.ruleNote").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                let knownApps = model.appIdentities()
                if !knownApps.isEmpty {
                    Text("metadata.hideIdentity").font(DayTraceDesign.bodyMedium)
                    ForEach(knownApps, id: \.self) { app in
                        Toggle(model.metadataStore.presentationName(for: app), isOn: Binding(
                            get: { model.metadataStore.isIdentityHidden(app: app) },
                            set: { _ in model.metadataStore.toggleIdentityHidden(app: app) }
                        ))
                    }
                }
            }

            Section("settings.privacySummary") {
                Label("settings.privacy.stored", systemImage: "checkmark.shield")
                Text("settings.privacy.storedDetail").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                Label("settings.privacy.neverStored", systemImage: "lock.shield")
                Text("settings.privacy.neverStoredDetail").font(DayTraceDesign.caption).foregroundStyle(.secondary)
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
                        diagnosticRow("diagnostics.persistence", persistenceStatusText)
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
        .frame(width: 600, height: 700)
        .padding(DayTraceDesign.spaceS)
        .alert("settings.deleteData.confirmTitle", isPresented: $deleteConfirmationPresented) {
            Button("settings.deleteData.cancel", role: .cancel) {}
            Button("settings.deleteData.confirm", role: .destructive, action: deleteData)
        } message: {
            Text("settings.deleteData.confirmMessage")
        }
        .alert("settings.timeline.deleteTitle", isPresented: $deleteTimelineConfirmationPresented) {
            Button("settings.deleteData.cancel", role: .cancel) {}
            Button("settings.timeline.deleteConfirm", role: .destructive) {
                actionMessage = model.deleteTimelineHistory() ? "settings.timeline.deleteSucceeded" : "settings.deleteFailed"
            }
        } message: {
            Text("settings.timeline.deleteMessage")
        }
        .alert("settings.restore.confirmTitle", isPresented: $restoreConfirmationPresented) {
            Button("settings.restore.cancel", role: .cancel) { pendingRestoreData = nil }
            Button("settings.restore.confirm", role: .destructive) {
                if let pendingRestoreData {
                    let result = model.restoreBackup(from: pendingRestoreData)
                    backupMessage = restoreMessage(for: result)
                }
                pendingRestoreData = nil
            }
        } message: {
            Text(pendingRestoreSummary)
        }
        .alert("settings.deleteActivity.confirmTitle", isPresented: $deleteActivityConfirmationPresented) {
            Button("settings.deleteData.cancel", role: .cancel) {}
            Button("settings.deleteData.confirm", role: .destructive) { deleteActivity() }
        } message: {
            Text("settings.deleteActivity.confirmMessage")
        }
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

    private var persistenceStatusText: Text {
        switch model.usageStore.status {
        case .ready:
            return Text("persistence.status.healthy")
        case .degraded:
            return Text("persistence.status.degraded")
        case .failed:
            return Text("persistence.status.failed")
        }
    }

    private var persistenceHealthKey: String {
        switch model.usageStore.status {
        case .ready: return "health.healthy"
        case .degraded: return "health.degraded"
        case .failed: return "health.unavailable"
        }
    }

    private func healthRow(_ label: LocalizedStringKey, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(LocalizedStringKey(value)).foregroundStyle(.secondary)
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

    private var menuBarDisplayBinding: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: MenuBarDisplayMode.storageKey) ?? MenuBarDisplayMode.usage.rawValue },
            set: { UserDefaults.standard.set($0, forKey: MenuBarDisplayMode.storageKey) }
        )
    }

    private func exportData() {
        guard let data = model.exportAggregatesJSON(includeDetailedTimeline: includeDetailedTimelineInExport) else {
            actionMessage = "settings.exportFailed"
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "DayTrace-aggregates.json"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            actionMessage = "settings.exportSucceeded"
        } catch {
            actionMessage = "settings.exportFailed"
        }
    }

    private func deleteData() {
        actionMessage = model.deleteAllData() ? "settings.deleteSucceeded" : "settings.deleteFailed"
    }

    private func chooseRestoreFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else {
            return
        }
        guard case .success(let payload) = DayTraceBackupCodec.validate(data) else {
            backupMessage = "settings.restore.invalid"
            return
        }
        pendingRestoreData = data
        pendingRestoreSummary = String(format: NSLocalizedString("settings.restore.summary", comment: "Restore summary"), payload.appUsage.count, payload.websiteUsage.count)
        restoreConfirmationPresented = true
    }

    private func restoreMessage(for result: RestoreResult) -> LocalizedStringKey {
        switch result {
        case .restored: return "settings.restore.succeeded"
        case .rejected: return "settings.restore.invalid"
        case .failed: return "settings.restore.failed"
        }
    }

    private func deleteActivity() {
        var datasets = Set<ActivityDataset>()
        if deleteAppUsage { datasets.insert(.appUsage) }
        if deleteTyping { datasets.insert(.typingActivity) }
        if deleteTimeline { datasets.insert(.detailedTimeline) }
        if deleteBackground { datasets.insert(.backgroundActivity) }
        actionMessage = model.deleteActivity(from: deleteStart, through: deleteEnd, datasets: datasets)
            ? "settings.deleteSucceeded"
            : "settings.deleteFailed"
    }

    private func exportDiagnosticReport() {
        guard let data = model.diagnosticReportData() else {
            backupMessage = "settings.exportFailed"
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "DayTrace-diagnostic-report.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            backupMessage = "settings.exportSucceeded"
        } catch {
            backupMessage = "settings.exportFailed"
        }
    }

    private func showDataLocation() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = base.appendingPathComponent("DayTrace", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    private func finishRenaming(_ category: String) {
        model.metadataStore.renameCategory(from: category, to: categoryDraft)
        renamingCategory = nil
        categoryDraft = ""
    }
}
