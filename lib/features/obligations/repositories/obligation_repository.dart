import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/obligation_model.dart';
import '../../levies/models/levy_model.dart';
import '../../../core/constants/enums.dart';

class ObligationRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'obligations';

  ObligationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<ObligationModel>> getAllObligations() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<ObligationModel>> getMemberObligations(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) {
    return _collection
        .where('memberId', isEqualTo: memberId)
        .where('status', whereIn: ['unpaid', 'partial'])
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<ObligationModel>> getLevyObligations(String levyId) {
    return _collection
        .where('levyId', isEqualTo: levyId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<ObligationModel?> getObligationById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) return ObligationModel.fromFirestore(doc);
    return null;
  }

  Future<String> createObligation(ObligationModel obligation) async {
    final docRef = _collection.doc();
    final newObligation = obligation.copyWith(
      id: docRef.id,
      outstandingBalance: obligation.amount - obligation.paidAmount,
    );
    await docRef.set(newObligation.toFirestore());
    return docRef.id;
  }

  Future<void> updateObligationStatus(
    String id, {
    double? paidAmount,
    double? outstandingBalance,
    ObligationStatus? status,
    DateTime? settledAt,
  }) async {
    final updates = <String, dynamic>{};
    if (paidAmount != null) updates['paidAmount'] = paidAmount;
    if (outstandingBalance != null) {
      updates['outstandingBalance'] = outstandingBalance;
    }
    if (status != null) updates['status'] = status.name;
    if (settledAt != null) updates['settledAt'] = Timestamp.fromDate(settledAt);
    await _collection.doc(id).update(updates);
  }

  Future<void> updateObligation(ObligationModel obligation) async {
    await _collection.doc(obligation.id).update(obligation.toFirestore());
  }

  Future<void> deleteObligation(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> batchCreateObligations(List<ObligationModel> obligations) async {
    final batch = _firestore.batch();
    for (final obligation in obligations) {
      final docRef = _collection.doc();
      final newObligation = obligation.copyWith(
        id: docRef.id,
        outstandingBalance: obligation.amount - obligation.paidAmount,
      );
      batch.set(docRef, newObligation.toFirestore());
    }
    await batch.commit();
  }

  Future<void> batchCreateFromMaps(List<Map<String, dynamic>> maps) async {
    final batch = _firestore.batch();
    for (final map in maps) {
      final docRef = _collection.doc();
      final data = {...map};
      data['id'] = docRef.id;
      if (!data.containsKey('outstandingBalance')) {
        final amount = data['amount'] ?? 0;
        final paidAmount = data['paidAmount'] ?? 0;
        data['outstandingBalance'] = amount - paidAmount;
      }
      batch.set(docRef, data);
    }
    await batch.commit();
  }

  Future<void> backfillObligationsForNewMember(String memberId) async {
    await reconcileMemberObligations(memberId);
  }

  /// Option C (All Active): Reconciles and synchronizes all currently active/open
  /// dues and levies for a member. If the member downloaded the app today while
  /// there are already running obligations, this creates missing obligations
  /// idempotently without duplicating any records.
  Future<int> reconcileMemberObligations(
    String memberOrUserId, {
    String? userId,
  }) async {
    String targetMemberId = memberOrUserId;
    String? targetUserId = userId;

    try {
      if (userId == null) {
        final memberByUid = await _firestore
            .collection('members')
            .where('userId', isEqualTo: memberOrUserId)
            .limit(1)
            .get();
        if (memberByUid.docs.isNotEmpty) {
          targetMemberId = memberByUid.docs.first.id;
          targetUserId = memberOrUserId;
        } else {
          final memberDoc =
              await _firestore.collection('members').doc(memberOrUserId).get();
          if (memberDoc.exists) {
            targetMemberId = memberDoc.id;
            targetUserId = memberDoc.data()?['userId'] as String?;
          }
        }
      }
    } catch (_) {
      // Best-effort ID resolution fallback
    }

    final allMemberIds = <String>{
      targetMemberId,
      if (targetUserId != null && targetUserId.isNotEmpty) targetUserId,
      if (memberOrUserId.isNotEmpty) memberOrUserId,
    };

    // 1. Fetch existing obligations for this member across all known IDs
    final existingObligationsSnap = await _collection.get();
    final allObligations = existingObligationsSnap.docs
        .map((doc) => ObligationModel.fromFirestore(doc))
        .toList();

    final memberExisting = allObligations
        .where((o) => allMemberIds.contains(o.memberId))
        .toList();

    final existingLevyIds = <String>{
      for (final o in memberExisting)
        if (o.levyId.isNotEmpty) o.levyId,
    };
    final existingTitles = <String>{
      for (final o in memberExisting)
        if (o.title.trim().isNotEmpty) o.title.trim().toLowerCase(),
    };

    final newObligations = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // 2. Source A: Active Levies from 'levies' collection
    try {
      final leviesSnap = await _firestore.collection('levies').get();
      final allLevies = leviesSnap.docs
          .map((doc) => LevyModel.fromFirestore(doc))
          .toList();
      final activeLevies = allLevies.where((l) => l.isActive).toList();

      for (final levy in activeLevies) {
        final normTitle = levy.title.trim().toLowerCase();
        if (existingLevyIds.contains(levy.id) || existingTitles.contains(normTitle)) {
          continue;
        }

        existingLevyIds.add(levy.id);
        existingTitles.add(normTitle);

        newObligations.add({
          'memberId': targetMemberId,
          'userId': targetUserId ?? targetMemberId,
          'levyId': levy.id,
          'type': levy.type.name,
          'title': levy.title,
          'description': levy.description,
          'amount': levy.amountPerMember,
          'paidAmount': 0.0,
          'outstandingBalance': levy.amountPerMember,
          'status': 'unpaid',
          'dueDate': Timestamp.fromDate(levy.dueDate),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    } catch (_) {
      // Continue to Source B
    }

    // 3. Source B: Active open dues categories from general obligations
    final groupedOther = <String, List<ObligationModel>>{};
    for (final o in allObligations) {
      final t = o.title.trim();
      if (t.isEmpty) continue;
      final normTitle = t.toLowerCase();
      if (existingTitles.contains(normTitle)) continue;
      groupedOther.putIfAbsent(normTitle, () => []).add(o);
    }

    for (final entry in groupedOther.entries) {
      final normTitle = entry.key;
      final group = entry.value;
      if (existingTitles.contains(normTitle)) continue;

      // Check if this category has active/ongoing dues
      final hasActiveDues = group.any(
        (o) => o.status != ObligationStatus.paid || o.outstandingBalance > 0,
      );
      if (!hasActiveDues && group.isNotEmpty) {
        final futureDue = group.any((o) => o.dueDate.isAfter(now));
        if (!futureDue) continue; // Closed/completed past obligation
      }

      final template = group.first;
      existingTitles.add(normTitle);
      if (template.levyId.isNotEmpty) existingLevyIds.add(template.levyId);

      newObligations.add({
        'memberId': targetMemberId,
        'userId': targetUserId ?? targetMemberId,
        'levyId': template.levyId,
        'type': template.type.name,
        'title': template.title,
        'description': template.description,
        'amount': template.amount,
        'paidAmount': 0.0,
        'outstandingBalance': template.amount,
        'status': 'unpaid',
        'dueDate': Timestamp.fromDate(template.dueDate),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    // 4. Batch commit missing obligations
    if (newObligations.isNotEmpty) {
      await batchCreateFromMaps(newObligations);
    }

    return newObligations.length;
  }
}
