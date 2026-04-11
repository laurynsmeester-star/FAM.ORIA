# Famoria 2026 - Project Structure

## Overview
Famoria is a family management app that allows families to connect, share events, posts, and stay organized together.

## App Flow

```
Launch Screen (2 seconds)
    ↓
Welcome Page
    ├─→ Sign In → Home Page
    └─→ Register
         ├─→ Family Admin Registration
         │       ├─→ Personal Info
         │       ├─→ Family Creation
         │       ├─→ Invite Code Generation
         │       └─→ Home Page
         └─→ General User Registration
                 ├─→ Personal Info
                 ├─→ Invite Code Entry
                 ├─→ Join Family
                 └─→ Home Page
```

## Project Structure

```
Famoria_2026/
├── Famoria_2026App.swift                 # Main app entry point
│
├── Models/
│   └── Models.swift                      # Data models (User, Family, FamilyEvent, FamilyPost)
│
├── Services/
│   ├── AppState.swift                    # Global app state management
│   └── FirebaseAuthService.swift        # Firebase authentication implementation
│
└── Views/
    ├── RootView.swift                    # Root navigation controller
    │
    ├── Launch/
    │   └── LaunchScreen.swift            # Initial splash screen
    │
    ├── Authentication/
    │   ├── WelcomePageView.swift         # Sign in or register selection
    │   └── SignInView.swift              # Existing user login
    │
    ├── Registration/
    │   ├── RegisterTypeSelectionView.swift   # Family Admin vs General User
    │   ├── FamilyAdmin/
    │   │   └── FamilyAdminRegistrationFlow.swift
    │   └── GeneralUser/
    │       └── GeneralUserRegistrationFlow.swift
    │
    ├── FamilySetup/
    │   └── FamilySetupNavigationView.swift   # Create or join family (post-auth)
    │
    └── Home/
        └── HomePageView.swift            # Main app with tabs
            ├── HomeTab                    # Feed and posts
            ├── CalendarTab                # Events calendar
            ├── FamilyTab                  # Family members and invites
            └── ProfileTab                 # User profile and settings
```

## Key Features by Page

### 1. Launch Screen
- Displays app logo and name
- Animated appearance
- Auto-transitions to Welcome Page after 2 seconds

### 2. Welcome Page
- **Sign In Button**: Opens sheet with email/password login
- **Register Button**: Opens sheet to choose registration type

### 3. Registration Flows

#### Family Admin Registration (3 Steps):
1. **Personal Info**: Name, email, password
2. **Family Creation**: Enter family name
3. **Review & Complete**: Shows generated invite code to share with family members

#### General User Registration (3 Steps):
1. **Personal Info**: Name, email, password
2. **Invite Code Entry**: Enter 6-character code from family admin
3. **Review & Complete**: Confirm joining the family

### 4. Family Setup (shown if authenticated but no family)
- **Create Family**: Start a new family as admin
- **Join Family**: Enter invite code to join existing family

### 5. Home Page (4 Tabs)

#### Home Tab
- Family header with name and welcome message
- Quick stats (members, events, posts)
- Post composer
- Family feed with all posts

#### Calendar Tab
- Graphical date picker
- Events list for selected day
- Add event button

#### Family Tab
- Family overview
- Members list with roles
- Invite new members button
- Pending invites

#### Profile Tab
- User information
- Settings and notifications links
- Sign out

## Data Models

### User
```swift
struct User {
    let id: String
    var name: String
    var email: String
    var familyId: String?
    var role: MemberRole?  // .admin, .owner, .member
}
```

### Family
```swift
struct Family {
    let id: String
    var name: String
    var members: [User]
}
```

### FamilyEvent
```swift
struct FamilyEvent {
    let id: String
    var title: String
    var date: Date
    var createdBy: String
}
```

### FamilyPost
```swift
struct FamilyPost {
    let id: String
    var authorName: String
    var content: String
    var timestamp: Date
}
```

## State Management

The app uses `AppState` as an `@ObservableObject` that manages:
- Current user authentication status
- Current user data
- Current family data
- Events and posts
- Pending invites

## Authentication Flow

1. User launches app → Launch Screen
2. Launch Screen → Welcome Page
3. User chooses Sign In or Register
4. After successful auth:
   - If has family → Home Page
   - If no family → Family Setup
5. After family setup → Home Page

## User Roles

- **Admin**: Can create family, generate invite codes, manage members
- **Member**: Can join family with invite code, participate in posts/events
- **Owner**: Original family creator (future use)

## Navigation Patterns

- **Sheets**: Used for sign in and registration flows (dismissible)
- **Full Screen Covers**: Used for complete registration flows
- **Navigation Stack**: Used for in-app navigation
- **Tab View**: Main app navigation with 4 tabs

## Design Patterns

- **SwiftUI**: Modern declarative UI
- **Swift Concurrency**: async/await for async operations
- **Environment Objects**: AppState shared across views
- **MVVM-like**: Views + State objects for logic
- **Protocol-based Auth**: Supports Firebase and stub implementations

## Future Enhancements

- [ ] Photo sharing
- [ ] Task/chore management
- [ ] Shopping lists
- [ ] Location sharing
- [ ] Push notifications
- [ ] Real-time synchronization with Firebase
- [ ] Profile pictures
- [ ] Event reminders
- [ ] Family chat
- [ ] Document storage

## Firebase Integration

The app uses Firebase for:
- User authentication (Email/Password)
- Future: Firestore for data persistence
- Future: Cloud Storage for photos
- Future: Cloud Messaging for notifications

## Testing

The app includes stub implementations for:
- `StubAuthService`: In-memory authentication for testing
- Mock data in previews for all views

## Notes

- All file paths use organized folder structure
- Consistent naming conventions (ViewName + "View.swift")
- Comprehensive error handling in auth flows
- Accessibility considerations with semantic labels
- Responsive design for different screen sizes
