# Firebase Backend - Quick Reference

## 🚀 Common Operations

### Authentication

```swift
// Sign Up
try await appState.handleSignUp(
    name: "John Doe",
    email: "john@example.com", 
    password: "password123"
)

// Sign In
try await appState.handleSignIn(
    email: "john@example.com",
    password: "password123"
)

// Sign Out
await appState.signOut()

// Check if authenticated
if appState.isAuthenticated {
    // User is signed in
}

// Get current user
if let user = appState.currentUser {
    print(user.name)
}
```

### Family Management

```swift
// Create a family
try await appState.createFamily(name: "The Smith Family")

// Generate invite code
let code = try await appState.generateInviteCode()
// Returns: "ABC123"

// Validate invite code
let (familyId, familyName) = try await appState.validateInviteCode("ABC123")

// Join family with code
try await appState.joinFamilyWithCode("ABC123")

// Check current family
if let family = appState.currentFamily {
    print(family.name)
    print(family.members.count)
}

// Remove member (owner/admin only)
appState.remove(member: someMember)
```

### Posts

```swift
// Create post
try await appState.createPost(content: "Hello family!")

// Get all posts (automatically updated)
appState.posts // Array of FamilyPost

// Display in view
ForEach(appState.posts) { post in
    Text(post.content)
}

// Delete post
try await appState.deletePost(somePost)
```

### Events

```swift
// Create event
let tomorrow = Date().addingTimeInterval(86400)
try await appState.createEvent(
    title: "Family Dinner",
    date: tomorrow
)

// Get all events (automatically updated)
appState.events // Array of FamilyEvent

// Display in view
ForEach(appState.events) { event in
    Text(event.title)
}

// Delete event
try await appState.deleteEvent(someEvent)
```

## 🎨 SwiftUI View Examples

### Basic View Structure

```swift
struct MyView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        // Your UI here
    }
}
```

### Sign Up Form

```swift
struct SignUpView: View {
    @EnvironmentObject var appState: AppState
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    
    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            
            Button("Sign Up") {
                Task {
                    do {
                        try await appState.handleSignUp(
                            name: name,
                            email: email,
                            password: password
                        )
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
    }
}
```

### Create Family Form

```swift
struct CreateFamilyView: View {
    @EnvironmentObject var appState: AppState
    @State private var familyName = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            TextField("Family Name", text: $familyName)
            
            Button("Create") {
                Task {
                    try? await appState.createFamily(name: familyName)
                    dismiss()
                }
            }
        }
    }
}
```

### Invite Code Generator

```swift
struct InviteView: View {
    @EnvironmentObject var appState: AppState
    @State private var code: String?
    
    var body: some View {
        VStack {
            if let code = code {
                Text(code)
                    .font(.largeTitle)
            } else {
                Button("Generate Code") {
                    Task {
                        code = try? await appState.generateInviteCode()
                    }
                }
            }
        }
    }
}
```

### Join Family Form

```swift
struct JoinFamilyView: View {
    @EnvironmentObject var appState: AppState
    @State private var code = ""
    
    var body: some View {
        VStack {
            TextField("Invite Code", text: $code)
                .textInputAutocapitalization(.characters)
            
            Button("Join") {
                Task {
                    try? await appState.joinFamilyWithCode(code)
                }
            }
            .disabled(code.count != 6)
        }
    }
}
```

### Post Feed

```swift
struct FeedView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(appState.posts) { post in
            VStack(alignment: .leading) {
                Text(post.authorName)
                    .fontWeight(.bold)
                Text(post.content)
                Text(post.timestamp, style: .relative)
                    .font(.caption)
            }
        }
    }
}
```

### Create Post Form

```swift
struct CreatePostView: View {
    @EnvironmentObject var appState: AppState
    @State private var content = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            TextEditor(text: $content)
                .navigationTitle("New Post")
                .toolbar {
                    Button("Post") {
                        Task {
                            try? await appState.createPost(content: content)
                            dismiss()
                        }
                    }
                }
        }
    }
}
```

### Events List

```swift
struct EventsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(appState.events) { event in
            VStack(alignment: .leading) {
                Text(event.title)
                    .fontWeight(.bold)
                Text(event.date, style: .date)
                Text(event.date, style: .time)
            }
        }
    }
}
```

## 🔍 Error Handling

```swift
// Comprehensive error handling
Task {
    do {
        try await appState.joinFamilyWithCode(code)
    } catch FamilyServiceError.invalidInviteCode {
        errorMessage = "Invalid code"
    } catch FamilyServiceError.inviteCodeExpired {
        errorMessage = "Code expired"
    } catch FamilyServiceError.userAlreadyInFamily {
        errorMessage = "Already in a family"
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

## 📊 Observing Changes

```swift
// Automatically react to changes
struct MyView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Text("Posts: \(appState.posts.count)")
            // Updates automatically when posts change!
    }
}

