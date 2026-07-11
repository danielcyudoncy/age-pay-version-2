import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/member_model.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';

class EditMemberScreen extends ConsumerStatefulWidget {
  final MemberModel member;
  final String? memberIdOverride;

  const EditMemberScreen({
    super.key,
    required this.member,
    this.memberIdOverride,
  });

  @override
  ConsumerState<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends ConsumerState<EditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _joinedDateController;
  bool _isLoading = false;
  String? _error;
  DateTime? _selectedDob;
  DateTime? _selectedJoinedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.fullName);
    _phoneController = TextEditingController(text: widget.member.phoneNumber);
    _selectedDob = widget.member.dateOfBirth;
    _selectedJoinedDate = widget.member.joinedDate;
    _dobController = TextEditingController(
      text: DateFormat('MMM d, yyyy').format(widget.member.dateOfBirth),
    );
    _joinedDateController = TextEditingController(
      text: DateFormat('MMM d, yyyy').format(widget.member.joinedDate),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _joinedDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isDob}) async {
    final initialDate = isDob
        ? (_selectedDob ?? DateTime.now())
        : (_selectedJoinedDate ?? DateTime.now());
    final firstDate = isDob ? DateTime(1900) : DateTime(2000);
    final lastDate = isDob ? DateTime.now() : DateTime(2100);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isDob) {
          _selectedDob = picked;
          _dobController.text = DateFormat('MMM d, yyyy').format(picked);
        } else {
          _selectedJoinedDate = picked;
          _joinedDateController.text = DateFormat('MMM d, yyyy').format(picked);
        }
      });
    }
  }

  bool _canEditJoinedDate() {
    final userRole = ref.read(authProvider).valueOrNull?.role;
    return userRole == UserRole.treasurer ||
        userRole == UserRole.president ||
        userRole == UserRole.superAdmin;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final updatedMember = widget.member.copyWith(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        dateOfBirth: _selectedDob ?? widget.member.dateOfBirth,
        joinedDate: _canEditJoinedDate()
            ? (_selectedJoinedDate ?? widget.member.joinedDate)
            : widget.member.joinedDate,
        updatedAt: DateTime.now(),
      );

      await ref.read(memberRepositoryProvider).updateMember(updatedMember);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member profile updated successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEditJoined = _canEditJoinedDate();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Member'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member Information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.member.email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                enabled: false,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: const Icon(Icons.cake),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(isDob: true),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(isDob: true),
                validator: (value) {
                  if (_selectedDob == null) {
                    return 'Please select a date of birth';
                  }
                  final age = DateTime.now().year - _selectedDob!.year;
                  if (age < 13) {
                    return 'Member must be at least 13 years old';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _joinedDateController,
                decoration: InputDecoration(
                  labelText: 'Joined Date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: canEditJoined
                      ? IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(isDob: false),
                        )
                      : null,
                ),
                readOnly: true,
                enabled: canEditJoined,
                onTap: canEditJoined ? () => _selectDate(isDob: false) : null,
                validator: canEditJoined
                    ? (value) {
                        if (_selectedJoinedDate == null) {
                          return 'Please select joined date';
                        }
                        if (_selectedJoinedDate!.isAfter(DateTime.now())) {
                          return 'Joined date cannot be in the future';
                        }
                        return null;
                      }
                    : null,
              ),
              if (!canEditJoined)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Contact admin to update joined date',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
