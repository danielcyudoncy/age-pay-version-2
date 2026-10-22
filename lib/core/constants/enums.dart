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
  executiveMember,
  committeeChair,
  member,
}

extension UserRoleExtension on UserRole {
  bool get isExecutive => this != UserRole.member;
}

enum ObligationType {
  registrationFee,
  monthlyDue,
  specialLevy,
  emergencyContribution,
  projectContribution,
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
  miscellaneous,
}

