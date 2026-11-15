import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/members/models/member_model.dart';

void main() {
  group('MembershipLifecycleStatus & MemberModel Integration Tests', () {
    test('displayName returns clear, human-readable labels', () {
      expect(MembershipLifecycleStatus.active.displayName, 'Active');
      expect(MembershipLifecycleStatus.probationary.displayName, 'Probationary');
      expect(MembershipLifecycleStatus.suspended.displayName, 'Suspended');
      expect(MembershipLifecycleStatus.diaspora.displayName, 'Diaspora');
      expect(MembershipLifecycleStatus.deceased.displayName, 'Deceased');
    });

    MemberModel createMember({
      required String status,
      bool isActive = true,
    }) {
      return MemberModel(
        id: 'mem_test',
        userId: 'usr_test',
        fullName: 'Test Member',
        email: 'test@example.com',
        phoneNumber: '+2348000000000',
        dateOfBirth: DateTime(1990, 1, 1),
        joinedDate: DateTime(2020, 1, 1),
        status: status,
        isActive: isActive,
        createdAt: DateTime(2020, 1, 1),
        updatedAt: DateTime.now(),
      );
    }

    test('lifecycleStatus maps active standing properly', () {
      final m1 = createMember(status: 'active', isActive: true);
      expect(m1.lifecycleStatus, MembershipLifecycleStatus.active);

      final mLegacy = createMember(status: 'approved', isActive: true);
      expect(mLegacy.lifecycleStatus, MembershipLifecycleStatus.active);
    });

    test('lifecycleStatus maps probationary and new applicants properly', () {
      final mProb = createMember(status: 'probationary', isActive: true);
      expect(mProb.lifecycleStatus, MembershipLifecycleStatus.probationary);

      final mPending = createMember(status: 'pending_approval', isActive: true);
      expect(mPending.lifecycleStatus, MembershipLifecycleStatus.probationary);

      final mNew = createMember(status: 'new', isActive: true);
      expect(mNew.lifecycleStatus, MembershipLifecycleStatus.probationary);
    });

    test('lifecycleStatus respects suspension flag and string status', () {
      final mSusp = createMember(status: 'suspended', isActive: false);
      expect(mSusp.lifecycleStatus, MembershipLifecycleStatus.suspended);

      final mInactive = createMember(status: 'approved', isActive: false);
      expect(mInactive.lifecycleStatus, MembershipLifecycleStatus.suspended);
    });

    test('lifecycleStatus maps diaspora and transferred status', () {
      final mDiaspora = createMember(status: 'diaspora', isActive: true);
      expect(mDiaspora.lifecycleStatus, MembershipLifecycleStatus.diaspora);

      final mTransferred = createMember(status: 'transferred', isActive: true);
      expect(mTransferred.lifecycleStatus, MembershipLifecycleStatus.diaspora);
    });

    test('lifecycleStatus maps deceased / in memoriam status', () {
      final mDeceased = createMember(status: 'deceased', isActive: false);
      expect(mDeceased.lifecycleStatus, MembershipLifecycleStatus.deceased);
    });
  });
}
