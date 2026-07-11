import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/organization_model.dart';
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      onEdit: () => _showEditDialog(context, org),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Organization'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: slugController, decoration: const InputDecoration(labelText: 'Slug')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Contact Email')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Contact Phone')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || slugController.text.isEmpty) {
                return;
              }
              final org = OrganizationModel(
                id: '',
                name: nameController.text.trim(),
                slug: slugController.text.trim(),
                contactEmail: emailController.text.trim(),
                contactPhone: phoneController.text.trim(),
                address: addressController.text.trim(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await ref.read(organizationRepositoryProvider).createOrganization(org);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, OrganizationModel org) {
    final nameController = TextEditingController(text: org.name);
    final slugController = TextEditingController(text: org.slug);
    final emailController = TextEditingController(text: org.contactEmail);
    final phoneController = TextEditingController(text: org.contactPhone);
    final addressController = TextEditingController(text: org.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Organization'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: slugController, decoration: const InputDecoration(labelText: 'Slug')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Contact Email')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Contact Phone')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || slugController.text.isEmpty) {
                return;
              }
              final updated = org.copyWith(
                name: nameController.text.trim(),
                slug: slugController.text.trim(),
                contactEmail: emailController.text.trim(),
                contactPhone: phoneController.text.trim(),
                address: addressController.text.trim(),
                updatedAt: DateTime.now(),
              );
              await ref.read(organizationRepositoryProvider).updateOrganization(updated);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
