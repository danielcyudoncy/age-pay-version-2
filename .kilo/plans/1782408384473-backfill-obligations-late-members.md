# Plan: Backfill Obligations for Late-Joining Members

## Problem

When a new member joins, no obligations are created for existing active levies.
Obligations are only created at levy-creation time, leaving late-joining members
with empty obligation histories.

## Solution

Add a backfill step that runs whenever a new member document is created.
Query all active levies and create matching obligations for the new member.

## Design Decisions (Resolved)

| Decision | Choice | Rationale |
|---|---|---|
| Scope of backfill | All active levies, regardless of `targetGroup` | Matches user requirement; avoids modifying registration/edit flows to add a `group` field |
| Active levy filter | `isActive == true` on levy | Prevents backfilling for deleted/archived levies |
| Obligation `createdAt` | New member's `joinedDate` | Preserves chronological order; obligation appears in ledger as if member was always a member |
| Where `group` field goes | Not added | Keeps scope minimal; `targetGroup` on levies becomes a label/reference only |
| Admin notification | Post obligations to `new_levies` FCM topic | Uses existing notification infra |
| Timing relative to levy creation flow | Client-side only in auth registration flow | Minimum blast radius; no cloud function changes needed |

## Implementation Steps

### 1. Add `backfillObligationsForNewMember` method to `ObligationProvider`

File: `lib/features/obligations/providers/obligation_provider.dart`

```dart
Future<void> backfillObligationsForNewMember(String memberId) async {
  final levies = await _levyRepository.getActiveLevies();
  final now = DateTime.now();

  final obligations = levies.map((levy) {
    return {
      'memberId': memberId,
      'levyId': levy.id,
      'type': levy.type.toJsonString(),          // convert enum to stored string
      'title': levy.title,
      'description': levy.description,
      'amount': levy.amountPerMember,
      'paidAmount': 0.0,
      'outstandingBalance': levy.amountPerMember,
      'status': 'unpaid',
      'dueDate': Timestamp.fromDate(levy.dueDate),
      'createdAt': Timestamp.fromDate(now),
    };
  }).toList();

  if (obligations.isEmpty) return;

  await _obligationRepository.batchCreateFromMaps(obligations);
  await subscribeToNewLeviesTopic();             // notify admins
}
```

**Notes:**
- Use existing `batchCreateFromMaps` on `ObligationRepository`
- `getActiveLevies()` may not exist on `LevyRepository` — if missing, add it:
  ```dart
  Future<List<LevyModel>> getActiveLevies() async {
    final snapshot = await _db.collection('levies').where('isActive', '==', true).get();
    return snapshot.docs.map((d) => LevyModel.fromFirestore(d)).toList();
  }
  ```
- Convert `ObligationType` enum to string using existing `.name` or `.toJsonString()` pattern (confirm which exists).

### 2. Call backfill from `AuthService.registerWithEmailAndPassword`

File: `lib/data/services/auth_service.dart`

After line where the `members` document is successfully created, call:

```dart
// After creating member document...
final obligationProvider = ObligationProvider();
await obligationProvider.backfillObligationsForNewMember(memberId);
```

**Edge case:** If Firestore write for member succeeds but backfill fails (network
error), the member is registered with no obligations. The partial failure is
acceptable — member can be manually re-linked by an admin if needed. No retry
logic or compensation required for v1.

**Edge case:** If creating obligations triggers the Firestore `onCreate` trigger
on `levies/{levyId}`, that trigger fires on the *levy* document (not on the
obligation write), so it will not re-fire. No duplicate obligations.

### 3. Add admin notification helper

File: same provider as step 1

```dart
Future<void> subscribeToNewLeviesTopic() async {
  await FirebaseMessaging.instance.subscribeToTopic('new_levies');
}
```

Uses existing `FirebaseMessaging`; no new topic needed.

### 4. Fix existing `targetGroup` inconsistency (optional but recommended)

The `createObligationsOnLevy` trigger in `functions/src/index.ts:15-66` creates
obligations for ALL active members, ignoring `targetGroup`. With the backfill
now running per-member, this is less critical, but consider aligning it:

- Either remove the `targetGroup` check from `createLevyWithObligations` (line 136)
  and treat it as a label, or
- Mark `targetGroup` as deprecated in the UI (`create_levy_screen.dart`)

This is **out of scope for v1** unless the implementation agent finds it
blocking.

## Files Changed

| File | Change |
|---|---|
| `lib/features/obligations/providers/obligation_provider.dart` | Add `backfillObligationsForNewMember` method |
| `lib/features/levies/repositories/levy_repository.dart` | Add `getActiveLevies()` if not present |
| `lib/data/services/auth_service.dart` | Call backfill after member creation |
| `firestore.rules` (optional) | Ensure new member documents are readable by obligations CF if any server-side path is added later |

## Validation

1. Create a levy with `isActive: true` and `dueDate` in the future
2. Register a new member via the app
3. Verify obligations appear in the member's obligation list
4. Register another member — verify both members see the levy obligations
5. Create a levy with `isActive: false` — register a new member — verify **no** obligations are created for that levy
6. Verify admin device subscribed to `new_levies` receives an FCM notification

## Migration

No data migration required. Existing members without obligations for past levies
are unchanged. Running this change affects only members registered after
deployment.

## Out of Scope

- Adding a `group` field to `MemberModel`, registration screen, or edit screen
- Cloud Function `onCreate` trigger on the `members` collection (client-side backfill is sufficient)
- Backfilling obligations for existing members already in the system
- Retry mechanism or dead-letter queue for failed backfills
- Consolidating the three levy-creation paths (`createObligationsOnLevy` trigger, `createLevyWithObligations` CF, client-side `levy_provider.dart`)
