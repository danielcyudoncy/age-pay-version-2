import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../meetings/models/meeting_model.dart';
import '../../members/models/member_model.dart';
import '../../secretary/controllers/secretary_dashboard_provider.dart';
import '../controllers/provost_provider.dart';
import '../models/infraction_presets.dart';
import '../widgets/issue_penalty_sheet.dart';

class MeetingDecorumScreen extends ConsumerStatefulWidget {
  final MeetingModel meeting;

  const MeetingDecorumScreen({
    super.key,
    required this.meeting,
  });

  @override
  ConsumerState<MeetingDecorumScreen> createState() =>
      _MeetingDecorumScreenState();
}

class _MeetingDecorumScreenState extends ConsumerState<MeetingDecorumScreen> {
  String _searchQuery = '';
  final Set<String> _sanctioningMembers = {};

  final _currencyFormat =
      NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  Future<void> _quickSanction({
    required MemberModel member,
    required PenaltyInfractionType type,
    required String provostName,
  }) async {
    final preset = InfractionPreset.forType(type);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sanction ${member.fullName}?'),
        content: Text(
          'Issue ${preset.title} fine of ${_currencyFormat.format(preset.defaultAmount)} for meeting "${widget.meeting.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Sanction'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sanctioningMembers.add(member.id));
    try {
      final controller = ref.read(provostControllerProvider);
      await controller.issuePenalty(
        organizationId: widget.meeting.organizationId,
        memberId: member.id,
        memberName: member.fullName,
        infractionType: type,
        title: preset.title,
        description:
            'Sanctioned during decorum roll-call for meeting "${widget.meeting.title}".',
        amount: preset.defaultAmount,
        issuedBy: provostName,
        meetingId: widget.meeting.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${preset.title} fine issued to ${member.fullName}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to sanction member: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sanctioningMembers.remove(member.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final provost = authState.valueOrNull;
    final provostName = provost?.displayName ?? 'Provost';

    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Decorum Roll-Call'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Meeting header info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.indigo.shade900,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SESSION IN PROGRESS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('EEE, MMM d, yyyy')
                          .format(widget.meeting.meetingDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.meeting.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.meeting.venue.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        widget.meeting.venue,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search member name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Members list
          Expanded(
            child: membersAsync.when(
              data: (rawMembers) {
                var members = rawMembers.whereType<MemberModel>().toList();
                if (_searchQuery.isNotEmpty) {
                  members = members
                      .where((m) =>
                          m.fullName.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                if (members.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No members registered'
                          : 'No matching members found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final member = members[index];
                    final isSanctioning =
                        _sanctioningMembers.contains(member.id);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.indigo.shade100,
                            child: Text(
                              member.fullName.isNotEmpty
                                  ? member.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (member.phoneNumber.isNotEmpty)
                                  Text(
                                    member.phoneNumber,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSanctioning)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _quickButton(
                                  label: 'Late',
                                  color: Colors.amber.shade800,
                                  onTap: () => _quickSanction(
                                    member: member,
                                    type: PenaltyInfractionType.lateComing,
                                    provostName: provostName,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                _quickButton(
                                  label: 'Absent',
                                  color: Colors.red.shade700,
                                  onTap: () => _quickSanction(
                                    member: member,
                                    type: PenaltyInfractionType.unexcusedAbsence,
                                    provostName: provostName,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  tooltip: 'Custom Sanction',
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20)),
                                      ),
                                      builder: (_) => IssuePenaltySheet(
                                        organizationId:
                                            widget.meeting.organizationId,
                                        provostName: provostName,
                                        meeting: widget.meeting,
                                        preselectedMember: member,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Error loading members')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
