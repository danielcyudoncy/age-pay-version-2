# FirestoreSchema.md

> **AgePay Firestore Database Schema**
>
> **Version:** 1.0.0
> **Last Updated:** July 2026
> **Status:** Active

---

## Overview

This document defines the Cloud Firestore database structure for AgePay.

The schema is designed to support:

* Multi-tenancy
* Financial integrity
* Offline synchronization
* Scalability
* Auditability
* High-performance queries

Every business document belongs to exactly one organization.

---

## Design Principles

## Multi-Tenant

Every business record must include:

```text
organizationId
```

All queries must be scoped by `organizationId`.

---

## Immutable Financial Records

The following collections are immutable:

* payments
* ledger
* refunds
* audit_logs

Records are never edited or deleted after completion.

---

## Standard Fields

Every document should contain:

```json
{
  "id": "",
  "organizationId": "",
  "createdAt": "",
  "updatedAt": "",
  "createdBy": "",
  "updatedBy": "",
  "isDeleted": false
}
```

---

## Database Structure

```text
organizations/
    {organizationId}

users/
    {userId}

roles/
    {roleId}

permissions/
    {permissionId}

invitations/
    {invitationId}

audit_logs/
    {auditId}
```

Each organization owns its business data.

---

## Organization Collection

```text
organizations/
    {organizationId}
```

Example

```json
{
  "id": "",
  "name": "",
  "shortName": "",
  "logo": "",
  "email": "",
  "phone": "",
  "address": "",
  "country": "",
  "currency": "NGN",
  "subscriptionPlan": "",
  "status": "active",
  "createdAt": "",
  "updatedAt": ""
}
```

---

## Members Collection

```text
organizations/

    {organizationId}

        members/

            {memberId}
```

Example

```json
{
  "id": "",
  "userId": "",
  "membershipNumber": "",
  "fullName": "",
  "email": "",
  "phone": "",
  "photoUrl": "",
  "gender": "",
  "status": "active",
  "joinedAt": "",
  "roleId": "",
  "permissions": []
}
```

---

## Roles Collection

```text
organizations/

    {organizationId}

        roles/

            {roleId}
```

Example

```json
{
  "name": "Treasurer",
  "description": "",
  "permissions": []
}
```

---

## Contributions Collection

```text
organizations/

    {organizationId}

        contributions/

            {contributionId}
```

Example

```json
{
  "id": "",
  "title": "",
  "type": "monthly_due",
  "amount": 5000,
  "currency": "NGN",
  "frequency": "monthly",
  "penaltyEnabled": true,
  "penaltyAmount": 500,
  "dueDate": "",
  "status": "active"
}
```

---

## Member Contributions

Tracks each member's payment obligation.

```text
organizations/

    {organizationId}

        member_contributions/

            {recordId}
```

Example

```json
{
  "memberId": "",
  "contributionId": "",
  "expectedAmount": 5000,
  "paidAmount": 3000,
  "balance": 2000,
  "status": "partial"
}
```

---

## Payments Collection

```text
organizations/

    {organizationId}

        payments/

            {paymentId}
```

Example

```json
{
  "paymentReference": "",
  "memberId": "",
  "contributionId": "",
  "amount": 5000,
  "currency": "NGN",
  "paymentMethod": "paystack",
  "status": "successful",
  "providerReference": "",
  "paidAt": "",
  "verifiedBy": ""
}
```

---

## Ledger Collection

Every successful payment creates a ledger record.

```text
organizations/

    {organizationId}

        ledger/

            {ledgerEntryId}
```

Example

```json
{
  "transactionType": "credit",
  "paymentId": "",
  "amount": 5000,
  "balanceAfter": "",
  "description": "",
  "postedAt": ""
}
```

Ledger entries are immutable.

---

## Expenses Collection

```text
organizations/

    {organizationId}

        expenses/

            {expenseId}
```

Example

```json
{
  "title": "",
  "category": "",
  "amount": "",
  "requestedBy": "",
  "approvedBy": "",
  "status": "approved",
  "receiptUrl": ""
}
```

---

## Meetings Collection

```text
organizations/

    {organizationId}

        meetings/

            {meetingId}
```

Example

