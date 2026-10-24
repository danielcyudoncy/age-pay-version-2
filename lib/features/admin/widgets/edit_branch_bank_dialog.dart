import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/branch_model.dart';
import '../../national/controllers/national_provider.dart';

class EditBranchBankDialog extends ConsumerStatefulWidget {
  final BranchModel branch;

  const EditBranchBankDialog({super.key, required this.branch});

  static Future<bool?> show(BuildContext context, BranchModel branch) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditBranchBankDialog(branch: branch),
    );
  }

  @override
  ConsumerState<EditBranchBankDialog> createState() =>
      _EditBranchBankDialogState();
}

class _EditBranchBankDialogState extends ConsumerState<EditBranchBankDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bankNameController = TextEditingController(text: widget.branch.bankName ?? '');
    _accountNumberController =
        TextEditingController(text: widget.branch.accountNumber ?? '');
    _accountNameController =
        TextEditingController(text: widget.branch.accountName ?? '');
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(nationalRepositoryProvider).updateBranchBankDetails(
            branchId: widget.branch.id,
            bankName: _bankNameController.text.trim(),
            accountNumber: _accountNumberController.text.trim(),
            accountName: _accountNameController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.brandGreen,
            content: Text(
              '${widget.branch.name} receiving account updated successfully',
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
            content: Text('Failed to update bank details: $e'),
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
    final isNational = widget.branch.isNational;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isNational ? Icons.account_balance : Icons.savings_outlined,
            color: AppTheme.brandGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isNational
                  ? 'National Receiving Bank'
                  : '${widget.branch.name} Bank Details',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNational
                    ? 'All payments for national-level obligations and AGM dues will be routed to this account.'
                    : 'Members of ${widget.branch.name} will pay local dues directly to this account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'Bank Name',
                  hintText: 'e.g. Zenith Bank, Access Bank',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  hintText: '10-digit account number',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (val.trim().length < 10) return 'Must be at least 10 digits';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _accountNameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. Apex Club National / Lagos Chapter',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.brandGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
              : const Text('Save Details'),
        ),
      ],
    );
  }
}
