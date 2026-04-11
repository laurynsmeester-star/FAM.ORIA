# Firebase SDK Installation Guide

## Error: "Unable to resolve module dependency: 'FirebaseFirestore'"

This error means you need to add the Firebase SDK to your Xcode project. Here's how:

## Option 1: Swift Package Manager (Recommended)

### Step 1: Add Firebase Package

1. Open your project in Xcode
2. Go to **File** → **Add Package Dependencies...**
3. In the search bar, paste: `https://github.com/firebase/firebase-ios-sdk`
4. Click **Add Package**

### Step 2: Select Firebase Products

When prompted, select the following packages (checkboxes):

- ✅ **FirebaseAuth** (Required for authentication)
- ✅ **FirebaseFirestore** (Required for database)
- ✅ **FirebaseCore** (Automatically included)

Optional (for future features):
- ⬜ **FirebaseStorage** (for photo uploads)
- ⬜ **FirebaseAnalytics** (for analytics)
- ⬜ **FirebaseMessaging** (for push notifications)

### Step 3: Click Add Package

Xcode will download and integrate the packages. This may take a few minutes.

## Option 2: CocoaPods (Alternative)

If you prefer CocoaPods:

### Step 1: Install CocoaPods

```bash
sudo gem install cocoapods
```

### Step 2: Create Podfile

In your project directory, run:

```bash
pod init
```

### Step 3: Edit Podfile

Open the `Podfile` and add:

```ruby
platform :ios, '16.0'

target 'YourAppName' do
  use_frameworks!

  # Firebase pods
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Core'
end
```

### Step 4: Install Pods

```bash
pod install
```

### Step 5: Open Workspace

From now on, use `YourApp.xcworkspace` instead of `YourApp.xcodeproj`

## Verify Installation

After adding the SDK, verify it works:

1. **Clean Build Folder**: Cmd+Shift+K
2. **Build Project**: Cmd+B
3. Check for errors

The import error should be resolved!

## Next Steps

Once the SDK is installed:

1. ✅ Firebase SDK added to project
2. ⬜ Download `GoogleService-Info.plist` from Firebase Console
3. ⬜ Add `GoogleService-Info.plist` to Xcode project
4. ⬜ Enable Authentication in Firebase Console
5. ⬜ Create Firestore database
6. ⬜ Add security rules

Refer to `FIREBASE_INTEGRATION_GUIDE.md` for the complete setup.

## Common Issues

### Issue: "No such module FirebaseAuth"
**Solution**: Make sure you selected FirebaseAuth when adding the package

### Issue: "Missing package product 'FirebaseFirestore'"
**Solution**: 
1. Go to your target's **Build Phases**
2. Check **Link Binary with Libraries**
3. Add FirebaseFirestore if missing

### Issue: Build succeeds but runtime error
**Solution**: Make sure `GoogleService-Info.plist` is added to your project

### Issue: "FirebaseApp.configure() must be called before..."
**Solution**: This is normal - Firebase is configured in `FirebaseAuthService.swift`

## Testing the Installation

Add this test to verify Firebase is properly installed:

```swift
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

struct FirebaseTestView: View {
    @State private var status = "Testing..."
    
    var body: some View {
        VStack {
            Text(status)
                .onAppear {
                    testFirebase()
                }
        }
    }
    
    func testFirebase() {
        // Test Firebase Core
        if FirebaseApp.app() != nil {
            status = "✅ Firebase SDK installed correctly!"
        } else {
            status = "❌ Firebase not configured"
        }
    }
}
```

## Minimum Requirements

- **iOS**: 13.0+
- **Xcode**: 14.0+
- **Swift**: 5.7+

The Firebase iOS SDK you're using requires these minimum versions.

---

**Once installed, all Firebase import errors will be resolved!** 🎉
