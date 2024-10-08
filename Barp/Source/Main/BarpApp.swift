//
//  BarpApp.swift
//  Barp
//
//  Created by Moses Varghese on 10/4/24.
//

//import SwiftUI
//
//@main
//struct BarpApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//        
//        MenuBarExtra("Barp", systemImage: "menubar.rectangle") {
//            VStack {
//                Button("High") {
//                    
//                }
//                Button("Medium") {
//                    
//                }
//                Button("Low") {
//                    
//                }
//                
//                Divider()
//                
//                Button("Quit") {
//                    
//                }
//            }
//        }
//    }
//}

import SwiftUI

@main
struct BarpApp: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    @ObservedObject var appState = AppState()

    init() {
        NSSplitViewItem.swizzle()
        IceBarPanel.swizzle()
        MigrationManager(appState: appState).migrateAll()
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        SettingsWindow(appState: appState)
        PermissionsWindow(appState: appState)
    }
}
