import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <ObligationModel>[]);
  }

  Stream<List<ObligationModel>> getMemberObligations(String memberId) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <ObligationModel>[]);
  }

  Stream<List<ObligationModel>> getMemberActiveObligations(String memberId) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('memberId', isEqualTo: memberId)
        .where('status', whereIn: ['unpaid', 'partial'])
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <ObligationModel>[]);
  }

  Stream<List<ObligationModel>> getLevyObligations(String levyId) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Stream.empty();
    }
    return _collection
        .where('levyId', isEqualTo: levyId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ObligationModel.fromFirestore(doc))
              .toList(),
        )
        .handleError((_) => <ObligationModel>[]);
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
    try {
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
    } catch (_) {
      // Graceful fallback: background obligation sync should not crash UI
    }
  }

  Future<void> backfillObligationsForNewMember(
    String memberId, {
    String? organizationId,
  }) async {
    await reconcileMemberObligations(memberId, organizationId: organizationId);
  }

  /// Option C (All Active): Reconciles and synchronizes active general dues
  /// for a member within their organization. If the member downloaded the app today while
  /// there are already running general dues, this creates missing obligations
  /// idempotently without duplicating any records.
  /// Only general dues shared with everyone (type == monthlyDue, targetGroup == null or 'all')
  /// within the member's organization are backfilled.
  /// If [duesStanding] is cleared, obligations are marked as settled (status: paid, balance: 0).
  Future<int> reconcileMemberObligations(
    String memberOrUserId, {
    String? userId,
    String? organizationId,
    MemberDuesStanding? duesStanding,
    double? openingBalance,
  }) async {
    String targetMemberId = memberOrUserId;
    String? targetUserId = userId;
    String? resolvedOrgId = organizationId;

    try {
      if (userId == null || resolvedOrgId == null || resolvedOrgId.isEmpty) {
        final memberByUid = await _firestore
            .collection('members')
            .where('userId', isEqualTo: memberOrUserId)
            .limit(1)
            .get();
        if (memberByUid.docs.isNotEmpty) {
          targetMemberId = memberByUid.docs.first.id;
          targetUserId = memberOrUserId;
          resolvedOrgId ??=
              memberByUid.docs.first.data()['organizationId'] as String?;
        } else {
          final memberDoc =
              await _firestore.collection('members').doc(memberOrUserId).get();
          if (memberDoc.exists) {
            targetMemberId = memberDoc.id;
            targetUserId = memberDoc.data()?['userId'] as String?;
            resolvedOrgId ??= memberDoc.data()?['organizationId'] as String?;
          }
        }
      }
    } catch (_) {
      // Best-effort ID resolution fallback
    }

    // Fallback: check users collection for organizationId if still missing
    if (resolvedOrgId == null || resolvedOrgId.isEmpty) {
      try {
        final checkUid =
            targetUserId ?? (memberOrUserId.isNotEmpty ? memberOrUserId : null);
        if (checkUid != null) {
          final uDoc = await _firestore.collection('users').doc(checkUid).get();
          if (uDoc.exists) {
            resolvedOrgId ??= uDoc.data()?['organizationId'] as String?;
          }
        }
      } catch (_) {}
    }

    MemberDuesStanding resolvedStanding =
        duesStanding ?? MemberDuesStanding.newMember;
    double? resolvedOpeningBalance = openingBalance;

    if (duesStanding == null) {
      try {
        final checkUid =
            targetUserId ?? (memberOrUserId.isNotEmpty ? memberOrUserId : null);
        if (checkUid != null) {
          final uDoc = await _firestore.collection('users').doc(checkUid).get();
          if (uDoc.exists) {
            final s = uDoc.data()?['duesStanding'] as String?;
            if (s != null) {
              resolvedStanding = MemberDuesStanding.values.firstWhere(
                (e) => e.name.toLowerCase() == s.trim().toLowerCase(),
                orElse: () => MemberDuesStanding.newMember,
              );
            }
            resolvedOpeningBalance ??=
                (uDoc.data()?['openingBalance'] as num?)?.toDouble();
            resolvedOrgId ??= uDoc.data()?['organizationId'] as String?;
          }
        }
      } catch (_) {}
    }

    final isCleared = resolvedStanding == MemberDuesStanding.cleared;

    final allMemberIds = <String>{
      targetMemberId,
      if (targetUserId != null && targetUserId.isNotEmpty) targetUserId,
      if (memberOrUserId.isNotEmpty) memberOrUserId,
    };

    // 1. Fetch existing obligations for this member, scoped by organizationId if available
    Query obligationsQuery = _collection;
    if (resolvedOrgId != null && resolvedOrgId.isNotEmpty) {
      obligationsQuery =
          obligationsQuery.where('organizationId', isEqualTo: resolvedOrgId);
    }
    final existingObligationsSnap = await obligationsQuery.get();
    final allObligations = existingObligationsSnap.docs
        .map((doc) => ObligationModel.fromFirestore(doc))
        .toList();

    final memberExisting = allObligations
        .where((o) => allMemberIds.contains(o.memberId))
        .toList();

    // If marked cleared, settle any existing unpaid obligations for this member
    if (isCleared && memberExisting.isNotEmpty) {
      final now = DateTime.now();
      final batch = _firestore.batch();
      bool needsUpdate = false;
      for (final o in memberExisting) {
        if (o.status != ObligationStatus.paid || o.outstandingBalance > 0.0) {
          needsUpdate = true;
          batch.update(_collection.doc(o.id), {
            'paidAmount': o.amount,
            'outstandingBalance': 0.0,
            'status': ObligationStatus.paid.name,
            'settledAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          });
        }
      }
      if (needsUpdate) {
        try {
          await batch.commit();
        } catch (_) {
          // Graceful fallback
        }
      }
    }

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

    // 2. Source A: Active General Dues Levies from 'levies' collection
    // Enforce: Only general monthly dues shared with all members in the organization
    try {
      Query leviesQuery =
          _firestore.collection('levies').where('isActive', isEqualTo: true);
      if (resolvedOrgId != null && resolvedOrgId.isNotEmpty) {
        leviesQuery =
            leviesQuery.where('organizationId', isEqualTo: resolvedOrgId);
      }
      final leviesSnap = await leviesQuery.get();
      final allLevies =
          leviesSnap.docs.map((doc) => LevyModel.fromFirestore(doc)).toList();

      for (final levy in allLevies) {
        // Enforce: ONLY general dues shared with everyone
        final isGeneralDue = levy.type == ObligationType.monthlyDue;
        final targetGroupLower = levy.targetGroup?.trim().toLowerCase();
        final isSharedWithAll = targetGroupLower == null ||
            targetGroupLower.isEmpty ||
            targetGroupLower == 'all';

        if (!isGeneralDue || !isSharedWithAll) {
          continue;
        }

        final normTitle = levy.title.trim().toLowerCase();
        if (existingLevyIds.contains(levy.id) ||
            existingTitles.contains(normTitle)) {
          continue;
        }

        existingLevyIds.add(levy.id);
        existingTitles.add(normTitle);

        newObligations.add({
          'organizationId': resolvedOrgId ??
              (levy.organizationId.isNotEmpty ? levy.organizationId : ''),
          'memberId': targetMemberId,
          'userId': targetUserId ?? targetMemberId,
          'levyId': levy.id,
          'type': levy.type.name,
          'title': levy.title,
          'description': levy.description,
          'amount': levy.amountPerMember,
          'paidAmount': isCleared ? levy.amountPerMember : 0.0,
          'outstandingBalance': isCleared ? 0.0 : levy.amountPerMember,
          'status': isCleared
              ? ObligationStatus.paid.name
              : ObligationStatus.unpaid.name,
          'dueDate': Timestamp.fromDate(levy.dueDate),
          'settledAt': isCleared ? Timestamp.fromDate(now) : null,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    } catch (_) {
      // Continue to Source B
    }

    // 3. Source B: Restrict to universal recurring organization dues (monthlyDue) only
    // Do not clone ad-hoc or individual obligations from other members
    final groupedOther = <String, List<ObligationModel>>{};
    for (final o in allObligations) {
      if (o.type != ObligationType.monthlyDue) continue;
      if (resolvedOrgId != null &&
          resolvedOrgId.isNotEmpty &&
          o.organizationId.isNotEmpty &&
          o.organizationId != resolvedOrgId) {
        continue;
      }
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
      if (template.type != ObligationType.monthlyDue) continue;

      existingTitles.add(normTitle);
      if (template.levyId.isNotEmpty) existingLevyIds.add(template.levyId);

      newObligations.add({
        'organizationId': resolvedOrgId ?? template.organizationId,
        'memberId': targetMemberId,
        'userId': targetUserId ?? targetMemberId,
        'levyId': template.levyId,
        'type': ObligationType.monthlyDue.name,
        'title': template.title,
        'description': template.description,
        'amount': template.amount,
        'paidAmount': isCleared ? template.amount : 0.0,
        'outstandingBalance': isCleared ? 0.0 : template.amount,
        'status': isCleared
            ? ObligationStatus.paid.name
            : ObligationStatus.unpaid.name,
        'dueDate': Timestamp.fromDate(template.dueDate),
        'settledAt': isCleared ? Timestamp.fromDate(now) : null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    // 4. Source C: Specific Opening Balance if provided
    if (resolvedStanding == MemberDuesStanding.openingBalance &&
        resolvedOpeningBalance != null &&
        resolvedOpeningBalance > 0 &&
        !existingTitles.contains('opening balance')) {
      newObligations.add({
        'organizationId': resolvedOrgId ?? '',
        'memberId': targetMemberId,
        'userId': targetUserId ?? targetMemberId,
        'levyId': 'opening_balance',
        'type': ObligationType.monthlyDue.name,
        'title': 'Opening Balance (Historical Arrears)',
        'description': 'Historical dues carried forward upon registration',
        'amount': resolvedOpeningBalance,
        'paidAmount': 0.0,
        'outstandingBalance': resolvedOpeningBalance,
        'status': ObligationStatus.unpaid.name,
        'dueDate': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    // 5. Batch commit missing obligations
    if (newObligations.isNotEmpty) {
      try {
        await batchCreateFromMaps(newObligations);
      } catch (_) {
        // Graceful fallback
      }
    }

    return newObligations.length;
  }

  /// Explicitly marks all past obligations for a member as paid/cleared
  Future<void> clearMemberHistoricalObligations(
    String memberOrUserId, {
    String? userId,
    String? organizationId,
  }) async {
    await reconcileMemberObligations(
      memberOrUserId,
      userId: userId,
      organizationId: organizationId,
      duesStanding: MemberDuesStanding.cleared,
    );
  }
}
