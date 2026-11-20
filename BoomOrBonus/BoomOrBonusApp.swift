//
//  BoomOrBonusApp.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // The ads SDK starts from ConsentManager (GameScreen), once the consent allows ads. Nothing to do here.

    return true
  }
}


@main
struct BoomOrBonusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    
    
    var body: some Scene {
        
        WindowGroup {
            NavigationView {
                GameScreen()
            }
            .navigationViewStyle(.stack)
            .modelContainer(sharedModelContainer)
        }
    }
}
