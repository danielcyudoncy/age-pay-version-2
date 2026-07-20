import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cls/features/admin/controllers/admin_provider.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/dashboard/views/home_router.dart';

/// Shown when an already signed-in user has no organization assigned yet.
/// Lets them pick the organization they belong to before entering the app.
class OrganizationPickerScreen extends ConsumerStatefulWidget {
  const OrganizationPickerScreen({super.key});

  @override
  ConsumerState<OrganizationPickerScreen> createState() =>
      _OrganizationPickerScreenState();
}

class _OrganizationPickerScreenState
    extends ConsumerState<OrganizationPickerScreen> {
  String? _selectedId;
  bool _isSaving = false;
  String? _error;

  Future<void> _save() async {
    if (_selectedId == null || _selectedId!.isEmpty) {
      setState(() => _error = 'Please select your organization');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final user = ref.read(authProvider).valueOrNull;
      if (user == null) {
        setState(() {
          _isSaving = false;
          _error = 'Session expired. Please sign in again.';
        });
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'organizationId': _selectedId});
      final refreshed = user.copyWith(organizationId: _selectedId!);
      ref.read(authProvider.notifier).setUser(refreshed);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeRouter()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orgsAsync = ref.watch(organizationsFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Organization')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose your organization',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the branch you belong to so you can see its '
                    'announcements and records.',
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
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.3),
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
                  orgsAsync.when(
                    data: (orgs) {
                      if (orgs.isEmpty) {
                        return const Text(
                          'No organizations are available yet.',
                          textAlign: TextAlign.center,
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedId,
                        decoration: const InputDecoration(
                          labelText: 'Organization',
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
                        onChanged: (value) =>
                            setState(() => _selectedId = value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Select your organization'
                            : null,
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, _) => const Text(
                      'Unable to load organizations.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
