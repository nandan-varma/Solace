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
                TodayPlaceholderView()
            }
            Tab("Scan", systemImage: "barcode.viewfinder") {
                ScanPlaceholderView()
            }
            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis") {
                HistoryPlaceholderView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsPlaceholderView()
            }
        }
        .tint(.solaceVitality)
    }
}

private struct TodayPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Today")
                .navigationTitle("Solace")
        }
    }
}

private struct ScanPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Scan")
                .navigationTitle("Scan")
        }
    }
}

private struct HistoryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Trends")
                .navigationTitle("Trends")
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Settings")
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
