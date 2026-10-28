import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';

class SystemResetService {
  final FirebaseFirestore _firestore;
  static const String superAdminEmail = 'danielcyudoncy@gmail.com';

  SystemResetService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Completely wipes all test transaction data, organizations, branches, and
  /// all user accounts except the designated Super Admin (`danielcyudoncy@gmail.com`).
  Future<void> resetAllTestData({
    required String currentUserId,
    void Function(String status, double progress)? onProgress,
  }) async {
    final collectionsToWipe = [
      'organizations',
      'branches',
      'payments',
      'expenses',
      'obligations',
      'levies',
      'receipts',
      'penalty_waivers',
      'meetings',
      'announcements',
      'notifications',
      'calendar_events',
      'attendance',
      'meeting_rsvps',
      'documents',
      'co_founder_invitations',
      'members',
    ];

    final totalSteps = collectionsToWipe.length + 1; // + users
    int currentStep = 0;

    // 1. Wipe all collections including organizations, branches, and members
    for (final col in collectionsToWipe) {
      currentStep++;
      onProgress?.call(
        'Clearing $col...',
        currentStep / totalSteps,
      );
      await _deleteEntireCollection(col);
    }

    // 2. Clean users collection (keep only super admin user)
    currentStep++;
    onProgress?.call(
      'Resetting user accounts...',
      currentStep / totalSteps,
    );
    await _cleanUsersCollection(currentUserId: currentUserId);
  }

  Future<void> _deleteEntireCollection(String collectionName) async {
    final snapshot = await _firestore.collection(collectionName).get();
    final docs = snapshot.docs;
    if (docs.isEmpty) return;

    for (int i = 0; i < docs.length; i += 400) {
      final batch = _firestore.batch();
      final chunk = docs.sublist(
        i,
        (i + 400 > docs.length) ? docs.length : i + 400,
      );
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _cleanUsersCollection({required String currentUserId}) async {
    final snapshot = await _firestore.collection('users').get();
    final docs = snapshot.docs;
    if (docs.isEmpty) return;

    for (int i = 0; i < docs.length; i += 400) {
      final batch = _firestore.batch();
      final chunk = docs.sublist(
        i,
        (i + 400 > docs.length) ? docs.length : i + 400,
      );
      for (final doc in chunk) {
        final data = doc.data();
        final email = (data['email'] as String?)?.toLowerCase().trim() ?? '';

        final isSuperAdminUser =
            email == superAdminEmail || doc.id == currentUserId;

        if (isSuperAdminUser) {
          // Ensure account is permanently marked as active Super Admin with fresh 0 stats
          batch.update(doc.reference, {
            'role': UserRole.superAdmin.name,
            'status': AccountStatus.approved.name,
            'isActive': true,
            'organizationId': '',
            'branchId': FieldValue.delete(),
            'branchName': FieldValue.delete(),
            'openingBalance': 0.0,
            'duesStanding': MemberDuesStanding.cleared.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
    }
  }
}
