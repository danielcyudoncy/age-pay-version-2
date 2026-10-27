import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/payments/models/payment_model.dart';
import 'package:cls/features/expenses/models/expense_model.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';

void main() {
  group('Branch Scoping & Multi-Tenancy Isolation Tests', () {
    final now = DateTime.now();
    final dob = DateTime(1990, 1, 1);

    final branchPresidentAba = UserModel(
      uid: 'pres_aba',
      organizationId: 'org_1',
      email: 'aba_president@test.com',
      displayName: 'Aba President',
      phoneNumber: '08011111111',
      role: UserRole.president,
      branchId: 'branch_aba',
      branchName: 'Aba Branch',
      createdAt: now,
    );

    final branchPresidentLagos = UserModel(
      uid: 'pres_lagos',
      organizationId: 'org_1',
      email: 'lagos_president@test.com',
      displayName: 'Lagos President',
      phoneNumber: '08022222222',
      role: UserRole.president,
      branchId: 'branch_lagos',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    final nationalPresident = UserModel(
      uid: 'pres_national',
      organizationId: 'org_1',
      email: 'nat_president@test.com',
      displayName: 'National President',
      phoneNumber: '08033333333',
      role: UserRole.member,
      nationalRole: UserRole.president,
      branchId: 'branch_lagos',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    final superAdmin = UserModel(
      uid: 'super_admin',
      organizationId: 'org_1',
      email: 'admin@test.com',
      displayName: 'Super Admin',
      phoneNumber: '08044444444',
      role: UserRole.superAdmin,
      createdAt: now,
    );

    group('Pending Registration Filtering', () {
      final pendingApplicantAba = UserModel(
        uid: 'applicant_1',
        organizationId: 'org_1',
        email: 'app_aba@test.com',
        displayName: 'Aba Applicant',
        phoneNumber: '08055555555',
        role: UserRole.member,
        status: AccountStatus.pendingApproval,
        isActive: false,
        branchId: 'branch_aba',
        branchName: 'Aba Branch',
        createdAt: now,
      );

      final pendingApplicantLagos = UserModel(
        uid: 'applicant_2',
        organizationId: 'org_1',
        email: 'app_lagos@test.com',
        displayName: 'Lagos Applicant',
        phoneNumber: '08066666666',
        role: UserRole.member,
        status: AccountStatus.pendingApproval,
        isActive: false,
        branchId: 'branch_lagos',
        branchName: 'Lagos Branch',
        createdAt: now,
      );

      final pendingApplicantNational = UserModel(
        uid: 'applicant_nat',
        organizationId: 'org_1',
        email: 'app_nat@test.com',
        displayName: 'National Secretariat Applicant',
        phoneNumber: '08077777777',
        role: UserRole.member,
        status: AccountStatus.pendingApproval,
        isActive: false,
        branchId: 'national',
        branchName: 'National Secretariat',
        createdAt: now,
      );

      final List<UserModel> allPending = [
        pendingApplicantAba,
        pendingApplicantLagos,
        pendingApplicantNational,
      ];

      List<UserModel> filterPending(UserModel viewer, {bool isNationalScope = false}) {
        final isNationalExecutive = isNationalScope &&
            (viewer.nationalRole != null || viewer.role == UserRole.superAdmin);

        return allPending.where((u) {
          if (isNationalExecutive) {
            // National executives only approve registrations intended directly for the national body.
            // Branch-level applicants are strictly approved by their respective branch presidents.
            if (u.branchId != null &&
                u.branchId!.isNotEmpty &&
                u.branchId != 'national') {
              return false;
            }
          } else if (viewer.branchId != null && viewer.branchId!.isNotEmpty) {
            if (u.branchId != null &&
                u.branchId!.isNotEmpty &&
                u.branchId != viewer.branchId) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      test('Aba Branch President only sees Aba pending registrations', () {
        final filtered = filterPending(branchPresidentAba);
        expect(filtered.length, 1);
        expect(filtered.first.uid, 'applicant_1');
        expect(filtered.first.branchId, 'branch_aba');
      });

      test('Lagos Branch President only sees Lagos pending registrations', () {
        final filtered = filterPending(branchPresidentLagos);
        expect(filtered.length, 1);
        expect(filtered.first.uid, 'applicant_2');
        expect(filtered.first.branchId, 'branch_lagos');
      });

      test('National President in national scope only sees national pending registrations', () {
        final filtered = filterPending(nationalPresident, isNationalScope: true);
        expect(filtered.length, 1);
        expect(filtered.first.uid, 'applicant_nat');
      });

      test('Super Admin in national scope only sees national pending registrations (branch applicants stay local)', () {
        final filtered = filterPending(superAdmin, isNationalScope: true);
        expect(filtered.length, 1);
        expect(filtered.first.uid, 'applicant_nat');
      });
    });

    group('Expense Branch Scoping', () {
      final expenseAba = ExpenseModel(
        id: 'exp_1',
        title: 'Aba Office Supplies',
        description: 'Stationery for Aba branch office',
        amount: 25000.0,
        category: ExpenseCategory.administration,
        expenseDate: now,
        createdBy: 'pres_aba',
        branchId: 'branch_aba',
        status: ExpenseStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      final expenseLagos = ExpenseModel(
        id: 'exp_2',
        title: 'Lagos Hall Rental',
        description: 'Meeting venue for Lagos branch',
        amount: 150000.0,
        category: ExpenseCategory.events,
        expenseDate: now,
        createdBy: 'pres_lagos',
        branchId: 'branch_lagos',
        status: ExpenseStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      final expenseNational = ExpenseModel(
        id: 'exp_nat',
        title: 'National Convention Venue Deposit',
        description: 'Venue deposit for national convention',
        amount: 500000.0,
        category: ExpenseCategory.events,
        expenseDate: now,
        createdBy: 'pres_national',
        branchId: 'national',
        status: ExpenseStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      final List<ExpenseModel> allExpenses = [expenseAba, expenseLagos, expenseNational];

      List<ExpenseModel> filterExpenses(UserModel viewer, {bool isNationalScope = false}) {
        final isNational = isNationalScope &&
            (viewer.nationalRole != null || viewer.role == UserRole.superAdmin);

        if (isNational) {
          return allExpenses.where((e) {
            return e.branchId == null ||
                e.branchId!.isEmpty ||
                e.branchId == 'national';
          }).toList();
        }
        if (viewer.role == UserRole.superAdmin) return allExpenses;

        return allExpenses.where((e) {
          if (e.branchId != null && e.branchId!.isNotEmpty) {
            return e.branchId == viewer.branchId;
          }
          return e.createdBy == viewer.uid;
        }).toList();
      }

      test('ExpenseModel roundtrip serialization preserves branchId', () {
        final map = expenseAba.toFirestore();
        expect(map['branchId'], 'branch_aba');

        final copied = expenseAba.copyWith(branchId: 'branch_new');
        expect(copied.branchId, 'branch_new');
      });

      test('Aba President only sees Aba expenses', () {
        final filtered = filterExpenses(branchPresidentAba);
        expect(filtered.length, 1);
        expect(filtered.first.id, 'exp_1');
        expect(filtered.first.branchId, 'branch_aba');
      });

      test('National President in national scope only sees national expenses (isolated from branch expenses)', () {
        final filtered = filterExpenses(nationalPresident, isNationalScope: true);
        expect(filtered.length, 1);
        expect(filtered.first.id, 'exp_nat');
        expect(filtered.first.branchId, 'national');
      });
    });

    group('Members & Payments Branch Scoping', () {
      final memberLagos1 = MemberModel(
        id: 'mem_l1',
        userId: 'user_l1',
        fullName: 'Lagos Member 1',
        email: 'l1@test.com',
        phoneNumber: '08077777777',
        branchId: 'branch_lagos',
        dateOfBirth: dob,
        joinedDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final memberLagos2 = MemberModel(
        id: 'mem_l2',
        userId: 'user_l2',
        fullName: 'Lagos Member 2',
        email: 'l2@test.com',
        phoneNumber: '08088888888',
        branchId: 'branch_lagos',
        dateOfBirth: dob,
        joinedDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final memberAba1 = MemberModel(
        id: 'mem_a1',
        userId: 'user_a1',
        fullName: 'Aba Member 1',
        email: 'a1@test.com',
        phoneNumber: '08099999999',
        branchId: 'branch_aba',
        dateOfBirth: dob,
        joinedDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final List<MemberModel> allMembers = [memberLagos1, memberLagos2, memberAba1];

      final paymentLagos = PaymentModel(
        id: 'pay_l1',
        memberId: 'mem_l1',
        amount: 50000.0,
        method: PaymentMethod.bankTransfer,
        status: PaymentStatus.approved,
        allocations: [
          const PaymentAllocationModel(obligationId: 'ob_lagos_1', amount: 50000.0),
        ],
        createdAt: now,
      );

      final paymentAba = PaymentModel(
        id: 'pay_a1',
        memberId: 'mem_a1',
        amount: 20000.0,
        method: PaymentMethod.cash,
        status: PaymentStatus.approved,
        allocations: [
          const PaymentAllocationModel(obligationId: 'ob_aba_1', amount: 20000.0),
        ],
        createdAt: now,
      );

      final paymentNational = PaymentModel(
        id: 'pay_nat_1',
        memberId: 'mem_l1',
        amount: 100000.0,
        method: PaymentMethod.online,
        status: PaymentStatus.approved,
        allocations: [
          const PaymentAllocationModel(obligationId: 'ob_nat_1', amount: 100000.0),
        ],
        notes: 'National Secretariat Building Levy',
        createdAt: now,
      );

      final List<PaymentModel> allPayments = [paymentLagos, paymentAba, paymentNational];
      final Set<String> nationalObligationIds = {'ob_nat_1'};

      List<MemberModel> filterMembers(UserModel viewer, {bool isNationalScope = false}) {
        final isNational = (isNationalScope && viewer.nationalRole != null) ||
            viewer.role == UserRole.superAdmin;
        if (isNational) return allMembers;
        return allMembers.where((m) => m.branchId == viewer.branchId).toList();
      }

      List<PaymentModel> filterPayments(
        UserModel viewer,
        List<MemberModel> members, {
        bool isNationalScope = false,
      }) {
        final isNational = isNationalScope &&
            (viewer.nationalRole != null || viewer.role == UserRole.superAdmin);

        if (isNational) {
          return allPayments.where((p) {
            if (p.allocations.isNotEmpty) {
              return p.allocations.any(
                (a) => nationalObligationIds.contains(a.obligationId),
              );
            }
            return (p.notes ?? '').toLowerCase().contains('national');
          }).toList();
        }

        if (viewer.role == UserRole.superAdmin) return allPayments;

        final branchMemberIds = <String>{};
        for (final m in members) {
          if (m.branchId == viewer.branchId) {
            branchMemberIds.add(m.id);
            if (m.userId.isNotEmpty) branchMemberIds.add(m.userId);
          }
        }
        branchMemberIds.add(viewer.uid);

        return allPayments.where((p) => branchMemberIds.contains(p.memberId)).toList();
      }

      test('Aba branch with 1 member sees only Aba member and Aba payments', () {
        final members = filterMembers(branchPresidentAba);
        expect(members.length, 1);
        expect(members.first.fullName, 'Aba Member 1');

        final payments = filterPayments(branchPresidentAba, members);
        expect(payments.length, 1);
        expect(payments.first.id, 'pay_a1');
        expect(payments.first.amount, 20000.0);
      });

      test('Aba branch president sees 0 members and 0 payments if Aba has no other members yet', () {
        final membersWithoutAba = [memberLagos1, memberLagos2];
        final viewerMembers = membersWithoutAba.where((m) => m.branchId == branchPresidentAba.branchId).toList();
        expect(viewerMembers, isEmpty);

        final branchMemberIds = {branchPresidentAba.uid};
        final payments = allPayments.where((p) => branchMemberIds.contains(p.memberId)).toList();
        expect(payments, isEmpty);
      });

      test('National President in national scope sees all members in national roll', () {
        final members = filterMembers(nationalPresident, isNationalScope: true);
        expect(members.length, 3);
      });

      test('National President in national scope only sees national payments (branch payments isolated)', () {
        final members = filterMembers(nationalPresident, isNationalScope: true);
        final payments = filterPayments(nationalPresident, members, isNationalScope: true);
        expect(payments.length, 1);
        expect(payments.first.id, 'pay_nat_1');
        expect(payments.first.amount, 100000.0);
      });
    });

    group('Levy & Obligation Branch Scoping', () {
      final nationalLevy = LevyModel(
        id: 'levy_nat',
        title: 'National Headquarters Building Levy',
        description: 'For national secretariat',
        type: ObligationType.specialLevy,
        amountPerMember: 100000.0,
        scope: 'national',
        dueDate: now.add(const Duration(days: 30)),
        createdBy: 'pres_national',
        createdAt: now,
        updatedAt: now,
      );

      final lagosBranchLevy = LevyModel(
        id: 'levy_lagos',
        title: 'Lagos Branch End of Year Party',
        description: 'Branch dues for celebration',
        type: ObligationType.monthlyDue,
        amountPerMember: 15000.0,
        scope: 'branch',
        branchId: 'branch_lagos',
        dueDate: now.add(const Duration(days: 15)),
        createdBy: 'pres_lagos',
        createdAt: now,
        updatedAt: now,
      );

      final abaBranchLevy = LevyModel(
        id: 'levy_aba',
        title: 'Aba Secretariat Furnishing',
        description: 'Furnishing Aba office',
        type: ObligationType.specialLevy,
        amountPerMember: 25000.0,
        scope: 'branch',
        branchId: 'branch_aba',
        dueDate: now.add(const Duration(days: 20)),
        createdBy: 'pres_aba',
        createdAt: now,
        updatedAt: now,
      );

      final List<LevyModel> allLevies = [nationalLevy, lagosBranchLevy, abaBranchLevy];

      List<LevyModel> filterLevies(UserModel viewer, {bool isNationalScope = false}) {
        final isNational = isNationalScope &&
            (viewer.nationalRole != null || viewer.role == UserRole.superAdmin);
        if (isNational) {
          return allLevies.where((l) => l.scope == 'national').toList();
        }
        if (viewer.role == UserRole.superAdmin) return allLevies;

        return allLevies.where((l) {
          return l.scope == 'national' || l.branchId == viewer.branchId;
        }).toList();
      }

      test('Aba President sees national levy and Aba levy, but not Lagos levy', () {
        final levies = filterLevies(branchPresidentAba);
        expect(levies.length, 2);
        expect(levies.map((l) => l.id), containsAll(['levy_nat', 'levy_aba']));
        expect(levies.map((l) => l.id), isNot(contains('levy_lagos')));
      });

      test('Lagos President sees national levy and Lagos levy, but not Aba levy', () {
        final levies = filterLevies(branchPresidentLagos);
        expect(levies.length, 2);
        expect(levies.map((l) => l.id), containsAll(['levy_nat', 'levy_lagos']));
        expect(levies.map((l) => l.id), isNot(contains('levy_aba')));
      });

      test('National President in national scope only sees national levies (branch levies isolated)', () {
        final levies = filterLevies(nationalPresident, isNationalScope: true);
        expect(levies.length, 1);
        expect(levies.first.id, 'levy_nat');
      });
    });

    group('National Branch Enrollment & Member Roster Privacy', () {
      final memberAbaRegular = MemberModel(
        id: 'mem_aba_1',
        userId: 'u_aba_1',
        fullName: 'Aba Local Member',
        email: 'aba1@test.com',
        phoneNumber: '08011110001',
        dateOfBirth: dob,
        joinedDate: now,
        branchId: 'branch_aba',
        branchName: 'Aba Branch',
        isEnrolledInNational: false,
        createdAt: now,
        updatedAt: now,
      );

      final memberAbaEnrolled = MemberModel(
        id: 'mem_aba_2',
        userId: 'u_aba_2',
        fullName: 'Aba Enrolled Member',
        email: 'aba2@test.com',
        phoneNumber: '08011110002',
        dateOfBirth: dob,
        joinedDate: now,
        branchId: 'branch_aba',
        branchName: 'Aba Branch',
        isEnrolledInNational: true,
        enrolledInNationalAt: now,
        enrolledInNationalBy: 'pres_aba',
        createdAt: now,
        updatedAt: now,
      );

      final memberLagosRegular = MemberModel(
        id: 'mem_lagos_1',
        userId: 'u_lagos_1',
        fullName: 'Lagos Local Member',
        email: 'lagos1@test.com',
        phoneNumber: '08022220001',
        dateOfBirth: dob,
        joinedDate: now,
        branchId: 'branch_lagos',
        branchName: 'Lagos Branch',
        isEnrolledInNational: false,
        createdAt: now,
        updatedAt: now,
      );

      final memberNationalExec = MemberModel(
        id: 'mem_nat_1',
        userId: 'u_nat_1',
        fullName: 'National Officer',
        email: 'nat1@test.com',
        phoneNumber: '08033330001',
        dateOfBirth: dob,
        joinedDate: now,
        branchId: 'branch_lagos',
        branchName: 'Lagos Branch',
        nationalRole: UserRole.president,
        isEnrolledInNational: true,
        createdAt: now,
        updatedAt: now,
      );

      final allMembers = [
        memberAbaRegular,
        memberAbaEnrolled,
        memberLagosRegular,
        memberNationalExec,
      ];

      List<MemberModel> filterMembers(UserModel viewer, {bool isNationalScope = false}) {
        if (isNationalScope) {
          return allMembers
              .where((m) =>
                  m.isEnrolledInNational ||
                  m.nationalRole != null ||
                  m.branchId == 'national')
              .toList();
        }
        if (viewer.role == UserRole.superAdmin) {
          return allMembers;
        }
        if (viewer.branchId != null && viewer.branchId!.isNotEmpty) {
          return allMembers.where((m) => m.branchId == viewer.branchId).toList();
        }
        return allMembers;
      }

      test('Aba President sees all Aba members (both regular and enrolled)', () {
        final members = filterMembers(branchPresidentAba);
        expect(members.length, 2);
        expect(members.map((m) => m.id), containsAll(['mem_aba_1', 'mem_aba_2']));
        expect(members.map((m) => m.id), isNot(contains('mem_lagos_1')));
      });

      test('National President in national scope only sees enrolled members and national officers', () {
        final members = filterMembers(nationalPresident, isNationalScope: true);
        expect(members.length, 2);
        expect(members.map((m) => m.id), containsAll(['mem_aba_2', 'mem_nat_1']));
        // Regular non-enrolled members are strictly hidden from national view
        expect(members.map((m) => m.id), isNot(contains('mem_aba_1')));
        expect(members.map((m) => m.id), isNot(contains('mem_lagos_1')));
      });

      test('MemberModel roundtrip serialization preserves isEnrolledInNational', () {
        final map = memberAbaEnrolled.toFirestore();
        expect(map['isEnrolledInNational'], true);
        expect(map['enrolledInNationalBy'], 'pres_aba');
      });
    });

    group('Meeting & Attendance Privacy Scoping', () {
      final abaBranchMeeting = MeetingModel(
        id: 'meet_aba',
        title: 'Aba Branch Monthly Meeting',
        meetingDate: now,
        createdBy: 'pres_aba',
        scope: 'branch',
        branchId: 'branch_aba',
        createdAt: now,
        updatedAt: now,
      );

      final lagosBranchMeeting = MeetingModel(
        id: 'meet_lagos',
        title: 'Lagos Branch General Meeting',
        meetingDate: now,
        createdBy: 'pres_lagos',
        scope: 'branch',
        branchId: 'branch_lagos',
        createdAt: now,
        updatedAt: now,
      );

      final nationalMeeting = MeetingModel(
        id: 'meet_national',
        title: 'National Executive Council Meeting',
        meetingDate: now,
        createdBy: 'pres_national',
        scope: 'national',
        branchId: 'national',
        createdAt: now,
        updatedAt: now,
      );

      final allMeetings = [abaBranchMeeting, lagosBranchMeeting, nationalMeeting];

      List<MeetingModel> filterMeetings(UserModel viewer, {bool isNationalScope = false}) {
        if (isNationalScope) {
          return allMeetings
              .where((m) => m.scope == 'national' || m.branchId == 'national')
              .toList();
        }
        if (viewer.role == UserRole.superAdmin) {
          return allMeetings;
        }
        if (viewer.branchId != null && viewer.branchId!.isNotEmpty) {
          return allMeetings
              .where((m) =>
                  m.branchId == viewer.branchId ||
                  (m.scope == 'national' && m.targetAudience == 'all') ||
                  (m.branchId == null && m.scope != 'branch'))
              .toList();
        }
        return allMeetings;
      }

      test('National President in national scope cannot see branch meetings', () {
        final meetings = filterMeetings(nationalPresident, isNationalScope: true);
        expect(meetings.length, 1);
        expect(meetings.first.id, 'meet_national');
        expect(meetings.map((m) => m.id), isNot(contains('meet_aba')));
        expect(meetings.map((m) => m.id), isNot(contains('meet_lagos')));
      });

      test('Aba President sees Aba meetings and global national meetings', () {
        final meetings = filterMeetings(branchPresidentAba);
        expect(meetings.length, 2);
        expect(meetings.map((m) => m.id), containsAll(['meet_aba', 'meet_national']));
        expect(meetings.map((m) => m.id), isNot(contains('meet_lagos')));
      });
    });

    group('Announcement Privacy Scoping', () {
      final abaBranchAnnouncement = AnnouncementModel(
        id: 'ann_aba_meeting',
        organizationId: 'org_1',
        title: '📅 Aba Branch Meeting Announcement',
        body: 'Details for upcoming Aba meeting',
        category: AnnouncementCategory.meeting,
        createdBy: 'pres_aba',
        targetAudience: 'branch',
        targetBranchId: 'branch_aba',
        createdAt: now,
        updatedAt: now,
      );

      final nationalAnnouncement = AnnouncementModel(
        id: 'ann_national',
        organizationId: 'org_1',
        title: '📢 National Assembly Announcement',
        body: 'National update for all members',
        category: AnnouncementCategory.general,
        createdBy: 'pres_national',
        targetAudience: 'all',
        createdAt: now,
        updatedAt: now,
      );

      test('National executive cannot see branch meeting announcements for other branches', () {
        final canSeeAbaMeeting = abaBranchAnnouncement.isVisibleTo(nationalPresident);
        expect(canSeeAbaMeeting, isFalse);
      });

      test('Aba President can see Aba meeting announcement', () {
        final canSeeAbaMeeting = abaBranchAnnouncement.isVisibleTo(branchPresidentAba);
        expect(canSeeAbaMeeting, isTrue);
      });

      test('National announcement is visible to all users', () {
        expect(nationalAnnouncement.isVisibleTo(branchPresidentAba), isTrue);
        expect(nationalAnnouncement.isVisibleTo(nationalPresident), isTrue);
      });

      test('Sole member of a new branch cannot see meeting announcements from other branches', () {
        final soleMemberNewBranch = UserModel(
          uid: 'user_sole_new',
          organizationId: 'org_1',
          email: 'sole_member@newbranch.com',
          displayName: 'Sole New Branch Member',
          phoneNumber: '08099999999',
          role: UserRole.member,
          branchId: 'branch_kano',
          branchName: 'Kano Branch',
          createdAt: now,
        );

        // Aba branch meeting announcement
        expect(abaBranchAnnouncement.isVisibleTo(soleMemberNewBranch), isFalse);

        // Legacy meeting announcement without targetBranchId created by Aba president
        final legacyAbaMeetingAnnouncement = AnnouncementModel(
          id: 'ann_legacy_meet',
          organizationId: 'org_1',
          title: '📅 Upcoming Meeting: Monthly Aba Review',
          body: 'Aba monthly review meeting',
          category: AnnouncementCategory.meeting,
          createdBy: 'pres_aba',
          targetAudience: 'all',
          createdAt: now,
          updatedAt: now,
        );
        expect(legacyAbaMeetingAnnouncement.isVisibleTo(soleMemberNewBranch), isFalse);

        // Meeting announcement for Kano branch is visible to Kano member
        final kanoMeetingAnnouncement = AnnouncementModel(
          id: 'ann_kano_meeting',
          organizationId: 'org_1',
          title: '📅 Upcoming Meeting: Kano Inaugural Meeting',
          body: 'First Kano meeting',
          category: AnnouncementCategory.meeting,
          createdBy: 'user_sole_new',
          targetAudience: 'branch',
          targetBranchId: 'branch_kano',
          createdAt: now,
          updatedAt: now,
        );
        expect(kanoMeetingAnnouncement.isVisibleTo(soleMemberNewBranch), isTrue);

        // Global national announcement is visible to Kano member
        expect(nationalAnnouncement.isVisibleTo(soleMemberNewBranch), isTrue);
      });

      test('SuperAdmin assigned to a branch cannot see other branch meeting announcements', () {
        final superAdminInBranch = UserModel(
          uid: 'super_admin_in_branch',
          organizationId: 'org_1',
          email: 'admin_in_branch@test.com',
          displayName: 'Admin In Kano',
          phoneNumber: '08088888888',
          role: UserRole.superAdmin,
          branchId: 'branch_kano',
          branchName: 'Kano Branch',
          createdAt: now,
        );

        // Cannot see Aba meeting announcement even though user is superAdmin
        expect(abaBranchAnnouncement.isVisibleTo(superAdminInBranch), isFalse);
      });

      test('Branch scoped upcoming meetings filter correctly for branch member', () {
        final meetings = [
          MeetingModel(
            id: 'meet_aba',
            organizationId: 'org_1',
            title: 'Aba General Meeting',
            meetingDate: now.add(const Duration(days: 2)),
            createdBy: 'pres_aba',
            branchId: 'branch_aba',
            createdAt: now,
            updatedAt: now,
          ),
          MeetingModel(
            id: 'meet_kano',
            organizationId: 'org_1',
            title: 'Kano Inaugural Meeting',
            meetingDate: now.add(const Duration(days: 3)),
            createdBy: 'user_sole_new',
            branchId: 'branch_kano',
            createdAt: now,
            updatedAt: now,
          ),
          MeetingModel(
            id: 'meet_national',
            organizationId: 'org_1',
            title: 'National Convention Meeting',
            meetingDate: now.add(const Duration(days: 5)),
            createdBy: 'pres_national',
            scope: 'national',
            targetAudience: 'all',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        // Member of Kano branch
        final kanoUser = UserModel(
          uid: 'user_sole_new',
          organizationId: 'org_1',
          email: 'sole_member@newbranch.com',
          displayName: 'Sole New Branch Member',
          phoneNumber: '08099999999',
          role: UserRole.member,
          branchId: 'branch_kano',
          createdAt: now,
        );

        // Filter replicating meetingsStreamProvider logic
        final visibleToKano = meetings.where((m) {
          if (kanoUser.branchId != null && kanoUser.branchId!.isNotEmpty) {
            return m.branchId == kanoUser.branchId ||
                (m.scope == 'national' && m.targetAudience == 'all');
          }
          return true;
        }).toList();

        expect(visibleToKano.length, 2);
        expect(visibleToKano.any((m) => m.id == 'meet_aba'), isFalse);
        expect(visibleToKano.any((m) => m.id == 'meet_kano'), isTrue);
        expect(visibleToKano.any((m) => m.id == 'meet_national'), isTrue);
      });

      test('Upcoming meeting card hides meetings with null branchId and other branches', () {
        final legacyNullBranchMeeting = MeetingModel(
          id: 'meet_legacy_null',
          organizationId: 'org_1',
          title: 'Legacy Meeting Without Branch',
          meetingDate: now.add(const Duration(days: 1)),
          createdBy: 'pres_aba',
          createdAt: now,
          updatedAt: now,
        );

        final kanoUser = UserModel(
          uid: 'user_sole_new',
          organizationId: 'org_1',
          email: 'sole_member@newbranch.com',
          displayName: 'Sole New Branch Member',
          phoneNumber: '08099999999',
          role: UserRole.member,
          branchId: 'branch_kano',
          createdAt: now,
        );

        bool isMeetingVisible(MeetingModel m, UserModel? user) {
          final userBranchId = user?.branchId;
          if (userBranchId != null && userBranchId.isNotEmpty) {
            final isGlobalNational =
                m.scope == 'national' && m.targetAudience == 'all';
            if (!isGlobalNational) {
              if (m.branchId == null || m.branchId != userBranchId) {
                return false;
              }
            }
          } else {
            if (m.scope != 'national') {
              return false;
            }
          }
          return true;
        }

        expect(isMeetingVisible(legacyNullBranchMeeting, kanoUser), isFalse);
      });
    });
  });
}
