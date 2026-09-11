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
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        #endif
        try! prepareDependencies {
            try $0.bootstrapDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
