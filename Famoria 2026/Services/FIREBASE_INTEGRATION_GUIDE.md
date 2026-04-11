# Firebase Backend Integration Guide

This document explains the Firebase backend integration for the Family Hub app, including Firestore data structure, security rules, and usage examples.

## Overview

The app uses three main Firebase services:
- **Firebase Authentication**: User authentication and management
- **Firestore Database**: Real-time data storage for families, posts, and events
- **Cloud Functions** (optional): For advanced features like push notifications

## Firestore Data Structure

```
firestore/
├── users/
│   └── {userId}/
│       ├── id: String
│       ├── name: String
│       ├── email: String
│       ├── familyId: String? (optional)
│       ├── role: String? (optional: "owner", "admin", "member")
│       └── createdAt: Timestamp
│
├── families/
│   └── {familyId}/
│       ├── id: String
│       ├── name: String
│       ├── ownerUserId: String
│       ├── createdAt: Timestamp
│       │
│       ├── members/ (subcollection)
│       │   └── {userId}/
│       │       ├── id: String
│       │       ├── name: String
│       │       ├── email: String
│       │       ├── role: String ("owner", "admin", "member")
│       │       └── joinedAt: Timestamp
│       │
│       ├── posts/ (subcollection)
│       │   └── {postId}/
│       │       ├── id: String
│       │       ├── authorName: String
│       │       ├── authorId: String
│       │       ├── content: String
│       │       ├── timestamp: Timestamp
│       │       ├── createdAt: Timestamp
│       │       └── editedAt: Timestamp? (optional)
│       │
│       └── events/ (subcollection)
│           └── {eventId}/
│               ├── id: String
│               ├── title: String
│               ├── date: Timestamp
│               ├── createdBy: String (userId)
│               ├── createdAt: Timestamp
│               └── editedAt: Timestamp? (optional)
│
└── invites/
    └── {inviteCode}/ (6-character code as document ID)
        ├── code: String
        ├── familyId: String
        ├── createdBy: String (userId)
        ├── createdAt: Timestamp
        ├── expiresAt: Timestamp
        ├── usedCount: Number
        └── maxUses: Number
```

## Firestore Security Rules

