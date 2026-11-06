import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../meetings/controllers/meeting_provider.dart';
import '../../meetings/views/meeting_detail_screen.dart';
import '../../meetings/views/meeting_list_screen.dart';
import '../../payments/views/make_payment_screen.dart';
import '../../secretary/views/member_announcements_screen.dart';
import '../controllers/notification_provider.dart';
import '../models/notification_model.dart';
import '../widgets/notification_widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  final UserModel currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  void _handleTap(BuildContext context, WidgetRef ref, NotificationModel notification) {
    ref.read(notificationListProvider.notifier).markAsRead(notification.id);

    final isExecutive = currentUser.role == UserRole.president ||
        currentUser.role == UserRole.vicePresident ||
        currentUser.role == UserRole.superAdmin;

    if (notification.type == 'pending_approval' &&
        notification.payload != null &&
        notification.payload!.isNotEmpty &&
        isExecutive) {
      _showApprovalSheet(context, ref, notification.payload!);
    } else {
      _showNotificationDetail(context, ref, notification);
    }
  }

  void _showNotificationDetail(BuildContext context, WidgetRef ref, NotificationModel notification) {
    showDialog(
      context: context,
      builder: (ctx) => _NotificationDetailDialog(
        notification: notification,
        currentUser: currentUser,
      ),
    );
  }

  void _showApprovalSheet(BuildContext context, WidgetRef ref, String applicantUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ApprovalModal(
        applicantUid: applicantUid,
        organizationId: currentUser.organizationId,
      ),
    );
  }

  void _confirmDelete({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              onConfirm();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Notifications'),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Badge(
                  label: Text('$unreadCount'),
                  child: const SizedBox(width: 16, height: 16),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (notifications.isNotEmpty) ...[
            if (unreadCount > 0)
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark all as read',
                onPressed: () {
                  ref.read(notificationListProvider.notifier).markAllAsRead();
                },
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Notification options',
              onSelected: (value) {
                final notifier = ref.read(notificationListProvider.notifier);
                switch (value) {
                  case 'mark_all_read':
                    notifier.markAllAsRead();
                    break;
                  case 'delete_read':
                    final readCount = notifications.where((n) => n.read).length;
                    if (readCount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No read notifications to delete.')),
                      );
                      return;
                    }
                    _confirmDelete(
                      context: context,
                      title: 'Delete Read Notifications',
                      message: 'Are you sure you want to delete all $readCount read notifications?',
                      onConfirm: () => notifier.deleteReadNotifications(),
                    );
                    break;
                  case 'delete_7_days':
                    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                    final oldCount = notifications.where((n) => n.receivedAt.isBefore(weekAgo)).length;
                    if (oldCount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No notifications older than 7 days.')),
                      );
                      return;
                    }
                    _confirmDelete(
                      context: context,
                      title: 'Delete Older Notifications',
                      message: 'Delete $oldCount notifications older than 7 days?',
                      onConfirm: () => notifier.deleteOlderThan(const Duration(days: 7)),
                    );
                    break;
                  case 'delete_30_days':
                    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
                    final oldCount = notifications.where((n) => n.receivedAt.isBefore(monthAgo)).length;
                    if (oldCount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No notifications older than 30 days.')),
                      );
                      return;
                    }
                    _confirmDelete(
                      context: context,
                      title: 'Delete Older Notifications',
                      message: 'Delete $oldCount notifications older than 30 days?',
                      onConfirm: () => notifier.deleteOlderThan(const Duration(days: 30)),
                    );
                    break;
                  case 'delete_all':
                    _confirmDelete(
                      context: context,
                      title: 'Clear All Notifications',
                      message: 'Are you sure you want to delete all ${notifications.length} notifications? This cannot be undone.',
                      onConfirm: () => notifier.deleteAllNotifications(),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                if (unreadCount > 0) ...[
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text('Mark all as read')),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                ],
                const PopupMenuItem(
                  value: 'delete_read',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('Delete read notifications')),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_7_days',
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('Delete older than 7 days')),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_30_days',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, size: 20),
                      SizedBox(width: 10),
                      Expanded(child: Text('Delete older than 30 days')),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Clear all notifications',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(notificationListProvider.notifier).refresh();
        },
        child: notifications.isEmpty
            ? const EmptyState()
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return NotificationCard(
                    notification: notification,
                    onTap: () => _handleTap(context, ref, notification),
                    onDismiss: () => ref
                        .read(notificationListProvider.notifier)
                        .deleteNotification(notification.id),
                  );
                },
              ),
      ),
    );
  }
}

