import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../controllers/national_provider.dart';

class AssignNationalOfficeDialog extends ConsumerStatefulWidget {
  final UserModel member;

  const AssignNationalOfficeDialog({super.key, required this.member});

  static Future<bool?> show(BuildContext context, UserModel member) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AssignNationalOfficeDialog(member: member),
    );
  }

  @override
  ConsumerState<AssignNationalOfficeDialog> createState() =>
      _AssignNationalOfficeDialogState();
}

class _AssignNationalOfficeDialogState
    extends ConsumerState<AssignNationalOfficeDialog> {
  UserRole? _selectedNationalRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedNationalRole = widget.member.nationalRole ?? UserRole.financialSecretary;
  }

  Future<void> _save() async {
    if (_selectedNationalRole == null) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(nationalRepositoryProvider).assignNationalOfficer(
            organizationId: widget.member.organizationId,
            uid: widget.member.uid,
            displayName: widget.member.displayName,
            nationalRole: _selectedNationalRole!,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.brandGreen,
            content: Text(
              '${widget.member.displayName} assigned as ${_selectedNationalRole!.displayName} (National Body)',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to assign national office: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _revoke() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(nationalRepositoryProvider).removeNationalOfficer(
            organizationId: widget.member.organizationId,
            uid: widget.member.uid,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'National office revoked from ${widget.member.displayName}',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to revoke national office: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligibleRoles = [
      UserRole.president,
      UserRole.vicePresident,
      UserRole.secretary,
      UserRole.viceSecretary,
      UserRole.financialSecretary,
      UserRole.treasurer,
      UserRole.viceTreasurer,
      UserRole.publicRelationsOfficer,
      UserRole.provost,
      UserRole.auditor,
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.stars_rounded, color: AppTheme.brandGreen),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Assign National Office',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appoint ${widget.member.displayName} to an executive leadership role at the National tier. They will retain their branch affiliation while gaining national executive privileges.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city, size: 20, color: AppTheme.brandGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current Branch: ${widget.member.branchName ?? 'Direct Member'} (${widget.member.role.displayName})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _selectedNationalRole,
              decoration: InputDecoration(
                labelText: 'Select National Office',
                prefixIcon: const Icon(Icons.military_tech, color: AppTheme.brandGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: eligibleRoles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedNationalRole = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.member.nationalRole != null)
          TextButton(
            onPressed: _isLoading ? null : _revoke,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke Office'),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm Appointment'),
        ),
      ],
    );
  }
}
