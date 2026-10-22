import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/enums.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore? _firestore;
  static const String collection = 'notifications';

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _fs.collection(collection);

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
  /// For executives (President/VP/SuperAdmin), this automatically listens to BOTH
  /// the notifications collection and the users collection in real time, so any
  /// registration immediately triggers a visible notification without needing a manual refresh.
  Stream<List<NotificationModel>> streamNotifications({
    required String organizationId,
    String? userId,
    UserRole? role,
  }) {
    try {
      final isExecutive = role == UserRole.president ||
          role == UserRole.vicePresident ||
          role == UserRole.superAdmin;

      if (organizationId.isEmpty && !isExecutive) {
        return Stream.value([]);
      }

      final notifsQuery = isExecutive
          ? _collection
          : (organizationId.isNotEmpty
              ? _collection.where('organizationId', isEqualTo: organizationId)
              : _collection);

      final notifsStream = notifsQuery.snapshots().map((snapshot) {
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

    if (!isExecutive) {
      return notifsStream;
    }

    // Combine notifications collection stream with users collection stream
    final StreamController<List<NotificationModel>> controller =
        StreamController<List<NotificationModel>>.broadcast();

    List<NotificationModel> latestNotifs = [];
    List<NotificationModel> latestPending = [];

    void emitMerged() {
      final Map<String, NotificationModel> map = {};
      for (final n in latestNotifs) {
        map[n.id] = n;
      }
      for (final n in latestPending) {
        final alreadyInMap = map.values.any((item) =>
            item.payload == n.payload && item.type == 'pending_approval');
        if (!alreadyInMap) {
          map[n.id] = n;
        }
      }
      final list = map.values.toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    StreamSubscription? notifSub;
    StreamSubscription? usersSub;

    controller.onListen = () {
      notifSub = notifsStream.listen(
        (items) {
          latestNotifs = items;
          emitMerged();
        },
        onError: (err) {
          log('Error on notifsStream: $err');
        },
      );

      final usersStream = _fs.collection('users').snapshots();
      usersSub = usersStream.listen(
        (snap) {
          final pendingList = <NotificationModel>[];
          for (final doc in snap.docs) {
            final data = doc.data();
            final statusStr = (data['status'] as String? ?? '').toLowerCase();
            final isActive = data['isActive'] ?? true;
            final isPending = statusStr == 'pendingapproval' ||
                statusStr == 'pending_approval' ||
                isActive == false;

            if (!isPending || statusStr == 'rejected') continue;

            final applicantUid = doc.id;
            if (applicantUid == userId) continue;

            final displayName =
                data['displayName'] as String? ?? 'New member';
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

            pendingList.add(
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

          latestPending = pendingList;
          emitMerged();
        },
        onError: (err) {
          log('Error on usersStream: $err');
        },
      );
    };

    controller.onCancel = () {
      notifSub?.cancel();
      usersSub?.cancel();
    };

      return controller.stream;
    } catch (_) {
      return Stream.value([]);
    }
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

      final batch = _fs.batch();
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
