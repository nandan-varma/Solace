//
//  ContentView.swift
//  Solace
//

import SwiftUI

/// Root tab shell. Today opens by default; Scan is reachable from anywhere
/// via its own tab per the spec's Section 10 hierarchy. `TabRouter` is
/// shared down to every tab so quick actions (e.g. Today's "Scan" button)
/// can switch tabs instead of pushing a nested copy of another tab's screen.
struct ContentView: View {
    @State private var router = TabRouter()

    var body: some View {
        TabView(selection: $router.selected) {
            Tab("Today", systemImage: "calendar", value: AppTab.today) {
                TodayView()
            }
            Tab("Scan", systemImage: "barcode.viewfinder", value: AppTab.scan) {
                ScanView()
            }
            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.trends) {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(.solaceVitality)
        .environment(router)
    }
}

#Preview {
    ContentView()
}
