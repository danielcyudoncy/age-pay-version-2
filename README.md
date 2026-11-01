# AgePay

<p align="center">
  <img src="assets/images/logo.png" alt="AgePay Logo" width="120" />
</p>

<p align="center">
  <strong>The Multi-Tenant Financial Operating System for Community Organizations, Age Grades & Alumni Associations.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Cloud%20Firestore-Database-FFA000?logo=firebase&logoColor=black" alt="Firestore" />
  <img src="https://img.shields.io/badge/Riverpod-State%20Management-blueviolet" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Material%203-Design-7B1FA2" alt="Material 3" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" />
</p>

---

## Overview

**AgePay** is a comprehensive, production-grade digital platform engineered to manage the finances, administration, and governance of community organizations, town unions, age grades, alumni associations, and cooperative societies.

Unlike simple payment tracking apps, AgePay acts as the **complete operating system for modern communities**. It unifies multi-branch governance, federated national assemblies, real-time treasury management, identity verification, and member transparency in a single, offline-capable mobile experience.

### Core Philosophy: Every User is a Member First
In AgePay, regardless of whether a user is the **Super Admin**, **President**, **Treasurer**, or **Secretary**, **every user is registered as a member of a local branch**. Executives manage administrative affairs while maintaining their personal member standing, dues obligations, meeting attendance, and voting eligibility.

---

## Key Capabilities & Role Dashboards

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AGEPAY PLATFORM TIERS                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  🛡️ SUPER ADMIN      Global Platform Governance, Fraud Gate & Auditing      │
│  🌐 NATIONAL TIER     Federated Assembly, Branch Remittances & Ledger       │
│  🏛️ BRANCH EXECUTIVE  Local Administration (President, Secretary, Treasurer)│
│  👤 MEMBER PORTAL     Personal Dues, Digital Receipts, Attendance & RSVPs   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1. 🛡️ Super Admin Console
- **Multi-Tenant Organization Management**: Onboard new organizations with state-wide branch creation (36 Nigerian states selectable with checkboxes or custom branch setup).
- **Platform Fraud & Compliance Gate**: Verify organization banking details and executive identities before granting live status.
- **Role Governance**: Manage administrative permissions, reassign branches, and audit system users.
- **Unified 3-in-1 Dashboard**: Features an integrated bottom navigation bar allowing Super Admins to seamlessly switch between **Admin Console**, their personal **Branch Member View**, and the **National Branch Hub**.

### 2. 🏛️ Executive Dashboards
- **President**: High-level financial purse oversight, meeting approvals, executive voting, and organizational health metrics.
- **Treasurer & Financial Secretary**: Dues and levy administration, automated obligation reconciliation, cash/bank-transfer verification, expense tracking, and real-time purse reporting.
- **General Secretary**: Member directory management, meeting scheduling (with agenda & minute attachments), QR/PIN attendance logging, official document repository, and broadcast announcements.
- **Provost**: Meeting discipline, fine assessment, attendance enforcement, and penalty waiver workflows.
- **Public Relations Officer (PRO)**: Community announcements, event notices, and public member communication.

### 3. 👤 Member Portal
- **Financial Purse & Obligations**: View total paid, outstanding dues, and active levies with real-time balance calculations.
- **Multi-Channel Payments**: Settle dues and levies via automated Paystack card processing, direct bank transfer, or verified cash payment.
- **Instant Digital Receipts**: Immutable, verifiable payment receipts with transaction references and downloadable payment proofs.
- **Meeting RSVPs & Attendance**: View scheduled meetings, submit excuses/RSVPs, and log attendance during sessions.
- **Announcements & Broadcasts**: Stay informed with targeted branch and organization-wide bulletins.

### 4. 🌐 National Assembly & Federated Ledger
- **Branch Remittance Tracking**: Monitor federated remittances from state branches to the National Secretariat.
- **National Assembly Roll**: Complete directory of accredited national delegates and executives.
- **Branch Compliance Leaderboard**: Real-time ranking of branches based on financial compliance, membership size, and remittance timeliness.
- **Executive Scope Switcher**: Executives holding both local and national offices can toggle between **Branch View** and **National View** with a single tap.

---

## Fraud Mitigation & Financial Integrity

AgePay is built with enterprise financial safety standards:

