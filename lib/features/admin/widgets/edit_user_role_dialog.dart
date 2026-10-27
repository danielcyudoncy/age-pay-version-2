import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';
import '../../auth/models/user_model.dart';

class EditUserRoleDialog extends StatefulWidget {
  final UserModel user;
  final Function(UserRole role, UserRole? nationalRole, bool clearNationalRole) onSave;

  const EditUserRoleDialog({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<EditUserRoleDialog> createState() => _EditUserRoleDialogState();
}

class _EditUserRoleDialogState extends State<EditUserRoleDialog> {
  late UserRole _selectedRole;
  UserRole? _selectedNationalRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
    _selectedNationalRole = widget.user.nationalRole;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          'Edit User Role & Permissions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User: ${widget.user.displayName.isNotEmpty ? widget.user.displayName : widget.user.email}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.user.branchName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Branch: ${widget.user.branchName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Branch Role',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<UserRole>(
                isExpanded: true,
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(
                      role.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newRole) {
                  if (newRole != null) {
                    setState(() => _selectedRole = newRole);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'National Role (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<UserRole?>(
                isExpanded: true,
                initialValue: _selectedNationalRole,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<UserRole?>(
                    value: null,
                    child: Text(
                      'None (Standard Branch Member)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...UserRole.values
                      .where((r) => r != UserRole.superAdmin && r != UserRole.member)
                      .map((role) {
                    return DropdownMenuItem<UserRole?>(
                      value: role,
                      child: Text(
                        'National ${role.displayName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (newRole) {
                  setState(() => _selectedNationalRole = newRole);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final clearNational = _selectedNationalRole == null && widget.user.nationalRole != null;
            widget.onSave(_selectedRole, _selectedNationalRole, clearNational);
            Navigator.of(context).pop();
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
