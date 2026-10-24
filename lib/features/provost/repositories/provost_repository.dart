import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';
import '../../obligations/models/obligation_model.dart';
import '../models/penalty_waiver_model.dart';

class ProvostRepository {
  final FirebaseFirestore _firestore;

  ProvostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _obligationsCollection =>
      _firestore.collection('obligations');

  CollectionReference get _waiversCollection =>
      _firestore.collection('penalty_waivers');

  /// Issues a new disciplinary penalty against a member.
  Future<String> issuePenalty({
    required String organizationId,
    required String memberId,
    required String memberName,
    required PenaltyInfractionType infractionType,
    required String title,
    required String description,
    required double amount,
    required String issuedBy,
    String? meetingId,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final docRef = _obligationsCollection.doc();

    final obligation = ObligationModel(
      id: docRef.id,
      organizationId: organizationId,
      memberId: memberId,
      levyId: 'disciplinary_penalty',
      type: ObligationType.penalty,
      title: title.trim().isEmpty ? infractionType.displayName : title.trim(),
      description: description.trim(),
      amount: amount,
      paidAmount: 0.0,
      outstandingBalance: amount,
      status: ObligationStatus.unpaid,
      dueDate: dueDate ?? now.add(const Duration(days: 14)),
      createdAt: now,
      meetingId: meetingId,
      infractionType: infractionType,
      isWaived: false,
      waiverStatus: null,
    );

    final data = obligation.toFirestore();
    data['memberName'] = memberName;
    data['issuedBy'] = issuedBy;

    await docRef.set(data);
    return docRef.id;
  }

  /// Requests a waiver/pardon for a penalty.
  /// Submits the pardon for President counter-signing approval.
  Future<String> requestPenaltyWaiver({
    required String organizationId,
    required String obligationId,
    required String memberId,
    required String memberName,
    required String penaltyTitle,
    required double amount,
    required PenaltyInfractionType infractionType,
    required String reason,
    required String requestedBy,
  }) async {
    final now = DateTime.now();
    final waiverDocRef = _waiversCollection.doc();

    final waiver = PenaltyWaiverModel(
      id: waiverDocRef.id,
      organizationId: organizationId,
      obligationId: obligationId,
      memberId: memberId,
      memberName: memberName,
      penaltyTitle: penaltyTitle,
      amount: amount,
      infractionType: infractionType,
      reason: reason.trim(),
      requestedBy: requestedBy,
      requestedAt: now,
      status: PenaltyWaiverStatus.pendingApproval,
    );

    // Run batch or atomic transaction to log waiver request and update obligation
    final batch = _firestore.batch();

    batch.set(waiverDocRef, waiver.toFirestore());

    final obligationDocRef = _obligationsCollection.doc(obligationId);
    batch.update(obligationDocRef, {
      'waiverStatus': PenaltyWaiverStatus.pendingApproval.name,
      'waiverReason': reason.trim(),
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
    return waiverDocRef.id;
  }

  /// President approves a penalty waiver request.
  /// Zeroes out the obligation balance and marks it waived.
  Future<void> approvePenaltyWaiver({
    required String waiverId,
    required String obligationId,
    required String reviewedBy,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final waiverDocRef = _waiversCollection.doc(waiverId);
    batch.update(waiverDocRef, {
      'status': PenaltyWaiverStatus.approved.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': Timestamp.fromDate(now),
    });

    final obligationDocRef = _obligationsCollection.doc(obligationId);
    batch.update(obligationDocRef, {
      'isWaived': true,
      'outstandingBalance': 0.0,
      'status': ObligationStatus.paid.name,
      'waivedBy': reviewedBy,
      'waivedAt': Timestamp.fromDate(now),
      'waiverStatus': PenaltyWaiverStatus.approved.name,
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }

  /// President rejects a penalty waiver request.
  Future<void> rejectPenaltyWaiver({
    required String waiverId,
    required String obligationId,
    required String reviewedBy,
    required String rejectionReason,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final waiverDocRef = _waiversCollection.doc(waiverId);
    batch.update(waiverDocRef, {
      'status': PenaltyWaiverStatus.rejected.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': Timestamp.fromDate(now),
      'rejectionReason': rejectionReason.trim(),
    });

    final obligationDocRef = _obligationsCollection.doc(obligationId);
    batch.update(obligationDocRef, {
      'waiverStatus': PenaltyWaiverStatus.rejected.name,
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }

  /// Real-time stream of all disciplinary penalties for an organization.
  Stream<List<ObligationModel>> getProvostPenalties(String organizationId) {
    if (organizationId.isEmpty) return const Stream.empty();

    return _obligationsCollection
        .where('organizationId', isEqualTo: organizationId)
        .where('type', isEqualTo: ObligationType.penalty.name)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((error) {
          return <ObligationModel>[];
        });
  }

  /// Real-time stream of penalty waivers (audit log) for an organization.
  Stream<List<PenaltyWaiverModel>> getWaivers(String organizationId) {
    if (organizationId.isEmpty) return const Stream.empty();

    return _waiversCollection
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => PenaltyWaiverModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return list;
        })
        .handleError((_) => <PenaltyWaiverModel>[]);
  }

  /// Real-time stream of pending waiver requests awaiting President approval.
  Stream<List<PenaltyWaiverModel>> getPendingWaivers(String organizationId) {
    if (organizationId.isEmpty) return const Stream.empty();

    return _waiversCollection
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: PenaltyWaiverStatus.pendingApproval.name)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => PenaltyWaiverModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return list;
        })
        .handleError((_) => <PenaltyWaiverModel>[]);
  }
}
