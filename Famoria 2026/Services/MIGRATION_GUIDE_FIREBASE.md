# Migration Guide: From Stub Data to Firebase

This guide helps you transition from in-memory/stub data to the Firebase backend.

## 📋 Pre-Migration Checklist

Before making any changes:

- [ ] Backup your current code
- [ ] Create a new Git branch: `git checkout -b firebase-backend`
- [ ] Firebase project set up and configured
- [ ] `GoogleService-Info.plist` added to Xcode project
- [ ] Firestore security rules deployed
- [ ] Email/Password authentication enabled

## 🔄 Migration Steps

### Step 1: Update AppState Service Reference

**Before:**
```swift
var auth: AuthService = StubAuthService()
```

**After:**
```swift
var auth: AuthService = FirebaseAuthService()
private let familyService = FirebaseFamilyService()
private let contentService = FirebaseContentService()
```

**Status:** ✅ Already done in AppState.swift

---

### Step 2: Replace Family Creation Logic

**Find code that looks like:**
```swift
// Old code
appState.currentFamily = Family(
    id: UUID().uuidString,
    name: familyName,
    members: [currentUser]
)
```

**Replace with:**
```swift
// New code
Task {
    do {
        try await appState.createFamily(name: familyName)
        // Success! Family is created in Firebase
    } catch {
        // Handle error
        errorMessage = error.localizedDescription
    }
}
```

**Files to check:**
- `ViewsRegistrationFamilyAdminFamilyAdminRegistrationFlow.swift`
- Any view with "Create Family" button

---

### Step 3: Replace Invite Code Generation

**Find code that looks like:**
```swift
// Old code
let invite = Invite(
    id: UUID().uuidString,
    familyId: family.id,
    familyName: family.name,
    invitedEmail: email
)
pendingInvites.append(invite)
```

**Replace with:**
```swift
// New code
Task {
    do {
        let code = try await appState.generateInviteCode()
        // Display code to user
        displayCode = code
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**Files to check:**
- `ViewsFamilySetupFamilySetupNavigationView.swift`
- Any invite management views

---

### Step 4: Replace Join Family Logic

**Find code that looks like:**
```swift
// Old code - synthetic invite acceptance
if let invite = pendingInvites.first(where: { $0.id == id }) {
    accept(invite: invite)
}
```

**Replace with:**
```swift
// New code - real Firebase validation and joining
@State private var inviteCode = ""
@State private var isJoining = false
@State private var error: Error?

TextField("Invite Code", text: $inviteCode)
    .textInputAutocapitalization(.characters)
    .onChange(of: inviteCode) { _, newValue in
        inviteCode = String(newValue.uppercased().prefix(6))
    }

Button("Join Family") {
    Task {
        do {
            isJoining = true
            try await appState.joinFamilyWithCode(inviteCode)
            // Success - navigate to home
        } catch {
            self.error = error
            isJoining = false
        }
    }
}
.disabled(inviteCode.count != 6 || isJoining)
```

**Files to check:**
- `ViewsRegistrationGeneralUserGeneralUserRegistrationFlow.swift`
- Any join family views

---

### Step 5: Update Post Display

**Before (if using mock data):**
```swift
// Mock posts
let mockPosts = [
    FamilyPost(id: "1", authorName: "John", content: "Test", timestamp: Date())
]

ForEach(mockPosts) { post in
    PostCard(post: post)
}
```

**After:**
```swift
// Real Firebase data
@EnvironmentObject var appState: AppState

ForEach(appState.posts) { post in
    PostCard(post: post)
}
// Posts update automatically in real-time!
```

**Files to check:**
- `ViewsHomeHomePageView.swift`
- `FamilyFeedView.swift`
- Any post display views

---

### Step 6: Update Post Creation

**Before:**
```swift
// Old code - in-memory
let newPost = FamilyPost(
    id: UUID().uuidString,
    authorName: currentUser.name,
    content: content,
    timestamp: Date()
)
posts.append(newPost)
```

**After:**
```swift
// New code - Firebase
@State private var content = ""
@State private var isPosting = false

Button("Post") {
    Task {
        do {
            isPosting = true
            try await appState.createPost(content: content)
            // Success - post appears automatically
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isPosting = false
        }
    }
}
.disabled(content.isEmpty || isPosting)
```

---

### Step 7: Update Event Display and Creation

**Before:**
```swift
// Mock events
let mockEvents = [
    FamilyEvent(id: "1", title: "Dinner", date: Date(), createdBy: "1")
]
```

**After:**
```swift
// Real Firebase events
@EnvironmentObject var appState: AppState

