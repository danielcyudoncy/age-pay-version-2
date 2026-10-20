import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../core/constants/enums.dart';

class ExecutiveApprovalQueueCard extends ConsumerStatefulWidget {
  final String organizationId;

  const ExecutiveApprovalQueueCard({
    super.key,
    required this.organizationId,
  });

  @override
  ConsumerState<ExecutiveApprovalQueueCard> createState() =>
      _ExecutiveApprovalQueueCardState();
}

class _ExecutiveApprovalQueueCardState
    extends ConsumerState<ExecutiveApprovalQueueCard> {
  final Set<String> _processingIds = {};
  final Map<String, UserRole> _assignedRoles = {};

  Future<void> _approve(UserModel applicant) async {
    setState(() => _processingIds.add(applicant.uid));
    try {
      final authService = ref.read(authServiceProvider);
      final assignedRole = _assignedRoles[applicant.uid] ??
          applicant.requestedRole ??
          UserRole.member;
      await authService.approveUserRegistration(
        uid: applicant.uid,
        organizationId: widget.organizationId,
        assignedRole: assignedRole,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${applicant.displayName} approved as ${_roleLabel(assignedRole)}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to approve: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(applicant.uid));
      }
    }
  }

  Future<void> _reject(UserModel applicant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Registration?'),
        content: Text(
          'Are you sure you want to reject ${applicant.displayName}\'s registration?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _processingIds.add(applicant.uid));
      try {
        final authService = ref.read(authServiceProvider);
        await authService.rejectUserRegistration(uid: applicant.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${applicant.displayName}\'s request rejected.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Error: $e'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _processingIds.remove(applicant.uid));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingAsync =
        ref.watch(pendingRegistrationsStreamProvider(widget.organizationId));

    return pendingAsync.when(
      data: (pendingList) {
        if (pendingList.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.shade100.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_alt_1,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pending Member Approvals (${pendingList.length})',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTION REQUIRED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'The following members registered and are awaiting your approval to gain access to the organization:',
                  style: TextStyle(
                    color: Colors.amber.shade900.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final applicant = pendingList[index];
                    final isProcessing =
                        _processingIds.contains(applicant.uid);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  applicant.displayName.isNotEmpty
                                      ? applicant.displayName[0].toUpperCase()
                                      : 'M',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      applicant.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${applicant.phoneNumber} • ${applicant.email}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _chip(
                                icon: Icons.location_on_outlined,
                                label: applicant.branchName ?? 'Headquarters',
                              ),
                              if (applicant.requestedRole != null &&
                                  applicant.requestedRole != UserRole.member)
                                _chip(
                                  icon: Icons.info_outline,
                                  label:
                                      'Requested: ${_roleLabel(applicant.requestedRole!)}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<UserRole>(
                                value: _assignedRoles[applicant.uid] ??
                                    applicant.requestedRole ??
                                    UserRole.member,
                                isExpanded: true,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.amber.shade900,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                                items: UserRole.values
                                    .where((role) => role != UserRole.superAdmin)
                                    .map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.badge_outlined,
                                          size: 15,
                                          color: Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Assign Role: ${_roleLabel(role)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: isProcessing
                                    ? null
                                    : (newRole) {
                                        if (newRole != null) {
                                          setState(() =>
                                              _assignedRoles[applicant.uid] =
                                                  newRole);
                                        }
                                      },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: isProcessing
                                    ? null
                                    : () => _reject(applicant),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Reject', style: TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () => _approve(applicant),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 16),
                                label: const Text('Approve', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
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
