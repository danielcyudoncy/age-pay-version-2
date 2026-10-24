import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
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
    }
  }

  void _showApprovalSheet(BuildContext context, WidgetRef ref, String applicantUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ApprovalModal(
        applicantUid: applicantUid,
        organizationId: currentUser.organizationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
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
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(notificationListProvider.notifier).markAllAsRead();
              },
              child: const Text('Mark all read'),
            ),
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
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${applicant.displayName} approved as ${_roleLabel(roleToAssign)}.',
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
                'Assign Official Role',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
