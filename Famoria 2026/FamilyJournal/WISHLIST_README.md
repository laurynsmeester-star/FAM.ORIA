# Family Wishlist — Integration Guide

The wishlist feature lives inside the **Family Journal** tab as a second
segment, so users open `FamilyJournalView` and toggle between **Journal** and
**Wishlists**. Below is the file map, data model, and integration notes.

## File map

All wishlist files live in `Famoria 2026/FamilyJournal/`:

| File | Purpose |
| --- | --- |
| `WishlistModels.swift` | `WishPriority`, `WishOccasion`, and the `WishlistItem` struct. Pure value types, no Firebase imports. |
| `FirebaseWishlistService.swift` | Firestore CRUD + live snapshot listener. Encodes/decodes `WishlistItem` to dictionaries. Uses `FieldValue.delete()` to clear claims. |
| `WishlistViewModel.swift` | `@MainActor ObservableObject`. Owns the items array, the selected tab, and the manual surprise toggle. Applies both surprise-mode filtering rules in `isVisible(_:)`. |
| `WishlistView.swift` | The screen rendered inside the Journal's `wishlistsTab`. Surprise-mode bar, recipient tab strip, grouped list, FAB, delete confirmation. |
| `WishlistItemCard.swift` | One card per wish. Priority + occasion badges, optional description, link button, claim/unclaim/fulfill/delete actions. |
| `AddWishSheet.swift` | Form sheet with recipient picker (family member or "Other"), name, description, link, priority, occasion. Lightweight URL validation on submit. |

The file `Views/Components/FamilyJournalView.swift` was refactored into a
two-segment container. The original journal is preserved verbatim under a
private `JournalEntriesTab` struct, and `wishlistsTab` instantiates
`WishlistView` from the current `appState.currentFamily` / `currentUser`.

## Firestore schema

```
families/{familyId}/wishlistItems/{itemId}
  id: String                   // mirrored doc id
  familyId: String
  recipientUserId: String?     // present when recipient is on the app
  recipientName: String        // always present, used for grouping/tabs
  itemName: String
  itemDescription: String?
  link: String?
  priority: "dream" | "would love" | "nice to have"
  occasion: "birthday" | "christmas" | "anniversary" | "graduation" | "housewarming" | "any occasion"
  claimedByUserId: String?     // who is gifting this; absent = unclaimed
  claimedByName: String?
  isFulfilled: Bool
  addedByUserId: String
  addedByName: String
  createdAt: Timestamp
  updatedAt: Timestamp
```

Documents are ordered by `createdAt` descending in the live listener; the view
model does its own per-recipient sort that pushes fulfilled items to the
bottom.

## Surprise mode (two rules, combined)

`WishlistViewModel.isVisible(_:)` applies both, in order:

1. **Auto-hide on your own list.** If you are the recipient of an item AND it
   is claimed or fulfilled, the item is hidden from you. This protects the
   surprise without anyone having to opt in.
2. **Manual surprise toggle.** When `manualSurpriseModeOn == true`, claimed and
   fulfilled items are hidden from every list, including other people's. This
   is the "older kids who still want surprises" mode.

Both rules are filter-only — items are never deleted, just hidden in the UI.

## Integration with `AppState`

`FamilyJournalView` reads `appState.currentFamily` and `appState.currentUser`
from the existing environment object. It builds the view model with:

```swift
WishlistViewModel(
    familyId: family.id,
    currentUserId: user.id,
    currentUserName: user.name,
    currentUserRole: user.role,
    familyMembers: family.members
)
```

If the user has no family yet, the wishlists tab shows an inline "Join a family
to use wishlists" prompt instead of the view.

## Suggested Firestore security rules

Below is a starter rule set; adapt it to your existing `families/{familyId}`
membership check.

```
match /families/{familyId}/wishlistItems/{itemId} {
  allow read: if isFamilyMember(familyId);

  // Anyone in the family can create a wish.
  allow create: if isFamilyMember(familyId)
                && request.resource.data.addedByUserId == request.auth.uid;

  // Anyone in the family can update claim/fulfilled status.
  // The author or an admin/owner can fully edit or delete.
  allow update: if isFamilyMember(familyId);
  allow delete: if isFamilyMember(familyId)
                && (
                  resource.data.addedByUserId == request.auth.uid
                  || isAdminOrOwner(familyId, request.auth.uid)
                );
}
```

## Permissions in the UI

* **Add a wish** — anyone in the family.
* **Claim / unclaim** — anyone except the recipient. Only the original claimer
  can unclaim (enforced in `WishlistViewModel.unclaim`).
* **Mark fulfilled** — anyone in the family except the recipient.
* **Delete** — the author of the wish, or any user with `MemberRole.owner` or
  `.admin`.

The card hides irrelevant buttons depending on the viewer, so a recipient
never sees Claim or Fulfill controls on their own items.

## Translation notes from the base44 reference

The original `Wishlist.jsx` was a single-page React component using a flat
in-memory list. The SwiftUI version splits responsibilities so the UI stays
declarative and Firebase stays isolated:

* React component state (`items`, `selectedTab`, `surpriseMode`) → `@Published`
  fields on `WishlistViewModel`.
* `useEffect` data fetch → Firestore live listener via `observeItems`.
* `handleClaim` / `handleFulfill` / `handleDelete` → async methods on the view
  model, each calling the corresponding service method.
* Recipient pills + "Everyone" filter → `recipientTabs` + `WishlistTabSelection`
  enum.
* The base44-specific entity calls were dropped entirely. No code from the
  reference implementation is loaded at runtime.
