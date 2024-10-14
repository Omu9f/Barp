//
//  BarpUI2App.swift
//  BarpUI2
//
//  Created by Moses Varghese on 10/11/24.
//

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

