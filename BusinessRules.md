# BusinessRules.md

> **AgePay Business Rules**
>
> **Version:** 1.0.0
> **Last Updated:** July 2026
> **Status:** Active

---

## Overview

This document defines the core business rules governing AgePay. Every feature, API, repository, controller, and user interface must comply with these rules.

The purpose is to ensure:

* Consistent business behavior
* Financial integrity
* Data isolation
* Secure operations
* Predictable workflows

---

## Core Principles

AgePay is built on the following principles:

* Multi-Tenant by Design
* Financial Records are Immutable
* Every Action is Auditable
* Organization Data is Isolated
* Role-Based Access Control
* Offline-First Operation
* Single Source of Truth
* Secure Payment Processing

---

## Organization Creation

An organization must contain:

* Name
* Short Name
* Country
* Currency
* Organization Type
* Administrator
* Subscription Plan

Every organization receives a unique **organizationId**.

---

## Organization Isolation

Organizations are completely isolated.

Members of one organization:

* Cannot view another organization's data.
* Cannot modify another organization's records.
* Cannot participate in another organization unless invited.

Every Firestore query must filter by `organizationId`.

---

## Organization Status

Organizations may have one of the following statuses:

* Active
* Suspended
* Archived
* Deleted

Only **Active** organizations can perform transactions.

---

## Member Rules

A member belongs to one organization at a time.

Each member has:

* Membership Number
* Full Name
* Email
* Phone Number
* Membership Status
* Assigned Role

Membership numbers must be unique within an organization.

---

## Member Status

Possible statuses:

* Pending
* Active
* Suspended
* Resigned
* Deceased
* Archived

Suspended members cannot make payments or access organization resources.

---

## User & Membership

A user account may belong to multiple organizations.

Each membership is independent.

Example:

```text id="hsv0rt"
John Doe

Organization A
    Treasurer

Organization B
    Member

Organization C
    Secretary
```

Permissions are determined by the active organization.

---

## Role Rules

Roles determine system access.

Default roles include:

* Super Admin
* Organization Admin
* President
* Vice President
* Secretary
* Treasurer
* Financial Secretary
* Provost (Disciplinary Officer)
* Public Relations Officer
* Auditor
* Executive Member
* Committee Chair
* Member

Organizations may create custom roles.

---

## Disciplinary Penalties & Provost Decorum Rules

The Provost enforces organizational discipline, meeting decorum, and sanctions.

### Infraction Presets
The system supports pre-configured, editable infraction penalties:
* Late Coming (Default: ₦1,000)
* Unexcused Absence (Default: ₦2,000)
* Phone Ringing / Meeting Disturbance (Default: ₦500)
* Improper Attire / No Prescribed Uniform (Default: ₦1,000)
* Custom Sanction (Editable title and amount)

### Meeting Decorum Integration
* When a meeting is scheduled or in progress, the Provost has access to an Active Meeting Decorum card and live roll-call interface to issue infractions linked directly to the meeting minutes.

### Financial Integrity & Pardon/Waiver Workflow
* Penalties create financial obligations billed to the member's statement.
* Financial records are immutable: Penalties can **never** be deleted or silently erased.
* **Pardon / Waiver Authority**: If a member presents a valid medical excuse or emergency justification, the Provost can request a waiver.
* **President Countersignature Required**: Every waiver request must be countersigned and approved by the President before the fine is excused.
* On President approval, the penalty balance is zeroed out and stamped `[Pardoned / Waived]`.
* An immutable audit record is preserved in the `penalty_waivers` ledger tracking requester, reason, reviewer, and decision timestamp.

---

## Permission Rules

Permissions are assigned to roles.

Examples:

* Create Members
* Edit Members
* Delete Members
* Create Contributions
* Record Payments
* Approve Expenses
* View Reports
* Manage Meetings
* Manage Projects
* Manage Users

Permissions are evaluated before every protected operation.

---

## Contribution Rules

A contribution represents a financial obligation.

Supported contribution types include:

* Registration Fee
* Monthly Dues
* Annual Dues
* Welfare Contribution
* Development Levy
* Building Fund
* Emergency Levy
* Event Fee
* Fine
* Donation
* Project Contribution
* Custom Contribution

Organizations may define additional contribution types.

---

## Contribution Status

Each contribution can be:

* Draft
* Active
* Closed
* Archived

Only **Active** contributions accept payments.

---

## Contribution Assignment

Contributions may be assigned to:

* All Members
* Specific Roles
* Specific Members
* Committees
* Groups

Assignment rules are configurable.

---

## Payment Rules

Supported payment methods:

* Paystack
* Flutterwave
* Manual Bank Transfer
* Cash

Every payment must reference:

