//
//  DevSettingsSection.swift
//  Solace
//
//  Debug-only developer tools section — #if DEBUG means this is compiled
//  out of Release builds entirely, not just hidden at runtime, so nothing
//  here can ship to users.
//

#if DEBUG

import Dependencies
import GRDB
import SwiftUI
import UIKit

struct DevSettingsSection: View {
    /// Called after seeding/wiping so the caller can reload its own
    /// @State from the (now-changed) database instead of showing stale data.
    let onDataChanged: () async -> Void

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var showWipeConfirmation = false

    var body: some View {
        Section {
            Button {
                Task { await run { try await DevDataSeeder.seedSampleData() } message: { "Seeded sample data." } }
            } label: {
                Label("Seed Sample Data", systemImage: "shippingbox")
            }
            .disabled(isWorking)

            Button(role: .destructive) {
                showWipeConfirmation = true
            } label: {
                Label("Wipe All Data", systemImage: "trash")
            }
            .disabled(isWorking)
            .confirmationDialog(
                "Wipe all local data?",
                isPresented: $showWipeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Wipe Everything", role: .destructive) {
                    Task { await run { try await DevDataSeeder.wipeAllData() } message: { "Wiped all data." } }
                }
            } message: {
                Text("Deletes every product, food, diary entry, and setting, and clears the Keychain. This cannot be undone.")
            }

            LabeledContent("Database File") {
                Button {
                    @Dependency(\.defaultDatabase) var database
                    UIPasteboard.general.string = database.path
                    statusMessage = "Copied path to clipboard."
                } label: {
                    Text("Copy Path").font(.solaceCaption)
                }
            }

            if isWorking {
                HStack {
                    ProgressView()
                    Text("Working…").foregroundStyle(.secondary)
                }
            } else if let statusMessage {
                Text(statusMessage).foregroundStyle(.secondary)
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Only visible in debug builds — never ships to the App Store.")
        }
    }

    private func run(_ action: @escaping () async throws -> Void, message: @escaping () -> String) async {
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }
        do {
            try await action()
            await onDataChanged()
            statusMessage = message()
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }
}

#endif
