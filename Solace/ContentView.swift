//
//  ContentView.swift
//  Solace
//

import SwiftUI

/// Root tab shell. Today opens by default; Scan is reachable from anywhere
/// via its own tab (a persistent scan action is layered on top of it once
/// the scanner ships in Phase 1), per the spec's Section 10 hierarchy.
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "calendar") {
                TodayView()
            }
            Tab("Scan", systemImage: "barcode.viewfinder") {
                ScanView()
            }
            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(.solaceVitality)
    }
}

#Preview {
    ContentView()
}
