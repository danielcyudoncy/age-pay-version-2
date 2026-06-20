// features/levies/screens/create_levy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/levies/providers/levy_provider.dart';

class CreateLevyScreen extends ConsumerStatefulWidget {
  final String creatorId;
  final List<String> memberIds;

  const CreateLevyScreen({
    super.key,
    required this.creatorId,
    required this.memberIds,
  });

  @override
  ConsumerState<CreateLevyScreen> createState() => _CreateLevyScreenState();
}

class _CreateLevyScreenState extends ConsumerState<CreateLevyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _groupController = TextEditingController();

  ObligationType _selectedType = ObligationType.monthlyDue;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  final List<ObligationType> _types = [
    ObligationType.monthlyDue,
    ObligationType.specialLevy,
    ObligationType.projectContribution,
    ObligationType.emergencyContribution,
    ObligationType.projectContribution,
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    ref
        .read(levyCreationProvider.notifier)
        .createLevy(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedType,
          amountPerMember: amount,
          dueDate: _dueDate,
          createdBy: widget.creatorId,
          targetGroup: _groupController.text.trim().isEmpty
              ? null
              : _groupController.text.trim(),
          memberIds: widget.memberIds,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final creationState = ref.watch(levyCreationProvider);

    ref.listen<LevyCreationState>(levyCreationProvider, (previous, next) {
      if (!previous!.isSuccess && next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Levy created successfully with ID: ${next.createdLevyId}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Reset form
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        _amountController.clear();
        _groupController.clear();
        setState(() {
          _dueDate = DateTime.now().add(const Duration(days: 30));
          _selectedType = ObligationType.monthlyDue;
        });
        ref.read(levyCreationProvider.notifier).reset();
      } else if (next.error != null && next.error != previous.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Levy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Levy Details', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g., June Monthly Due',
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
                  labelText: 'Description',
                  hintText: 'Brief description of this levy',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Type dropdown
              DropdownButtonFormField<ObligationType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: _types.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_typeLabel(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Amount per member
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount Per Member (₦) *',
                  hintText: 'e.g., 1000.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
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

              // Due date picker
              InkWell(
                onTap: _selectDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_dueDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Target group (optional)
              TextFormField(
                controller: _groupController,
                decoration: const InputDecoration(
                  labelText: 'Target Group (Optional)',
                  hintText: 'e.g., Elder Group, Youth Group',
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              // Member count info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.memberIds.length} member(s) will receive this obligation',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: creationState.isLoading ? null : _submit,
                  child: creationState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Levy & Generate Obligations'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(ObligationType type) {
    switch (type) {
      case ObligationType.monthlyDue:
        return 'Monthly Due';
      case ObligationType.specialLevy:
        return 'Special Levy';
      case ObligationType.projectContribution:
        return 'Project Contribution';
      case ObligationType.emergencyContribution:
        return 'Emergency Contribution';
      default:
        return type.name;
    }
  }
}
