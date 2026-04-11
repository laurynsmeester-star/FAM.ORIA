import SwiftUI

struct OnboardingPageView2: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Welcome to Famoria")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Build a shared space for your family: invites, shared dashboards, and more.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
            Button("Get Started") {
                hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
