// features/expenses/views/expense_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
// path package not needed – using DateTime-based file names
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../national/controllers/national_provider.dart';
import '../models/expense_model.dart';
import '../controllers/expense_provider.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String currentUserId;
  final String organizationId;
  final ExpenseModel? expense;

  const ExpenseFormScreen({
    super.key,
    required this.currentUserId,
    this.organizationId = '',
    this.expense,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _grossAmountController = TextEditingController();
  final _contributionsController = TextEditingController();
  final _noteRefController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.miscellaneous;
  DateTime _expenseDate = DateTime.now();
  String? _receiptUrl;
  File? _pickedImageFile;
  bool _isSaving = false;
  bool _isCoFunded = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final expense = widget.expense!;
      _titleController.text = expense.title;
      _descriptionController.text = expense.description;
      _amountController.text = expense.amount.toString();
      _selectedCategory = expense.category;
      _expenseDate = expense.expenseDate;
      _receiptUrl = expense.receiptUrl;
      if (expense.grossAmount != null) {
        _isCoFunded = true;
        _grossAmountController.text = expense.grossAmount.toString();
      }
      if (expense.contributionsDeduction != null) {
        _contributionsController.text =
            expense.contributionsDeduction.toString();
      }
      if (expense.noteRef != null) {
        _noteRefController.text = expense.noteRef!;
      }
    }
  }

  void _recalculateNetAmount() {
    final gross = double.tryParse(_grossAmountController.text) ?? 0.0;
    final contributed = double.tryParse(_contributionsController.text) ?? 0.0;
    final net = (gross - contributed).clamp(0.0, double.infinity);
    _amountController.text = net.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _grossAmountController.dispose();
    _contributionsController.dispose();
    _noteRefController.dispose();
    super.dispose();
  }

  Future<void> _pickExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImageFile = File(picked.path);
      });
    }
  }

  void _clearImage() {
    setState(() {
      _pickedImageFile = null;
      _receiptUrl = null;
    });
  }

  Future<String?> _uploadReceipt() async {
    if (_pickedImageFile == null) return _receiptUrl;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';
    final ref = FirebaseStorage.instance.ref().child('receipts/$fileName');
    await ref.putFile(_pickedImageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final receiptUrl = await _uploadReceipt();
      final repo = ref.read(expenseRepositoryProvider);
      final orgId = widget.organizationId;

      final user = ref.read(authProvider).valueOrNull;
      final activeScope = ref.read(activeExecutiveScopeProvider);
      final defaultBranchId =
          activeScope == ExecutiveScope.national ? 'national' : user?.branchId;

      final grossAmount = _isCoFunded
          ? double.tryParse(_grossAmountController.text)
          : null;
      final contributionsDeduction = _isCoFunded
          ? double.tryParse(_contributionsController.text)
          : null;
      final noteRef = _noteRefController.text.trim().isNotEmpty
          ? _noteRefController.text.trim()
          : null;

      if (_isEditing) {
        final updated = widget.expense!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          expenseDate: _expenseDate,
          receiptUrl: receiptUrl,
          grossAmount: grossAmount,
          contributionsDeduction: contributionsDeduction,
          noteRef: noteRef,
          organizationId: widget.expense!.organizationId.isNotEmpty
              ? widget.expense!.organizationId
              : orgId,
          branchId: widget.expense!.branchId ?? defaultBranchId,
          updatedAt: DateTime.now(),
        );
        await repo.updateExpense(updated);
      } else {
        final expense = ExpenseModel(
          id: '',
          organizationId: orgId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          expenseDate: _expenseDate,
          createdBy: widget.currentUserId,
          receiptUrl: receiptUrl,
          branchId: defaultBranchId,
          grossAmount: grossAmount,
          contributionsDeduction: contributionsDeduction,
          noteRef: noteRef,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createExpense(expense);
      }

      try {
        ref.invalidate(expensesStreamProvider);
        ref.invalidate(expenseTotalProvider);
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving expense: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expense Details', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g., Office Supplies',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Brief description of the expense',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: _isCoFunded
                      ? 'Net Purse Deficit (₦) *'
                      : 'Amount (₦) *',
                  hintText: 'e.g., 5000',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: const OutlineInputBorder(),
                  helperText: _isCoFunded
                      ? 'Automatically calculated: Gross Spent minus Member Contributions'
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Event Co-Funding Netting Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Event / Welfare Co-Funding Netting'),
                subtitle: const Text(
                  'Enable if members contributed donations toward this event (e.g. EDU Hosting or Welfare) to calculate net purse deficit.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isCoFunded,
                onChanged: (val) {
                  setState(() {
                    _isCoFunded = val;
                    if (val) {
                      _recalculateNetAmount();
                    }
                  });
                },
              ),
              if (_isCoFunded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _grossAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Gross Total Spent (₦)',
                          hintText: 'e.g. 248500',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _recalculateNetAmount(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _contributionsController,
                        decoration: const InputDecoration(
                          labelText: 'Member Contributions (₦)',
                          hintText: 'e.g. 219000',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _recalculateNetAmount(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Note Reference (e.g., Note 7, Note 12)
              TextFormField(
                controller: _noteRefController,
                decoration: const InputDecoration(
                  labelText: 'Report Note Reference (Optional)',
                  hintText: 'e.g., Note 5, Note 7, Note 12',
                  prefixIcon: Icon(Icons.bookmark_border),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: ExpenseCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(_categoryLabel(category)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Category is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Expense date picker
              InkWell(
                onTap: _pickExpenseDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expense Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateFormat.format(_expenseDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Receipt upload section
              Text('Receipt', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_pickedImageFile != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _pickedImageFile!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (_receiptUrl != null && _receiptUrl!.isNotEmpty)
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Colors.green,
                              ),
                              SizedBox(height: 8),
                              Text('Receipt uploaded'),
                            ],
                          ),
                        )
                      else
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text('No receipt uploaded'),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSaving ? null : _pickImage,
                              icon: const Icon(Icons.image),
                              label: const Text('Pick Image'),
                            ),
                          ),
                          if (_pickedImageFile != null ||
                              (_receiptUrl != null && _receiptUrl!.isNotEmpty))
                            const SizedBox(width: 8),
                          if (_pickedImageFile != null ||
                              (_receiptUrl != null && _receiptUrl!.isNotEmpty))
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _clearImage,
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Update Expense' : 'Save Expense'),
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.welfare:
        return 'Welfare';
      case ExpenseCategory.projects:
        return 'Projects';
      case ExpenseCategory.events:
        return 'Events';
      case ExpenseCategory.administration:
        return 'Administration';
      case ExpenseCategory.assetsAndUtensils:
        return 'Utensils & Assets';
      case ExpenseCategory.meetingRefreshment:
        return 'Refreshment & Hosting';
      case ExpenseCategory.delegationAndTransport:
        return 'Transport & Delegations';
      case ExpenseCategory.communications:
        return 'SMS & Communications';
      case ExpenseCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }
}
