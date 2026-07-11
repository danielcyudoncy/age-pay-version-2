# PROJECT_RULES.md

> **AgePay Project Rules**
>
> Version: 1.0.0
>
> Last Updated: July 2026
>
> Status: Active

---

## Purpose

This document defines the mandatory engineering, architecture, security, and coding rules for the AgePay project.

Every contributor and AI coding assistant **must** follow these rules.

These rules override personal coding preferences.

---

## 1. Architecture Rules

## MUST

* Follow the Feature-First architecture.
* Use the Repository Pattern.
* Use GetX for state management.
* Keep business logic inside repositories or domain services.
* Keep UI and business logic separate.

## MUST NOT

* Access Firestore directly from Views.
* Access Firestore directly from Controllers.
* Store business logic inside Widgets.
* Duplicate business logic across modules.

---

## 2. Multi-Tenant Rules

AgePay is a multi-tenant platform.

Every business record must belong to exactly one organization.

Every Firestore document must contain:

* organizationId
* createdAt
* updatedAt
* createdBy

All Firestore queries must be filtered using `organizationId`.

Cross-organization data access is strictly prohibited.

---

## 3. Firestore Rules

Collections must remain modular.

Example:

```text
organizations/

members/

contributions/

payments/

expenses/

projects/

meetings/

notifications/
```

Never:

* Create deeply nested collections without justification.
* Store duplicate data unnecessarily.
* Expose unrestricted queries.

Indexes should be added whenever required for performance.

---

## 4. Controller Rules

Controllers are responsible only for:

* UI state
* Navigation
* User interactions
* Loading state
* Error handling

Controllers must never:

* Access Firebase directly
* Perform payment verification
* Contain financial calculations
* Parse API responses
* Perform database transactions

---

## 5. Repository Rules

Repositories are responsible for:

* Firestore
* Hive
* Synchronization
* Business rules
* Validation
* Transactions
* Offline support

Repositories are the single source of truth.

---

## 6. UI Rules

Every screen must support:

* Loading state
* Empty state
* Error state
* Success state

Every screen should:

* Be responsive
* Support dark mode
* Use reusable widgets
* Avoid duplicated UI

---

## 7. Theme Rules

Do not hardcode:

* Colors
* Font sizes
* Text styles
* Padding
* Border radius

Use centralized theme definitions.

---

## 8. Model Rules

Models must:

* Be immutable
* Support JSON serialization
* Include copyWith()
* Implement equality
* Validate required fields

Avoid dynamic typing where possible.

---

## 9. Financial Rules

Financial integrity is the highest priority.

Never:

* Delete payments
* Edit completed transactions
* Remove ledger entries
* Modify financial history

Instead:

* Reverse transactions
* Create adjustment records
* Record audit logs

Every financial action must be traceable.

---

## 10. Audit Rules

The following actions must create audit records:

* Login
* Logout
* Member creation
* Member updates
* Contribution creation
* Payment confirmation
* Refund
* Expense approval
* Project creation
* Executive appointment
* Permission changes

Audit records must never be edited.

---

## 11. Security Rules

Never trust client input.

Always validate:

* User permissions
* Organization ownership
* Required fields
* Payment status

Never expose:

* Secret keys
* Tokens
* Passwords
* Payment credentials

---

## 12. Authentication Rules

Authentication methods:

* Email & Password
* Google Sign-In

Every authenticated user must belong to at least one organization before accessing organization data.

---

## 13. Offline Rules

Hive is the offline cache.

Repositories decide:

* Cache strategy
* Synchronization
* Conflict resolution

Offline mode should never compromise data integrity.

---

## 14. Payment Rules

Supported payment methods:

* Paystack
* Flutterwave
* Manual Bank Transfer
* Cash Payment

Payment verification must occur before marking online payments as successful.

Manual payments require approval by authorized users.

---

## 15. Notification Rules

Notifications should be generated for:

* New contributions
* Payment confirmations
* Meeting reminders
* Project updates
* Expense approvals
* Announcements

Notifications should never contain sensitive financial information.

---

## 16. Testing Rules

Every feature must include appropriate tests.

Before every merge:

```bash
flutter analyze

flutter test
```

Both commands must pass successfully.

Critical financial modules require high test coverage.

---

## 17. Documentation Rules

Documentation is mandatory.

Whenever a feature changes:

* Business rules
* Firestore schema
* Architecture
* APIs
* User workflow

The relevant documentation must also be updated.

---

## 18. Code Review Checklist

Before approving a Pull Request, verify:

* Architecture respected
* Repository pattern followed
* No duplicated logic
* No direct Firestore access from UI
* Error handling implemented
* Loading states implemented
* Dark mode supported
* Tests added
* Documentation updated

---

## 19. Definition of Done

A feature is considered complete only if:

* Requirements are implemented.
* Business rules are respected.
* Financial integrity is preserved.
* Security checks are complete.
* Tests pass.
* Static analysis passes.
* Documentation is updated.
* Code review is approved.

---

## 20. Non-Negotiable Rules

The following rules are mandatory:

* Never bypass the Repository Pattern.
* Never access Firestore from a View.
* Never access Firestore from a Controller.
* Never delete financial records.
* Never expose organization data across tenants.
* Never hardcode secrets.
* Never merge failing tests.
* Never merge undocumented architectural changes.

Failure to follow these rules may result in rejected pull requests or production defects.

---

## Related Documents

* README.md
* AGENTS.md
* ARCHITECTURE.md
* CONTRIBUTING.md
* SECURITY.md
* docs/BusinessRules.md
* docs/FirestoreSchema.md

---

**Pack 1 Status:** ✅ Complete

Files included:

* README.md
* AGENTS.md
* ARCHITECTURE.md
* PROJECT_RULES.md
