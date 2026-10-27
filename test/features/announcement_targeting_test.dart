import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';

void main() {
  group('AnnouncementModel Audience Targeting Tests', () {
    final now = DateTime.now();

    final regularMemberBranchA = UserModel(
      uid: 'user_1',
      organizationId: 'org_1',
      email: 'member_a@test.com',
      displayName: 'Member A',
      phoneNumber: '08011111111',
      role: UserRole.member,
      branchId: 'branch_a',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    final regularMemberBranchB = UserModel(
      uid: 'user_2',
      organizationId: 'org_1',
      email: 'member_b@test.com',
      displayName: 'Member B',
      phoneNumber: '08022222222',
      role: UserRole.member,
      branchId: 'branch_b',
      branchName: 'Abuja Branch',
      createdAt: now,
    );

    final branchExecA = UserModel(
      uid: 'user_3',
      organizationId: 'org_1',
      email: 'exec_a@test.com',
      displayName: 'Secretary Branch A',
      phoneNumber: '08033333333',
      role: UserRole.secretary,
      branchId: 'branch_a',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    final branchExecB = UserModel(
      uid: 'user_4',
      organizationId: 'org_1',
      email: 'exec_b@test.com',
      displayName: 'Secretary Branch B',
      phoneNumber: '08044444444',
      role: UserRole.secretary,
      branchId: 'branch_b',
      branchName: 'Abuja Branch',
      createdAt: now,
    );

    final nationalPro = UserModel(
      uid: 'user_5',
      organizationId: 'org_1',
      email: 'national_pro@test.com',
      displayName: 'National PRO',
      phoneNumber: '08055555555',
      role: UserRole.member,
      nationalRole: UserRole.publicRelationsOfficer,
      branchId: 'branch_a',
      branchName: 'Lagos Branch',
      createdAt: now,
    );

    test('Everyone (all) announcement is visible to all members and executives', () {
      final announcement = AnnouncementModel(
        id: 'ann_1',
        organizationId: 'org_1',
        title: 'General Convention',
        body: 'Welcome everyone.',
        category: AnnouncementCategory.general,
        targetAudience: 'all',
        createdBy: 'user_5',
        createdAt: now,
        updatedAt: now,
      );

      expect(announcement.isVisibleTo(regularMemberBranchA), isTrue);
      expect(announcement.isVisibleTo(regularMemberBranchB), isTrue);
      expect(announcement.isVisibleTo(branchExecA), isTrue);
      expect(announcement.isVisibleTo(branchExecB), isTrue);
      expect(announcement.isVisibleTo(nationalPro), isTrue);
      expect(announcement.audienceLabel, 'Everyone');
    });

    test('All Executives announcement is only visible to executives', () {
      final announcement = AnnouncementModel(
        id: 'ann_2',
        organizationId: 'org_1',
        title: 'Executive Council Meeting',
        body: 'Quarterly review.',
        category: AnnouncementCategory.meeting,
        targetAudience: 'allExecutives',
        createdBy: 'user_5',
        createdAt: now,
        updatedAt: now,
      );

      expect(announcement.isVisibleTo(regularMemberBranchA), isFalse);
      expect(announcement.isVisibleTo(regularMemberBranchB), isFalse);
      expect(announcement.isVisibleTo(branchExecA), isTrue);
      expect(announcement.isVisibleTo(branchExecB), isTrue);
      expect(announcement.isVisibleTo(nationalPro), isTrue);
      expect(announcement.audienceLabel, 'All Executives');
    });

    test('Specific Branch (all members) announcement is only visible to that branch and national officers', () {
      final announcement = AnnouncementModel(
        id: 'ann_3',
        organizationId: 'org_1',
        title: 'Lagos Branch Sanitation',
        body: 'Local cleanup day.',
        category: AnnouncementCategory.event,
        targetAudience: 'branch',
        targetBranchId: 'branch_a',
        targetBranchName: 'Lagos Branch',
        createdBy: 'user_5',
        createdAt: now,
        updatedAt: now,
      );

      expect(announcement.isVisibleTo(regularMemberBranchA), isTrue);
      expect(announcement.isVisibleTo(branchExecA), isTrue);
      expect(announcement.isVisibleTo(regularMemberBranchB), isFalse);
      expect(announcement.isVisibleTo(branchExecB), isFalse);
      expect(announcement.isVisibleTo(nationalPro), isTrue);
      expect(announcement.audienceLabel, 'Lagos Branch (All Members)');
    });

    test('Specific Branch (executives only) is restricted to that branch executives and national officers', () {
      final announcement = AnnouncementModel(
        id: 'ann_4',
        organizationId: 'org_1',
        title: 'Lagos Executive Disciplinary Committee',
        body: 'Private session.',
        category: AnnouncementCategory.meeting,
        targetAudience: 'branchExecutives',
        targetBranchId: 'branch_a',
        targetBranchName: 'Lagos Branch',
        createdBy: 'user_5',
        createdAt: now,
        updatedAt: now,
      );

      expect(announcement.isVisibleTo(regularMemberBranchA), isFalse);
      expect(announcement.isVisibleTo(branchExecA), isTrue);
      expect(announcement.isVisibleTo(regularMemberBranchB), isFalse);
      expect(announcement.isVisibleTo(branchExecB), isFalse);
      expect(announcement.isVisibleTo(nationalPro), isTrue);
      expect(announcement.audienceLabel, 'Lagos Branch (Executives)');
    });

    test('National Executives Only announcement is only visible to national officers', () {
      final announcement = AnnouncementModel(
        id: 'ann_5',
        organizationId: 'org_1',
        title: 'National EXCO Strategy Session',
        body: 'National leadership only.',
        category: AnnouncementCategory.meeting,
        targetAudience: 'nationalExecutives',
        createdBy: 'admin_1',
        createdAt: now,
        updatedAt: now,
      );

      expect(announcement.isVisibleTo(regularMemberBranchA), isFalse);
      expect(announcement.isVisibleTo(regularMemberBranchB), isFalse);
      expect(announcement.isVisibleTo(branchExecA), isFalse);
      expect(announcement.isVisibleTo(branchExecB), isFalse);
      expect(announcement.isVisibleTo(nationalPro), isTrue);
      expect(announcement.audienceLabel, 'National Executives');
    });
  });
}
