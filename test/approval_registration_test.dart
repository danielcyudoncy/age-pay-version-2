import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/auth/models/co_founder_invitation_model.dart';
import 'package:cls/features/auth/repositories/co_founder_invitation_repository.dart';

void main() {
  group('Approval-Based Registration Models & Utilities', () {
    final now = DateTime(2026, 10, 20);

    test('UserModel supports pendingApproval status and branch attributes', () {
      final user = UserModel(
        uid: 'user-1',
        organizationId: 'org-1',
        email: 'test@example.com',
        displayName: 'John Doe',
        phoneNumber: '08031234567',
        role: UserRole.member,
        requestedRole: UserRole.financialSecretary,
        status: AccountStatus.pendingApproval,
        branchId: 'branch-1',
        branchName: 'Lagos Branch',
        coFounderName: 'Chief Emeka',
        coFounderPhone: '08039876543',
        createdAt: now,
        isActive: false,
      );

      expect(user.status, AccountStatus.pendingApproval);
      expect(user.isActive, isFalse);
      expect(user.requestedRole, UserRole.financialSecretary);
      expect(user.branchName, 'Lagos Branch');
      expect(user.coFounderName, 'Chief Emeka');

      final approved = user.copyWith(
        status: AccountStatus.approved,
        isActive: true,
        role: user.requestedRole,
      );
      expect(approved.status, AccountStatus.approved);
      expect(approved.isActive, isTrue);
      expect(approved.role, UserRole.financialSecretary);
    });

    test('MemberModel supports branch and pending approval status', () {
      final member = MemberModel(
        id: 'mem-1',
        userId: 'user-1',
        fullName: 'John Doe',
        email: 'test@example.com',
        phoneNumber: '08031234567',
        dateOfBirth: DateTime(1995, 5, 20),
        joinedDate: now,
        branchId: 'branch-1',
        branchName: 'Lagos Branch',
        status: 'pending_approval',
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(member.status, 'pending_approval');
      expect(member.isActive, isFalse);
      expect(member.branchName, 'Lagos Branch');

      final approvedMember = member.copyWith(
        status: 'approved',
        isActive: true,
      );
      expect(approvedMember.status, 'approved');
      expect(approvedMember.isActive, isTrue);
    });

    test('BranchModel creates and copies correctly', () {
      final branch = BranchModel(
        id: 'b-1',
        organizationId: 'org-1',
        name: 'Abiriba Central Branch',
        state: 'Abia',
        city: 'Abiriba',
        presidentId: 'pres-1',
        presidentName: 'Chief Kalu',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(branch.name, 'Abiriba Central Branch');
      expect(branch.organizationId, 'org-1');
      expect(branch.state, 'Abia');

      final updated = branch.copyWith(name: 'Enugu Branch', state: 'Enugu');
      expect(updated.name, 'Enugu Branch');
      expect(updated.state, 'Enugu');
    });

    test('CoFounderInvitationModel initializes correctly', () {
      final invitation = CoFounderInvitationModel(
        id: 'inv-1',
        organizationId: 'org-1',
        organizationName: 'Udoka Age Grade',
        branchName: 'Lagos Branch',
        presidentUid: 'p-1',
        presidentName: 'Chief Emeka',
        presidentPhone: '08031112222',
        secretaryName: 'Chief Anya',
        secretaryPhone: '08039998888',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      expect(invitation.organizationName, 'Udoka Age Grade');
      expect(invitation.secretaryPhone, '08039998888');
      expect(invitation.status, 'pending');

      final approved = invitation.copyWith(status: 'approved');
      expect(approved.status, 'approved');
    });

    test('CoFounderInvitationRepository phone normalization', () {
      expect(
        CoFounderInvitationRepository.normalizePhone('+234 803 123 4567'),
        '08031234567',
      );
      expect(
        CoFounderInvitationRepository.normalizePhone('0803-123-4567'),
        '08031234567',
      );
      expect(
        CoFounderInvitationRepository.normalizePhone('2348031234567'),
        '08031234567',
      );
    });
  });
}
