import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../controllers/auth_provider.dart';
import '../../admin/controllers/admin_provider.dart';
import '../../dashboard/views/home_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();

  // Multi-Level Organization & Branch Controllers
  bool _isCreatingNewOrg = false;
  final _newOrgNameController = TextEditingController();
  final _newBranchNameController = TextEditingController();
  final _secretaryNameController = TextEditingController();
  final _secretaryPhoneController = TextEditingController();

  String? _selectedOrganizationId;
  String? _selectedBranchId;
  String? _selectedBranchName;
  bool _isCreatingNewBranch = false;
  bool _isLoading = false;
  String? _error;
  DateTime? _selectedDob;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _newOrgNameController.dispose();
    _newBranchNameController.dispose();
    _secretaryNameController.dispose();
    _secretaryPhoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDob == null) {
      setState(() => _error = 'Please select your date of birth');
      return;
    }

    if (_isCreatingNewOrg) {
      if (_newOrgNameController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter the name of your Age Grade');
        return;
      }
      if (_secretaryPhoneController.text.trim().isEmpty) {
        setState(() => _error =
            'Please provide your General Secretary\'s phone number for co-signing verification');
        return;
      }
    } else {
      if (_selectedOrganizationId == null || _selectedOrganizationId!.isEmpty) {
        setState(() => _error = 'Please select your Age Grade');
        return;
      }
      if (!_isCreatingNewBranch &&
          (_selectedBranchId == null || _selectedBranchId!.isEmpty)) {
        setState(() => _error = 'Please select or add your branch');
        return;
      }
      if (_isCreatingNewBranch &&
          _newBranchNameController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter the new branch name');
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            role: _isCreatingNewOrg ? UserRole.president : UserRole.member,
            organizationId: _isCreatingNewOrg ? '' : _selectedOrganizationId!,
            dateOfBirth: _selectedDob!,
            branchId: _isCreatingNewOrg || _isCreatingNewBranch
                ? null
                : _selectedBranchId,
            branchName: _isCreatingNewOrg
                ? (_newBranchNameController.text.trim().isNotEmpty
                    ? _newBranchNameController.text.trim()
                    : 'Headquarters / Main Branch')
                : (_isCreatingNewBranch
                    ? _newBranchNameController.text.trim()
                    : _selectedBranchName),
            isNewOrganization: _isCreatingNewOrg,
            newOrganizationName: _isCreatingNewOrg
                ? _newOrgNameController.text.trim()
                : null,
            newBranchName: (_isCreatingNewOrg || _isCreatingNewBranch)
                ? _newBranchNameController.text.trim()
                : null,
            coFounderName: _isCreatingNewOrg
                ? _secretaryNameController.text.trim()
                : null,
            coFounderPhone: _isCreatingNewOrg
                ? _secretaryPhoneController.text.trim()
                : null,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('MMM d, yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeRouter()),
            );
          }
        },
        error: (err, _) {
          if (mounted) {
            setState(() => _error = err.toString());
          }
        },
        loading: () {},
      );
    });

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Icon(
                      Icons.account_balance,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join or register your Age Grade on AgePay',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.errorContainer,
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),

                    // Personal Details Section
                    Text(
                      'Personal Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: 'e.g. 0803 123 4567',
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
                        prefixIcon: const Icon(Icons.cake_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectDob,
                        ),
                      ),
                      readOnly: true,
                      onTap: _selectDob,
                      validator: (value) {
                        if (_selectedDob == null) {
                          return 'Please select your date of birth';
                        }
                        final age = DateTime.now().year - _selectedDob!.year;
                        if (age < 13) {
                          return 'You must be at least 13 years old';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),
                    // Multi-Level Organization & Branch Section
                    Text(
                      'Organization & Branch',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Choice: Join Existing vs Register New
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Join Existing Age Grade'),
                            selected: !_isCreatingNewOrg,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _isCreatingNewOrg = false;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('+ Register New'),
                            selected: _isCreatingNewOrg,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _isCreatingNewOrg = true;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isCreatingNewOrg) ...[
                      // Registering a brand new Age Grade
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Colors.blue.shade800, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🛡️ Dual-Executive Verification:\nAs pioneer founder, you will be registered as President. Provide your General Secretary\'s details below—they will receive an alert to co-sign and activate the Age Grade.',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newOrgNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Age Grade Name',
                          hintText: 'e.g. Udoka Age Grade',
                          prefixIcon: Icon(Icons.corporate_fare_outlined),
                        ),
                        validator: (v) => _isCreatingNewOrg && (v == null || v.isEmpty)
                            ? 'Enter the Age Grade name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newBranchNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Primary Branch / Headquarters',
                          hintText: 'e.g. Lagos Branch (or Abiriba HQ)',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _secretaryNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'General Secretary Full Name',
                          hintText: 'e.g. Chief Kalu Anya',
                          prefixIcon: Icon(Icons.person_add_outlined),
                        ),
                        validator: (v) => _isCreatingNewOrg && (v == null || v.isEmpty)
                            ? 'Enter Secretary name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _secretaryPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'General Secretary Phone Number',
                          hintText: 'e.g. 0803 123 4567',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                        validator: (v) => _isCreatingNewOrg && (v == null || v.isEmpty)
                            ? 'Enter Secretary phone number for co-signing'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        child: const Text('President (Pioneer Founder)'),
                      ),
                    ] else ...[
                      // Joining existing Age Grade
                      _OrganizationPicker(
                        selectedId: _selectedOrganizationId,
                        onChanged: (id) {
                          setState(() {
                            _selectedOrganizationId = id;
                            _selectedBranchId = null;
                            _selectedBranchName = null;
                            _isCreatingNewBranch = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_selectedOrganizationId != null &&
                          _selectedOrganizationId!.isNotEmpty) ...[
                        _BranchPicker(
                          organizationId: _selectedOrganizationId!,
                          selectedBranchId: _selectedBranchId,
                          isCreatingNew: _isCreatingNewBranch,
                          onChanged: (branchId, branchName, isNew) {
                            setState(() {
                              _selectedBranchId = branchId;
                              _selectedBranchName = branchName;
                              _isCreatingNewBranch = isNew;
                            });
                          },
                        ),
                        if (_isCreatingNewBranch) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _newBranchNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'New Branch Name',
                              hintText: 'e.g. Port Harcourt Branch',
                              prefixIcon: Icon(Icons.add_location_alt_outlined),
                            ),
                            validator: (v) => _isCreatingNewBranch &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Enter new branch name'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 20,
                              color: Colors.blue.shade800,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your registration will be submitted to the Branch Executive for review and role assignment.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    // Password Section
                    Text(
                      'Security',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
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
                                'Register',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Already have an account? Sign In'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizationPicker extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _OrganizationPicker({
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(organizationsFutureProvider);

    return orgsAsync.when(
      data: (orgs) {
        if (orgs.isEmpty) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Age Grade',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            child: Text('No Age Grades registered yet'),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: 'Select Age Grade',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          items: orgs
              .map(
                (org) => DropdownMenuItem(
                  value: org.id,
                  child: Text(org.name),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (value) =>
              value == null || value.isEmpty ? 'Select your Age Grade' : null,
        );
      },
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Age Grade',
          prefixIcon: Icon(Icons.business_outlined),
        ),
        child: Text('Loading Age Grades...'),
      ),
      error: (_, _) => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Age Grade',
          prefixIcon: Icon(Icons.business_outlined),
        ),
        child: Text('Unable to load Age Grades'),
      ),
    );
  }
}

