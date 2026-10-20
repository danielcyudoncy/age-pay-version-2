import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  static const String collection = 'notifications';

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  /// Send or save a notification to Firestore.
  Future<void> sendNotification(NotificationModel notification) async {
    try {
      final docRef = notification.id.isNotEmpty
          ? _collection.doc(notification.id)
          : _collection.doc();
      final data = notification.copyWith(id: docRef.id).toMap();
      await docRef.set(data);
    } catch (e) {
      log('Failed to send notification: $e');
      rethrow;
    }
  }

  /// Streams notifications scoped by organization and filtered by target recipient.
  Stream<List<NotificationModel>> streamNotifications({
    required String organizationId,
    String? userId,
    UserRole? role,
  }) {
    final isExecutive = role == UserRole.president ||
        role == UserRole.vicePresident ||
        role == UserRole.superAdmin;

    if (organizationId.isEmpty && !isExecutive) {
      return Stream.value([]);
    }

    final notifsStream = organizationId.isNotEmpty
        ? _collection
            .where('organizationId', isEqualTo: organizationId)
            .snapshots()
        : _collection.snapshots();

    if (!isExecutive) {
      return notifsStream.map((snapshot) {
        final items = snapshot.docs
            .map((doc) => NotificationModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .where((n) => _isNotificationForUser(n, userId, role))
            .toList();
        items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        return items;
      }).handleError((error) {
        log('Error streaming notifications: $error');
        return <NotificationModel>[];
      });
    }

    // For executives, merge pending member registrations from the users collection
    // so any member pending approval is ALWAYS visible as an actionable notification.
    return notifsStream.asyncMap((snapshot) async {
      final notifList = snapshot.docs
          .map((doc) => NotificationModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .where((n) => _isNotificationForUser(n, userId, role))
          .toList();

      try {
        final pendingUsersSnap = organizationId.isNotEmpty
            ? await _firestore
                .collection('users')
                .where('organizationId', isEqualTo: organizationId)
                .get()
            : await _firestore.collection('users').get();

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> allPendingDocs = [
          ...pendingUsersSnap.docs,
        ];

        if (organizationId.isNotEmpty) {
          final unassignedSnap = await _firestore
              .collection('users')
              .where('organizationId', isEqualTo: '')
              .get();
          for (final doc in unassignedSnap.docs) {
            if (!allPendingDocs.any((d) => d.id == doc.id)) {
              allPendingDocs.add(doc);
            }
          }
          if (userId != null && userId.isNotEmpty && organizationId != userId) {
            final uidScopedSnap = await _firestore
                .collection('users')
                .where('organizationId', isEqualTo: userId)
                .get();
            for (final doc in uidScopedSnap.docs) {
              if (!allPendingDocs.any((d) => d.id == doc.id)) {
                allPendingDocs.add(doc);
              }
            }
          }
        }

        for (final doc in allPendingDocs) {
          final data = doc.data();
          final statusStr = data['status'] as String?;
          final isActive = data['isActive'] ?? true;
          final isPending = statusStr == 'pendingApproval' ||
              statusStr == 'pending_approval' ||
              isActive == false;

          if (isPending && statusStr != 'rejected') {
            final applicantUid = doc.id;
            // Don't show the president themselves as a pending approval applicant
            if (applicantUid == userId) continue;

            final alreadyInList = notifList.any((n) =>
                n.payload == applicantUid && n.type == 'pending_approval');
            if (!alreadyInList) {
              final displayName = data['displayName'] as String? ?? 'New member';
              final branchName = data['branchName'] as String?;
              final createdAtRaw = data['createdAt'];
              final DateTime receivedAt;
              if (createdAtRaw is Timestamp) {
                receivedAt = createdAtRaw.toDate();
              } else if (createdAtRaw is String) {
                receivedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
              } else {
                receivedAt = DateTime.now();
              }

              notifList.add(
                NotificationModel(
                  id: 'pending_$applicantUid',
                  title: 'New Member Registration',
                  body:
                      '$displayName has registered for ${branchName ?? "your organization"} and is awaiting approval and role assignment.',
                  type: 'pending_approval',
                  payload: applicantUid,
                  targetRole: 'president',
                  organizationId: organizationId,
                  receivedAt: receivedAt,
                  read: false,
                ),
              );
            }
          }
        }
      } catch (e) {
        log('Error fetching pending users in notifications stream: $e');
      }

      notifList.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return notifList;
    }).handleError((error) {
      log('Error streaming notifications: $error');
      return <NotificationModel>[];
    });
  }

  bool _isNotificationForUser(
    NotificationModel n,
    String? userId,
    UserRole? role,
  ) {
    if (n.targetUserId != null && n.targetUserId!.isNotEmpty) {
      if (n.targetUserId != userId) return false;
    }

    if (n.targetRole != null && n.targetRole!.isNotEmpty) {
      final target = n.targetRole!.toLowerCase();
      if (role != null) {
        if (target == 'president' &&
            role != UserRole.president &&
            role != UserRole.vicePresident &&
            role != UserRole.superAdmin) {
          return false;
        }
        if (target == 'secretary' &&
            role != UserRole.secretary &&
            role != UserRole.viceSecretary &&
            role != UserRole.superAdmin) {
          return false;
        }
        if (target == 'treasurer' &&
            role != UserRole.treasurer &&
            role != UserRole.viceTreasurer &&
            role != UserRole.financialSecretary &&
            role != UserRole.superAdmin) {
          return false;
        }
      }
    }
    return true;
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _collection.doc(notificationId).update({'read': true});
    } catch (e) {
      log('Failed to mark notification read: $e');
    }
  }

  /// Mark all notifications for an organization/user as read.
  Future<void> markAllAsRead({
    required String organizationId,
    String? userId,
    UserRole? role,
  }) async {
    try {
      final snap = await _collection
          .where('organizationId', isEqualTo: organizationId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      log('Failed to mark all read: $e');
    }
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _collection.doc(notificationId).delete();
    } catch (e) {
      log('Failed to delete notification: $e');
    }
  }
}
