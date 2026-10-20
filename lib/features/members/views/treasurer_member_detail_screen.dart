// features/members/views/treasurer_member_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart';
import 'package:cls/features/obligations/controllers/obligation_provider.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'edit_member_screen.dart';
import '../widgets/member_widgets.dart';

class TreasurerMemberDetailScreen extends ConsumerWidget {
  final String memberId;
  final bool isReadOnly;

  const TreasurerMemberDetailScreen({
    super.key,
    required this.memberId,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);
    final obligationsAsync = ref.watch(memberObligationsProvider(memberId));
    final authState = ref.watch(authProvider);
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy');

    final currentUserRole = authState.valueOrNull?.role;
    final canEdit = !isReadOnly &&
        (currentUserRole == UserRole.treasurer ||
            currentUserRole == UserRole.financialSecretary ||
            currentUserRole == UserRole.viceTreasurer ||
            currentUserRole == UserRole.superAdmin);

    return Scaffold(
      appBar: AppBar(title: const Text('Member Details'), centerTitle: true),
      body: membersAsync.when(
        data: (members) {
          final member = members.firstWhere(
            (m) => m.userId == memberId || m.id == memberId,
            orElse: () => MemberModel(
              id: memberId,
              userId: memberId,
              fullName: 'Unknown Member',
              email: '',
              phoneNumber: '',
              dateOfBirth: DateTime(2000),
              joinedDate: DateTime(2000),
              createdAt: DateTime(2000),
              updatedAt: DateTime(2000),
            ),
          );

          return obligationsAsync.when(
            data: (obligations) {
              final owed = obligations.fold<double>(
                0.0,
                (sum, o) => sum + o.outstandingBalance,
              );
              final paid = obligations.fold<double>(
                0.0,
                (sum, o) => sum + o.paidAmount,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MemberInfoCard(
                    member: member,
                    dateFormat: dateFormat,
                    canEdit: canEdit,
                    onEdit: canEdit
                        ? () => _navigateToEditScreen(context, ref, member)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  LevySummaryCard(
                    label: 'Levies Owed',
                    amount: owed,
                    color: Colors.redAccent,
                    currency: currency,
                  ),
                  const SizedBox(height: 12),
                  LevySummaryCard(
                    label: 'Levies Paid',
                    amount: paid,
                    color: Colors.green,
                    currency: currency,
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.edit_note,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Manage Member Dues',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        obligations.isEmpty
                                            ? 'No dues recorded yet for this member.'
                                            : 'Total outstanding dues: ${currency.format(owed)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: obligations.isEmpty
                                              ? Colors.orange.shade800
                                              : Colors.grey.shade700,
                                          fontWeight: obligations.isEmpty
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              obligations.isEmpty
                                  ? 'Set initial onboarding dues/arrears for this new member based on organization inception.'
                                  : 'Update or assign dues owed by this member. Changes reflect immediately on the member dashboard.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _showSetOrAdjustDuesDialog(
                                      context,
                                      ref,
                                      member,
                                      currency,
                                      owed,
                                    ),
                                    icon: const Icon(Icons.currency_exchange, size: 18),
                                    label: Text(
                                      obligations.isEmpty
                                          ? 'Set Initial Dues'
                                          : 'Update / Add Dues',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _confirmBackfillLevies(
                                    context,
                                    ref,
                                    member,
                                  ),
                                  icon: const Icon(Icons.auto_awesome, size: 18),
                                  label: const Text('Import Levies'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Obligations (${obligations.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (canEdit)
                        TextButton.icon(
                          onPressed: () => _showSetOrAdjustDuesDialog(
                            context,
                            ref,
                            member,
                            currency,
                            owed,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Dues'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (obligations.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No obligations recorded',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use "Set Initial Dues" or "Import Levies" above to assign dues to this member.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: obligations.map((o) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    StatusChip(status: o.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildAmountColumn(
                                        'Total',
                                        o.amount,
                                        isBold: true,
                                        currency: currency,
                                        context: context,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildAmountColumn(
                                        'Paid',
                                        o.paidAmount,
                                        color: Colors.green,
                                        currency: currency,
                                        context: context,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildAmountColumn(
                                        'Owing',
                                        o.outstandingBalance,
                                        color: Colors.redAccent,
                                        currency: currency,
                                        context: context,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Due: ${dateFormat.format(o.dueDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (canEdit) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showEditFullObligationDialog(
                                                context,
                                                ref,
                                                o,
                                                currency,
                                              ),
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('Edit / Adjust'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Delete obligation',
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _confirmDeleteObligation(
                                          context,
                                          ref,
                                          o,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
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
    );
  }

  void _navigateToEditScreen(
    BuildContext context,
    WidgetRef ref,
    MemberModel member,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditMemberScreen(member: member)),
    );
    if (result == true) {
      ref.invalidate(membersStreamProvider);
    }
  }

  void _showSetOrAdjustDuesDialog(
    BuildContext context,
    WidgetRef ref,
    MemberModel member,
    NumberFormat currency,
    double currentOwed,
  ) {
    final titleController = TextEditingController(
      text: currentOwed == 0 ? 'Onboarding Dues & Levies' : 'Dues Adjustment',
    );
    final amountController = TextEditingController();
    final paidController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    ObligationType selectedType = ObligationType.monthlyDue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomNavPadding = MediaQuery.of(context).padding.bottom;
            final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: keyboardPadding > 0
                    ? keyboardPadding + 16
                    : bottomNavPadding + 32,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentOwed == 0
                                    ? 'Set Dues: ${member.fullName}'
                                    : 'Update Dues: ${member.fullName}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Current outstanding: ${currency.format(currentOwed)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title / Reason',
                        hintText: 'e.g. Onboarding Dues, Back Dues',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Dues Amount to Assign (₦)',
                        hintText: 'Enter total amount owing',
                        prefixText: '₦ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: paidController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount Already Paid (Optional)',
                        hintText: 'Enter 0 if unpaid',
                        prefixText: '₦ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.check_circle_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ObligationType>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Dues Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ObligationType.monthlyDue,
                          child: Text('Monthly / Regular Dues'),
                        ),
                        DropdownMenuItem(
                          value: ObligationType.specialLevy,
                          child: Text('Special Levy / Arrears'),
                        ),
                        DropdownMenuItem(
                          value: ObligationType.projectContribution,
                          child: Text('Project Contribution'),
                        ),
                        DropdownMenuItem(
                          value: ObligationType.emergencyContribution,
                          child: Text('Emergency Contribution'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 3),
                                ),
                              );
                              if (picked != null) {
                                setModalState(() => dueDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final cleanAmount = amountController.text
                                    .trim()
                                    .replaceAll(',', '');
                                final amount =
                                    double.tryParse(cleanAmount) ?? 0.0;
                                final cleanPaid = paidController.text
                                    .trim()
                                    .replaceAll(',', '');
                                final paid = double.tryParse(cleanPaid) ?? 0.0;

                                if (amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please enter a valid amount'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);

                                try {
                                  ObligationStatus status;
                                  if (paid >= amount) {
                                    status = ObligationStatus.paid;
                                  } else if (paid > 0) {
                                    status = ObligationStatus.partial;
                                  } else {
                                    status = ObligationStatus.unpaid;
                                  }

                                  final targetId = member.userId.isNotEmpty
                                      ? member.userId
                                      : member.id;
                                  final newObligation = ObligationModel(
                                    id: '',
                                    memberId: targetId,
                                    levyId: '',
                                    type: selectedType,
                                    title: titleController.text.trim().isEmpty
                                        ? 'Member Dues'
                                        : titleController.text.trim(),
                                    description:
                                        notesController.text.trim().isNotEmpty
                                            ? notesController.text.trim()
                                            : 'Assigned by Financial Secretary',
                                    amount: amount,
                                    paidAmount: paid,
                                    outstandingBalance: (amount - paid).clamp(
                                      0.0,
                                      double.infinity,
                                    ),
                                    status: status,
                                    dueDate: dueDate,
                                    createdAt: DateTime.now(),
                                    settledAt: status == ObligationStatus.paid
                                        ? DateTime.now()
                                        : null,
                                  );

                                  await ref
                                      .read(obligationRepositoryProvider)
                                      .createObligation(newObligation);

                                  ref.invalidate(
                                    memberObligationsProvider(targetId),
                                  );
                                  ref.invalidate(
                                    memberActiveObligationsProvider(targetId),
                                  );
                                  ref.invalidate(allObligationsProvider);

                                  if (context.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Dues of ${currency.format(amount - paid)} assigned to ${member.fullName}. Reflected on member dashboard.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to save dues: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          isSaving ? 'Saving Dues...' : 'Save and Assign Dues',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmBackfillLevies(
    BuildContext context,
    WidgetRef ref,
    MemberModel member,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Import All Active Levies?'),
          content: Text(
            'This will automatically calculate and assign all active organization levies to ${member.fullName}.\n\n'
            'Their total outstanding dues will automatically update on their dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final targetId = member.userId.isNotEmpty
                    ? member.userId
                    : member.id;
                await ref
                    .read(obligationRepositoryProvider)
                    .backfillObligationsForNewMember(targetId);

                ref.invalidate(memberObligationsProvider(targetId));
                ref.invalidate(memberActiveObligationsProvider(targetId));
                ref.invalidate(allObligationsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Active levies successfully assigned to ${member.fullName}!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download_done),
              label: const Text('Import Levies'),
            ),
          ],
        );
      },
    );
  }

  void _showEditFullObligationDialog(
    BuildContext context,
    WidgetRef ref,
    ObligationModel obligation,
    NumberFormat currency,
  ) {
    final titleController = TextEditingController(text: obligation.title);
    final amountController = TextEditingController(
      text: obligation.amount.toStringAsFixed(0),
    );
    final paidController = TextEditingController(
      text: obligation.paidAmount > 0
          ? obligation.paidAmount.toStringAsFixed(0)
          : '0',
    );
    DateTime dueDate = obligation.dueDate;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit / Adjust Dues'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title / Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total Amount (₦)',
                        border: OutlineInputBorder(),
                        prefixText: '₦ ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: paidController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid (₦)',
                        border: OutlineInputBorder(),
                        prefixText: '₦ ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 3),
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final cleanAmount = amountController.text
                        .trim()
                        .replaceAll(',', '');
                    final newAmount =
                        double.tryParse(cleanAmount) ?? obligation.amount;
                    final cleanPaid = paidController.text
                        .trim()
                        .replaceAll(',', '');
                    final newPaid =
                        double.tryParse(cleanPaid) ?? obligation.paidAmount;
                    final outstanding = (newAmount - newPaid).clamp(
                      0.0,
                      double.infinity,
                    );

                    ObligationStatus status;
                    if (newPaid >= newAmount) {
                      status = ObligationStatus.paid;
                    } else if (newPaid > 0) {
                      status = ObligationStatus.partial;
                    } else {
                      status = ObligationStatus.unpaid;
                    }

                    final updated = obligation.copyWith(
                      title: titleController.text.trim().isNotEmpty
                          ? titleController.text.trim()
                          : obligation.title,
                      amount: newAmount,
                      paidAmount: newPaid,
                      outstandingBalance: outstanding,
                      status: status,
                      dueDate: dueDate,
                      settledAt: status == ObligationStatus.paid
                          ? DateTime.now()
                          : null,
                    );

                    await ref
                        .read(obligationRepositoryProvider)
                        .updateObligation(updated);
                    ref.invalidate(
                      memberObligationsProvider(obligation.memberId),
                    );
                    ref.invalidate(
                      memberActiveObligationsProvider(obligation.memberId),
                    );
                    ref.invalidate(allObligationsProvider);

                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dues updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteObligation(
    BuildContext context,
    WidgetRef ref,
    ObligationModel obligation,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Obligation?'),
          content: Text(
            'Are you sure you want to remove "${obligation.title}"?\n\n'
            'This will delete this obligation from the member\'s outstanding dues.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await ref
                    .read(obligationRepositoryProvider)
                    .deleteObligation(obligation.id);
                ref.invalidate(memberObligationsProvider(obligation.memberId));
                ref.invalidate(
                  memberActiveObligationsProvider(obligation.memberId),
                );
                ref.invalidate(allObligationsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Obligation deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAmountColumn(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
    required NumberFormat currency,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          currency.format(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}




