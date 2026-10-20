import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/co_founder_invitation_model.dart';
import '../models/user_model.dart';
import '../controllers/auth_provider.dart';

class CoFounderVerificationDialog extends ConsumerStatefulWidget {
  final CoFounderInvitationModel invitation;
  final UserModel user;

  const CoFounderVerificationDialog({
    super.key,
    required this.invitation,
    required this.user,
  });

  @override
  ConsumerState<CoFounderVerificationDialog> createState() =>
      _CoFounderVerificationDialogState();
}

class _CoFounderVerificationDialogState
    extends ConsumerState<CoFounderVerificationDialog> {
  bool _isLoading = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(coFounderInvitationRepositoryProvider);
      await repo.acceptInvitation(
        invitationId: widget.invitation.id,
        secretaryUid: widget.user.uid,
        secretaryName: widget.user.displayName,
        secretaryEmail: widget.user.email,
      );
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${widget.invitation.organizationName} is now active! Welcome, General Secretary.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Invitation?'),
        content: const Text(
          'Are you sure you want to decline this executive invitation? The organization will not be activated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(coFounderInvitationRepositoryProvider);
        await repo.declineInvitation(widget.invitation.id);
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Executive Co-Sign',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Dual-Verification Required',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'You have been invited by the President to co-found and verify a new organization on AgePay:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    _infoRow('Age Grade', widget.invitation.organizationName),
                    const SizedBox(height: 8),
                    _infoRow('Branch', widget.invitation.branchName),
                    const SizedBox(height: 8),
                    _infoRow(
                      'President',
                      '${widget.invitation.presidentName} (${widget.invitation.presidentPhone})',
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Your Role', 'General Secretary'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  ),
                ),
              Text(
                'By approving, you confirm this organization is legitimate and accept the role of General Secretary.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _approve,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Approve & Activate Organization'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _decline,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Not Me / Decline Invitation'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
