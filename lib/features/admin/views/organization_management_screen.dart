import 'package:cls/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/admin/models/branch_model.dart';
import 'package:cls/features/admin/models/organization_model.dart';
import 'package:cls/features/admin/widgets/edit_branch_bank_dialog.dart';
import 'package:cls/features/admin/widgets/organization_list_item.dart';
import '../widgets/add_branch_dialog.dart';
import '../services/bank_verification_service.dart';

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
        title: const Text('Organisations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Organisation',
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
                hintText: 'Search organisations...',
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
                      'No organisations found',
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final branchNameController =
        TextEditingController(text: 'Headquarters / Main Branch');
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    final overrideReasonController = TextEditingController();

    bool openForJoin = true;
    bool showBankSection = false;
    bool overrideBankVerification = false;
    bool slugManuallyEdited = false;
    bool isSaving = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.statusBg(context, Colors.blue),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.business, color: AppTheme.statusColor(context, Colors.blue), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Provision Organisation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'As Super Admin, creating this organisation pre-verifies it and immediately provisions its primary branch so members can join easily without verification delays.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    if (dialogError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.statusBg(context, Colors.red),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.statusColor(context, Colors.red).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          dialogError!,
                          style: TextStyle(fontSize: 12, color: AppTheme.statusColor(context, Colors.red)),
                        ),
                      ),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Organisation Name *',
                        hintText: 'e.g. Udoka Association / Club',
                        prefixIcon: Icon(Icons.corporate_fare_outlined),
                      ),
                      onChanged: (val) {
                        if (!slugManuallyEdited) {
                          setDialogState(() {
                            slugController.text = val
                                .trim()
                                .toLowerCase()
                                .replaceAll(RegExp(r'\s+'), '-');
                          });
                        }
                      },
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Organisation name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: slugController,
                      decoration: const InputDecoration(
                        labelText: 'Platform Slug *',
                        hintText: 'e.g. udoka-association',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      onChanged: (_) => slugManuallyEdited = true,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Slug is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: branchNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Primary Branch / Headquarters *',
                        hintText: 'e.g. Headquarters / Main Branch',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Primary branch name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Contact Email (Optional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Community Address (Optional)',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Toggle optional Bank Account setup upfront
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setDialogState(() => showBankSection = !showBankSection),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cardBorder(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              showBankSection
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 20,
                              color: AppTheme.statusColor(context, Colors.blue),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                showBankSection
                                    ? 'Hide Receiving Bank Setup'
                                    : '+ Configure Association Bank Account (Optional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.statusColor(context, Colors.blue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (showBankSection) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bankNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g. First Bank of Nigeria',
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: accountNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Account Number (10 Digits)',
                          hintText: 'e.g. 0123456789',
                          prefixIcon: Icon(Icons.numbers),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: accountNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Account Name',
                          hintText: 'e.g. Udoka Association Central',
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.statusBg(context, Colors.purple),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.statusColor(context, Colors.purple).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.purple.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Super Admin Name Override',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: overrideBankVerification,
                                  activeThumbColor: Colors.purple.shade700,
                                  onChanged: (v) => setDialogState(
                                    () => overrideBankVerification = v,
                                  ),
                                ),
                              ],
                            ),
                            if (overrideBankVerification) ...[
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: overrideReasonController,
                                decoration: const InputDecoration(
                                  labelText: 'Override Reason *',
                                  hintText:
                                      'e.g. Former corporate name prior to rebrand',
                                  isDense: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Open for join', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                        'Allow members to select and join this organisation on registration',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: openForJoin,
                      onChanged: (v) => setDialogState(() => openForJoin = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      final bankName = bankNameController.text.trim();
                      final accNo = accountNumberController.text.trim();
                      final accName = accountNameController.text.trim();
                      bool hasBank = bankName.isNotEmpty || accNo.isNotEmpty || accName.isNotEmpty;
                      bool isBankValid = false;

                      if (hasBank) {
                        final verifyRes = BankVerificationService.verifyAccount(
                          bankName: bankName,
                          accountNumber: accNo,
                          organizationName: nameController.text.trim(),
                          accountName: accName,
                        );
                        if (!verifyRes.isApproved && !overrideBankVerification) {
                          setDialogState(() => dialogError = verifyRes.message);
                          return;
                        }
                        if (!verifyRes.isApproved && overrideBankVerification) {
                          if (overrideReasonController.text.trim().length < 5) {
                            setDialogState(() => dialogError =
                                'Please provide a valid override reason (min. 5 characters).');
                            return;
                          }
                        }
                        isBankValid = true;
                      }

                      setDialogState(() {
                        isSaving = true;
                        dialogError = null;
                      });

                      try {
                        final org = OrganizationModel(
                          id: '',
                          name: nameController.text.trim(),
                          slug: slugController.text.trim(),
                          contactEmail: emailController.text.trim(),
                          contactPhone: phoneController.text.trim(),
                          address: addressController.text.trim(),
                          isActive: true,
                          openForJoin: openForJoin,
                          verificationStatus: 'verified',
                          isBankVerified: isBankValid,
                          bankAccountType: (isBankValid && overrideBankVerification)
                              ? 'super_admin_override'
                              : (isBankValid ? 'association' : null),
                          bankVerificationOverridden: overrideBankVerification,
                          bankVerificationOverrideReason: overrideBankVerification
                              ? overrideReasonController.text.trim()
                              : null,
                          bankVerificationOverriddenBy: overrideBankVerification
                              ? 'Super Admin'
                              : null,
                          bankVerificationOverriddenAt: overrideBankVerification
                              ? DateTime.now()
                              : null,
                          bankName: hasBank ? bankName : null,
                          accountNumber: hasBank ? accNo : null,
                          accountName: hasBank ? accName : null,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        await ref.read(organizationRepositoryProvider).createOrganization(
                              org,
                              initialBranchName: branchNameController.text.trim(),
                            );

                        ref.invalidate(organizationsStreamProvider);
                        ref.invalidate(organizationsFutureProvider);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green.shade700,
                              content: Text(
                                '${org.name} and primary branch provisioned successfully! Members can now join with ease.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          dialogError = e.toString();
                        });
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Provision & Activate'),
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
          title: const Text('Edit Organisation'),
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
    AddBranchDialog.show(context, org);
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
                'Delete Organisation',
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
              'This action cannot be undone. All branches and associated data for this organisation will be removed.',
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
                        'Organisation "${org.name}" deleted successfully',
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
                      content: Text('Failed to delete organisation: $e'),
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
