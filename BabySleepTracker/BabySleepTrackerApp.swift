//
//  BabySleepTrackerApp.swift
//  BabySleepTracker
//
//  Created by MacBook on 24.02.2026.
//

import SwiftUI

@main
struct BabySleepTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
