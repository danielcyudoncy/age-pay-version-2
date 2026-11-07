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
        final explicitId = map['id'] as String?;
        final levyId = map['levyId'] as String?;
        final memberId = map['memberId'] as String?;
        final resolvedId = (explicitId != null && explicitId.isNotEmpty)
            ? explicitId
            : ((levyId != null &&
                    levyId.isNotEmpty &&
                    memberId != null &&
                    memberId.isNotEmpty)
                ? '${levyId}_$memberId'
                : null);

        final docRef = resolvedId != null
            ? _collection.doc(resolvedId)
            : _collection.doc();
        final data = {...map};
        data['id'] = docRef.id;
        if (!data.containsKey('outstandingBalance')) {
          final amount = data['amount'] ?? 0;
          final paidAmount = data['paidAmount'] ?? 0;
          data['outstandingBalance'] = amount - paidAmount;
        }
        batch.set(docRef, data, SetOptions(merge: true));
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
    String? targetBranchId;

    try {
      // Always query members to resolve both member doc ID and user UID
      final memberByUid = await _firestore
          .collection('members')
          .where('userId', isEqualTo: memberOrUserId)
          .limit(1)
          .get();
      if (memberByUid.docs.isNotEmpty) {
        targetMemberId = memberByUid.docs.first.id;
        targetUserId = memberOrUserId;
        final data = memberByUid.docs.first.data();
        resolvedOrgId ??= data['organizationId'] as String?;
        targetBranchId = data['branchId'] as String?;
      } else {
        final memberDoc =
            await _firestore.collection('members').doc(memberOrUserId).get();
        if (memberDoc.exists) {
          targetMemberId = memberDoc.id;
          final data = memberDoc.data();
          targetUserId ??= data?['userId'] as String?;
          resolvedOrgId ??= data?['organizationId'] as String?;
          targetBranchId = data?['branchId'] as String?;
        } else if (userId != null && userId.isNotEmpty) {
          final memberByParamUid = await _firestore
              .collection('members')
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get();
          if (memberByParamUid.docs.isNotEmpty) {
            targetMemberId = memberByParamUid.docs.first.id;
            targetUserId = userId;
            final data = memberByParamUid.docs.first.data();
            resolvedOrgId ??= data['organizationId'] as String?;
            targetBranchId = data['branchId'] as String?;
          }
        }
      }
    } catch (_) {
      // Best-effort ID resolution fallback
    }

    // Fallback: check users collection for organizationId / branchId if still missing
    if (resolvedOrgId == null || resolvedOrgId.isEmpty || targetBranchId == null) {
      try {
        final checkUid =
            targetUserId ?? (memberOrUserId.isNotEmpty ? memberOrUserId : null);
        if (checkUid != null) {
          final uDoc = await _firestore.collection('users').doc(checkUid).get();
          if (uDoc.exists) {
            final uData = uDoc.data();
            resolvedOrgId ??= uData?['organizationId'] as String?;
            targetBranchId ??= uData?['branchId'] as String?;
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

    // Query approved payments to verify which obligations have legitimate allocations
    final allocatedObligationIds = <String>{};
    try {
      final paymentsSnap = await _firestore
          .collection('payments')
          .where('memberId', whereIn: allMemberIds.take(10).toList())
          .get();
      for (final pDoc in paymentsSnap.docs) {
        final pData = pDoc.data();
        if (pData['status'] == PaymentStatus.approved.name) {
          final allocs = pData['allocations'] as List<dynamic>? ?? [];
          for (final a in allocs) {
            if (a is Map && a['obligationId'] != null) {
              allocatedObligationIds.add(a['obligationId'] as String);
            }
          }
        }
      }
    } catch (_) {}

    // Self-healing: Deduplicate existing obligations & reset phantom paid amounts
    final duplicatesToDelete = <String>[];
    final obligationsToReset = <ObligationModel>[];
    final seenKeys = <String, ObligationModel>{};

    for (final o in memberExisting) {
      final key = o.levyId.isNotEmpty
          ? 'levy_${o.levyId}'
          : 'title_${o.type.name}_${o.title.trim().toLowerCase()}';

      // Check for phantom paid amounts (paidAmount > 0 but no actual payment allocated)
      final hasRealPayment = allocatedObligationIds.contains(o.id);
      if (o.paidAmount > 0 && !hasRealPayment) {
        obligationsToReset.add(o);
      }

      if (!seenKeys.containsKey(key)) {
        seenKeys[key] = o;
      } else {
        final existing = seenKeys[key]!;
        final existingHasRealPayment = allocatedObligationIds.contains(existing.id);
        final oHasRealPayment = allocatedObligationIds.contains(o.id);

        if (existingHasRealPayment && !oHasRealPayment) {
          duplicatesToDelete.add(o.id);
        } else if (!existingHasRealPayment && oHasRealPayment) {
          duplicatesToDelete.add(existing.id);
          seenKeys[key] = o;
        } else {
          final existingIsDeterministic =
              existing.id == '${existing.levyId}_${existing.memberId}';
          final oIsDeterministic = o.id == '${o.levyId}_${o.memberId}';

          if (oIsDeterministic && !existingIsDeterministic) {
            duplicatesToDelete.add(existing.id);
            seenKeys[key] = o;
          } else {
            duplicatesToDelete.add(o.id);
          }
        }
      }
    }

    final now = DateTime.now();

    if (duplicatesToDelete.isNotEmpty || obligationsToReset.isNotEmpty) {
      final cleanupBatch = _firestore.batch();
      for (final id in duplicatesToDelete) {
        cleanupBatch.delete(_collection.doc(id));
      }
      for (final o in obligationsToReset) {
        if (!duplicatesToDelete.contains(o.id)) {
          cleanupBatch.update(_collection.doc(o.id), {
            'paidAmount': 0.0,
            'outstandingBalance': o.amount,
            'status': ObligationStatus.unpaid.name,
            'settledAt': FieldValue.delete(),
            'updatedAt': Timestamp.fromDate(now),
          });
        }
      }
      try {
        await cleanupBatch.commit();
      } catch (_) {
        // Fallback if batch delete fails
      }
      memberExisting.removeWhere((o) => duplicatesToDelete.contains(o.id));
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

        // Branch scoping check
        final isBranchScope = levy.scope.toLowerCase() == 'branch';
        if (isBranchScope &&
            levy.branchId != null &&
            levy.branchId!.isNotEmpty &&
            targetBranchId != null &&
            targetBranchId.isNotEmpty &&
            levy.branchId != targetBranchId) {
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
          'id': '${levy.id}_$targetMemberId',
          'organizationId': resolvedOrgId ??
              (levy.organizationId.isNotEmpty ? levy.organizationId : ''),
          'memberId': targetMemberId,
          'userId': targetUserId ?? targetMemberId,
          'levyId': levy.id,
          'type': levy.type.name,
          'title': levy.title,
          'description': levy.description,
          'amount': levy.amountPerMember,
          'paidAmount': 0.0,
          'outstandingBalance': levy.amountPerMember,
          'status': ObligationStatus.unpaid.name,
          'dueDate': Timestamp.fromDate(levy.dueDate),
          'settledAt': null,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'scope': levy.scope,
          if (levy.branchId != null) 'branchId': levy.branchId,
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
        if (template.levyId.isNotEmpty) 'id': '${template.levyId}_$targetMemberId',
        'organizationId': resolvedOrgId ?? template.organizationId,
        'memberId': targetMemberId,
        'userId': targetUserId ?? targetMemberId,
        'levyId': template.levyId,
        'type': ObligationType.monthlyDue.name,
        'title': template.title,
        'description': template.description,
        'amount': template.amount,
        'paidAmount': 0.0,
        'outstandingBalance': template.amount,
        'status': ObligationStatus.unpaid.name,
        'dueDate': Timestamp.fromDate(template.dueDate),
        'settledAt': null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'scope': template.scope,
        if (template.branchId != null) 'branchId': template.branchId,
      });
    }

    // 4. Source C: Specific Opening Balance if provided
    if (resolvedStanding == MemberDuesStanding.openingBalance &&
        resolvedOpeningBalance != null &&
        resolvedOpeningBalance > 0 &&
        !existingTitles.contains('opening balance')) {
      newObligations.add({
        'id': 'opening_balance_$targetMemberId',
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
        'scope': 'branch',
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

  /// Organization-wide cleanup of duplicate and phantom obligations created by race conditions.
  /// Scans all obligations in the organization, cross-references with approved payments,
  /// deletes redundant duplicate documents without legitimate payment allocations,
  /// and resets phantom paid obligations (paidAmount > 0 without approved payment) to unpaid.
  Future<int> cleanupOrganizationDuplicateObligations(
    String organizationId,
  ) async {
    if (organizationId.isEmpty) return 0;

    try {
      // 1. Fetch all members in organization to map userId -> documentId
      final membersSnap = await _firestore
          .collection('members')
          .where('organizationId', isEqualTo: organizationId)
          .get();

      final userToDocId = <String, String>{};
      for (final doc in membersSnap.docs) {
        final data = doc.data();
        final uid = data['userId'] as String?;
        if (uid != null && uid.isNotEmpty) {
          userToDocId[uid] = doc.id;
        }
      }

      // 2. Fetch all approved payments for this organization to identify legitimate allocations
      final allocatedObligationIds = <String>{};
      try {
        final paymentsSnap = await _firestore
            .collection('payments')
            .where('organizationId', isEqualTo: organizationId)
            .get();
        for (final pDoc in paymentsSnap.docs) {
          final pData = pDoc.data();
          if (pData['status'] == PaymentStatus.approved.name) {
            final allocs = pData['allocations'] as List<dynamic>? ?? [];
            for (final a in allocs) {
              if (a is Map && a['obligationId'] != null) {
                allocatedObligationIds.add(a['obligationId'] as String);
              }
            }
          }
        }
      } catch (_) {}

      // 3. Fetch all obligations for this organization
      final snap = await _collection
          .where('organizationId', isEqualTo: organizationId)
          .get();

      if (snap.docs.isEmpty) return 0;

      final obligations =
          snap.docs.map((d) => ObligationModel.fromFirestore(d)).toList();

      // 4. Group by canonical member ID + levy/title key
      final grouped = <String, List<ObligationModel>>{};
      for (final o in obligations) {
        final canonicalMemberId = userToDocId[o.memberId] ?? o.memberId;
        final dueKey = o.levyId.isNotEmpty
            ? 'levy_${o.levyId}'
            : 'title_${o.type.name}_${o.title.trim().toLowerCase()}';
        final compoundKey = '${canonicalMemberId}_$dueKey';
        grouped.putIfAbsent(compoundKey, () => []).add(o);
      }

      final duplicatesToDelete = <String>[];
      final obligationsToReset = <ObligationModel>[];
      final now = DateTime.now();

      for (final list in grouped.values) {
        if (list.length > 1) {
          // Identify if any has real payment
          final withRealPayment =
              list.where((o) => allocatedObligationIds.contains(o.id)).toList();
          final withoutRealPayment =
              list.where((o) => !allocatedObligationIds.contains(o.id)).toList();

          ObligationModel keep;
          if (withRealPayment.isNotEmpty) {
            keep = withRealPayment.first;
            // Delete redundant without payment
            for (final o in withoutRealPayment) {
              duplicatesToDelete.add(o.id);
            }
            // If multiple with real payment, keep first, delete others
            for (var i = 1; i < withRealPayment.length; i++) {
              duplicatesToDelete.add(withRealPayment[i].id);
            }
          } else {
            // None have real payment: prefer deterministic ID or earliest
            keep = withoutRealPayment.first;
            for (final o in withoutRealPayment) {
              if (o.id == '${o.levyId}_${o.memberId}' ||
                  o.id.startsWith('${o.levyId}_')) {
                keep = o;
                break;
              }
            }
            for (final o in withoutRealPayment) {
              if (o.id != keep.id) {
                duplicatesToDelete.add(o.id);
              }
            }
            // Check if kept record has phantom payment
            if (keep.paidAmount > 0) {
              obligationsToReset.add(keep);
            }
          }
        } else {
          // Single record: check if phantom payment
          final o = list.first;
          if (o.paidAmount > 0 && !allocatedObligationIds.contains(o.id)) {
            obligationsToReset.add(o);
          }
        }
      }

      if (duplicatesToDelete.isEmpty && obligationsToReset.isEmpty) return 0;

      // 5. Batch delete duplicates and update phantom records (Firestore limit: 500 ops per batch)
      const batchSize = 350;
      final allOpDocIds = <String>{...duplicatesToDelete, ...obligationsToReset.map((o) => o.id)};
      final allDocIdList = allOpDocIds.toList();

      for (var i = 0; i < allDocIdList.length; i += batchSize) {
        final batch = _firestore.batch();
        final chunk = allDocIdList.sublist(
          i,
          (i + batchSize > allDocIdList.length) ? allDocIdList.length : i + batchSize,
        );
        for (final docId in chunk) {
          if (duplicatesToDelete.contains(docId)) {
            batch.delete(_collection.doc(docId));
          } else {
            final o = obligationsToReset.firstWhere((item) => item.id == docId);
            batch.update(_collection.doc(docId), {
              'paidAmount': 0.0,
              'outstandingBalance': o.amount,
              'status': ObligationStatus.unpaid.name,
              'settledAt': FieldValue.delete(),
              'updatedAt': Timestamp.fromDate(now),
            });
          }
        }
        await batch.commit();
      }

      return duplicatesToDelete.length + obligationsToReset.length;
    } catch (_) {
      return 0;
    }
  }
}
