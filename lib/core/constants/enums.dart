enum UserRole {
  superAdmin,
  president,
  vicePresident,
  secretary,
  viceSecretary,
  treasurer,
  viceTreasurer,
  financialSecretary,
  auditor,
  publicRelationsOfficer,
  provost,
  executiveMember,
  committeeChair,
  member,
}

extension UserRoleExtension on UserRole {
  bool get isExecutive => this != UserRole.member;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.president:
        return 'President';
      case UserRole.vicePresident:
        return 'Vice President';
      case UserRole.secretary:
        return 'Secretary';
      case UserRole.viceSecretary:
        return 'Vice Secretary';
      case UserRole.treasurer:
        return 'Treasurer';
      case UserRole.viceTreasurer:
        return 'Vice Treasurer';
      case UserRole.financialSecretary:
        return 'Financial Secretary';
      case UserRole.auditor:
        return 'Auditor';
      case UserRole.publicRelationsOfficer:
        return 'Public Relations Officer';
      case UserRole.provost:
        return 'Provost';
      case UserRole.executiveMember:
        return 'Executive Member';
      case UserRole.committeeChair:
        return 'Committee Chair';
      case UserRole.member:
        return 'Member';
    }
  }
}

enum ObligationType {
  registrationFee,
  monthlyDue,
  specialLevy,
  emergencyContribution,
  projectContribution,
  penalty,
}

extension ObligationTypeExtension on ObligationType {
  String get displayName {
    switch (this) {
      case ObligationType.registrationFee:
        return 'Registration Fee';
      case ObligationType.monthlyDue:
        return 'Monthly Due';
      case ObligationType.specialLevy:
        return 'Special Levy';
      case ObligationType.emergencyContribution:
        return 'Emergency Contribution';
      case ObligationType.projectContribution:
        return 'Project Contribution';
      case ObligationType.penalty:
        return 'Disciplinary Penalty';
    }
  }
}

enum PenaltyWaiverStatus {
  pendingApproval,
  approved,
  rejected,
}

enum PenaltyInfractionType {
  lateComing,
  unexcusedAbsence,
  noiseOrDisturbance,
  improperAttire,
  custom,
}

extension PenaltyInfractionTypeExtension on PenaltyInfractionType {
  String get displayName {
    switch (this) {
      case PenaltyInfractionType.lateComing:
        return 'Late Coming';
      case PenaltyInfractionType.unexcusedAbsence:
        return 'Unexcused Absence';
      case PenaltyInfractionType.noiseOrDisturbance:
        return 'Phone / Disturbance';
      case PenaltyInfractionType.improperAttire:
        return 'Improper Attire / No Uniform';
      case PenaltyInfractionType.custom:
        return 'Custom Sanction';
    }
  }

  double get defaultFineAmount {
    switch (this) {
      case PenaltyInfractionType.lateComing:
        return 1000.0;
      case PenaltyInfractionType.unexcusedAbsence:
        return 2000.0;
      case PenaltyInfractionType.noiseOrDisturbance:
        return 500.0;
      case PenaltyInfractionType.improperAttire:
        return 1000.0;
      case PenaltyInfractionType.custom:
        return 1000.0;
    }
  }
}

enum AccountStatus {
  pendingApproval,
  approved,
  rejected,
  suspended,
}

enum ObligationStatus { unpaid, partial, paid }

enum PaymentMethod { cash, bankTransfer, online }

enum PaymentProvider { paystack, flutterwave }

enum PaymentStatus { pending, approved, rejected }

enum ExpenseStatus {
  pendingApproval,
  approved,
  rejected,
}

enum MemberDuesStanding {
  cleared,
  openingBalance,
  newMember,
}

enum ExpenseCategory {
  welfare,
  projects,
  events,
  administration,
  assetsAndUtensils,
  meetingRefreshment,
  delegationAndTransport,
  communications,
  miscellaneous,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get displayName {
    switch (this) {
      case ExpenseCategory.welfare:
        return 'Welfare & Bereavement';
      case ExpenseCategory.projects:
        return 'Projects & Development';
      case ExpenseCategory.events:
        return 'Events & Hosting';
      case ExpenseCategory.administration:
        return 'Administration & Secretariat';
      case ExpenseCategory.assetsAndUtensils:
        return 'Utensils & Assets (Plates, Spoons)';
      case ExpenseCategory.meetingRefreshment:
        return 'Meeting Refreshment & Host Bailout';
      case ExpenseCategory.delegationAndTransport:
        return 'Delegation & Transportation';
      case ExpenseCategory.communications:
        return 'SMS, Calls & Broadcasts';
      case ExpenseCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }
}

enum CashHandoverStatus {
  pending,
  accepted,
  rejected,
}

extension CashHandoverStatusExtension on CashHandoverStatus {
  String get displayName {
    switch (this) {
      case CashHandoverStatus.pending:
        return 'Pending Handover';
      case CashHandoverStatus.accepted:
        return 'Received & Deposited';
      case CashHandoverStatus.rejected:
        return 'Disputed / Returned';
    }
  }
}

enum BranchTier {
  national,
  branch,
}

enum ExecutiveScope {
  branch,
  national,
}

enum ObligationScope {
  national,
  branch,
}