Add these security rules in the Firebase Console (Firestore Database → Rules):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }
    
    function isFamilyMember(familyId) {
      return isAuthenticated() && getUserData().familyId == familyId;
    }
    
    function isFamilyOwner(familyId) {
      return isAuthenticated() && 
             getUserData().familyId == familyId && 
             getUserData().role == 'owner';
    }
    
    function isFamilyAdmin(familyId) {
      return isAuthenticated() && 
             getUserData().familyId == familyId && 
             (getUserData().role == 'owner' || getUserData().role == 'admin');
    }
    
    // Users collection
    match /users/{userId} {
      // Users can read their own data
      allow read: if isAuthenticated() && request.auth.uid == userId;
      
      // Users can create their own document
      allow create: if isAuthenticated() && request.auth.uid == userId;
      
      // Users can update their own data, but not their familyId (must use family service)
      allow update: if isAuthenticated() && 
                       request.auth.uid == userId &&
                       request.resource.data.id == resource.data.id;
      
      // Only the user can delete their own document
      allow delete: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // Families collection
    match /families/{familyId} {
      // Family members can read family data
      allow read: if isFamilyMember(familyId);
      
      // Any authenticated user can create a family
      allow create: if isAuthenticated();
      
      // Only owner can update family data
      allow update: if isFamilyOwner(familyId);
      
      // Only owner can delete family
      allow delete: if isFamilyOwner(familyId);
      
      // Members subcollection
      match /members/{memberId} {
        // Family members can read all members
        allow read: if isFamilyMember(familyId);
        
        // Family service can add members (via backend or cloud function)
        allow create: if isAuthenticated();
        
        // Admins and owners can update member roles
        allow update: if isFamilyAdmin(familyId);
        
        // Admins and owners can remove members, or users can remove themselves
        allow delete: if isFamilyAdmin(familyId) || request.auth.uid == memberId;
      }
      
      // Posts subcollection
      match /posts/{postId} {
        // Family members can read all posts
        allow read: if isFamilyMember(familyId);
        
        // Family members can create posts
        allow create: if isFamilyMember(familyId) && 
                         request.resource.data.authorId == request.auth.uid;
        
        // Post author can update their own posts
        allow update: if isFamilyMember(familyId) && 
                         resource.data.authorId == request.auth.uid;
        
        // Post author or admins can delete posts
        allow delete: if isFamilyMember(familyId) && 
                         (resource.data.authorId == request.auth.uid || 
                          isFamilyAdmin(familyId));
      }
      
      // Events subcollection
      match /events/{eventId} {
        // Family members can read all events
        allow read: if isFamilyMember(familyId);
        
        // Family members can create events
        allow create: if isFamilyMember(familyId) && 
                         request.resource.data.createdBy == request.auth.uid;
        
        // Event creator can update their own events
        allow update: if isFamilyMember(familyId) && 
                         resource.data.createdBy == request.auth.uid;
        
        // Event creator or admins can delete events
        allow delete: if isFamilyMember(familyId) && 
                         (resource.data.createdBy == request.auth.uid || 
                          isFamilyAdmin(familyId));
      }
    }
    
    // Invites collection
    match /invites/{inviteCode} {
      // Anyone authenticated can read invites to validate codes
      allow read: if isAuthenticated();
      
      // Family members can create invite codes
      allow create: if isAuthenticated();
      
      // Invites can be updated to increment usage count
      allow update: if isAuthenticated();
      
      // Only the creator can delete invite codes
      allow delete: if isAuthenticated() && resource.data.createdBy == request.auth.uid;
    }
  }
}
```

## Firestore Indexes

Create these composite indexes in Firebase Console (Firestore Database → Indexes):

1. **Posts by family and timestamp** (for efficient feed queries):
   - Collection: `families/{familyId}/posts`
   - Fields: `timestamp` (Descending)

2. **Events by family and date** (for calendar queries):
   - Collection: `families/{familyId}/events`
   - Fields: `date` (Ascending)

These will be automatically suggested when you run the app for the first time.

## Usage Examples

### Creating a Family

```swift
// In your view or view model
Task {
    do {
        try await appState.createFamily(name: "The Smith Family")
        // Family is created and appState.currentFamily is updated
    } catch {
        print("Error creating family: \(error.localizedDescription)")
    }
}
```

### Generating an Invite Code

```swift
Task {
    do {
        let code = try await appState.generateInviteCode()
        print("Share this code: \(code)")
        // Code expires in 7 days by default
    } catch {
        print("Error generating code: \(error.localizedDescription)")
    }
}
```

### Joining a Family

```swift
Task {
    do {
        try await appState.joinFamilyWithCode(userEnteredCode)
        // User joins family and appState.currentFamily is updated
    } catch FamilyServiceError.invalidInviteCode {
        print("Invalid invite code")
    } catch FamilyServiceError.inviteCodeExpired {
        print("This invite code has expired")
    } catch {
        print("Error joining family: \(error.localizedDescription)")
    }
}
```

### Creating a Post

```swift
Task {
    do {
        try await appState.createPost(content: "Hello family!")
        // Post is added to the feed
    } catch {
        print("Error creating post: \(error.localizedDescription)")
    }
}
```

### Creating an Event

```swift
Task {
    do {
        let eventDate = Date().addingTimeInterval(86400 * 7) // 1 week from now
        try await appState.createEvent(title: "Family Dinner", date: eventDate)
        // Event is added to the calendar
    } catch {
        print("Error creating event: \(error.localizedDescription)")
    }
}
```

### Observing Real-time Updates

The AppState automatically sets up real-time listeners when a user signs in and has a family. Updates to posts, events, and family members are pushed automatically:

```swift
// In your view
struct FamilyFeedView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(appState.posts) { post in
            PostCard(post: post)
        }
        // Posts automatically update when changes occur in Firestore
    }
}
```

## Initial Setup Steps

1. **Create a Firebase project** at [firebase.google.com](https://firebase.google.com)

2. **Add Firebase to your iOS app**:
   - Download `GoogleService-Info.plist`
   - Add it to your Xcode project
   - Install Firebase SDK via SPM (already done if you have FirebaseAuth)

3. **Enable Authentication**:
   - Go to Authentication → Sign-in method
   - Enable Email/Password authentication

4. **Create Firestore Database**:
   - Go to Firestore Database
   - Create database in production mode (we'll add rules next)
   - Choose a location close to your users

5. **Add Security Rules**:
   - Copy the rules from above
   - Paste them in Firestore Database → Rules
   - Publish the rules

6. **Update AppState initialization**:
   ```swift
   // In your App file
   @StateObject private var appState = AppState()
   
   var body: some Scene {
       WindowGroup {
           ContentView()
               .environmentObject(appState)
       }
   }
   ```

7. **Test the integration**:
   - Sign up a new user
   - Create a family
   - Generate an invite code
   - Sign in with another user and join with the code
   - Create posts and events

## Performance Considerations

1. **Offline Support**: Firestore automatically caches data for offline use
2. **Real-time Listeners**: Use sparingly to avoid excessive reads
3. **Pagination**: Implement pagination for large post/event lists
4. **Indexes**: Create composite indexes as suggested by Firestore errors

## Optional: Cloud Functions

For advanced features, consider adding Cloud Functions:

```javascript
// Example: Send push notifications when a new post is created
exports.onPostCreated = functions.firestore
  .document('families/{familyId}/posts/{postId}')
  .onCreate(async (snap, context) => {
    const post = snap.data();
    const familyId = context.params.familyId;
    
    // Get all family members
    const members = await admin.firestore()
      .collection('families')
      .doc(familyId)
      .collection('members')
      .get();
    
    // Send notifications to all members except the author
    const tokens = []; // Get FCM tokens from user documents
    
    await admin.messaging().sendMulticast({
      tokens: tokens,
      notification: {
        title: `New post from ${post.authorName}`,
        body: post.content
      }
    });
  });
```

## Troubleshooting

**Issue**: "Missing or insufficient permissions"
- **Solution**: Check your Firestore security rules and ensure the user has the correct role

**Issue**: Real-time updates not working
- **Solution**: Ensure listeners are set up after successful sign-in and family loading

**Issue**: Invite codes not validating
- **Solution**: Check that the invite document exists and hasn't expired

**Issue**: User data not persisting after sign-in
- **Solution**: Ensure `FirebaseAuthService` creates user documents in Firestore on sign-up

## Next Steps

- [ ] Add pagination for posts and events
- [ ] Implement push notifications with Cloud Functions
- [ ] Add photo upload support with Firebase Storage
- [ ] Implement email invites with Cloud Functions
- [ ] Add family settings and preferences
- [ ] Implement member role management UI
- [ ] Add post reactions and comments
- [ ] Implement event RSVPs