class _ApprovalModal extends ConsumerStatefulWidget {
  final String applicantUid;
  final String organizationId;

  const _ApprovalModal({
    required this.applicantUid,
    required this.organizationId,
  });

  @override
  ConsumerState<_ApprovalModal> createState() => _ApprovalModalState();
}

class _ApprovalModalState extends ConsumerState<_ApprovalModal> {
  UserRole? _selectedRole;
  UserRole? _selectedNationalRole;
  bool _isProcessing = false;

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.president:
        return 'President';
      case UserRole.vicePresident:
        return 'Vice President';
      case UserRole.secretary:
        return 'Secretary';
      case UserRole.viceSecretary:
        return 'Vice Secretary';
      case UserRole.treasurer:
        return 'Treasurer';
      case UserRole.viceTreasurer:
        return 'Vice Treasurer';
      case UserRole.financialSecretary:
        return 'Financial Secretary';
      case UserRole.auditor:
        return 'Auditor';
      case UserRole.publicRelationsOfficer:
        return 'Public Relations Officer';
      case UserRole.provost:
        return 'Provost';
      case UserRole.executiveMember:
        return 'Executive Member';
      case UserRole.committeeChair:
        return 'Committee Chair';
      case UserRole.member:
        return 'Member';
    }
  }

  Future<void> _approve(UserModel applicant) async {
    setState(() => _isProcessing = true);
    try {
      final authService = ref.read(authServiceProvider);
      final roleToAssign = _selectedRole ?? applicant.requestedRole ?? UserRole.member;

      await authService.approveUserRegistration(
        uid: applicant.uid,
        organizationId: widget.organizationId,
        assignedRole: roleToAssign,
        assignedNationalRole: _selectedNationalRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final nationalNotice = _selectedNationalRole != null
            ? ' & National ${_roleLabel(_selectedNationalRole!)}'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${applicant.displayName} approved as ${_roleLabel(roleToAssign)}$nationalNotice.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject(UserModel applicant) async {
    setState(() => _isProcessing = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.rejectUserRegistration(uid: applicant.uid);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${applicant.displayName}\'s registration rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = ref.watch(authServiceProvider);
    final currentUser = ref.watch(authProvider).valueOrNull;
    final canAssignNational = currentUser?.role == UserRole.president ||
        currentUser?.role == UserRole.superAdmin ||
        currentUser?.nationalRole == UserRole.president;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FutureBuilder<UserModel?>(
        future: authService.getUserById(widget.applicantUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final applicant = snapshot.data;
          if (applicant == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Applicant details could not be found.')),
            );
          }

          if (applicant.status == AccountStatus.approved) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    '${applicant.displayName} is already approved as ${_roleLabel(applicant.role)}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          _selectedRole ??= applicant.requestedRole ?? UserRole.member;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      applicant.displayName.isNotEmpty
                          ? applicant.displayName[0].toUpperCase()
                          : 'M',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          applicant.displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${applicant.phoneNumber} • ${applicant.email}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.brown),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Branch: ${applicant.branchName ?? "Headquarters"}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (applicant.requestedRole != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 16, color: Colors.brown),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Applicant requested role: ${_roleLabel(applicant.requestedRole!)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Assign Branch Role',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Operational role within ${applicant.branchName ?? "their branch"}.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserRole>(
                    value: _selectedRole,
                    isExpanded: true,
                    items: UserRole.values
                        .where((role) => role != UserRole.superAdmin)
                        .map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabel(role)),
                      );
                    }).toList(),
                    onChanged: _isProcessing
                        ? null
                        : (newRole) {
                            if (newRole != null) {
                              setState(() => _selectedRole = newRole);
                            }
                          },
                  ),
                ),
              ),
              if (canAssignNational) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 16, color: Colors.teal),
                    const SizedBox(width: 6),
                    const Text(
                      '2. Assign National Office (Optional)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Elevate this member into the National Executive / Assembly.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade300),
                    color: Colors.teal.shade50.withValues(alpha: 0.3),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserRole?>(
                      value: _selectedNationalRole,
                      isExpanded: true,
                      hint: const Text('None (Regular Member)'),
                      items: [
                        const DropdownMenuItem<UserRole?>(
                          value: null,
                          child: Text('None (Regular Member)'),
                        ),
                        ...UserRole.values
                            .where((role) =>
                                role != UserRole.superAdmin &&
                                role != UserRole.member)
                            .map((role) {
                          return DropdownMenuItem<UserRole?>(
                            value: role,
                            child: Text('National ${_roleLabel(role)}'),
                          );
                        }),
                      ],
                      onChanged: _isProcessing
                          ? null
                          : (newNatRole) {
                              setState(() => _selectedNationalRole = newNatRole);
                            },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => _reject(applicant),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _approve(applicant),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Approve & Assign Role'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationDetailDialog extends ConsumerWidget {
  final NotificationModel notification;
  final UserModel currentUser;

  const _NotificationDetailDialog({
    required this.notification,
    required this.currentUser,
  });

  (IconData, Color, String) _typeMetadata(BuildContext context) {
    switch (notification.type) {
      case 'meeting':
        return (Icons.event_available, Colors.indigo, 'MEETING NOTICE');
      case 'announcement':
        return (Icons.campaign, Colors.teal, 'ANNOUNCEMENT');
      case 'levy':
        return (Icons.receipt_long, Theme.of(context).colorScheme.primary, 'LEVY / DUES');
      case 'payment':
        return (Icons.payment, Colors.green, 'PAYMENT CONFIRMATION');
      case 'pending_approval':
        return (Icons.person_add_alt_1, Colors.amber.shade800, 'APPROVAL REQUEST');
      case 'approval_success':
        return (Icons.verified_user, Colors.green, 'APPROVAL SUCCESS');
      case 'co_founder_invite':
        return (Icons.shield, Colors.blue, 'INVITATION');
      case 'reminder':
        return (Icons.alarm, Colors.orange, 'REMINDER');
      case 'general':
      default:
        return (Icons.notifications_active, Colors.blueGrey, 'NOTIFICATION');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (iconData, iconColor, typeLabel) = _typeMetadata(context);
    final dateTimeFormat = DateFormat('EEE, MMM dd, yyyy \u2022 hh:mm a');

    final isExecutive = currentUser.role == UserRole.president ||
        currentUser.role == UserRole.vicePresident ||
        currentUser.role == UserRole.superAdmin;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Type badge, Close
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: iconColor.withValues(alpha: 0.15),
                    child: Icon(iconData, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                notification.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),

              // Timestamp
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateTimeFormat.format(notification.receivedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Message Body
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    notification.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons based on type
              Row(
                children: [
                  if (notification.type == 'meeting') ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandGreen,
                        ),
                        icon: const Icon(Icons.event, size: 18),
                        label: const Text('View Meeting & RSVP'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final meetingId = notification.payload;
                          if (meetingId != null && meetingId.isNotEmpty) {
                            final meeting = await ref
                                .read(meetingRepositoryProvider)
                                .getMeetingById(meetingId);
                            if (context.mounted) {
                              if (meeting != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MeetingDetailScreen(
                                      meeting: meeting,
                                      readOnly: true,
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                          }
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MeetingListScreen(initialTabIndex: 0),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (notification.type == 'levy') ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandGreen,
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Pay Now'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MakePaymentScreen(
                                memberId: currentUser.uid,
                                memberEmail: currentUser.email,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (notification.type == 'announcement') ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandGreen,
                        ),
                        icon: const Icon(Icons.campaign, size: 18),
                        label: const Text('View Announcements'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MemberAnnouncementsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (notification.type == 'pending_approval' && isExecutive) ...[
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                        ),
                        icon: const Icon(Icons.how_to_reg, size: 18),
                        label: const Text('Review Application'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (notification.payload != null &&
                              notification.payload!.isNotEmpty) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => _ApprovalModal(
                                applicantUid: notification.payload!,
                                organizationId: currentUser.organizationId,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
