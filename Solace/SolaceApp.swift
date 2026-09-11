//
//  SolaceApp.swift
//  Solace
//
//  Created by Nandan Varma Pericharla on 9/11/26.
//

import Dependencies
import SQLiteData
import SwiftUI

@main
struct SolaceApp: App {
    /// Set if the database still couldn't be opened after `bootstrapDatabase`
    /// already tried resetting a corrupt local file — e.g. disk full. Shown
    /// instead of crashing the whole app at launch.
    private static var launchError: String?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        #endif
        do {
            try prepareDependencies {
                try $0.bootstrapDatabase()
            }
        } catch {
            Self.launchError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let launchError = Self.launchError {
                LaunchErrorView(message: launchError)
            } else {
                ContentView()
            }
        }
    }
}

private struct LaunchErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Solace couldn't start")
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Try closing and reopening the app. If this keeps happening, check that your device has free storage.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
