//
//  RootView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// RootView determines whether to show the launch/auth flow or the main app
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLaunchAnimation = true
    
    var body: some View {
        Group {
            if showLaunchAnimation {
                LaunchScreen()
            } else if appState.isAuthenticated && appState.currentFamily != nil {
                // User is authenticated and has a family → show main app
                HomePageView()
            } else if appState.isAuthenticated {
                // User is authenticated but needs to create/join a family
                FamilySetupNavigationView()
            } else {
                // Not authenticated → show welcome/auth flow
                WelcomePageView()
            }
        }
        .task {
            // Show launch screen for 2 seconds
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showLaunchAnimation = false
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
