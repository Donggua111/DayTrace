import SwiftUI

struct ContentView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            DashboardView(model: model, languageRawValue: $languageRawValue)
                .tabItem {
                    Label("tab.dashboard", systemImage: "chart.bar.xaxis")
                }
            HistoryView(model: model, languageRawValue: $languageRawValue)
                .tabItem {
                    Label("tab.history", systemImage: "clock.arrow.circlepath")
                }
        }
        .onAppear {
            let key = "daytrace.onboarding.completed"
            if UserDefaults.standard.object(forKey: key) == nil,
               model.history(for: .last30Days).appUsageByApp.isEmpty {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "daytrace.onboarding.completed")
                showOnboarding = false
            }
            .environment(\.locale, (AppLanguage(rawValue: languageRawValue) ?? .system).locale)
        }
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: DayTraceDesign.spaceL) {
            TabView(selection: $page) {
                onboardingPage("onboarding.welcome.title", detail: "onboarding.welcome.detail", symbol: "clock.arrow.circlepath", tag: 0)
                onboardingPage("onboarding.records.title", detail: "onboarding.records.detail", symbol: "chart.bar.xaxis", tag: 1)
                onboardingPage("onboarding.privacy.title", detail: "onboarding.privacy.detail", symbol: "lock.shield", tag: 2)
                onboardingPage("onboarding.setup.title", detail: "onboarding.setup.detail", symbol: "checkmark.shield", tag: 3)
            }
            .tabViewStyle(.automatic)
            .frame(width: 460, height: 250)

            HStack {
                if page > 0 {
                    Button("onboarding.back") { page -= 1 }
                }
                Spacer()
                if page < 3 {
                    Button("onboarding.next") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("onboarding.done", action: onComplete)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(DayTraceDesign.spaceXL)
    }

    private func onboardingPage(_ title: LocalizedStringKey, detail: LocalizedStringKey, symbol: String, tag: Int) -> some View {
        VStack(spacing: DayTraceDesign.spaceM) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(DayTraceDesign.accent)
            Text(title).font(DayTraceDesign.title)
            Text(detail)
                .font(DayTraceDesign.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tag(tag)
    }
}
