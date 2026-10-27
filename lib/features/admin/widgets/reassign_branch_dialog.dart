import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/admin_provider.dart';
import '../../auth/models/user_model.dart';

class ReassignBranchDialog extends ConsumerStatefulWidget {
  final UserModel user;
  final Function(String organizationId, String branchId, String branchName) onSave;

  const ReassignBranchDialog({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  ConsumerState<ReassignBranchDialog> createState() => _ReassignBranchDialogState();
}

class _ReassignBranchDialogState extends ConsumerState<ReassignBranchDialog> {
  String? _selectedOrgId;
  String? _selectedBranchId;
  String? _selectedBranchName;

  @override
  void initState() {
    super.initState();
    _selectedOrgId = widget.user.organizationId;
    _selectedBranchId = widget.user.branchId;
    _selectedBranchName = widget.user.branchName;
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsStreamProvider);
    final branchesAsync = _selectedOrgId != null && _selectedOrgId!.isNotEmpty
        ? ref.watch(branchesStreamFamily(_selectedOrgId!))
        : null;

    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      title: const Text(
        'Reassign Organization / Branch',
        overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 16),
              const Text(
                'Select Organization',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              orgsAsync.when(
                data: (orgs) {
                  if (orgs.isEmpty) {
                    return const Text('No organizations found.');
                  }
                  final validOrgId = orgs.any((o) => o.id == _selectedOrgId)
                      ? _selectedOrgId
                      : orgs.first.id;

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: validOrgId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: orgs.map((org) {
                      return DropdownMenuItem(
                        value: org.id,
                        child: Text(
                          org.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newOrgId) {
                      if (newOrgId != null) {
                        setState(() {
                          _selectedOrgId = newOrgId;
                          _selectedBranchId = null;
                          _selectedBranchName = null;
                        });
                      }
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error loading orgs: $err'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Branch',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (branchesAsync != null)
                branchesAsync.when(
                  data: (branches) {
                    if (branches.isEmpty) {
                      return const Text(
                        'No branches available in this organization.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      );
                    }
                    final validBranchId = branches.any((b) => b.id == _selectedBranchId)
                        ? _selectedBranchId
                        : branches.first.id;

                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: validBranchId,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: branches.map((branch) {
                        return DropdownMenuItem(
                          value: branch.id,
                          child: Text(
                            branch.city.isNotEmpty
                                ? '${branch.name} (${branch.city})'
                                : branch.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (newBranchId) {
                        if (newBranchId != null) {
                          final found = branches.firstWhere((b) => b.id == newBranchId);
                          setState(() {
                            _selectedBranchId = found.id;
                            _selectedBranchName = found.name;
                          });
                        }
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error loading branches: $err'),
                )
              else
                const Text('Select an organization first.'),
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
            if (_selectedOrgId != null &&
                _selectedBranchId != null &&
                _selectedBranchName != null) {
              widget.onSave(_selectedOrgId!, _selectedBranchId!, _selectedBranchName!);
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select both organization and branch.')),
              );
            }
          },
          child: const Text('Save Assignment'),
        ),
      ],
    );
  }
}
