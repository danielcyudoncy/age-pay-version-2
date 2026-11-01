// features/pro/services/pro_communication_service.dart
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/repositories/notification_repository.dart';
import 'package:cls/features/notifications/services/notification_service.dart';

class ProCommunicationService {
  AnnouncementRepository? _announcementRepo;
  NotificationRepository? _notificationRepo;
  NotificationService? _notificationService;

  ProCommunicationService({
    AnnouncementRepository? announcementRepo,
    NotificationRepository? notificationRepo,
    NotificationService? notificationService,
  })  : _announcementRepo = announcementRepo,
        _notificationRepo = notificationRepo,
        _notificationService = notificationService;

  AnnouncementRepository get announcementRepo =>
      _announcementRepo ??= AnnouncementRepository();
  NotificationRepository get notificationRepo =>
      _notificationRepo ??= NotificationRepository();
  NotificationService get notificationService =>
      _notificationService ??= NotificationService();

  /// Formats a professional broadcast message for WhatsApp, SMS, or external sharing.
  String formatBroadcastMessage({
    required String title,
    required String body,
    required String organizationName,
    String? branchName,
    String? senderName,
    String? urgency,
  }) {
    final buffer = StringBuffer();
    final cleanOrg = organizationName.trim().toUpperCase();
    final cleanBranch = (branchName != null && branchName.isNotEmpty)
        ? ' • ${branchName.trim()}'
        : '';
    final urgencyTag = (urgency != null && urgency.isNotEmpty && urgency.toLowerCase() != 'normal')
        ? '🚨 [${urgency.toUpperCase()}] '
        : '📢 ';

    buffer.writeln('$urgencyTag*$cleanOrg$cleanBranch*');
    buffer.writeln();
    buffer.writeln('📌 *${title.trim()}*');
    buffer.writeln('────────────────────');
    buffer.writeln(body.trim());
    buffer.writeln('────────────────────');

    final signatory = (senderName != null && senderName.isNotEmpty)
        ? senderName.trim()
        : 'Public Relations Officer';
    buffer.writeln('👤 *Dispatched by:* $signatory (PRO)');

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    buffer.writeln('📅 *Date:* $dateStr');
    buffer.write('📱 _Dispatched via AgePay Platform_');

    return buffer.toString();
  }

  /// Sends a message via WhatsApp (either to a direct member or to community/group).
  Future<bool> shareToWhatsApp({
    required String message,
    String? phoneNumber,
  }) async {
    try {
      final cleanPhone = phoneNumber != null
          ? phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')
          : '';

      Uri uri;
      if (cleanPhone.isNotEmpty) {
        // Direct WhatsApp chat link (standard WhatsApp Web/Mobile Universal URL)
        uri = Uri.parse(
          'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
        );
      } else {
        // Broadcast / Share to WhatsApp intent
        uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
      }

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web WhatsApp or generic share
        final fallbackWeb = Uri.parse(
          'https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}',
        );
        if (await canLaunchUrl(fallbackWeb)) {
          return await launchUrl(fallbackWeb, mode: LaunchMode.externalApplication);
        }
        await Share.share(message);
        return true;
      }
    } catch (e) {
      log('WhatsApp dispatch fallback note: $e');
      await Share.share(message);
      return true;
    }
  }

  /// Sends an SMS message to one or multiple recipients.
  Future<bool> sendSms({
    required String message,
    List<String> recipients = const [],
  }) async {
    try {
      final cleanRecipients = recipients
          .map((p) => p.replaceAll(RegExp(r'[^0-9+]'), ''))
          .where((p) => p.isNotEmpty)
          .join(',');

      final uri = Uri.parse(
        'sms:$cleanRecipients?body=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        await Share.share(message);
        return true;
      }
    } catch (e) {
      log('SMS dispatch fallback note: $e');
      await Share.share(message);
      return true;
    }
  }

  /// Initiates a phone call to a member.
  Future<bool> makeCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return false;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Generic system share to any installed messaging app (Telegram, Email, etc.).
  Future<void> shareGeneral(String message, {String? subject}) async {
    await Share.share(message, subject: subject);
  }

  /// Publishes an In-App Broadcast to all target members:
  /// 1. Saves to `announcements` collection.
  /// 2. Saves an in-app `NotificationModel` in `notifications` collection so
  ///    every targeted member receives a push/banner alert with sound and app icon badge.
  /// 3. Plays a confirmation sound on the PRO device.
  Future<String> broadcastInApp({
    required String title,
    required String body,
    required String organizationId,
    required String createdBy,
    String? branchId,
    String targetAudience = 'all', // 'all', 'branch', 'executives'
    bool isPinned = false,
    DateTime? announcementDate,
  }) async {
    final now = DateTime.now();

    // 1. Create Announcement Document
    final announcement = AnnouncementModel(
      id: '',
      title: title.trim(),
      body: body.trim(),
      category: AnnouncementCategory.general,
      organizationId: organizationId,
      createdBy: createdBy,
      targetAudience: targetAudience,
      targetBranchId: (targetAudience == 'branch') ? branchId : null,
      isPinned: isPinned,
      announcementDate: announcementDate ?? now,
      createdAt: now,
      updatedAt: now,
    );
    final announcementId = await announcementRepo.createAnnouncement(announcement);

    // 2. Dispatch In-App Notification record for instant push & audio chime
    try {
      final notif = NotificationModel(
        id: '',
        title: '📢 $title',
        body: body.length > 150 ? '${body.substring(0, 147)}...' : body,
        type: 'announcement',
        receivedAt: now,
        organizationId: organizationId,
        targetRole: (targetAudience == 'executives') ? 'executives' : null,
        targetBranchId: (targetAudience == 'branch') ? branchId : null,
      );
      await notificationRepo.sendNotification(notif);
    } catch (e) {
      log('In-app notification dispatch note: $e');
    }

    // 3. Play confirmation chime and trigger local notification confirmation
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.mediumImpact();
      await notificationService.showNotification(
        title: 'Broadcast Dispatched Successfully',
        body: 'Your message "$title" was delivered across in-app channels.',
      );
    } catch (_) {}

    return announcementId;
  }
}
