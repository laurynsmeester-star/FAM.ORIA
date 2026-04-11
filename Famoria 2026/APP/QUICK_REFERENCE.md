# Quick Reference Guide

## File Organization Checklist

Use this checklist when organizing your Xcode project:

### ✅ Step 1: Create Folder Groups in Xcode

In Xcode, create these folder groups (Right-click → New Group):

```
Famoria_2026
├── 📁 App
├── 📁 Models  
├── 📁 Services
├── 📁 Views
│   ├── 📁 Launch
│   ├── 📁 Authentication
│   ├── 📁 Registration
│   │   ├── 📁 FamilyAdmin
│   │   └── 📁 GeneralUser
│   ├── 📁 FamilySetup
│   ├── 📁 Home
│   └── 📁 Components
└── 📁 Resources
```

### ✅ Step 2: Move Files to Correct Groups

#### App Group
- `Famoria_2026App.swift` ✓ (already updated)

#### Models Group
- `Models.swift` ✓ (keep existing)

#### Services Group
- `AppState.swift` ✓ (updated)
- `FirebaseAuthService.swift` ✓ (keep existing)

#### Views/Launch Group
- `LaunchScreen.swift` ✅ NEW

#### Views/Authentication Group
- `WelcomePageView.swift` ✅ NEW
- `SignInView.swift` ✅ NEW

#### Views/Registration Group
- `RegisterTypeSelectionView.swift` ✅ NEW

#### Views/Registration/FamilyAdmin Group
- `FamilyAdminRegistrationFlow.swift` ✅ NEW

#### Views/Registration/GeneralUser Group
- `GeneralUserRegistrationFlow.swift` ✅ NEW

#### Views/FamilySetup Group
- `FamilySetupNavigationView.swift` ✅ NEW

#### Views/Home Group
- `HomePageView.swift` ✅ NEW

#### Views/Components Group
- `AddEventView.swift` ✓ (move existing)
- `FamilyCalendarView.swift` ✓ (move existing)
- `FamilyFeedView.swift` ✓ (move existing)
- `InviteComposer.swift` ✅ NEW
- `FeedCard.swift` ✅ NEW
- `OnboardingPageView.swift` ✅ NEW

#### Views Root
- `RootView.swift` ✅ NEW

### ✅ Step 3: Archive Old Files

Move these to an "Archive" or "Old" folder (don't delete yet, just in case):
- `welcome page.swift`
- `ContentView.swift`
- `OnboardingPage.swift`
- `MainAppView.swift`
- `FamilySetupView.swift`
- `FamoriaOnboardingCard.swift`

## Quick Test Scenarios

### Test 1: Family Admin Flow
1. Launch app → see launch screen
2. Tap "Register" 
3. Tap "Family Admin"
4. Fill in personal info → Next
5. Enter family name → Next
6. See invite code → Complete
7. Should see Home Page

### Test 2: General User Flow
1. Launch app → see launch screen
2. Tap "Register"
3. Tap "General User"
4. Fill in personal info → Next
5. Enter any 6-character code (e.g., "ABC123")
6. Should validate → Next
7. Review and Complete
8. Should see Home Page

### Test 3: Sign In Flow
1. Launch app
2. Tap "Sign In"
3. Enter credentials (or use stub)
4. Should see Home Page

### Test 4: Home Page Features
1. **Home Tab**:
   - See family name and welcome
   - See stats (members, events, posts)
   - Type a post and send
   - See post appear in feed

2. **Calendar Tab**:
   - Pick a date
   - Tap "+" to add event
   - Fill in event details
   - See event in list

3. **Family Tab**:
   - See family members
   - Tap invite button
   - Enter email and send

4. **Profile Tab**:
   - See user info
   - Tap sign out
   - Should return to Welcome Page

## Component Reuse Guide

### Using FeedCard
```swift
FeedCard(post: yourPost)
```

### Using InviteComposer
```swift
InviteComposer()
    .environmentObject(appState)
```

### Using FormField (in registration flows)
```swift
FormField(
    label: "Email",
    text: $email,
    placeholder: "email@example.com",
    keyboardType: .emailAddress
)
```

### Using StatCard
```swift
StatCard(
    icon: "person.2.fill",
    value: "5",
    label: "Members"
)
```

## Common Customizations

### Change App Colors
In each view, replace `Color.blue` with your brand color:
```swift
// Define in a separate Colors file
extension Color {
    static let familyPrimary = Color(red: 0.2, green: 0.4, blue: 0.8)
    static let familySecondary = Color(red: 0.6, green: 0.3, blue: 0.8)
}
```

### Change Launch Screen Duration
In `RootView.swift`:
```swift
try? await Task.sleep(for: .seconds(2)) // Change to desired duration
```

### Customize Invite Code Length
In registration flows, change from 6 to another number:
```swift
inviteCode = String(newValue.prefix(6).uppercased()) // Change 6
```

### Add More Tabs to Home
In `HomePageView.swift`, add new tab:
```swift
YourNewTab()
    .tabItem {
        Label("Tab Name", systemImage: "icon.name")
    }
```

## Environment Setup

### AppState Injection
Every view that needs AppState must have:
```swift
@EnvironmentObject var appState: AppState
```

And previews need:
```swift
#Preview {
    YourView()
        .environmentObject(AppState())
}
```

### Navigation Patterns

**Sheet (dismissible)**:
```swift
.sheet(isPresented: $showSheet) {
    DetailView()
}
```

**Full Screen Cover**:
```swift
.fullScreenCover(isPresented: $showCover) {
    RegistrationView()
}
```

**Navigation Link**:
```swift
NavigationLink("Details") {
    DetailView()
}
```

## Debugging Tips

### Issue: White screen on launch
**Check**: Is RootView set as root in Famoria_2026App.swift?

### Issue: EnvironmentObject error
**Check**: Is `.environmentObject(appState)` in WindowGroup?

### Issue: Navigation not working
**Check**: Are you inside a NavigationStack?

### Issue: Form not submitting
**Check**: Is validation logic correct? (isFormValid)

### Issue: Data not updating
**Check**: Is property marked with `@State` or `@Published`?

## Firebase Connection Checklist

When ready to connect real Firebase:

- [ ] Add GoogleService-Info.plist to project
- [ ] Enable Email/Password auth in Firebase Console
- [ ] Create Firestore database
- [ ] Add collections: `users`, `families`, `events`, `posts`
- [ ] Update AppState to use FirebaseAuthService instead of StubAuthService
- [ ] Implement loadFamilyData() in AppState
- [ ] Add real-time listeners in observeLiveUpdates()

## Next Features to Add

Priority order:
1. ✅ Complete user authentication flow
2. ✅ Family creation and joining
3. ✅ Basic home page with tabs
4. 🔲 Connect to real Firebase backend
5. 🔲 Photo uploads for posts
6. 🔲 Event notifications
7. 🔲 Task/chore management
8. 🔲 Shopping lists
9. 🔲 Family chat
10. 🔲 Profile pictures

## Support Resources

- **PROJECT_STRUCTURE.md** - Detailed architecture documentation
- **MIGRATION_GUIDE.md** - How files were reorganized
- **This file** - Quick reference for daily development

## Contact

For questions about this structure, refer to the documentation files or review the inline comments in each view file.

---

**Last Updated**: April 3, 2026
**Version**: 1.0
**Author**: Lauryn Smeester
