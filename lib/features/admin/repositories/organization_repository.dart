import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/organization_model.dart';

class OrganizationRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'organizations';

  OrganizationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<OrganizationModel>> getOrganizations() {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrganizationModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((error) {
          if (FirebaseAuth.instance.currentUser == null) {
            return <OrganizationModel>[];
          }
          throw error;
        });
  }

  /// Public org list used by the register / org-picker screens, which run
  /// before the user is authenticated. The query is filtered to active,
  /// joinable orgs so it matches the Firestore read rule for anonymous users.
  /// Sorter is run in memory to avoid requiring a Cloud Firestore composite index.
  Stream<List<OrganizationModel>> getPublicOrganizations() {
    return _collection
        .where('isActive', isEqualTo: true)
        .where('openForJoin', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) {
            final list = snapshot.docs
                .map((doc) => OrganizationModel.fromFirestore(doc))
                .toList();
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            return list;
          },
        )
        .handleError((error) {
          return <OrganizationModel>[];
        });
  }

  Future<OrganizationModel?> getOrganizationById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return OrganizationModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<OrganizationModel?> streamOrganizationById(String id) {
    if (FirebaseAuth.instance.currentUser == null || id.isEmpty) {
      return const Stream.empty();
    }
    return _collection
        .doc(id)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return OrganizationModel.fromFirestore(doc);
          }
          return null;
        })
        .handleError((_) => null);
  }

  Future<String> createOrganization(
    OrganizationModel organization, {
    String? initialBranchName,
  }) async {
    final docRef = _collection.doc();
    final trialExpiry = DateTime.now().add(const Duration(days: 60));
    final newOrg = organization.copyWith(
      id: docRef.id,
      subscriptionTier: organization.subscriptionExpiresAt == null
          ? 'trial'
          : organization.subscriptionTier,
      subscriptionStatus: 'active',
      isTrial: organization.subscriptionExpiresAt == null
          ? true
          : organization.isTrial,
      subscriptionExpiresAt: organization.subscriptionExpiresAt ?? trialExpiry,
    );
    await docRef.set(newOrg.toFirestore());

    final effectiveBranchName =
        (initialBranchName != null && initialBranchName.trim().isNotEmpty)
            ? initialBranchName.trim()
            : 'Headquarters / Main Branch';

    final branchDoc = _firestore.collection('branches').doc();
    await branchDoc.set({
      'organizationId': docRef.id,
      'name': effectiveBranchName,
      'state': '',
      'city': '',
      'isActive': true,
      'bankName': organization.bankName,
      'accountNumber': organization.accountNumber,
      'accountName': organization.accountName,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return docRef.id;
  }

  Future<void> updateOrganization(OrganizationModel organization) async {
    await _collection
        .doc(organization.id)
        .update(organization.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> activateOrganization(String id) async {
    await _collection.doc(id).update({
      'isActive': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deactivateOrganization(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> setOpenForJoin(String id, bool openForJoin) async {
    await _collection.doc(id).update({
      'openForJoin': openForJoin,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteOrganization(String id) async {
    // 1. Delete associated branches
    final branchesSnap = await _firestore
        .collection('branches')
        .where('organizationId', isEqualTo: id)
        .get();
    for (final doc in branchesSnap.docs) {
      await doc.reference.delete();
    }
    // 2. Delete the organization document
    await _collection.doc(id).delete();
  }

  Future<void> updateBankDetails({
    required String organizationId,
    required String bankName,
    required String accountNumber,
    required String accountName,
    bool isBankVerified = false,
    String? bankAccountType,
    bool isOverridden = false,
    String? overrideReason,
    String? overriddenBy,
  }) async {
    await _collection.doc(organizationId).update({
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'isBankVerified': isBankVerified,
      'bankAccountType': ?bankAccountType,
      'bankVerificationOverridden': isOverridden,
      'bankVerificationOverrideReason': ?overrideReason,
      'bankVerificationOverriddenBy': ?overriddenBy,
      if (isOverridden)
        'bankVerificationOverriddenAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> verifyOrganization(
    String id, {
    String? verifiedBy,
  }) async {
    await _collection.doc(id).update({
      'isActive': true,
      'openForJoin': true,
      'verificationStatus': 'verified',
      'verifiedBy': ?verifiedBy,
      'verifiedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> rejectOrganization(
    String id, {
    String? reason,
  }) async {
    await _collection.doc(id).update({
      'isActive': false,
      'openForJoin': false,
      'verificationStatus': 'rejected',
      'rejectionReason': ?reason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> submitLicenseRenewal({
    required String organizationId,
    required String proofUrl,
    required String reference,
    required String bankName,
    required double amount,
    required String submittedBy,
  }) async {
    await _collection.doc(organizationId).update({
      'subscriptionStatus': 'pending_verification',
      'licenseProofUrl': proofUrl,
      'licensePaymentReference': reference,
      'licensePaymentBank': bankName,
      'licensePaymentAmount': amount,
      'licenseSubmittedAt': Timestamp.fromDate(DateTime.now()),
      'licenseSubmittedBy': submittedBy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> approveLicenseRenewal(
    String organizationId, {
    required String approvedBy,
    int days = 365,
    String tier = 'pro',
  }) async {
    final doc = await _collection.doc(organizationId).get();
    DateTime currentExpiry = DateTime.now();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['subscriptionExpiresAt'] != null) {
        final parsed = (data['subscriptionExpiresAt'] as Timestamp).toDate();
        if (parsed.isAfter(DateTime.now())) {
          currentExpiry = parsed;
        }
      }
    }

    final newExpiry = currentExpiry.add(Duration(days: days));

    await _collection.doc(organizationId).update({
      'subscriptionTier': tier,
      'subscriptionStatus': 'active',
      'isTrial': false,
      'subscriptionExpiresAt': Timestamp.fromDate(newExpiry),
      'licenseVerifiedBy': approvedBy,
      'licenseApprovedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> rejectLicenseRenewal(
    String organizationId, {
    required String rejectedBy,
    String? reason,
  }) async {
    await _collection.doc(organizationId).update({
      'subscriptionStatus': 'expired',
      'licenseRejectionReason': reason ?? 'Payment proof could not be verified',
      'licenseRejectedBy': rejectedBy,
      'licenseRejectedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
