import SwiftUI

struct ContentView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String

    var body: some View {
        DashboardView(model: model, languageRawValue: $languageRawValue)
    }
}
