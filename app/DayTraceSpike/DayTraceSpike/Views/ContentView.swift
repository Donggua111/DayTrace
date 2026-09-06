import SwiftUI

struct ContentView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String

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
    }
}
