# Famoria 2026 - Visual Flow Diagram

## Complete User Journey Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                                  │
│                    Famoria_2026App.swift                            │
│                  Creates AppState & RootView                        │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │      RootView         │
                    │  (Navigation Router)  │
                    └───────┬───────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
    [showLaunch=true] [isAuth=false] [isAuth=true]
            │               │               │
            ▼               ▼               └──────┐
    ┌──────────────┐  ┌──────────────┐            │
    │ Launch       │  │ Welcome      │            │
    │ Screen       │  │ Page         │            │
    │ (2 seconds)  │  │              │            │
    └──────┬───────┘  └──────┬───────┘            │
           │                 │                     │
           │        ┌────────┴────────┐            │
           │        │                 │            │
           │        ▼                 ▼            │
           │  ┌──────────┐     ┌──────────┐       │
           │  │ Sign In  │     │ Register │       │
           │  │  Sheet   │     │  Sheet   │       │
           │  └────┬─────┘     └────┬─────┘       │
           │       │                │              │
           │       │        ┌───────┴───────┐      │
           │       │        │               │      │
           │       │        ▼               ▼      │
           │       │  ┌──────────┐   ┌──────────┐ │
           │       │  │  Family  │   │ General  │ │
           │       │  │  Admin   │   │   User   │ │
           │       │  │   Flow   │   │   Flow   │ │
           │       │  └────┬─────┘   └────┬─────┘ │
           │       │       │              │       │
           │       │       │    ┌─────────┘       │
           │       │       │    │                 │
           │       │       ▼    ▼                 │
           │       │  [User Created]              │
           │       │       │                      │
           └───────┴───────┴──────────────────────┘
                           │
                           ▼
                  [Check if has family?]
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
         [No Family]            [Has Family]
                │                     │
                ▼                     │
      ┌─────────────────┐             │
      │ Family Setup    │             │
      │ Navigation View │             │
      └────────┬────────┘             │
               │                      │
      ┌────────┴────────┐             │
      │                 │             │
      ▼                 ▼             │
┌──────────┐      ┌──────────┐        │
│ Create   │      │  Join    │        │
│ Family   │      │ Family   │        │
└────┬─────┘      └────┬─────┘        │
     │                 │              │
     └────────┬────────┘              │
              │                       │
              ▼                       │
      [Family Assigned]               │
              │                       │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │    HOME PAGE VIEW     │
              │   (TabView with 4)    │
              └───────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
    ┌─────────┐      ┌─────────┐     ┌─────────┐
    │  Home   │      │Calendar │     │ Family  │
    │   Tab   │      │   Tab   │     │   Tab   │
    └─────────┘      └─────────┘     └─────────┘
         │
         ▼
    ┌─────────┐
    │ Profile │
    │   Tab   │
    └────┬────┘
         │
         ▼ [Sign Out]
    [Back to Welcome Page]
```

## Registration Flow Details

### Family Admin Registration Flow
```
Step 1: Personal Info              Step 2: Family Info            Step 3: Review & Complete
┌─────────────────────┐           ┌─────────────────────┐        ┌─────────────────────┐
│ • Full Name         │           │ • Family Name       │        │ • Review Details    │
│ • Email             │  ──Next──▶│                     │ ──Next─▶│ • See Invite Code   │
│ • Password          │           │ "The Smith Family"  │        │   [ABC123]          │
│ • Confirm Password  │           │                     │        │ • Copy & Share      │
└─────────────────────┘           └─────────────────────┘        └──────────┬──────────┘
                                                                             │
                                                                             ▼
                                                                       [Complete]
                                                                             │
                                                                             ▼
                                                                      [Home Page]
```

### General User Registration Flow
```
Step 1: Personal Info              Step 2: Invite Code            Step 3: Review & Complete
┌─────────────────────┐           ┌─────────────────────┐        ┌─────────────────────┐
│ • Full Name         │           │ • Enter Code        │        │ • Review Details    │
│ • Email             │  ──Next──▶│   [ABC123]          │ ──Next─▶│ • Joining:          │
│ • Password          │           │                     │        │   "The Smith Family"│
│ • Confirm Password  │           │ ✓ Code Valid!       │        │                     │
└─────────────────────┘           └─────────────────────┘        └──────────┬──────────┘
                                                                             │
                                                                             ▼
                                                                       [Complete]
                                                                             │
                                                                             ▼
                                                                      [Home Page]
