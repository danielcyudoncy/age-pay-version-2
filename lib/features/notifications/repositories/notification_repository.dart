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
    if (organizationId.isEmpty) return Stream.value([]);

    return _collection
        .where('organizationId', isEqualTo: organizationId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            return NotificationModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).where((n) {
            // If targeted to a specific user, ensure user matches
            if (n.targetUserId != null && n.targetUserId!.isNotEmpty) {
              if (n.targetUserId != userId) return false;
            }

            // If targeted to a specific role, ensure role matches
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
          }).toList();

          items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
          return items;
        })
        .handleError((error) {
          log('Error streaming notifications: $error');
          return <NotificationModel>[];
        });
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
