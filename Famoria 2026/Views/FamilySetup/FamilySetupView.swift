import SwiftUI

struct FamilySetupView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var familyName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Your Family")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Family Name", text: $familyName)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            
            Button("Create Family") { createFamily() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func createFamily() {
        guard let user = appState.currentUser else { return }
        let family = Family(
            id: UUID().uuidString,
            name: familyName.isEmpty ? "My Family" : familyName,
            members: [user]
        )
        appState.currentFamily = family
        appState.currentUser?.familyId = family.id
    }
}
