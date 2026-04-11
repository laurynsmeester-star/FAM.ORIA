import SwiftUI

struct InviteStep: View {

@Binding var phoneNumber: String

@State private var showContacts = false
@State private var showMessage = false

var body: some View {
    VStack(spacing: 20) {
        
        Text("Invite Your Family")
            .font(.title2)
            .fontWeight(.bold)
        
        Text("Select a contact or enter a number to invite.")
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
        
        // Manual Input
        TextField("Phone Number", text: $phoneNumber)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
        
        // Contacts Button
        Button("Pick from Contacts") {
            showContacts = true
        }
        .padding()
        
        // Send Invite
        Button("Send Invite") {
            showMessage = true
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    .sheet(isPresented: $showContacts) {
        ContactPicker { number in
            phoneNumber = number
        }
    }
    .sheet(isPresented: $showMessage) {
        MessageComposeView(
            recipients: [phoneNumber],
            body: "Join my family on Famoria 💙"
        )
    }
}
}