```json
{
  "title": "",
  "description": "",
  "meetingDate": "",
  "venue": "",
  "status": "scheduled"
}
```

---

## Attendance Collection

```text
organizations/

    {organizationId}

        attendance/

            {attendanceId}
```

Example

```json
{
  "meetingId": "",
  "memberId": "",
  "status": "present",
  "checkedInAt": ""
}
```

---

## Projects Collection

```text
organizations/

    {organizationId}

        projects/

            {projectId}
```

Example

```json
{
  "title": "",
  "budget": "",
  "spent": "",
  "status": "active",
  "startDate": "",
  "endDate": ""
}
```

---

## Notifications Collection

```text
organizations/

    {organizationId}

        notifications/

            {notificationId}
```

Example

```json
{
  "title": "",
  "body": "",
  "type": "",
  "memberId": "",
  "isRead": false,
  "createdAt": ""
}
```

---

## Reports Collection

```text
organizations/

    {organizationId}

        reports/

            {reportId}
```

Stores generated reports.

Example

```json
{
  "title": "",
  "type": "",
  "generatedBy": "",
  "generatedAt": "",
  "downloadUrl": ""
}
```

---

## Audit Logs

Every important system action generates an audit record.

```text
audit_logs/

    {auditId}
```

Example

```json
{
  "organizationId": "",
  "userId": "",
  "action": "PAYMENT_CREATED",
  "entity": "payment",
  "entityId": "",
  "oldValue": {},
  "newValue": {},
  "timestamp": "",
  "ipAddress": "",
  "device": ""
}
```

Audit logs must never be edited.

---

## Invitations Collection

```text
organizations/

    {organizationId}

        invitations/

            {invitationId}
```

Stores pending member invitations.

---

## File Storage

Firebase Storage structure

```text
organizations/

    organizationId/

        logos/

        profile_photos/

        receipts/

        payment_proofs/

        meeting_documents/

        project_documents/

        reports/
```

---

## Recommended Firestore Indexes

Create composite indexes for:

### Payments

* organizationId
* memberId
* paidAt

---

### Contributions

* organizationId
* status
* dueDate

---

### Expenses

* organizationId
* status
* createdAt

---

### Meetings

* organizationId
* meetingDate

---

### Notifications

* organizationId
* memberId
* isRead

---

### Reports

* organizationId
* generatedAt

---

## Security Rules

Every Firestore request must validate:

* User is authenticated.
* User belongs to the organization.
* User has required permission.
* Document belongs to the same organization.

Never allow unrestricted collection access.

---

## Offline Support

The following collections should be cached in Hive:

* organizations
* members
* roles
* contributions
* member_contributions
* meetings
* attendance
* notifications
* projects

Sensitive financial collections should always synchronize with Firestore before updates.

---

## Future Collections

The schema is designed for future expansion.

Potential collections include:

```text
loans/

loan_payments/

investments/

shares/

budgets/

assets/

inventory/

vendors/

procurement/

events/

surveys/

polls/

announcements/

support_tickets/
```

---

## Collection Relationships

```text
Organization
│
├── Members
│
├── Roles
│
├── Contributions
│
│   └── Member Contributions
│
├── Payments
│
├── Ledger
│
├── Expenses
│
├── Meetings
│
│   └── Attendance
│
├── Projects
│
├── Notifications
│
├── Reports
│
└── Invitations
```

---

## Best Practices

* Keep documents under Firestore size limits.
* Avoid unnecessary nested collections.
* Use server timestamps where possible.
* Use transactions for financial operations.
* Batch writes for related updates.
* Never expose financial collections without authorization.
* Always validate `organizationId`.
* Soft-delete non-financial records when required.
* Never hardcode document paths.
* Keep Firestore rules synchronized with application permissions.

---

## Related Documents

* BusinessRules.md
* ContributionEngine.md
* PaymentArchitecture.md
* PermissionSystem.md
* OfflineArchitecture.md
* Reporting.md
* ARCHITECTURE.md
* PROJECT_RULES.md

---

## Summary

The AgePay Firestore schema is designed to provide a secure, scalable, and maintainable foundation for multi-tenant financial management. It enforces organization isolation, protects financial integrity, supports offline synchronization, and allows the platform to evolve without major structural changes.
