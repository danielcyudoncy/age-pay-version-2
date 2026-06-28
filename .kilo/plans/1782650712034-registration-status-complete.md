# Plan: Registration Status Logic Update

## Goal
Change the Registration Status card on the member dashboard so it reads "Complete" only when the member's **original back-calculated registration fee obligation** (the "Past Obligation") has been fully paid. Any registration fee obligations created after the member joined must **not** affect this status. If no `registrationFee` obligations exist at all, show "Complete".

## Current Code
- **Provider**: `lib/features/dashboard/providers/member_dashboard_provider.dart:50-60`
  - Uses `.any()` — returns true if **any** registration fee is paid
  - Does not distinguish between the backfill (original) registration obligation and later-added registration fees

## Desired Logic
- Identify the **"Past Obligation"**: the earliest-created (`createdAt` oldest) `registrationFee` obligation for the member
  - This is the obligation created via `backfillObligationsForNewMember` at member join time
- If the member has **no** `registrationFee` obligations at all → `true` (Complete)
- If they do have registration fee obligations → check the **earliest one only**
  - Paid (`ObligationStatus.paid`) → Complete
  - Unpaid or partial → Incomplete
- Registration fee obligations created after joining (with later `createdAt`) are ignored
- Other obligation types (monthlyDue, specialLevy, etc.) do **not** affect registration status

## Changes

### 1. `lib/features/dashboard/providers/member_dashboard_provider.dart`
Replace:
```dart
return asyncObligations.whenData(
  (list) => list.any(
    (o) =>
        o.type == ObligationType.registrationFee &&
        o.status == ObligationStatus.paid,
  ),
);
```
With:
```dart
return asyncObligations.whenData(
  (list) {
    final registrationFees = list
        .where((o) => o.type == ObligationType.registrationFee)
        .toList();
    if (registrationFees.isEmpty) return true;
    registrationFees.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return registrationFees.first.status == ObligationStatus.paid;
  },
);
```

### 2. `lib/features/dashboard/screens/member_dashboard.dart`
Change line 316:
```dart
isRegistered ? 'Registered \u2713' : 'Incomplete',
```
To:
```dart
isRegistered ? 'Complete' : 'Incomplete',
```

## Rationale for "earliest createdAt" approach
- `backfillObligationsForNewMember` creates the member's initial obligations at join time with `createdAt = now`
- Any subsequent levy (including a new registration fee) creates obligations with a **later** `createdAt`
- Therefore, the earliest `createdAt` among `registrationFee` obligations reliably identifies the back-calculated registration fee
- No schema changes or new fields are required

## Validation
- Run `dart analyze lib/` — expect no new analyzer errors
- Run the app and verify on member dashboard:
  - Member with no registration levies → "Complete"
  - Member with one unpaid backfilled registration levy → "Incomplete"
  - Member with one fully-paid backfilled registration levy → "Complete"
  - Member with paid backfilled registration levy + later unpaid registration fee → "Complete" (only oldest counts)
  - Member with unpaid backfilled registration levy + later paid registration fee → "Incomplete" (oldest unpaid)
  - Post-joining levies (monthly dues, etc.) do **not** affect registration status

## Affected Boundaries
- **Only** the member dashboard registration status card is changed
- Treasurer and president dashboards show aggregate "Total Registered Members" counts and are **not** affected by this change

## No Data Migration Needed
This is a presentation-only logic change; no Firestore data changes are required.
