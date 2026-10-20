# Registration Workflow Redesign Plan

**Plan ID:** 1792498967993-registration-approval-architecture  
**Created:** 2026-10-20  
**Status:** Implementation-Ready  
**Purpose:** Redesign registration with multi-level selection (Age Grade, Branch, User Role), approval-based onboarding via authentication queue, and conditional approval by President/VP of selected Age Grade+Branch

---

## 1. Current State Analysis

### 1.1 Current Registration Flow (As-Is)

**UI (`register_screen.dart`):**
1. User fills form: Full Name, Email, Phone, Date of Birth (with age validation >=13), Password, Confirm Password
2. Selects Organization via `_OrganizationPicker` (dropdown of organizations from `organizationsFutureProvider`)
3. Selects User Role via dropdown (all `UserRole` values except `superAdmin`)
4. On "Register" click: validates form, checks DOB, organization selected, calls `authProvider.register()`

**Backend (`auth_service.dart` registerWithEmailAndPassword):**
1. Creates Firebase Auth user via `createUserWithEmailAndPassword`
2. Forces ID token refresh (`getIdToken(true)`)
3. Creates `UserModel` with `isActive: true` (default) and stores in `users/{uid}` 
4. Creates `MemberModel` with `isActive: true` and stores via `MemberRepository`
5. Reconciles obligations via `ObligationRepository.reconcileMemberObligations`
6. Returns `UserModel` immediately
7. AuthProvider sets state to logged-in user → navigates to HomeRouter

**Key Observations:**
- User is immediately active (`isActive: true`) and logged in after registration
- No approval gate, no queue
- No Age Grade or Branch fields in UserModel or MemberModel
- Role selection is at registration time but not scoped to organizational unit (Age Grade + Branch)
- Organization is selected from existing organizations list

---

## 2. Problem Statement Requirements

1. **Multi-Level Selection:** After clicking "Register," they must select three specific attributes under the "Organization" section: Age Grade Name, Branch Name, User Role

2. **Approval-Based Onboarding:** New registrations should not be immediately active; instead, they must be routed to an authentication queue.

3. **Conditional Approval Logic:** Define a logic where new members are only authorized once they have been approved by the designated President or Vice President corresponding to the specific Age Grade and Branch selected during registration.

---

## 3. Proposed Design

### 3.1 Core Concepts

**Age Grade:** Represents age-based grouping within organization. Needs to be modeled as entities scoped to organization.

**Branch:** Represents physical/location branches within organization.

**Scoped Leadership:** President/VP authority is scoped to (Organization + Age Grade + Branch). Need to track leaders for specific organizational units.

**Registration Request (Approval Queue):** Instead of creating active user immediately, create a pending registration request. Create Firebase Auth account only upon approval (or gate at application level). Recommended: create registration requests in `registration_requests` collection; on approval create Firebase Auth user, User, Member docs.

### 3.2 Data Model Changes

#### New Collections
- `organizations/{orgId}/age_grades/{ageGradeId}` - Age grade definitions
- `organizations/{orgId}/branches/{branchId}` - Branch definitions  
- `organizations/{orgId}/registration_requests/{requestId}` - Pending/approved/rejected requests
- `organizations/{orgId}/unit_leaders/{leaderId}` - Maps (ageGradeId, branchId) to leader userId with role president/vicePresident

#### Extended Models
- **UserModel**: add `ageGradeId`, `ageGradeName`, `branchId`, `branchName` (nullable for backward compat)
- **MemberModel**: add `ageGradeId`, `branchId`, `ageGradeName`, `branchName` (nullable)

---

## 4. UI/UX Changes

**Multi-step Registration:**
- Step 1: Personal info (name, email, phone, DOB, password, org selection)
- Step 2: Under "Organization" section, select Age Grade, Branch, User Role (cascading dropdowns). Submit creates registration request.
- Success state: "Registration submitted - pending approval by President/Vice President of [Age Grade] - [Branch]"

**New UI:**
- `RegistrationRequestsScreen` for Presidents/VPs to view and approve/reject requests for their units

---

## 5. Backend Logic

**New Methods in AuthService:**
- `submitRegistrationRequest()` - Create pending request (no auth account yet)
- `approveRegistrationRequest(requestId, approverId)` - Validate leadership, create auth user + profile + member, send password reset
- `rejectRegistrationRequest(requestId, approverId, reason)` - Mark rejected

**Approval Authorization:**
Check if approver is in `unit_leaders` for (orgId, ageGradeId, branchId) with role `president` or `vicePresident` and `isActive: true`. Must match exactly.

**Sign-in Gate:**
In `signInWithEmailAndPassword`, after loading profile, if `!userModel.isActive` sign out and throw "Your account is pending approval..."

**Password Strategy:**
On approval, create Firebase Auth user with random secure password, immediately call `sendPasswordResetEmail(email)` so user sets their own password.

---

## 6. Implementation Tasks

### Phase 1: Models & Schema
- [ ] Create AgeGradeModel, BranchModel, RegistrationRequestModel, UnitLeaderModel
- [ ] Extend UserModel and MemberModel with unit fields
- [ ] Update FirestoreSchema.md

### Phase 2: Repos & Providers
- [ ] Create repositories for age grades, branches, registration requests, unit leaders
- [ ] Add Riverpod providers for data fetching

### Phase 3: Registration UI (Multi-step)
- [ ] Refactor RegisterScreen to 2-step wizard
- [ ] Add Age Grade/Branch dropdowns (cascading by org)
- [ ] Change submit to create request
- [ ] Add pending approval success screen

### Phase 4: Approval UI & Logic
- [ ] Create RegistrationRequestsScreen for approvers
- [ ] Implement approve/reject in AuthService with authorization checks
- [ ] Add audit logging
- [ ] Update sign-in to block inactive users

### Phase 5: Security & Testing
- [ ] Update Firestore rules
- [ ] Unit/widget/integration tests
- [ ] Validate all scenarios

---

## 7. Critical Security Notes

- **Never store passwords in registration requests** - use password reset flow on approval
- **Enforce approval authorization server-side** (backend validation, not just UI)
- **Organization isolation** - all queries scoped by orgId
- **Prevent self-approval** and cross-unit approval
- **Audit all approve/reject actions**
- **Only allow request submission if org.openForJoin is true**

---

## Files to Modify/Create

**Modify:** `lib/features/auth/views/register_screen.dart`, `lib/features/auth/services/auth_service.dart`, `lib/features/auth/controllers/auth_provider.dart`, `lib/features/auth/models/user_model.dart`, `lib/features/members/models/member_model.dart`, `FirestoreSchema.md`

**Create:** Models (age_grade, branch, registration_request, unit_leader), Repositories (4 new), UI screens/providers as needed

---

**Next Step:** Implement Phase 1 starting with models, then proceed systematically.
