import SwiftUI

struct RootView: View {
    @StateObject var appState = AppState()
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingPageView()
                    .environmentObject(appState)
            } else if !appState.isAuthenticated {
                AuthView()
                    .environmentObject(appState)
            } else {
                MainAppView()
                    .environmentObject(appState)
            }
        }
    }
}

// Temporary placeholder for MainAppView to ensure compilation if not present yet.
struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(appState.currentFamily?.name ?? "Your Family")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if appState.currentUser?.familyId == nil {
                    NavigationLink("Set up your family") {
                        FamilySetupView()
                    }
                } else {
                    Text("Welcome, \(appState.currentUser?.name ?? "User")")
                }
            }
            .padding()
            .navigationTitle("Famoria")
        }
    }
}