* Organization
* Member
* Contribution
* Payment Method
* Amount
* Currency

---

## Payment Status

Payments progress through:

```text id="x5m75w"
Pending

↓

Processing

↓

Successful

↓

Ledger Entry

↓

Receipt

↓

Notification
```

Failed payments never affect financial balances.

---

## Partial Payments

Organizations may allow partial payments.

If enabled:

Outstanding Balance = Expected Amount − Paid Amount

Payment remains incomplete until the balance reaches zero.

---

## Overpayments

Organizations may choose one of the following policies:

* Reject overpayment
* Credit member account
* Allocate to future contributions
* Require manual approval

Policy is configurable per organization.

---

## Refund Rules

Refunds never modify the original payment.

Instead:

* Create a refund record.
* Create a ledger adjustment.
* Create an audit log.

The original payment remains unchanged.

---

## Ledger Rules

Every successful financial transaction creates a ledger entry.

The ledger is immutable.

Entries cannot be:

* Edited
* Deleted
* Reordered

Corrections require adjustment entries.

---

## Expense Rules

Expenses require:

* Title
* Amount
* Category
* Requested By
* Approval Status

Expense statuses:

* Draft
* Pending Approval
* Approved
* Rejected
* Paid

Only approved expenses may be paid.

---

## Approval Rules

Organizations define approval workflows.

Examples:

Expense > ₦100,000

↓

Treasurer Approval

↓

President Approval

↓

Payment

Approval levels are configurable.

---

## Meeting Rules

Meetings include:

* Title
* Date
* Venue
* Agenda
* Organizer

Attendance is recorded for each member.

Meeting minutes may be attached after completion.

---

## Attendance Rules

Attendance statuses:

* Present
* Absent
* Excused
* Late

Rules:

* Attendance is recorded per meeting by the Secretary or authorized executive.
* Attendance is aggregated on an **Annual Basis** for calendar year audits and AGMs.
* Annual attendance metrics include: total meetings held, present count, late count, absent count, and attendance percentage.
* Both the **Secretary** and the **President** have access to the Annual Attendance Register for administrative tracking, good standing verification, and executive review.
* Attendance history contributes to reporting and annual general meeting (AGM) secretarial records.

---

## Project Rules

Projects include:

* Budget
* Funding Source
* Expenses
* Progress
* Status

Projects may receive dedicated contributions.

Project budgets should not be exceeded without authorization.

---

## Notification Rules

Notifications are generated for:

* Contribution creation
* Payment confirmation
* Due reminders
* Meeting invitations
* Expense approvals
* Project updates
* Organization announcements

Notifications may be:

* Push
* In-App
* Email (future)

---

## Reporting Rules

Reports may be generated for:

* Contributions
* Payments
* Expenses
* Member Balances
* Meetings
* Attendance
* Projects
* Executive Activities
* Financial Summary
* Audit Logs

Reports respect organization permissions.

---

## Audit Rules

The following actions must be audited:

* Login
* Logout
* Member Creation
* Member Update
* Role Assignment
* Contribution Creation
* Payment Verification
* Expense Approval
* Refund
* Project Update
* Meeting Creation

Audit records are immutable.

---

## Offline Rules

Offline mode supports:

* Member management
* Meeting attendance
* Cached contributions
* Notifications
* Draft expenses

Financial transactions requiring external verification are synchronized once connectivity is restored.

---

## Data Validation Rules

Before saving any record:

* Required fields must exist.
* User permissions must be verified.
* Organization ownership must be confirmed.
* Business rules must be satisfied.

Invalid transactions are rejected.

---

## Financial Integrity Rules

The following actions are prohibited:

* Deleting payments
* Editing completed payments
* Editing ledger entries
* Deleting audit logs
* Modifying receipts

Corrections must always create new records.

---

## Security Rules

Every protected action requires:

* Authentication
* Organization membership
* Permission validation

Sensitive information such as API keys, passwords, and payment secrets must never be stored in Firestore.

---

## Future Business Modules

The business architecture supports future modules including:

* Loan Management
* Investments
* Savings
* Shares
* Budgeting
* Procurement
* Asset Management
* Inventory
* Events
* Voting
* Surveys
* Membership Renewals
* Subscription Billing
* AI Treasurer
* AI Financial Advisor

---

## Related Documents

* FirestoreSchema.md
* ContributionEngine.md
* PaymentArchitecture.md
* PermissionSystem.md
* OfflineArchitecture.md
* NotificationSystem.md
* Reporting.md
* ARCHITECTURE.md
* PROJECT_RULES.md

---

## Summary

These business rules define the operational foundation of AgePay. Every module, workflow, and financial transaction must conform to this specification to ensure consistency, security, scalability, and financial accuracy across all organizations using the platform.
