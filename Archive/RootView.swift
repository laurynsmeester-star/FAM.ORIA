import SwiftUI

struct RootView: View {
    
    @StateObject var appState = AppState ()
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

      
struct InviteComposer: View {
    @EnvironmentObject var appState: AppState
    @State private var email: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Invitee email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            Button("Create Invite") {
                guard !email.isEmpty else { return }
                appState.createInvite(for: email)
                email = ""
            }
            .buttonStyle(.bordered)
        }
    }
}

