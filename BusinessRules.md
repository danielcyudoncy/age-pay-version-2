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

### Onboarding Unregistered / Traditional Organizations (No CAC Credentials)

* CAC Registration Number is strictly **optional**.
* Traditional community age-grades, clans, and cultural associations lacking formal CAC incorporation can onboard legitimately using traditional and community endorsements:
  - Town Union affiliation name.
  - Traditional ruler, elder, or community executive endorsement contact.
  - Founder / Admin verified identity credential (NIN or BVN).
* Organizations onboarding without CAC credentials enter a pending state and are manually reviewed and verified by the Platform SuperAdmin via the Organization Verification module.
* Once verified, the organization receives full operational status without requiring formal corporate registry paperwork.

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

## Fraud Mitigation & Verification Rules (Zero-Trust Onboarding)

To eliminate collusion, unauthorized age-grade creation, and fund siphoning:

### 1. Executive Identity Verification (NIN / BVN)
* Pioneer founders (President and General Secretary) must provide a valid 11-digit National Identity Number (NIN) or Bank Verification Number (BVN).
* Sequences with repetitive dummy patterns or flagged IDs on the platform blacklist are blocked immediately from registration.

### 2. Community & Legal Credentials
* When registering an Age Grade, applicants must submit their Corporate Affairs Commission (CAC) incorporation status or number, their ancestral Town Union name, and Town Union executive contact.

### 3. Platform Verification Gate (SuperAdmin Approval)
* Mutual co-signing by President and Secretary transitions an organization to `verificationStatus: pending_verification` and `openForJoin: false`.
* Newly registered organizations remain invisible to public user join searches and cannot collect payments until Platform SuperAdmins review and approve their credentials in the Admin Panel.

### 4. Bank Account Matching & Anti-Siphoning Controls
* Personal bank accounts are strictly prohibited from receiving association dues.
* Receiving bank accounts must be in the name of the Age Grade or contain corporate/association keywords.
* Account names must be verified via NUBAN lookup and matched against the organization entity before being activated.

---

## Annual Software License & Direct Bank Transfer Verification

AgePay operates on a B2B organizational subscription model:

### 1. Billed to the Association (Not Individual Members)
* Individual members download and use AgePay freely without monthly subscription paywalls.
* Subscriptions are billed per organization/branch as an annual administrative license.

### 2. Traditional Corporate Bank Transfer Flow
* To match the traditional operations of community associations that do not use debit cards:
  * Associations view AgePay's official corporate receiving bank details (Zenith Bank, AgePay Technologies Ltd, 1012345678) in the app's settings.
  * Associations transfer the annual fee (default ₦35,000) directly from their association bank account.
  * The Treasurer or President uploads their mobile transfer slip or bank teller image in the app with the transaction reference.

### 3. SuperAdmin Verification & 365-Day Unlock
* Submitted renewal slips transition the organization to `subscriptionStatus: pending_verification`.
* Platform SuperAdmins review the uploaded receipt in the Admin Dashboard and verify payment credit.
* Upon approval, `subscriptionExpiresAt` is extended by 365 days (from the current date or from the previous future expiration date).
* If the transfer proof cannot be verified, the SuperAdmin rejects the submission with a clear reason, allowing the organization to re-upload.

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

### Super Admin Governance Rules
1. **Platform Scope**: The Super Admin possesses platform-level authority across all tenant organizations and branches.
2. **User & Role Administration**: The Super Admin can globally search all registered users, adjust branch or national roles, reassign members between organizations/branches, approve pending registrations, and suspend or activate accounts.
3. **Privilege Elevation**: Super Admin status can only be granted or revoked by another active Super Admin.
4. **System Configuration**: Only the Super Admin can configure global payment gateway modes (live/sandbox), fee bearer policies, dual-approval expense thresholds, maintenance mode, and communication integrations.
5. **Maintenance Mode Enforcement**: When maintenance mode is activated, standard user logins and operations are temporarily restricted with a custom public announcement notice.

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
* Agenda / Minutes Text
* Uploaded Minutes Scan / PDF
* Organizer (createdBy)
* Target Audience ('all' vs 'executives')
* Scope ('branch' vs 'national')
* BranchId

Attendance is recorded for each member.

### Meeting Minutes & Archive Architecture

* **Two Unified Tabs**:
  1. **Upcoming Meetings**: Displays scheduled sessions with RSVP buttons, live RSVP counters, venue badges, and scoping indicators.
  2. **Past Meetings & Minutes Archive**: Searchable archive of completed meetings with secretarial status indicators (`Minutes Ready` vs `Pending Minutes`), minute snippets, and `Doc Attached` tags.
* **Secretarial Publishing Workflow**:
  - The Secretary records detailed minute notes and can attach physical scans/PDFs.
  - Tapping **"Publish Minutes & Notify Members"** atomically saves the minutes, generates an official broadcast announcement (`category: meeting`), and triggers high-priority in-app notifications.
  - Tapping **"Save Details (Without Notifying)"** allows secretarial drafting and updates without triggering notifications.
