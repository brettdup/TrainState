//
//  TrainStateWatchApp.swift
//  TrainStateWatch Watch App
//
//  Created by Brett du Plessis on 2026/02/17.
//

import SwiftUI

@main
struct TrainStateWatch_Watch_AppApp: App {
    init() {
        WatchHealthKitWorkoutSyncService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
