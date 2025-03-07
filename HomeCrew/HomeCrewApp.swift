//
//  HomeCrewApp.swift
//  HomeCrew
//
//  Created by Vipul Swarup on 07/03/25.
//

import SwiftUI

@main
struct HomeCrewApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
