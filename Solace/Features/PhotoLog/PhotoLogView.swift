//
//  PhotoLogView.swift
//  Solace
//

import SwiftUI

/// Placeholder — the real photo capture → AI draft → editable log flow ships
/// in Phase 4 once the BYOK cloud AI client exists (Section 7).
struct PhotoLogView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Photo AI Logging",
                systemImage: "sparkles",
                description: Text("Coming once you configure a cloud AI provider in Settings (Phase 4).")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
