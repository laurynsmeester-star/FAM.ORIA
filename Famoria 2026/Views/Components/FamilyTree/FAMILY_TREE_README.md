# Family Tree

A self-contained, user-specific, scrollable family tree component for Famoria 2026.

## What's in this folder

| File | Purpose |
|---|---|
| `FamilyTreeModels.swift` | `FamilyTreeMember`, `Relationship`, `FamilyTree`, `RelationshipType`, `TreeGender`, `AddRelativeKind`. |
| `FirebaseFamilyTreeService.swift` | Firestore CRUD + live listeners for `families/{id}/treeMembers` and `families/{id}/relationships`. |
| `FamilyTreeViewModel.swift` | Owns state, runs the layout engine, exposes mutations. |
| `FamilyTreeNodeCard.swift` | The polished per-person card. |
| `FamilyTreeConnections.swift` | Canvas-drawn parent/child + spouse lines. |
| `FamilyTreeView.swift` | The main scrollable, zoomable, searchable screen. |
| `AddRelativeSheet.swift` | Form for adding parents/children/spouse/sibling. |
| `MemberProfileSheet.swift` | Tap-a-node mini profile + edit + delete + invite ghost. |
| `README.md` | This file. |

## How to add the files to Xcode

1. In Xcode, right-click your project navigator → **Add Files to "Famoria 2026"…**
2. Select the entire `FamilyTree/` folder.
3. Choose **Create groups** (not folder reference) so Xcode picks them up as Swift sources.
4. Make sure the target **Famoria 2026** is checked.

## How to open the screen

Anywhere in your nav (e.g., a tab in `FamoriaNavigationLayout`, or a row inside `FamilyAdminView`):

```swift
NavigationLink {
    if let family = appState.currentFamily, let user = appState.currentUser {
        FamilyTreeView(
            viewModel: FamilyTreeViewModel(
                familyId: family.id,
                currentUserId: user.id,
                currentUserRole: user.role
            ),
            currentUserDisplayName: user.name,
            currentUserPhotoURL: nil // wire to your user photo when available
        )
    }
} label: {
    Label("Family Tree", systemImage: "tree.fill")
}
```

Or, if you'd rather present modally:

```swift
.sheet(isPresented: $showTree) {
    FamilyTreeView(
        viewModel: FamilyTreeViewModel(
            familyId: appState.currentFamily!.id,
            currentUserId: appState.currentUser!.id,
            currentUserRole: appState.currentUser?.role
        ),
        currentUserDisplayName: appState.currentUser!.name,
        currentUserPhotoURL: nil
    )
}
```

The view auto-creates a "self" node for the current user the first time it's opened, so the tree is never empty for them.

## Firestore schema

```
families/{familyId}/
    treeMembers/{memberId}
        id, familyId, linkedUserId?, displayName, photoURL?,
        gender, birthDate?, deathDate?, isDeceased,
        notes?, addedBy, createdAt, updatedAt, inviteEmail?

    relationships/{relationshipId}
        id, familyId, fromMemberId, toMemberId,
        type ("parent" | "spouse"), createdAt
```

Per-family isolation means each family account has its own tree — accuracy is guaranteed across all members of the family because they all read/write the same Firestore subcollection in real time via `addSnapshotListener`.

## Suggested Firestore security rules

Drop this into your `firestore.rules` (adjust to match your existing auth helpers):

```
match /families/{familyId} {

  // Anyone in the family can read the tree.
  match /treeMembers/{memberId} {
    allow read: if request.auth != null
      && exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));

    // Only owners and admins can write.
    allow write: if request.auth != null
      && get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role in ['owner', 'admin'];
  }

  match /relationships/{relationshipId} {
    allow read: if request.auth != null
      && exists(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid));
    allow write: if request.auth != null
      && get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid)).data.role in ['owner', 'admin'];
  }
}
```

## Linking ghost profiles to real Famoria users

When an extended relative joins Famoria via your existing invite flow:

1. After they accept and `joinFamily(...)` succeeds, call:
   ```swift
   try await FirebaseFamilyTreeService().linkUser(
       memberId: ghostMemberId,
       familyId: family.id,
       userId: newUser.id
   )
   ```
2. The ghost node automatically becomes a real linked node — color changes from dashed-outline to full-color, "Not on Famoria" badge disappears, and tapping it can route to that user's full Famoria profile.

The cleanest place to wire this is in your existing `FirebaseFamilyService.joinFamily(...)` (or wherever you process invite acceptance): if the joining email matches a `treeMember.inviteEmail`, link them automatically.

## Built-in features (recap)

- **User-specific** — each family's tree is stored under `families/{familyId}` and only loaded for the current user's family.
- **Full-page scrollability** — pan in any direction, pinch to zoom (0.4×–2.5×), double-tap to toggle, "fit to screen" button.
- **Beautiful display** — classic vertical pedigree layout, gradient theme matching Famoria's purple/pink, gender-accent rings, dashed outlines for ghosts, deceased indicator.
- **Seamless add flow** — tap any node → "Add a relative" chips for Parent / Child / Spouse / Sibling. The view model handles all the relationship plumbing (e.g., adding a child also links the anchor's spouse as a co-parent).
- **Accuracy across the family** — Firestore live listeners (`addSnapshotListener`) mean every member of the family sees updates in real time.
- **Linking profiles** — `linkedUserId` bridges tree nodes to real `User` accounts. Ghost profiles can be invited via email and upgraded automatically.
- **Photos & life dates** — avatar (or initials fallback), birth/death dates rendered as a "1948–2019" lifespan label.
- **Tap → mini profile sheet** — shows parents/spouse/siblings/children, notes, invite/edit/remove actions.
- **Search & jump** — typing in the search bar lists matches; selecting one animates the canvas to center the person.
- **Permissions** — owners and admins can edit; everyone can view (matches your existing `MemberRole`).

## Possible next steps (not implemented yet)

- Wire the "Invite to Famoria" button on `MemberProfileSheet` to your existing `FirebaseFamilyService.generateInviteCode(...)` and an email-sending Cloud Function.
- Photo upload via `FirebaseStorage` (currently we accept a photo URL string).
- Conflict-resolution UI when two admins edit the same member at once (Firestore `merge: true` minimizes this but a polish pass would help).
- Multi-spouse / blended-family edge cases — current layout handles them but visually could be improved (stacking ex-spouses below).
- Export the tree as a PDF using your existing `pdf` skill.
