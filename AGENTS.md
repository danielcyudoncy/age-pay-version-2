# AGENTS.md

> **AgePay Engineering Handbook**
>
> Version: 1.0.0
>
> Last Updated: July 2026
>
> Status: Active

---

You are an expert Flutter engineer helping build a production-quality teaching project.

You write clean, simple, maintainable code. You prioritize clarity over unnecessary abstraction because this app is used to teach developers how to build feature by feature.

Think like a senior Flutter developer, but explain and implement like someone building a practical learning project.

## Purpose

This document defines the engineering standards, architectural principles, and development workflow for the AgePay project.

It is intended for:

* Developers
* AI coding assistants
* Code reviewers
* Contributors

Every code change should follow the standards defined in this document.

---

## Project Overview

AgePay is a multi-tenant contribution and financial management platform built with Flutter and Firebase.

The application enables organizations to manage:

* Members
* Contributions
* Payments
* Expenses
* Meetings
* Projects
* Reports
* Notifications

Each organization operates within its own isolated workspace.

---

## Engineering Principles

Every implementation should prioritize:

* Simplicity
* Readability
* Scalability
* Maintainability
* Testability
* Security
* Financial Integrity

Always choose long-term maintainability over short-term convenience.

---

## Architecture

AgePay follows:

* Feature-First Architecture
* Repository Pattern
* GetX State Management
* Firebase Backend
* Hive Offline Storage

Data flow:

```text
View
   │
Controller
   │
Repository
   │
Firebase / Hive
```

Views never communicate directly with Firebase.

---

## Project Structure

Every feature follows the same structure.

```text
feature/

├── bindings/
├── controllers/
├── models/
├── repositories/
├── services/
├── views/
└── widgets/
```

Responsibilities:

| Folder       | Responsibility               |
| ------------ | ---------------------------- |
| bindings     | Dependency injection         |
| controllers  | UI state                     |
| models       | Data models                  |
| repositories | Business logic & data access |
| services     | External integrations        |
| views        | Screens                      |
| widgets      | Reusable UI                  |

---

## Development Workflow

Before implementing a feature:

1. Understand the business requirement.
2. Check existing architecture.
3. Reuse existing components where possible.
4. Implement using the repository pattern.
5. Add tests.
6. Update documentation.
7. Understand the user's request.
8. Read this guide before coding.
9. Keep implementations simple.
10. Avoid overengineering.
11. Prefer readability over cleverness.
12. Build the smallest useful version first.
13. Refactor only when repetition appears.
14. Keep the project educational.

Never implement duplicate functionality.

---

## State Management

AgePay standardizes on GetX.

Controllers should:

* Manage UI state
* Expose reactive variables
* Call repositories
* Handle loading states
* Handle errors

Controllers should **not**:

* Access Firestore directly
* Parse JSON
* Contain payment logic
* Contain business rules

---

## Repository Standards

Repositories are responsible for:

* Firestore operations
* Hive operations
* Data validation
* Business rules
* Synchronization
* Transactions

Repositories are the only layer allowed to communicate with the data source.

---

## Firestore Standards

Every document must include:

* id
* organizationId
* createdAt
* updatedAt
* createdBy

Financial records may include additional metadata.

Queries must always be scoped by `organizationId`.

Never expose data across organizations.

---

## Multi-Tenancy

AgePay uses a shared application with isolated organizational data.

Rules:

* One installation supports multiple organizations.
* Every business record belongs to exactly one organization.
* Data isolation is mandatory.
* Cross-organization access is prohibited.

---

## Financial Integrity

Financial records are immutable.

Never:

* Delete payments
* Edit completed transactions
* Modify ledger history

Corrections must be handled using adjustment or reversal records.

Every financial action must create an audit trail.

---

## Security

Never trust client-side input.

Validate all data before writing.

Sensitive operations must enforce permission checks.

Do not log:

* Passwords
* Tokens
* API keys
* Payment secrets
* Personal financial information

---

## Offline Support

Hive is the local persistence layer.

Repositories decide whether data comes from:

* Firebase
* Hive

Offline writes should be queued and synchronized automatically.

---

## Testing

Every feature should include:

* Unit tests
* Repository tests
* Widget tests (where appropriate)
* Integration tests for critical flows

Critical financial logic should maintain high test coverage.

---

## Code Style

* Use meaningful names.
* Keep methods focused.
* Prefer immutable models.
* Use `const` where possible.
* Avoid duplicated code.
* Keep widgets small and reusable.

---

## UI Rules (VERY IMPORTANT)

If a design is provided:

Replicate it exactly.

Match:

* spacing
* colors
* typography
* icons
* shadows
* border radius
* sizing
* alignment
* proportions

Do not simplify unless instructed.

---

## Documentation

Documentation is part of the feature.

Update documentation whenever changes affect:

* Architecture
* Business rules
* Firestore schema
* APIs
* User workflows

A feature is not complete until the relevant documentation has been updated.

---

## Definition of Done

A feature is complete when:

* Requirements are implemented.
* Business rules are respected.
* Tests pass.
* Static analysis passes.
* Documentation is updated.
* Code has been reviewed.
* The feature is production-ready.

---

## Related Documents

* README.md
* ARCHITECTURE.md
* PROJECT_RULES.md
* BusinessRules.md
* FirestoreSchema.md
* PaymentArchitecture.md
