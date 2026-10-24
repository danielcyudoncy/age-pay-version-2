# Add Provost User Role

## Goal
Add a new `UserRole.provost` representing a senior governance executive who can review and approve organization-wide records but cannot record or verify payments.

## Decisions
- Role name: `provost` / display name `Provost`.
- Senior executive: included in `isExecutive`.
- Permissions: review/approve governance records only; no payment recording or verification.
- Routing: reuse `PresidentDashboard` initially.
- Alias support: parse `provost`.
- Penalties are created manually by Provost and stored as `ObligationType.penalty`.
- Penalty amounts are added to member total dues and clearly indicated as penalties.

## Affected Areas
- `lib/core/constants/enums.dart`: add `provost`, display name, switch cases, and `penalty` obligation type.
- `lib/features/auth/models/user_model.dart`: parse `provost` in role and requested role.
- `lib/features/dashboard/views/home_router.dart`: route Provost to `PresidentDashboard`.
- `lib/features/notifications/services/notification_service.dart`: add Provost to executive notification topics.
- `lib/features/notifications/views/notifications_screen.dart`: include Provost in executive filtering.
- `lib/features/dashboard/widgets/executive_approval_queue_card.dart`: include Provost in approval queue visibility.
- `lib/features/auth/views/pending_approval_screen.dart`: include Provost in role-specific UI cases.
- `lib/features/obligations/models/obligation_model.dart`: add optional `meetingId` and `reason` fields for penalty obligations.
- `firestore.rules`: add `isProvost()`; allow Provost to create penalty obligations and approve governance records, but do not add Provost to payment create/update rules.
- Tests: update role parsing, notification filtering, and obligation serialization tests.

## Implementation Notes
- Add Provost to president-level governance checks where appropriate; keep treasurer-only payment functions unchanged.
- Treat Provost as approver for expenses, levies, meetings, announcements, and member/registration approvals.
- Do not grant Provost payment create/update permissions.
- Penalty obligations should use title `Penalty: <reason>` and store `meetingId`, `reason`, and `createdByRole: provost`.
- Penalty obligations participate in dues totals and payment allocation like other obligations.

## Validation
- Run `flutter test`.
- Run `flutter analyze`.
- Verify role parsing, notification filtering, and obligation serialization tests pass.
- Verify no unhandled switch cases remain.
- Verify Firestore rules allow penalty creation by Provost but not payment recording.