ForEach(appState.events) { event in
    EventCard(event: event)
}

// Create event
Button("Create Event") {
    Task {
        try await appState.createEvent(title: title, date: date)
    }
}
```

---

### Step 8: Update Delete Operations

**Before:**
```swift
// Old code - in-memory
posts.removeAll { $0.id == postId }
```

**After:**
```swift
// New code - Firebase with optimistic UI
Task {
    do {
        try await appState.deletePost(post)
        // Post removed from UI automatically
    } catch {
        print("Error deleting post: \(error)")
    }
}
```

---

### Step 9: Add Real-time Listener Management

**No code to replace** - This is automatically handled in AppState!

When user signs in:
```swift
try await appState.handleSignIn(email: email, password: password)
// ↓ Automatically loads family data if user has one
// ↓ Automatically starts real-time listeners
// ↓ Posts, events, members update live!
```

---

### Step 10: Update Sign Out Logic

**Before:**
```swift
func signOut() {
    currentUser = nil
    currentFamily = nil
    isAuthenticated = false
}
```

**After:**
```swift
// This is already done in AppState!
await appState.signOut()
// Automatically:
// - Signs out of Firebase Auth
// - Clears all data
// - Removes all listeners
// - Resets authentication state
```

---

## 🔍 Finding Code to Update

### Search Patterns

Use Xcode's Find in Project (Cmd+Shift+F) to search for:

1. **Mock/Stub Data**
   - Search: `UUID().uuidString`
   - Search: `mock` or `Mock`
   - Search: `stub` or `Stub`
   - Search: `= []` (empty array initializations)

2. **Direct State Modifications**
   - Search: `appState.posts.append`
   - Search: `appState.events.append`
   - Search: `appState.currentFamily =`
   - Search: `.removeAll`

3. **Invite Logic**
   - Search: `Invite(`
   - Search: `pendingInvites`
   - Search: `accept(invite:`

4. **Family Creation**
   - Search: `Family(id: UUID`
   - Search: `Family(id:"`

---

## ✅ Verification Checklist

After migration, verify each feature:

### Authentication
- [ ] Sign up creates user in Firebase Auth
- [ ] Sign up creates user document in Firestore
- [ ] Sign in loads user data from Firestore
- [ ] Sign in loads family data if user has one
- [ ] Sign out clears all data and stops listeners

### Family Management
- [ ] Create family writes to Firestore
- [ ] Create family sets current user as owner
- [ ] Family data persists after app restart
- [ ] Family members list shows all members

### Invite Codes
- [ ] Generate code creates invite document
- [ ] Code is 6 characters, uppercase, readable
- [ ] Invalid code shows error
- [ ] Expired code shows error
- [ ] Valid code allows joining
- [ ] Joining adds user to family
- [ ] Joining updates user's familyId

### Posts
- [ ] Create post writes to Firestore
- [ ] Post appears immediately (optimistic UI)
- [ ] Post appears on other devices (real-time)
- [ ] Posts sorted by timestamp (newest first)
- [ ] Delete post removes from Firestore
- [ ] Delete post updates UI immediately

### Events
- [ ] Create event writes to Firestore
- [ ] Event appears on all devices
- [ ] Events sorted by date
- [ ] Delete event works correctly
- [ ] Past events can be filtered (optional)

### Real-time Updates
- [ ] New post on device A appears on device B
- [ ] New event on device A appears on device B
- [ ] New member appears for all family members
- [ ] Deleted content disappears for all users

---

## 🐛 Common Migration Issues

### Issue 1: Data Not Persisting

**Symptom:** Data disappears after app restart

**Cause:** Still using in-memory data structures

**Solution:**
```swift
// Find code like this:
@Published var posts: [FamilyPost] = []

// This is correct! But ensure you're using:
try await appState.createPost(content: content)
// NOT:
appState.posts.append(newPost)
```

---

### Issue 2: Real-time Updates Not Working

**Symptom:** Changes on one device don't appear on another

**Cause:** Listeners not started

**Solution:**
Check that after sign-in, if user has a family:
```swift
if let familyId = user.familyId {
    await loadFamilyData(familyId: familyId)
}
// This should happen automatically in AppState.handleSignIn()
```

---

### Issue 3: Permission Denied Errors

**Symptom:** Firestore operations fail with permission errors

**Cause:** Security rules not deployed or incorrect

**Solution:**
1. Open Firebase Console
2. Go to Firestore Database → Rules
3. Copy rules from `FIREBASE_INTEGRATION_GUIDE.md`
4. Publish rules

---

### Issue 4: Invite Codes Not Working

**Symptom:** Valid code shows as invalid

**Cause:** Code not in Firestore or expired

**Solution:**
```swift
// Check code generation:
let code = try await appState.generateInviteCode()
print("Generated code: \(code)")

// Check in Firestore Console:
// invites collection → {CODE} document should exist
```

---

### Issue 5: User Data Not Loading

**Symptom:** User has familyId but family data doesn't load

**Cause:** Listener not started or family doesn't exist

**Solution:**
```swift
// After sign in, AppState should call:
if let familyId = user.familyId {
    await loadFamilyData(familyId: familyId)
}

// Verify this happens in AppState.handleSignIn()
```

---

## 🧪 Testing Your Migration

### Manual Testing Flow

1. **Clean Install Test**
   ```
   - Delete app from device/simulator
   - Clean build folder (Cmd+Shift+K)
   - Build and run
   - Sign up new user
   - Create family
   - Generate invite code
   - Verify code in Firestore Console
   ```

2. **Multi-Device Test**
   ```
   Device 1:
   - Sign up as user A
   - Create family
   - Generate invite code: XYZ123
   - Create a post
   
   Device 2:
   - Sign up as user B
   - Join with code: XYZ123
   - Verify post from user A appears
   - Create own post
   
   Device 1:
   - Verify post from user B appears
   ```

3. **Persistence Test**
   ```
   - Sign in
   - Create family, posts, events
   - Force quit app
   - Relaunch app
   - Sign in
   - Verify all data still exists
   ```

4. **Real-time Test**
   ```
   - Open app on two devices with same user
   - Create post on device 1
   - Verify it appears on device 2 within 1-2 seconds
   ```

---

## 📊 Migration Progress Tracker

Use this checklist to track your migration:

### Files Updated
- [ ] AppState.swift ✅ (already done)
- [ ] Main App file (add @EnvironmentObject)
- [ ] FamilyAdminRegistrationFlow.swift
- [ ] GeneralUserRegistrationFlow.swift
- [ ] FamilySetupNavigationView.swift
- [ ] HomePageView.swift
- [ ] FeedView.swift (if separate)
- [ ] EventsView.swift (if separate)
- [ ] Any custom post/event creation views

### Features Migrated
- [ ] User authentication
- [ ] Family creation
- [ ] Invite code generation
- [ ] Invite code validation
- [ ] Join family
- [ ] Post creation
- [ ] Post display
- [ ] Post deletion
- [ ] Event creation
- [ ] Event display
- [ ] Event deletion
- [ ] Member list display
- [ ] Member removal

### Testing Completed
- [ ] Sign up flow
- [ ] Sign in flow
- [ ] Create family flow
- [ ] Generate invite code
- [ ] Join with invite code
- [ ] Create posts
- [ ] Delete posts
- [ ] Create events
- [ ] Delete events
- [ ] Real-time updates
- [ ] Multi-device sync
- [ ] Persistence across restarts
- [ ] Error handling
- [ ] Sign out

---

## 🎉 Post-Migration

### Cleanup Tasks

1. **Remove unused code**
   ```swift
   // You can now remove:
   // - StubAuthService (keep if you want for testing)
   // - Any mock data generators
   // - Old invite acceptance logic
   ```

2. **Update documentation**
   - Update README with Firebase setup instructions
   - Document any custom features you added

3. **Add analytics**
   ```swift
   import FirebaseAnalytics
   
   // Track important events
   Analytics.logEvent("family_created", parameters: nil)
   Analytics.logEvent("user_joined_family", parameters: nil)
   ```

4. **Configure for production**
   - Update security rules for production
   - Enable App Check for security
   - Set up Firebase monitoring

---

## 📞 Getting Help

If you encounter issues during migration:

1. **Check Xcode console** for error messages
2. **Check Firebase Console** → Firestore Database → Data
3. **Review security rules** in Firestore Rules tab
4. **Check authentication** in Firebase Console → Authentication
5. **Enable debug logging**:
   ```swift
   FirebaseConfiguration.shared.setLoggerLevel(.debug)
   ```

---

## ✨ You're Done!

Once all checklists are complete, you have:
- ✅ Full Firebase backend integration
- ✅ Real-time data synchronization
- ✅ Persistent data storage
- ✅ Secure access control
- ✅ Production-ready app

**Congratulations!** 🎊 Your app now has a professional, scalable backend!
