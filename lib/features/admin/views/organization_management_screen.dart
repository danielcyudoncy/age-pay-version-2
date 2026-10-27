import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/widgets/edit_branch_bank_dialog.dart';
import 'package:cls/features/admin/widgets/organization_list_item.dart';

class OrganizationManagementScreen extends ConsumerStatefulWidget {
  const OrganizationManagementScreen({super.key});

  @override
  ConsumerState<OrganizationManagementScreen> createState() =>
      _OrganizationManagementScreenState();
}

class _OrganizationManagementScreenState
    extends ConsumerState<OrganizationManagementScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final organizationsAsync = ref.watch(organizationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Organization',
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search organizations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: organizationsAsync.when(
              data: (organizations) {
                final filtered = _query.isEmpty
                    ? organizations
                    : organizations.where((org) {
                        final q = _query;
                        return org.name.toLowerCase().contains(q) ||
                            org.slug.toLowerCase().contains(q) ||
                            org.contactEmail.toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No organizations found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final org = filtered[index];
                    return OrganizationListItem(
                      organization: org,
                      onToggleStatus: () {
                        if (org.isActive) {
                          ref
                              .read(organizationRepositoryProvider)
                              .deactivateOrganization(org.id);
                        } else {
                          ref
                              .read(organizationRepositoryProvider)
                              .activateOrganization(org.id);
                        }
                      },
                      onToggleJoin: () {
                        ref
                            .read(organizationRepositoryProvider)
                            .setOpenForJoin(org.id, !org.openForJoin);
                      },
                      onEdit: () => _showEditDialog(context, org),
                      onAddBranch: () => _showAddBranchDialog(context, org),
                      onDelete: () => _confirmDeleteOrganization(context, org),
                      onBranchTap: (branch) =>
                          _showBranchDetailsDialog(context, branch),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    bool openForJoin = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Organization'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Contact Email'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Contact Phone'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Open for join'),
                  subtitle: const Text('Allow members to join this branch'),
                  value: openForJoin,
                  onChanged: (v) => setDialogState(() => openForJoin = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    slugController.text.isEmpty) {
                  return;
                }
                final org = OrganizationModel(
                  id: '',
                  name: nameController.text.trim(),
                  slug: slugController.text.trim(),
                  contactEmail: emailController.text.trim(),
                  contactPhone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  openForJoin: openForJoin,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await ref
                    .read(organizationRepositoryProvider)
                    .createOrganization(org);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, OrganizationModel org) {
    final nameController = TextEditingController(text: org.name);
    final slugController = TextEditingController(text: org.slug);
    final emailController = TextEditingController(text: org.contactEmail);
    final phoneController = TextEditingController(text: org.contactPhone);
    final addressController = TextEditingController(text: org.address);
    bool openForJoin = org.openForJoin;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Organization'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Contact Email'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Contact Phone'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Open for join'),
                  subtitle: const Text('Allow members to join this branch'),
                  value: openForJoin,
                  onChanged: (v) => setDialogState(() => openForJoin = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    slugController.text.isEmpty) {
                  return;
                }
                final updated = org.copyWith(
                  name: nameController.text.trim(),
                  slug: slugController.text.trim(),
                  contactEmail: emailController.text.trim(),
                  contactPhone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  openForJoin: openForJoin,
                  updatedAt: DateTime.now(),
                );
                await ref
                    .read(organizationRepositoryProvider)
                    .updateOrganization(updated);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBranchDialog(BuildContext context, OrganizationModel org) {
    final nameController = TextEditingController();
    final stateController = TextEditingController();
    final cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Add Branch to ${org.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  hintText: 'e.g. Aba, Lagos, Abuja',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stateController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'State',
                  hintText: 'e.g. Abia, Lagos',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. Aba, Ikeja',
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final branchName = nameController.text.trim();
              if (branchName.isEmpty) return;

              final newBranch = BranchModel(
                id: '',
                organizationId: org.id,
                name: branchName,
                state: stateController.text.trim(),
                city: cityController.text.trim(),
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await ref.read(branchRepositoryProvider).createBranch(newBranch);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Branch "$branchName" created for ${org.name}',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add Branch'),
          ),
        ],
      ),
    );
  }

  void _showBranchDetailsDialog(BuildContext context, BranchModel branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${branch.name} Branch',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (branch.city.isNotEmpty || branch.state.isNotEmpty) ...[
              Text(
                'Location: ${[branch.city, branch.state].where((s) => s.isNotEmpty).join(', ')}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
            ],
            if (branch.presidentName != null &&
                branch.presidentName!.isNotEmpty) ...[
              Text('President: ${branch.presidentName}'),
              const SizedBox(height: 8),
            ],
            Text(
              'Status: ${branch.isActive ? 'Active' : 'Inactive'}',
              style: TextStyle(
                color: branch.isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              branch.accountNumber != null && branch.accountNumber!.isNotEmpty
                  ? 'Bank: ${branch.bankName ?? ''} - ${branch.accountNumber}'
                  : 'Bank account: Not configured yet',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteBranch(context, branch);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.account_balance, size: 16),
            label: const Text('Bank Details'),
            onPressed: () {
              Navigator.pop(ctx);
              EditBranchBankDialog.show(context, branch);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOrganization(BuildContext context, OrganizationModel org) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Organization',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${org.name}"?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. All branches and associated data for this organization will be removed.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(organizationRepositoryProvider)
                    .deleteOrganization(org.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Organization "${org.name}" deleted successfully',
                      ),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete organization: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBranch(BuildContext context, BranchModel branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Branch', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${branch.name} Branch"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(branchRepositoryProvider)
                    .deleteBranch(branch.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Branch "${branch.name}" deleted successfully',
                      ),
                      backgroundColor: Colors.red.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete branch: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
