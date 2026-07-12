enum UserRole { member, treasurer, president, superAdmin }

enum ObligationType {
  registrationFee,
  monthlyDue,
  specialLevy,
  emergencyContribution,
  projectContribution,
}

enum ObligationStatus { unpaid, partial, paid }

enum PaymentMethod { cash, bankTransfer, online }

enum PaymentProvider { paystack, flutterwave }

enum PaymentStatus { pending, approved, rejected }

enum ExpenseCategory {
  welfare,
  projects,
  events,
  administration,
  miscellaneous,
}