// Or use onChange modifier
.onChange(of: appState.posts) { _, newPosts in
    print("Posts updated: \(newPosts.count)")
}

// React to family changes
.onChange(of: appState.currentFamily) { _, family in
    if let family = family {
        print("Now in family: \(family.name)")
    }
}
```

## 🔐 Permission Checks

```swift
// Check user role
if appState.currentUser?.role == .owner {
    // Show owner-only features
}

if appState.currentUser?.role == .admin || 
   appState.currentUser?.role == .owner {
    // Show admin features
}

// Check if in family
if appState.currentFamily != nil {
    // User is in a family
}

// Check if post is by current user
if post.authorName == appState.currentUser?.name {
    // Show edit/delete options
}
```

## 🎯 Common Patterns

### Loading State

```swift
struct MyView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false
    @State private var error: Error?
    
    func performAction() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await appState.createPost(content: "...")
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    var body: some View {
        if isLoading {
            ProgressView()
        } else {
            Button("Action") {
                performAction()
            }
        }
    }
}
```

### Conditional Navigation

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if !appState.isAuthenticated {
            LoginView()
        } else if appState.currentFamily == nil {
            FamilySetupView()
        } else {
            HomeView()
        }
    }
}
```

### Pull to Refresh

```swift
List(appState.posts) { post in
    PostRow(post: post)
}
.refreshable {
    // Data refreshes automatically via listeners
    // But you can force reload if needed
    if let familyId = appState.currentFamily?.id {
        await appState.loadFamilyData(familyId: familyId)
    }
}
```

## 🧪 Testing

```swift
// Preview with mock data
#Preview {
    ContentView()
        .environmentObject({
            let state = AppState()
            state.currentUser = User(
                id: "1",
                name: "Test User",
                email: "test@example.com",
                familyId: "family1",
                role: .member
            )
            state.currentFamily = Family(
                id: "family1",
                name: "Test Family",
                members: []
            )
            state.posts = [
                FamilyPost(
                    id: "1",
                    authorName: "Test",
                    content: "Test post",
                    timestamp: Date()
                )
            ]
            return state
        }())
}
```

## 📱 Platform-Specific Code

### iOS vs macOS Clipboard

```swift
func copyToClipboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}
```

## 🔔 Notifications (Future Feature)

```swift
// When you add push notifications
import UserNotifications

// Request permission
UNUserNotificationCenter.current()
    .requestAuthorization(options: [.alert, .sound]) { granted, _ in
        if granted {
            // Register device token with Firebase
        }
    }
```

## 💡 Tips & Tricks

1. **Always use Task for async calls in SwiftUI**
   ```swift
   Button("Action") {
       Task {
           try await appState.someAsyncFunction()
       }
   }
   ```

2. **Check for nil before using optional data**
   ```swift
   guard let user = appState.currentUser else { return }
   ```

3. **Use @MainActor for UI updates**
   ```swift
   Task {
       let result = try await someBackgroundWork()
       await MainActor.run {
           // Update UI here
       }
   }
   ```

4. **AppState methods already handle @MainActor**
   ```swift
   // This is already on MainActor
   try await appState.createPost(content: "...")
   ```

5. **Real-time listeners are automatic**
   ```swift
   // No need to manually refresh!
   // Just observe appState.posts
   ```

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "FirebaseApp not configured" | Add GoogleService-Info.plist |
| "Permission denied" | Check Firestore security rules |
| Posts not updating | Ensure listeners are started |
| Invite code invalid | Check code format (6 chars, uppercase) |
| User data not loading | Ensure user document exists in Firestore |

## 📞 Quick Debug Commands

```swift
// Print current state
print("User:", appState.currentUser?.name ?? "nil")
print("Family:", appState.currentFamily?.name ?? "nil")
print("Posts:", appState.posts.count)
print("Events:", appState.events.count)

// Test Firebase connection
import FirebaseCore
print("Firebase configured:", FirebaseApp.app() != nil)

// Enable debug logging
FirebaseConfiguration.shared.setLoggerLevel(.debug)
```

---

## 🎯 Most Common Use Cases

1. **Sign up new user**
   ```swift
   try await appState.handleSignUp(name: name, email: email, password: password)
   ```

2. **Create family**
   ```swift
   try await appState.createFamily(name: familyName)
   ```

3. **Generate and share invite code**
   ```swift
   let code = try await appState.generateInviteCode()
   ```

4. **Join family**
   ```swift
   try await appState.joinFamilyWithCode(code)
   ```

5. **Create post**
   ```swift
   try await appState.createPost(content: content)
   ```

6. **Create event**
   ```swift
   try await appState.createEvent(title: title, date: date)
   ```

7. **Sign out**
   ```swift
   await appState.signOut()
   ```

---

**Keep this file handy for quick reference!** 📚