```

## Home Page Structure

```
┌─────────────────────────────────────────────────────────────┐
│                       HOME PAGE                             │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ TabView (Bottom Navigation)                           │  │
│  │                                                       │  │
│  │  ┌──────────┬──────────┬──────────┬──────────┐      │  │
│  │  │  Home    │ Calendar │  Family  │ Profile  │      │  │
│  │  │  🏠      │    📅    │    👥    │    👤    │      │  │
│  │  └──────────┴──────────┴──────────┴──────────┘      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Home Tab Layout
```
┌─────────────────────────────────────────┐
│  The Smith Family                    🏠 │
│  Welcome, John!                         │
├─────────────────────────────────────────┤
│  ┌───────┐  ┌───────┐  ┌───────┐      │
│  │  👥   │  │  📅   │  │  💬   │      │
│  │   5   │  │   3   │  │  12   │      │
│  │Members│  │Events │  │Posts  │      │
│  └───────┘  └───────┘  └───────┘      │
├─────────────────────────────────────────┤
│  ┌────────────────────────────┐ ✈️    │
│  │ Share something...         │       │
│  └────────────────────────────┘       │
├─────────────────────────────────────────┤
│  Feed Posts:                           │
│  ┌─────────────────────────────────┐   │
│  │ 👤 Jane Doe                     │   │
│  │ 2 hours ago                     │   │
│  │                                 │   │
│  │ Can't wait for dinner tonight!  │   │
│  │                                 │   │
│  │ ❤️ Like  💬 Comment             │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ 👤 John Doe                     │   │
│  │ 5 hours ago                     │   │
│  │                                 │   │
│  │ Great family game night!        │   │
│  │                                 │   │
│  │ ❤️ Like  💬 Comment             │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Calendar Tab Layout
```
┌─────────────────────────────────────────┐
│  Calendar                            ➕  │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐   │
│  │      April 2026                 │   │
│  │  S  M  T  W  T  F  S           │   │
│  │        1  2  3  4  5           │   │
│  │  6  7  8  9 10 11 12           │   │
│  │ 13 14 15 16 17 18 19           │   │
│  │ 20 21 22 23 24 25 26           │   │
│  │ 27 28 29 30                    │   │
│  └─────────────────────────────────┘   │
├─────────────────────────────────────────┤
│  Events for Apr 3:                     │
│  ┌─────────────────────────────────┐   │
│  │ Family Dinner                   │   │
│  │ 🕐 6:00 PM · by John            │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ Movie Night                     │   │
│  │ 🕐 8:00 PM · by Jane            │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Family Tab Layout
```
┌─────────────────────────────────────────┐
│  Family                                 │
├─────────────────────────────────────────┤
│  The Smith Family                    ➕ │
│  5 members                              │
├─────────────────────────────────────────┤
│  Members:                               │
│  ┌─────────────────────────────────┐   │
│  │ 👤 John Doe                     │   │
│  │    john@email.com               │   │
│  │                          [Admin]│   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ 👤 Jane Doe                     │   │
│  │    jane@email.com               │   │
│  │                         [Member]│   │
│  └─────────────────────────────────┘   │
├─────────────────────────────────────────┤
│  Pending Invites:                       │
│  ┌─────────────────────────────────┐   │
│  │ The Johnson Family              │   │
│  │ invite@email.com                │   │
│  │                        [Accept] │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Profile Tab Layout
```
┌─────────────────────────────────────────┐
│  Profile                                │
├─────────────────────────────────────────┤
│  👤                                     │
│                                         │
│  John Doe                               │
│  john@email.com                         │
│  [Admin]                                │
├─────────────────────────────────────────┤
│  Account                                │
│  ⚙️  Settings                    ›      │
│  🔔  Notifications               ›      │
├─────────────────────────────────────────┤
│  🚪 Sign Out                            │
└─────────────────────────────────────────┘
```

## State Management Flow

```
┌─────────────────────────────────────────┐
│           AppState                      │
│  (@ObservableObject / @MainActor)       │
├─────────────────────────────────────────┤
│  @Published Properties:                 │
│  • currentUser: User?                   │
│  • currentFamily: Family?               │
│  • isAuthenticated: Bool                │
│  • pendingInvites: [Invite]             │
│  • events: [FamilyEvent]                │
│  • posts: [FamilyPost]                  │
├─────────────────────────────────────────┤
│  Methods:                               │
│  • handleSignIn()                       │
│  • handleSignUp()                       │
│  • signOut()                            │
│  • createInvite()                       │
│  • accept(invite:)                      │
│  • remove(member:)                      │
└─────────────────────────────────────────┘
          │
          │ Injected via @EnvironmentObject
          │
          ▼
┌─────────────────────────────────────────┐
│         All Views                       │
│  @EnvironmentObject var appState        │
└─────────────────────────────────────────┘
```

## File Dependencies

```
Famoria_2026App.swift
    │
    ├──▶ AppState.swift
    │       └──▶ FirebaseAuthService.swift
    │       └──▶ Models.swift
    │
    └──▶ RootView.swift
            │
            ├──▶ LaunchScreen.swift
            │
            ├──▶ WelcomePageView.swift
            │       ├──▶ SignInView.swift
            │       └──▶ RegisterTypeSelectionView.swift
            │               ├──▶ FamilyAdminRegistrationFlow.swift
            │               └──▶ GeneralUserRegistrationFlow.swift
            │
            ├──▶ FamilySetupNavigationView.swift
            │
            └──▶ HomePageView.swift
                    ├──▶ AddEventView.swift
                    ├──▶ FamilyCalendarView.swift
                    ├──▶ FamilyFeedView.swift
                    ├──▶ InviteComposer.swift
                    └──▶ FeedCard.swift
```

## Data Flow Example: Creating a Post

```
1. User types in PostComposerView
   ↓
2. User taps send button
   ↓
3. addPost() function creates FamilyPost
   ↓
4. appState.posts.append(post)
   ↓
5. @Published property updates
   ↓
6. SwiftUI auto-refreshes all views using appState.posts
   ↓
7. FeedCard displays new post in feed
```

## Navigation Patterns Used

### Sheet (Modal)
```swift
.sheet(isPresented: $showSheet) {
    DetailView()
}
```
**Used for**: Sign In, Invites, Add Event

### Full Screen Cover
```swift
.fullScreenCover(isPresented: $showCover) {
    OnboardingView()
}
```
**Used for**: Registration flows

### Navigation Link
```swift
NavigationLink("Title") {
    DetailView()
}
```
**Used for**: Settings, Notifications

### Tab View
```swift
TabView {
    Tab1().tabItem { Label("Tab 1", systemImage: "icon") }
    Tab2().tabItem { Label("Tab 2", systemImage: "icon") }
}
```
**Used for**: Main app navigation

---

This visual guide should help you understand the complete structure and flow of your reorganized app!