* **Dual-Platform Scoping**:
  - **National Secretary**: In the National Platform, schedules and documents National Assembly & Executive meetings (`scope == 'national'`). Broadcast announcements and notifications are delivered organization-wide (or to National Executives).
  - **Branch Secretary**: In the Branch Platform, schedules and documents Branch Assembly meetings (`scope == 'branch'`). Broadcast announcements and notifications are strictly confined to that specific branch.
* **Member Access**:
  - Ordinary members have immediate read-only access to published minutes and downloadable document scans through the Member Dashboard ("Meeting Minutes" Quick Action button and interactive Meeting Minutes card).
  - Ordinary members cannot view executive-only meeting minutes.

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

## National Portfolios & Branch Privacy Boundaries

### Core Privacy Principle
National account holders (National President, National Secretary, National Treasurer, etc.) do NOT have the right to inspect or access local branch records without explicit delegation or authorization by that branch:
* **National account holders only see what the branch president wants them to see.**
* Branch internal activities remain isolated from national visibility by default.

### Specific Isolation Boundaries
1. **Meetings & Roll Call Privacy**:
   * National executives cannot view branch meetings, branch meeting minutes, attendance roll calls, or branch attendee counts.
   * National dashboard and executive views only query and display national-tier meetings (`scope == 'national'`).
2. **Announcement & Meeting Cross-Branch Privacy**:
   * Announcements for branch meetings and branch-specific notices are private to the members and executives of that branch.
   * Cross-branch leakage is strictly prohibited: A member of a branch (including a sole member of a newly created branch) must never see meeting announcements, upcoming meeting cards, or calendar events from any other branch.
   * National account holders cannot view branch announcements unless they are directly registered members of that branch.
   * SuperAdmin users belonging to a branch are scoped to their branch on the Member Dashboard and will not see other branches' meetings or meeting broadcasts.
   * Legacy meeting records or announcements lacking explicit target branch identifiers default to the creator's branch boundary and will not leak to members of different branches. Global broadcasts require explicit national scope (`scope == 'national'` with `targetAudience == 'all'`).
   * **Meeting Announcement Structure**: Meeting announcements must include dedicated **Meeting Date & Time** columns, a dedicated **Meeting Venue** column, and a dedicated **Meeting Agenda (Body)** space specifying the order of proceedings.
   * **Announcement & Notification Reader Accessibility**: Every announcement card (across member, executive, and search screens) and in-app notification inbox card is interactive (`InkWell`/tap response). Tapping opens a full modal reader displaying the complete title, metadata (date, time, venue, category, target audience), and scrollable unabridged body/agenda without text cutoffs, alongside contextual action deep-links (e.g. "View Meeting & RSVP", "Pay Now", "View Announcements").
3. **Member Directory & National Assembly Roll**:
   * Branch members are NOT visible to national account holders unless they are explicitly **"Enrolled in national branch"** (`isEnrolledInNational == true`) by their Branch President.
   * Branch Presidents (and SuperAdmins) have exclusive authority to enroll or unenroll branch members in the national tier with an audit trail (`enrolledInNationalAt`, `enrolledInNationalBy`).
   * National officers and direct national branch members are visible by virtue of their national roles.
4. **Registration Approvals**:
   * New applicant registrations for a branch are exclusively approved by that branch's president.
   * National executives only receive and approve registrations intended directly for the national secretariat or unassigned applicants.
5. **National Levies Applicability**:
   * When a national levy is created, it applies to **all branch members** across all branches nationwide.
   * Automated obligations are distributed to every active branch member in the organization, ensuring comprehensive national compliance while preserving member private record isolation at the branch level.

---

## Nigerian State Branch Provisioning Rules

1. **Standardized State Coverage**:
   * Branch provisioning provides a canonical catalog of all 36 States in Nigeria + Federal Capital Territory (FCT Abuja).
   * Prevents inconsistent spelling, casing, or colloquial abbreviations (e.g., standardizes "Lagos Branch", "Abia Branch", "Abuja Branch").

2. **Batch Checkbox Provisioning**:
   * Super Admins can select multiple states via checkboxes and provision all selected chapters atomically in a single batch write (`BranchRepository.createBranches`).
   * Provides quick filters for common diaspora hubs (Lagos, Abuja, Rivers, Abia, Enugu, Anambra, Imo, Delta, Kano, Oyo).

3. **Duplicate Prevention**:
   * System inspects existing organization branches; any state that already has an active chapter is marked as "Already added" with its checkbox disabled to prevent redundant branch creation.

4. **Custom Branch Fallback**:
   * Dedicated custom branch tab permits provisioning non-state chapters (e.g. specialized town branches like "Aba North Chapter" or international branches like "UK / Diaspora Chapter").

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