| Security Gate | Description |
|---|---|
| **Executive Identity Verification** | Super Admins and organization founders verify their identities via 11-digit NIN or BVN, automatically masked across the UI (`••••••1234`). |
| **Bank Account Matching** | Organization settlement accounts are validated against authorized Central Bank payment rails to prevent diversion of community funds. |
| **Dual Co-Founder Attestation** | New organization registration requires mutual attestation between President and General Secretary before approval. |
| **Immutable Ledger** | Completed payments and receipts are permanent. Corrections are handled strictly via audited adjustment entries. |

---

## Offline Support & Data Sync

Community organizations often hold meetings in areas with variable network connectivity:
- **Offline Payment Queuing**: Treasurers can record cash collections and bank transfers without an internet connection.
- **Background Synchronization**: Pending records queue locally and automatically reconcile with Cloud Firestore once connectivity is restored.
- **Real-Time Reactive Streams**: UI updates instantaneously using Riverpod stream providers scoped to the user's active session.

---

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Framework** | [Flutter](https://flutter.dev) (v3.x) | Cross-platform native mobile performance (Android & iOS) |
| **Language** | [Dart](https://dart.dev) (v3.x) | Modern, type-safe reactive development |
| **State Management** | [Flutter Riverpod](https://riverpod.dev) | Dependency injection, reactive stream caching & auto-dispose |
| **Backend & Auth** | [Firebase Authentication](https://firebase.google.com/docs/auth) | Secure email/password and token-based identity |
| **Database** | [Cloud Firestore](https://firebase.google.com/docs/firestore) | Real-time multi-tenant document database with strict security rules |
| **Storage** | [Firebase Storage](https://firebase.google.com/docs/storage) | Payment receipts, meeting documents, and profile media |
| **Payments** | [Paystack](https://paystack.com) | Automated card and bank payments |
| **Design System** | Material 3 | Consistent, accessible theming with AgePay brand green styling |

---

## Architecture

AgePay follows a strict **Feature-First Clean Architecture** with the **Repository Pattern**:

```
lib/
├── core/                  # Constants, Enums, Theme, Shared Utils & Base Widgets
├── demo/                  # Demo mode overrides and offline stubs
└── features/
    ├── admin/             # Platform Super Admin, Organizations, Branches & System Config
    ├── auth/              # Authentication, Registration, Co-Founder Gate & Identity Verification
    ├── dashboard/         # Role-based Dashboards (President, Treasurer, Member, PRO)
    ├── expenses/          # Expense requests, approvals, and disbursement logs
    ├── financial_secretary/# Financial Secretary specialized reconciliation tools
    ├── levies/            # Custom levy creation, deadlines, and collection tracking
    ├── meetings/          # Meeting agendas, minutes, RSVPs, and attendance
    ├── members/           # Member directory, profiles, and role management
    ├── national/          # National Assembly, branch remittances, and leaderboard
    ├── notifications/     # In-app alerts, broadcast notices, and reminders
    ├── obligations/       # Automated member dues and obligation reconciliation
    ├── payments/          # Payment recording, verification, and Paystack integration
    ├── provost/           # Meeting discipline, penalties, and waiver approvals
    ├── receipts/          # Digital receipt generation and history
    ├── reports/           # Financial statements, member ledgers, and purse reports
    ├── secretary/         # General Secretary tools, documents, and calendars
    └── settings/          # App settings, help, support, and about dialogs
```

> **Architectural Rule**: Views never communicate directly with Firebase. All data flows from **View → Controller / Notifier → Repository → Firestore / Local Storage**.

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24.x or later)
- Android Studio / Xcode
- Firebase CLI (`npm install -g firebase-tools`)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/danieludoncy/age-pay-version-2.git
   cd age-pay-version-2
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**:
   - Add your Android `google-services.json` to `android/app/`.
   - Add your iOS `GoogleService-Info.plist` to `ios/Runner/`.
   - Deploy Firestore rules:
     ```bash
     firebase deploy --only firestore:rules
     ```

4. **Run the Application**:
   ```bash
   flutter run
   ```

---

## Testing & Quality

To ensure stability and financial data integrity, AgePay maintains automated test suites:

```bash
# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test

# Run admin dashboard tests
flutter test test/admin_dashboard_navigation_test.dart test/admin_profile_test.dart test/features/admin/admin_users_test.dart
```

---

## License

This project is licensed under the [MIT License](LICENSE).
