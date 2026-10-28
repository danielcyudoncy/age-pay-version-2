import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../dashboard/controllers/president_dashboard_provider.dart';
import '../../dashboard/controllers/treasurer_dashboard_provider.dart'
    hide expenseTotalProvider, pendingExpenseTotalProvider;
import '../../expenses/controllers/expense_provider.dart';
import '../controllers/admin_provider.dart';

class SystemResetDialog extends ConsumerStatefulWidget {
  const SystemResetDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SystemResetDialog(),
    );
  }

  @override
  ConsumerState<SystemResetDialog> createState() => _SystemResetDialogState();
}

class _SystemResetDialogState extends ConsumerState<SystemResetDialog> {
  final _confirmController = TextEditingController();
  bool _isResetting = false;
  String _currentStatus = '';
  double _progress = 0.0;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    setState(() {
      _isResetting = true;
      _errorMessage = null;
      _currentStatus = 'Initiating system reset...';
      _progress = 0.05;
    });

    try {
      final resetService = ref.read(systemResetServiceProvider);
      await resetService.resetAllTestData(
        currentUserId: user.uid,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
              _progress = progress;
            });
          }
        },
      );

      // Invalidate all providers so UI updates across the entire app
      ref.invalidate(allUsersStreamProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(organizationsStreamProvider);
      ref.invalidate(currentOrganizationProvider);
      ref.invalidate(presidentDashboardProvider);
      ref.invalidate(financialOverviewProvider);
      ref.invalidate(totalCollectionsProvider);
      ref.invalidate(presidentExpensesStreamProvider);
      ref.invalidate(expensesStreamProvider);
      ref.invalidate(expenseTotalProvider);
      ref.invalidate(pendingExpensesStreamProvider);
      ref.invalidate(pendingExpenseTotalProvider);
      ref.invalidate(treasurerDashboardProvider);
      ref.invalidate(authProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResetting = false;
          _errorMessage = 'Reset failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirmed = _confirmController.text.trim().toUpperCase() == 'RESET';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Reset System Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will completely wipe all test data and restore the app to a clean slate:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _BulletItem('Delete all collections (₦0 balance & ₦0 disbursed)'),
                  _BulletItem('Delete all expenses, levies, obligations & receipts'),
                  _BulletItem('Delete all meetings, announcements & notifications'),
                  _BulletItem('Delete all organizations & branches (0 Organizations)'),
                  _BulletItem('Delete all users & members EXCEPT danielcyudoncy@gmail.com'),
                  _BulletItem('Preserve your Super Admin master access'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isResetting) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: Colors.red,
                backgroundColor: Colors.red.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  _currentStatus,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Type RESET below to confirm:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'RESET',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: _isResetting
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isConfirmed ? _handleReset : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('Reset All Data'),
              ),
            ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;

  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
