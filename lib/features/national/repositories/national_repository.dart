import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';
import '../../admin/models/branch_model.dart';
import '../../auth/models/user_model.dart';
import '../../payments/models/payment_model.dart';
import '../models/branch_compliance_report.dart';
import '../models/national_contribution_record.dart';

class NationalRepository {
  final FirebaseFirestore _firestore;

  NationalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Assigns a member to a National Executive post and updates the National Branch officer record.
  Future<void> assignNationalOfficer({
    required String organizationId,
    required String uid,
    required String displayName,
    required UserRole nationalRole,
  }) async {
    final batch = _firestore.batch();

    // 1. Update user profile
    final userRef = _firestore.collection('users').doc(uid);
    batch.update(userRef, {
      'nationalRole': nationalRole.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update National branch officer if national branch exists
    final nationalBranchQuery = await _firestore
        .collection('branches')
        .where('organizationId', isEqualTo: organizationId)
        .where('isNational', isEqualTo: true)
        .limit(1)
        .get();

    if (nationalBranchQuery.docs.isNotEmpty) {
      final branchRef = nationalBranchQuery.docs.first.reference;
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (nationalRole) {
        case UserRole.president:
          updates['presidentId'] = uid;
          updates['presidentName'] = displayName;
          break;
        case UserRole.secretary:
          updates['secretaryId'] = uid;
          updates['secretaryName'] = displayName;
          break;
        case UserRole.financialSecretary:
          updates['financialSecretaryId'] = uid;
          updates['financialSecretaryName'] = displayName;
          break;
        case UserRole.treasurer:
          updates['treasurerId'] = uid;
          updates['treasurerName'] = displayName;
          break;
        default:
          break;
      }
      batch.update(branchRef, updates);
    }

    await batch.commit();
  }

  /// Removes national executive post from a user.
  Future<void> removeNationalOfficer({
    required String organizationId,
    required String uid,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'nationalRole': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates receiving bank details for a branch or the National branch.
  Future<void> updateBranchBankDetails({
    required String branchId,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    await _firestore.collection('branches').doc(branchId).update({
      'bankName': bankName.trim(),
      'accountNumber': accountNumber.trim(),
      'accountName': accountName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ensures a designated National Chapter branch document exists for the organization.
  Future<BranchModel> ensureNationalBranchExists(String organizationId) async {
    final query = await _firestore
        .collection('branches')
        .where('organizationId', isEqualTo: organizationId)
        .where('isNational', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return BranchModel.fromFirestore(query.docs.first);
    }

    // Create National Branch
    final docRef = _firestore.collection('branches').doc();
    final now = DateTime.now();
    final nationalBranch = BranchModel(
      id: docRef.id,
      organizationId: organizationId,
      name: 'National Assembly',
      state: 'National HQ',
      city: 'Central',
      isNational: true,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(nationalBranch.toFirestore());
    return nationalBranch;
  }

  /// Stream of Branch Compliance Reports for National Executives.
  /// Combines all branches, active members, and obligations.
  Stream<List<BranchComplianceReport>> getBranchComplianceLeaderboard(
    String organizationId, {
    String? levyId,
  }) {
    // Listen to branches
    return _firestore
        .collection('branches')
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((branchesSnap) async {
      final branches =
          branchesSnap.docs.map((d) => BranchModel.fromFirestore(d)).toList();

      if (branches.isEmpty) return <BranchComplianceReport>[];

      // Fetch active users in the org
      final usersSnap = await _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .where('isActive', isEqualTo: true)
          .get();

      // Map users to branches: branchId -> Set<uid>
      final branchMembersMap = <String, Set<String>>{};
      for (final branch in branches) {
        branchMembersMap[branch.id] = <String>{};
      }

      for (final userDoc in usersSnap.docs) {
        final data = userDoc.data();
        final branchId = data['branchId'] as String?;
        if (branchId != null && branchMembersMap.containsKey(branchId)) {
          branchMembersMap[branchId]!.add(userDoc.id);
        }
      }

      // Query obligations (national scope or specific levyId)
      Query obligationsQuery = _firestore
          .collection('obligations')
          .where('organizationId', isEqualTo: organizationId);

      if (levyId != null && levyId.isNotEmpty) {
        obligationsQuery = obligationsQuery.where('levyId', isEqualTo: levyId);
      } else {
        obligationsQuery =
            obligationsQuery.where('scope', isEqualTo: 'national');
      }

      final obligationsSnap = await obligationsQuery.get();

      // Aggregate obligations by member and match to branch
      final memberExpected = <String, double>{};
      final memberPaid = <String, double>{};

      for (final doc in obligationsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final mId = data['memberId'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final isWaived = data['isWaived'] == true;

        if (isWaived) continue;

        memberExpected[mId] = (memberExpected[mId] ?? 0.0) + amount;
        memberPaid[mId] = (memberPaid[mId] ?? 0.0) + paid;
      }

      // Build reports
      final reports = <BranchComplianceReport>[];
      for (final branch in branches) {
        // Skip national chapter in branch comparison leaderboard if desired,
        // or show all branches
        final memberIds = branchMembersMap[branch.id] ?? <String>{};
        double branchExpected = 0.0;
        double branchPaid = 0.0;

        for (final mId in memberIds) {
          branchExpected += memberExpected[mId] ?? 0.0;
          branchPaid += memberPaid[mId] ?? 0.0;
        }

        final outstanding = (branchExpected - branchPaid).clamp(0.0, double.infinity);
        final complianceRate = branchExpected > 0
            ? ((branchPaid / branchExpected) * 100).clamp(0.0, 100.0)
            : 100.0;

        reports.add(
          BranchComplianceReport(
            branchId: branch.id,
            branchName: branch.name,
            state: branch.state,
            city: branch.city,
            isNational: branch.isNational,
            memberCount: memberIds.length,
            totalExpected: branchExpected,
            totalRemitted: branchPaid,
            outstandingBalance: outstanding,
            complianceRate: complianceRate,
          ),
        );
      }

      // Sort: highest compliance rate first, then highest remitted
      reports.sort((a, b) {
        final rateComp = b.complianceRate.compareTo(a.complianceRate);
        if (rateComp != 0) return rateComp;
        return b.totalRemitted.compareTo(a.totalRemitted);
      });

      return reports;
    });
  }

  /// Public transparency stream of individual contributions to National levies/dues.
  /// Visible to all members in the organization.
  Stream<List<NationalContributionRecord>> getNationalContributionsStream(
    String organizationId, {
    String? levyId,
  }) {
    return _firestore
        .collection('payments')
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .asyncMap((paymentsSnap) async {
      if (paymentsSnap.docs.isEmpty) return <NationalContributionRecord>[];

      // Fetch national obligations
      Query obligationsQuery = _firestore
          .collection('obligations')
          .where('organizationId', isEqualTo: organizationId);

      if (levyId != null && levyId.isNotEmpty) {
        obligationsQuery = obligationsQuery.where('levyId', isEqualTo: levyId);
      } else {
        obligationsQuery =
            obligationsQuery.where('scope', isEqualTo: 'national');
      }

      final obligationsSnap = await obligationsQuery.get();
      if (obligationsSnap.docs.isEmpty) return <NationalContributionRecord>[];

      // obligationId -> Map details
      final nationalObligationsMap = <String, Map<String, dynamic>>{};
      for (final doc in obligationsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        nationalObligationsMap[doc.id] = data;
      }

      // Fetch users to resolve member branch names
      final usersSnap = await _firestore
          .collection('users')
          .where('organizationId', isEqualTo: organizationId)
          .get();

      final userBranchMap = <String, String>{};
      final userDisplayNameMap = <String, String>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        userBranchMap[doc.id] =
            data['branchName'] as String? ?? 'General Member';
        userDisplayNameMap[doc.id] =
            data['displayName'] as String? ?? 'Member';
      }

      final records = <NationalContributionRecord>[];

      for (final payDoc in paymentsSnap.docs) {
        final payment = PaymentModel.fromFirestore(payDoc);
        final payerName = payment.memberName ??
            userDisplayNameMap[payment.memberId] ??
            'Member';
        final branchName = userBranchMap[payment.memberId] ?? 'General Member';

        for (final alloc in payment.allocations) {
          if (nationalObligationsMap.containsKey(alloc.obligationId)) {
            final obData = nationalObligationsMap[alloc.obligationId]!;
            final levyTitle =
                obData['title'] as String? ?? 'National Obligation';
            final obLevyId = obData['levyId'] as String? ?? '';
            final branchId = obData['branchId'] as String?;

            records.add(
              NationalContributionRecord(
                paymentId: payment.id,
                memberId: payment.memberId,
                memberName: payerName,
                branchId: branchId,
                branchName: branchName,
                levyId: obLevyId,
                levyTitle: levyTitle,
                amount: alloc.amount,
                paidAt: payment.createdAt,
                method: payment.method,
              ),
            );
          }
        }
      }

      // Sort newest contributions first
      records.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      return records;
    });
  }

  /// Streams members enrolled in the National Assembly roll.
  /// Branch members are only included if the branch president has enrolled them into the national branch.
  Stream<List<UserModel>> getNationalMembersStream(String organizationId) {
    return _firestore
        .collection('users')
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final members = snap.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where(
            (u) =>
                u.isEnrolledInNational ||
                u.nationalRole != null ||
                u.branchId == 'national',
          )
          .toList();

      // Sort: National Officers first, then branch officers, then alphabetically
      members.sort((a, b) {
        final aScore = _roleWeight(a);
        final bScore = _roleWeight(b);
        if (aScore != bScore) return bScore.compareTo(aScore);
        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

      return members;
    });
  }

  int _roleWeight(UserModel user) {
    if (user.nationalRole == UserRole.president) return 100;
    if (user.nationalRole == UserRole.secretary) return 90;
    if (user.nationalRole == UserRole.financialSecretary) return 85;
    if (user.nationalRole == UserRole.treasurer) return 80;
    if (user.nationalRole != null) return 75;
    if (user.role == UserRole.president) return 60;
    if (user.role == UserRole.secretary) return 55;
    if (user.role == UserRole.financialSecretary) return 50;
    if (user.role == UserRole.treasurer) return 45;
    if (user.role == UserRole.superAdmin) {
      return 40;
    }
    return 10;
  }
}
