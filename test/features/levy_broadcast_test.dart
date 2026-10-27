import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/repositories/notification_repository.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';

void main() {
  group('Levy Automated Broadcast & Notification Tests', () {
    final now = DateTime.now();
    final notifRepo = NotificationRepository();

    final memberBranchA = UserModel(
      uid: 'user_a',
      organizationId: 'org_1',
      email: 'member_a@test.com',
      displayName: 'Member Branch A',
      phoneNumber: '08011111111',
      role: UserRole.member,
      branchId: 'branch_a',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    final memberBranchB = UserModel(
      uid: 'user_b',
      organizationId: 'org_1',
      email: 'member_b@test.com',
      displayName: 'Member Branch B',
      phoneNumber: '08022222222',
      role: UserRole.member,
      branchId: 'branch_b',
      branchName: 'Abuja Branch',
      createdAt: now,
    );

    final branchTreasurerA = UserModel(
      uid: 'treasurer_a',
      organizationId: 'org_1',
      email: 'treasurer_a@test.com',
      displayName: 'Treasurer Branch A',
      phoneNumber: '08033333333',
      role: UserRole.treasurer,
      branchId: 'branch_a',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    final nationalFinSec = UserModel(
      uid: 'nat_finsec',
      organizationId: 'org_1',
      email: 'nat_finsec@test.com',
      displayName: 'National Financial Secretary',
      phoneNumber: '08044444444',
      role: UserRole.member,
      nationalRole: UserRole.financialSecretary,
      branchId: 'branch_b',
      branchName: 'Abuja Branch',
      createdAt: now,
    );

    test('National levy notification reaches all members and executives nationwide', () {
      final nationalLevyNotif = NotificationModel(
        id: 'notif_national_1',
        title: '🏛️ National Obligation: Annual National Levy',
        body: '₦10,000.00 due by Dec 31, 2026. Tap to view and pay.',
        type: 'levy',
        organizationId: 'org_1',
        targetBranchId: null,
        payload: 'levy_101',
        receivedAt: now,
      );

      // Check member in Branch A
      expect(
        notifRepo.isNotificationForUser(
          nationalLevyNotif,
          memberBranchA.uid,
          memberBranchA.role,
          branchId: memberBranchA.branchId,
          isNationalExecutive: memberBranchA.isNationalExecutive,
        ),
        isTrue,
      );

      // Check member in Branch B
      expect(
        notifRepo.isNotificationForUser(
          nationalLevyNotif,
          memberBranchB.uid,
          memberBranchB.role,
          branchId: memberBranchB.branchId,
          isNationalExecutive: memberBranchB.isNationalExecutive,
        ),
        isTrue,
      );

      // Check Branch Treasurer
      expect(
        notifRepo.isNotificationForUser(
          nationalLevyNotif,
          branchTreasurerA.uid,
          branchTreasurerA.role,
          branchId: branchTreasurerA.branchId,
          isNationalExecutive: branchTreasurerA.isNationalExecutive,
        ),
        isTrue,
      );

      // Check National FinSec
      expect(
        notifRepo.isNotificationForUser(
          nationalLevyNotif,
          nationalFinSec.uid,
          nationalFinSec.role,
          branchId: nationalFinSec.branchId,
          isNationalExecutive: nationalFinSec.isNationalExecutive,
        ),
        isTrue,
      );
    });

    test('National executive levy notice is received by branch officers & national leaders only', () {
      final execLevyNotif = NotificationModel(
        id: 'notif_exec_1',
        title: '📢 Executive Notice: National Levy Declared',
        body: 'National Financial Directorate announced "Annual National Levy" (₦10,000.00). Please monitor branch compliance.',
        type: 'levy',
        targetRole: 'executives',
        organizationId: 'org_1',
        payload: 'levy_101',
        receivedAt: now,
      );

      // Regular members should NOT receive executive notices
      expect(
        notifRepo.isNotificationForUser(
          execLevyNotif,
          memberBranchA.uid,
          memberBranchA.role,
          branchId: memberBranchA.branchId,
          isNationalExecutive: memberBranchA.isNationalExecutive,
        ),
        isFalse,
      );

      expect(
        notifRepo.isNotificationForUser(
          execLevyNotif,
          memberBranchB.uid,
          memberBranchB.role,
          branchId: memberBranchB.branchId,
          isNationalExecutive: memberBranchB.isNationalExecutive,
        ),
        isFalse,
      );

      // Branch Treasurer SHOULD receive it to oversee remittance
      expect(
        notifRepo.isNotificationForUser(
          execLevyNotif,
          branchTreasurerA.uid,
          branchTreasurerA.role,
          branchId: branchTreasurerA.branchId,
          isNationalExecutive: branchTreasurerA.isNationalExecutive,
        ),
        isTrue,
      );

      // National Executive SHOULD receive it
      expect(
        notifRepo.isNotificationForUser(
          execLevyNotif,
          nationalFinSec.uid,
          nationalFinSec.role,
          branchId: nationalFinSec.branchId,
          isNationalExecutive: nationalFinSec.isNationalExecutive,
        ),
        isTrue,
      );
    });

    test('Branch-level levy notification is only received by that branch and national officers', () {
      final branchLevyNotif = NotificationModel(
        id: 'notif_branch_a_1',
        title: '💳 New Due / Levy: Branch Hall Renovation',
        body: '₦2,500.00 due by Nov 30, 2026. Tap to view and pay.',
        type: 'levy',
        targetBranchId: 'branch_a',
        organizationId: 'org_1',
        payload: 'levy_202',
        receivedAt: now,
      );

      // Branch A member gets it
      expect(
        notifRepo.isNotificationForUser(
          branchLevyNotif,
          memberBranchA.uid,
          memberBranchA.role,
          branchId: memberBranchA.branchId,
          isNationalExecutive: memberBranchA.isNationalExecutive,
        ),
        isTrue,
      );

      // Branch B member DOES NOT get it
      expect(
        notifRepo.isNotificationForUser(
          branchLevyNotif,
          memberBranchB.uid,
          memberBranchB.role,
          branchId: memberBranchB.branchId,
          isNationalExecutive: memberBranchB.isNationalExecutive,
        ),
        isFalse,
      );

      // National FinSec gets oversight access
      expect(
        notifRepo.isNotificationForUser(
          branchLevyNotif,
          nationalFinSec.uid,
          nationalFinSec.role,
          branchId: nationalFinSec.branchId,
          isNationalExecutive: nationalFinSec.isNationalExecutive,
        ),
        isTrue,
      );
    });

    test('National levy announcement is pinned and visible to all members', () {
      final announcement = AnnouncementModel(
        id: 'ann_nat_1',
        organizationId: 'org_1',
        title: '🏛️ National Decree: Annual National Levy',
        body: 'National levy details...',
        category: AnnouncementCategory.contribution,
        isPinned: true,
        targetAudience: 'all',
        createdBy: nationalFinSec.uid,
        createdAt: now,
        updatedAt: now,
      );

      expect(announcement.isPinned, isTrue);
      expect(announcement.isVisibleTo(memberBranchA), isTrue);
      expect(announcement.isVisibleTo(memberBranchB), isTrue);
      expect(announcement.isVisibleTo(branchTreasurerA), isTrue);
      expect(announcement.isVisibleTo(nationalFinSec), isTrue);
    });
  });
}
