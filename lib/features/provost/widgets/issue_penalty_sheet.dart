import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../meetings/controllers/meeting_provider.dart';
import '../../meetings/models/meeting_model.dart';
import '../../members/models/member_model.dart';
import '../../secretary/controllers/secretary_dashboard_provider.dart';
import '../controllers/provost_provider.dart';
import '../models/infraction_presets.dart';

class IssuePenaltySheet extends ConsumerStatefulWidget {
  final String organizationId;
  final String provostName;
  final MeetingModel? meeting;
  final MemberModel? preselectedMember;
  final PenaltyInfractionType? initialInfractionType;

  const IssuePenaltySheet({
    super.key,
    required this.organizationId,
    required this.provostName,
    this.meeting,
    this.preselectedMember,
    this.initialInfractionType,
  });

  @override
  ConsumerState<IssuePenaltySheet> createState() => _IssuePenaltySheetState();
}

class _IssuePenaltySheetState extends ConsumerState<IssuePenaltySheet> {
  final _formKey = GlobalKey<FormState>();
  MemberModel? _selectedMember;
  late PenaltyInfractionType _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String? _selectedMeetingId;
  bool _isSubmitting = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.preselectedMember;
    _selectedType =
        widget.initialInfractionType ?? PenaltyInfractionType.lateComing;
    final preset = InfractionPreset.forType(_selectedType);
    _titleController = TextEditingController(text: preset.title);
    _amountController = TextEditingController(
      text: preset.defaultAmount.toInt().toString(),
    );
    _descriptionController = TextEditingController();
    _selectedMeetingId = widget.meeting?.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSelectPreset(InfractionPreset preset) {
    setState(() {
      _selectedType = preset.type;
      _titleController.text = preset.title;
      _amountController.text = preset.defaultAmount.toInt().toString();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a member to sanction.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid fine amount.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(provostControllerProvider);
      await controller.issuePenalty(
        organizationId: widget.organizationId,
        memberId: _selectedMember!.id,
        memberName: _selectedMember!.fullName,
        infractionType: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: amount,
        issuedBy: widget.provostName,
        meetingId: _selectedMeetingId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Disciplinary fine of ${_currencyFormat.format(amount)} issued to ${_selectedMember!.fullName}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to issue penalty: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersStreamProvider);
    final meetingsAsync = ref.watch(meetingsStreamProvider);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final navBarPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + (navBarPadding > 0 ? navBarPadding : 16) + 12,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.gavel_rounded,
                            color: Colors.red.shade800,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Issue Disciplinary Sanction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Provost decorum enforcement. Fines will be billed to the member\'s statement.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),

              // Member Picker
              const Text(
                'Offending Member *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              membersAsync.when(
                data: (rawMembers) {
                  final members = rawMembers.whereType<MemberModel>().toList();
                  if (members.isEmpty) {
                    return const Text(
                      'No members registered in this organization.',
                      style: TextStyle(color: Colors.red),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedMember?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hintText: 'Select member...',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    items: members.map((m) {
                      return DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(
                          m.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedMember = members.firstWhere(
                          (m) => m.id == val,
                        );
                      });
                    },
                    validator: (val) =>
                        val == null ? 'Please select a member' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text(
                  'Error loading members',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),

              // Infraction Presets
              const Text(
                'Infraction Presets (Editable) *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: InfractionPreset.presets.map((preset) {
                  final isSelected = _selectedType == preset.type;
                  return ChoiceChip(
                    avatar: Icon(
                      preset.icon,
                      size: 16,
                      color: isSelected ? Colors.white : preset.color,
                    ),
                    label: Text(
                      '${preset.title} (${_currencyFormat.format(preset.defaultAmount)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.red.shade700,
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (selected) {
                      if (selected) _onSelectPreset(preset);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Sanction Title & Fine Amount Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sanction Title *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fine Amount (₦) *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₦ ',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Meeting Linkage
              const Text(
                'Linked Meeting Minutes (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              meetingsAsync.when(
                data: (meetings) {
                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedMeetingId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.meeting_room_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'General Decorum (No specific meeting)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...meetings.map((m) {
                        return DropdownMenuItem<String?>(
                          value: m.id,
                          child: Text(
                            '${m.title} (${DateFormat('MMM d').format(m.meetingDate)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedMeetingId = val);
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),

              // Reason / Infraction Notes
              const Text(
                'Infraction Incident Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Arrived 40 minutes late without notification...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.gavel),
                  label: Text(
                    _isSubmitting ? 'Posting Fine...' : 'Sanction & Post Fine',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
