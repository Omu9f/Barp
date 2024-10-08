//
//  ContentView.swift
//  Barp
//
//  Created by Moses Varghese on 10/4/24.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var runningApps: [NSRunningApplication] = []

    var body: some View {
        VStack {
            Text("Running Applications (Non-Apple Menu Bar Apps)")
                .font(.headline)
                .padding()

            List(runningApps, id: \.bundleIdentifier) { app in
                HStack {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    Text(app.localizedName ?? "Unknown App")
                }
            }
        }
        .frame(width: 300, height: 400)
        .onAppear {
            updateRunningApps()
            
            // Observe changes in running applications
            NotificationCenter.default.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { _ in
                updateRunningApps()
            }
            
            NotificationCenter.default.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { _ in
                updateRunningApps()
            }
        }
        // Clean up notification observers to avoid memory leaks
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        }
    }

    // Helper function to update the list of running apps (filtering out Apple system processes)
    private func updateRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications.filter { app in
            // Filter to show only non-Apple apps (exclude "com.apple" apps)
            (app.activationPolicy == .regular || app.activationPolicy == .accessory) &&
            !(app.bundleIdentifier?.hasPrefix("com.apple") ?? false) // Exclude Apple system processes
        }
    }
}


#Preview {
    ContentView()
}
