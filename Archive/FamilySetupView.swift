import SwiftUI

struct FamilySetupView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var familyName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Your Family")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Family Name", text: $familyName)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button {
                createFamily()
            } label: {
                if isCreating {
                    ProgressView()
                } else {
                    Text("Create Family")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(familyName.isEmpty || isCreating)
        }
        .padding()
    }
    
    private func createFamily() {
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let name = familyName.isEmpty ? "My Family" : familyName
                try await appState.createFamily(name: name)
                // Family created! AppState automatically updates
                await MainActor.run {
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    FamilySetupView()
        .environmentObject(AppState())
}

