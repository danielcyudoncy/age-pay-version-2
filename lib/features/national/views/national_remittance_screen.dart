import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_provider.dart';
import '../models/national_remittance_model.dart';
import '../controllers/national_remittance_provider.dart';

class NationalRemittanceScreen extends ConsumerStatefulWidget {
  const NationalRemittanceScreen({super.key});

  @override
  ConsumerState<NationalRemittanceScreen> createState() =>
      _NationalRemittanceScreenState();
}

class _NationalRemittanceScreenState
    extends ConsumerState<NationalRemittanceScreen> {
  final _levyTitleController = TextEditingController();
  final _collectedController = TextEditingController();
  final _remittedController = TextEditingController();
  final _recipientRefController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _levyTitleController.dispose();
    _collectedController.dispose();
    _remittedController.dispose();
    _recipientRefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showAddRemittanceDialog() {
    _levyTitleController.clear();
    _collectedController.clear();
    _remittedController.clear();
    _recipientRefController.clear();
    _notesController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record National Remittance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Track funds collected on behalf of National (e.g. Burial Levies, Izarafo certificates) and remittances sent to headquarters.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _levyTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Levy / Purpose *',
                    hintText: 'e.g. National Burial Levies (5 Burials)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _collectedController,
                  decoration: const InputDecoration(
                    labelText: 'Total Collected from Members (₦) *',
                    hintText: 'e.g. 103000',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remittedController,
                  decoration: const InputDecoration(
                    labelText: 'Amount Sent to National (₦) *',
                    hintText: 'e.g. 75000',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _recipientRefController,
                  decoration: const InputDecoration(
                    labelText: 'Receipt / Bank Reference',
                    hintText: 'e.g. National Treasurer Receipt #045',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Report Note (e.g. Note 4)',
                    hintText: 'e.g. Balance with us belongs to National',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
              onPressed: _isSaving
                  ? null
                  : () async {
                      final title = _levyTitleController.text.trim();
                      final collected =
                          double.tryParse(_collectedController.text) ?? 0.0;
                      final remitted =
                          double.tryParse(_remittedController.text) ?? 0.0;
                      if (title.isEmpty || collected <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill required fields')),
                        );
                        return;
                      }

                      final user = ref.read(authProvider).valueOrNull;
                      if (user == null) return;

                      setDialogState(() => _isSaving = true);
                      try {
                        final unremitted =
                            (collected - remitted).clamp(0.0, double.infinity);
                        final repo =
                            ref.read(nationalRemittanceRepositoryProvider);
                        final record = NationalRemittanceModel(
                          id: '',
                          organizationId: user.organizationId,
                          branchId: user.branchId,
                          branchName: user.branchId ?? 'Branch',
                          levyId: 'national_${DateTime.now().millisecondsSinceEpoch}',
                          levyTitle: title,
                          totalCollected: collected,
                          amountRemitted: remitted,
                          unremittedBalance: unremitted,
                          remittedAt: remitted > 0 ? DateTime.now() : null,
                          remittedBy: user.displayName.isNotEmpty
                              ? user.displayName
                              : 'Financial Secretary',
                          recipientRef:
                              _recipientRefController.text.trim().isNotEmpty
                                  ? _recipientRefController.text.trim()
                                  : null,
                          notes: _notesController.text.trim().isNotEmpty
                              ? _notesController.text.trim()
                              : null,
                          createdBy: user.uid,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        await repo.recordRemittance(record);

                        ref.invalidate(nationalRemittancesStreamProvider);

                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('National remittance recorded!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() => _isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Record'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final remittancesAsync = ref.watch(nationalRemittancesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('National Escrow & Remittances'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRemittanceDialog,
        backgroundColor: AppTheme.brandGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Record Remittance',
            style: TextStyle(color: Colors.white)),
      ),
      body: Builder(
        builder: (context) {
          final records = remittancesAsync.valueOrNull ?? [];
          final totalCollected =
              records.fold<double>(0.0, (s, r) => s + r.totalCollected);
          final totalRemitted =
              records.fold<double>(0.0, (s, r) => s + r.amountRemitted);
          final totalUnremitted =
              records.fold<double>(0.0, (s, r) => s + r.unremittedBalance);

          return Column(
            children: [
              if (remittancesAsync.isLoading)
                const LinearProgressIndicator(),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.indigo.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Collected',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            currency.format(totalCollected),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.indigo),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sent to National',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            currency.format(totalRemitted),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Held in Trust',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            currency.format(totalUnremitted),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.deepOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          'No National remittances recorded yet.\nClick below to track pass-through funds (Note 3 & 4).',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: records.length,
                        itemBuilder: (ctx, index) {
                          final r = records[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.levyTitle,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Unremitted: ${currency.format(r.unremittedBalance)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Collected: ${currency.format(r.totalCollected)} | Remitted: ${currency.format(r.amountRemitted)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  if (r.recipientRef != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Ref: ${r.recipientRef}',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                  if (r.notes != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Note: ${r.notes}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
