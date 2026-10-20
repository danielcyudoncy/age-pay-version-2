import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/enums.dart';
import '../models/user_model.dart';
import '../controllers/auth_provider.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const PendingApprovalScreen({super.key, required this.user});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(authProvider.notifier).refreshUser();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRejected = widget.user.status == AccountStatus.rejected;
    final isPioneerPresident = widget.user.role == UserRole.president &&
        widget.user.coFounderPhone != null &&
        widget.user.coFounderPhone!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: isRejected
                          ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                          : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRejected
                          ? Icons.cancel_outlined
                          : isPioneerPresident
                              ? Icons.shield_outlined
                              : Icons.hourglass_top_rounded,
                      size: 48,
                      color: isRejected
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isRejected
                        ? 'Application Not Approved'
                        : isPioneerPresident
                            ? 'Awaiting Co-Founder Verification'
                            : 'Approval Pending',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRejected
                        ? 'Your registration was reviewed and not approved by the organization executive.'
                        : isPioneerPresident
                            ? 'Your new Age Grade requires dual-executive verification before going live.'
                            : 'Your application has been received and is awaiting approval by your Branch Executive.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Application Details',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            context,
                            'Applicant',
                            widget.user.displayName,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            'Branch',
                            widget.user.branchName ?? 'Headquarters',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            'Role Requested',
                            _roleLabel(widget.user.requestedRole ?? widget.user.role),
                          ),
                          if (isPioneerPresident) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context,
                              'Invited Secretary',
                              '${widget.user.coFounderName ?? 'General Secretary'} (${widget.user.coFounderPhone})',
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            context,
                            'Status',
                            isRejected
                                ? 'Declined'
                                : isPioneerPresident
                                    ? 'Awaiting Secretary Co-Sign'
                                    : 'In Review by President/VP',
                            valueColor: isRejected
                                ? theme.colorScheme.error
                                : Colors.amber.shade800,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isPioneerPresident && !isRejected)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tell ${widget.user.coFounderName ?? 'your Secretary'} to open AgePay and sign in or register with phone number ${widget.user.coFounderPhone}. They will see an instant prompt to co-sign and activate your Age Grade.',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              final phone = widget.user.coFounderPhone ?? '';
                              final name = widget.user.coFounderName ?? 'General Secretary';
                              final message =
                                  'Hello $name, I have registered our Age Grade on AgePay and listed you as General Secretary. Please download/open the AgePay app and sign in with your phone number ($phone) to co-sign and activate our Age Grade!';
                              Share.share(message);
                            },
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Send Invite via WhatsApp / SMS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isRejected) ...[
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isRefreshing ? null : _refresh,
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Check Approval Status'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

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
      case UserRole.executiveMember:
        return 'Executive Member';
      case UserRole.committeeChair:
        return 'Committee Chair';
      case UserRole.member:
        return 'Member';
    }
  }
}
