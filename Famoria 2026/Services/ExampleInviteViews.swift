import SwiftUI

// MARK: - EXAMPLE VIEWS
// These are example implementations for reference.
// The actual production views are in separate files.
// Structs in this file are prefixed with "Example" to avoid conflicts.

// MARK: - Invite Code View
// MARK: - EXAMPLE VIEWS
// These are example implementations for reference.
// The actual production views are in separate files.
// Structs in this file are prefixed with "Example" to avoid conflicts.

/// Example view demonstrating invite code generation and sharing
struct InviteCodeView: View {
    @EnvironmentObject var appState: AppState
    @State private var generatedCode: String?
    @State private var isGenerating = false
    @State private var error: Error?
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: 24) {
            if let family = appState.currentFamily {
                Text("Invite to \(family.name)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let code = generatedCode {
                    // Display generated code
                    VStack(spacing: 12) {
                        Text("Share this code:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .tracking(8)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        
                        Text("Code expires in 7 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            Button {
                                copyToClipboard(code)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    // Generate code button
                    Button {
                        generateCode()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Generate Invite Code", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                    
                    Text("Create a code that others can use to join your family")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if let error = error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
            } else {
                Text("You must be in a family to generate invite codes")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $showShareSheet) {
            if let code = generatedCode {
                ShareSheet(items: [createShareMessage(code: code)])
            }
        }
    }
    
    private func generateCode() {
        isGenerating = true
        error = nil
        
        Task {
            do {
                let code = try await appState.generateInviteCode()
                await MainActor.run {
                    self.generatedCode = code
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    
    private func createShareMessage(code: String) -> String {
        if let familyName = appState.currentFamily?.name {
            return "Join \(familyName) on Family Hub! Use invite code: \(code)"
        }
        return "Join my family on Family Hub! Use invite code: \(code)"
    }
}

/// Example view for joining a family with an invite code
struct ExampleJoinFamilyView: View {
    @EnvironmentObject var appState: AppState
    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var isValidating = false
    @State private var error: Error?
    @State private var validationResult: (familyId: String, familyName: String)?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Join a Family")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the 6-character invite code you received")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite Code")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("ABC123", text: $inviteCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                        .onChange(of: inviteCode) { _, newValue in
                            // Format as uppercase and limit to 6 characters
                            inviteCode = String(newValue.uppercased().prefix(6))
                            
                            // Auto-validate when 6 characters entered
                            if inviteCode.count == 6 {
                                validateCode()
                            } else {
                                validationResult = nil
                            }
                        }
                    
                    if let result = validationResult {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("You'll be joining: \(result.familyName)")
                                .font(.caption)
                        }
                        .padding(.top, 4)
                    }
                }
                
                if let error = error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error.localizedDescription)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button {
                    joinFamily()
                } label: {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Join Family")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inviteCode.count != 6 || isJoining || validationResult == nil)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func validateCode() {
        guard inviteCode.count == 6 else { return }
        
        isValidating = true
        error = nil
        validationResult = nil
        
        Task {
            do {
                let result = try await appState.validateInviteCode(inviteCode)
                await MainActor.run {
                    self.validationResult = result
                    self.isValidating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isValidating = false
                }
            }
        }
    }
    
    private func joinFamily() {
        isJoining = true
        error = nil
        
        Task {
            do {
                try await appState.joinFamilyWithCode(inviteCode)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isJoining = false
                }
            }
        }
    }
}

// MARK: - Share Sheet Wrapper

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

// MARK: - Preview

#Preview("Invite Code View") {
    InviteCodeView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(id: "1", name: "John Doe", email: "john@example.com", familyId: "family1", role: .owner)
            state.currentFamily = Family(id: "family1", name: "The Doe Family", members: [])
            return state
        }())
}

#Preview("Join Family View") {
    ExampleJoinFamilyView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(id: "2", name: "Jane Smith", email: "jane@example.com", familyId: nil, role: nil)
            return state
        }())
}

