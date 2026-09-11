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