class _BranchPicker extends ConsumerWidget {
  final String organizationId;
  final String? selectedBranchId;
  final bool isCreatingNew;
  final void Function(String? branchId, String? branchName, bool isNew) onChanged;

  const _BranchPicker({
    required this.organizationId,
    required this.selectedBranchId,
    required this.isCreatingNew,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesStreamFamily(organizationId));

    return branchesAsync.when(
      data: (branches) {
        final items = <DropdownMenuItem<String>>[
          ...branches.map(
            (b) => DropdownMenuItem(
              value: b.id,
              child: Text(b.name),
            ),
          ),
          const DropdownMenuItem(
            value: '__NEW__',
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('+ Add New Branch',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
          ),
        ];

        final currentValue = isCreatingNew ? '__NEW__' : selectedBranchId;

        return DropdownButtonFormField<String>(
          initialValue: items.any((i) => i.value == currentValue) ? currentValue : null,
          decoration: const InputDecoration(
            labelText: 'Branch Name',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: items,
          onChanged: (val) {
            if (val == '__NEW__') {
              onChanged(null, null, true);
            } else if (val != null) {
              final selected = branches.firstWhere((b) => b.id == val);
              onChanged(selected.id, selected.name, false);
            }
          },
          validator: (v) => !isCreatingNew && (v == null || v.isEmpty)
              ? 'Select your branch'
              : null,
        );
      },
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Branch Name',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
        child: Text('Loading branches...'),
      ),
      error: (_, _) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Branch Name',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
        items: const [
          DropdownMenuItem(
            value: '__NEW__',
            child: Text('+ Add New Branch'),
          ),
        ],
        onChanged: (_) => onChanged(null, null, true),
      ),
    );
  }
}
