import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/co_founder_invitation_model.dart';
import '../../../core/constants/enums.dart';

class CoFounderInvitationRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'co_founder_invitations';

  CoFounderInvitationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  static String normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234') && digits.length > 10) {
      digits = '0${digits.substring(3)}';
    }
    return digits;
  }

  Future<String> createInvitation(CoFounderInvitationModel invitation) async {
    final docRef = _collection.doc();
    final model = invitation.copyWith(
      id: docRef.id,
      secretaryPhone: normalizePhone(invitation.secretaryPhone),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(model.toFirestore());
    return docRef.id;
  }

  Future<CoFounderInvitationModel?> getPendingInvitationForPhone(
      String rawPhone) async {
    final cleanPhone = normalizePhone(rawPhone);
    if (cleanPhone.isEmpty) return null;

    final snapshot = await _collection
        .where('secretaryPhone', isEqualTo: cleanPhone)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return CoFounderInvitationModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Stream<CoFounderInvitationModel?> streamPendingInvitationForPhone(
      String rawPhone) {
    final cleanPhone = normalizePhone(rawPhone);
    if (cleanPhone.isEmpty) return Stream.value(null);

    return _collection
        .where('secretaryPhone', isEqualTo: cleanPhone)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return CoFounderInvitationModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  Future<CoFounderInvitationModel?> getInvitationByOrgId(
      String organizationId) async {
    final snapshot = await _collection
        .where('organizationId', isEqualTo: organizationId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return CoFounderInvitationModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Atomic acceptance:
  /// 1. Updates invitation to 'approved'
  /// 2. Updates organization to active & openForJoin
  /// 3. Updates President's user account to approved
  /// 4. Updates Secretary's user account to approved as secretary
  Future<void> acceptInvitation({
    required String invitationId,
    required String secretaryUid,
    required String secretaryName,
    required String secretaryEmail,
  }) async {
    final invDoc = await _collection.doc(invitationId).get();
    if (!invDoc.exists) {
      throw Exception('Invitation not found.');
    }
    final inv = CoFounderInvitationModel.fromFirestore(invDoc);

    final batch = _firestore.batch();

    // 1. Mark invitation approved
    batch.update(_collection.doc(invitationId), {
      'status': 'approved',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // 2. Activate Organization
    final orgRef = _firestore.collection('organizations').doc(inv.organizationId);
    batch.update(orgRef, {
      'isActive': true,
      'openForJoin': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // 3. Approve President
    final presidentRef = _firestore.collection('users').doc(inv.presidentUid);
    batch.update(presidentRef, {
      'status': AccountStatus.approved.name,
      'isActive': true,
    });

    // Also activate President member doc if present
    final presMembers = await _firestore
        .collection('members')
        .where('userId', isEqualTo: inv.presidentUid)
        .limit(1)
        .get();
    if (presMembers.docs.isNotEmpty) {
      batch.update(presMembers.docs.first.reference, {
        'status': 'approved',
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    // 4. Update Secretary User
    final secUserRef = _firestore.collection('users').doc(secretaryUid);
    batch.update(secUserRef, {
      'organizationId': inv.organizationId,
      'role': UserRole.secretary.name,
      'status': AccountStatus.approved.name,
      'isActive': true,
      'branchName': inv.branchName,
    });

    // Update or create Secretary Member record
    final secMembers = await _firestore
        .collection('members')
        .where('userId', isEqualTo: secretaryUid)
        .limit(1)
        .get();
    if (secMembers.docs.isNotEmpty) {
      batch.update(secMembers.docs.first.reference, {
        'organizationId': inv.organizationId,
        'branchName': inv.branchName,
        'status': 'approved',
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
  }

  Future<void> declineInvitation(String invitationId) async {
    await _collection.doc(invitationId).update({
      'status': 'rejected',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
