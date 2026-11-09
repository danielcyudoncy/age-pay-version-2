// features/pro/views/pro_communication_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/auth/models/user_model.dart';
import 'package:cls/features/pro/controllers/pro_communication_provider.dart';
import 'package:cls/features/pro/models/pro_communication_template.dart';
import 'package:cls/features/dashboard/controllers/treasurer_dashboard_provider.dart'
    show membersStreamProvider;
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/secretary/controllers/secretary_dashboard_provider.dart'
    show announcementsStreamProvider;

enum CommunicationChannel { omnichannel, inApp, whatsApp, sms }

class ProCommunicationHubScreen extends ConsumerStatefulWidget {
  final CommunicationChannel initialChannel;

  const ProCommunicationHubScreen({
    super.key,
    this.initialChannel = CommunicationChannel.omnichannel,
  });

  @override
  ConsumerState<ProCommunicationHubScreen> createState() =>
      _ProCommunicationHubScreenState();
}

class _ProCommunicationHubScreenState
    extends ConsumerState<ProCommunicationHubScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late CommunicationChannel _selectedChannel;

  String _targetAudience = 'all'; // 'all', 'branch', 'executives'
  String _urgency = 'normal'; // 'normal', 'important', 'urgent'
  bool _isPinned = false;
  bool _isSending = false;

  MemberModel? _selectedDirectMember;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(ProCommunicationTemplate template) {
    setState(() {
      _titleController.text = template.title;
      _bodyController.text = template.body;
      _urgency = template.urgency;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied template: ${template.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleDispatch(UserModel user, List<MemberModel> members) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    final proService = ref.read(proCommunicationServiceProvider);

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final orgName = user.organizationId.isNotEmpty ? user.organizationId : 'AgePay Community';
    final branchName = user.branchName ?? user.branchId;
    final senderName = user.displayName.isNotEmpty ? user.displayName : 'Public Relations Officer';

    final formattedMessage = proService.formatBroadcastMessage(
      title: title,
      body: body,
      organizationName: orgName,
      branchName: branchName,
      senderName: senderName,
      urgency: _urgency,
    );

    try {
      switch (_selectedChannel) {
        case CommunicationChannel.inApp:
          await proService.broadcastInApp(
            title: title,
            body: body,
            organizationId: user.organizationId,
            createdBy: user.uid,
            branchId: user.branchId,
            targetAudience: _targetAudience,
            isPinned: _isPinned,
          );
          ref.invalidate(announcementsStreamProvider(user.organizationId));
          if (mounted) {
            _showSuccessDialog('In-App broadcast posted and notification dispatched!');
          }
          break;

        case CommunicationChannel.whatsApp:
          final recipientPhone = _selectedDirectMember?.phoneNumber;
          await proService.shareToWhatsApp(
            message: formattedMessage,
            phoneNumber: recipientPhone,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primary(context),
                content: Text('Dispatched to WhatsApp successfully!'),
              ),
            );
          }
          break;

        case CommunicationChannel.sms:
          final recipients = _selectedDirectMember != null
              ? [_selectedDirectMember!.phoneNumber]
              : members
                  .map((m) => m.phoneNumber)
                  .where((p) => p.isNotEmpty)
                  .toList();

          await proService.sendSms(
            message: '$title: $body',
            recipients: recipients,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.blue,
                content: Text('SMS application opened with recipients!'),
              ),
            );
          }
          break;

        case CommunicationChannel.omnichannel:
          // 1. Post in-app first
          await proService.broadcastInApp(
            title: title,
            body: body,
            organizationId: user.organizationId,
            createdBy: user.uid,
            branchId: user.branchId,
            targetAudience: _targetAudience,
            isPinned: _isPinned,
          );
          ref.invalidate(announcementsStreamProvider(user.organizationId));

          // 2. Open WhatsApp share for community groups
          await proService.shareToWhatsApp(message: formattedMessage);

          if (mounted) {
            _showSuccessDialog(
              'Omnichannel dispatch triggered: In-App published, alerts sent, and WhatsApp opened!',
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Dispatch note: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Dispatch Successful'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;
    final members = ref.watch(membersStreamProvider).valueOrNull ?? [];

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final validPhoneCount = members.where((m) => m.phoneNumber.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PRO Communication Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all member phone numbers',
            onPressed: () {
              final phones = members
                  .map((m) => m.phoneNumber.trim())
                  .where((p) => p.isNotEmpty)
                  .join(', ');
              if (phones.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: phones));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $validPhoneCount member phone numbers to clipboard'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 32,
          ),
          children: [
            // 1. Channel Switcher Header Card
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.podcasts,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select Dispatch Channel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.all_inclusive, size: 16),
                          label: const Text('Omnichannel'),
                          selected: _selectedChannel == CommunicationChannel.omnichannel,
                          onSelected: (_) => setState(
                            () => _selectedChannel = CommunicationChannel.omnichannel,
                          ),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.campaign, size: 16),
                          label: const Text('In-App Broadcast'),
                          selected: _selectedChannel == CommunicationChannel.inApp,
                          onSelected: (_) => setState(
                            () => _selectedChannel = CommunicationChannel.inApp,
                          ),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.chat, size: 16, color: Colors.green),
                          label: const Text('WhatsApp'),
                          selected: _selectedChannel == CommunicationChannel.whatsApp,
                          onSelected: (_) => setState(
                            () => _selectedChannel = CommunicationChannel.whatsApp,
                          ),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.sms, size: 16, color: Colors.blue),
                          label: const Text('SMS Text'),
                          selected: _selectedChannel == CommunicationChannel.sms,
                          onSelected: (_) => setState(
                            () => _selectedChannel = CommunicationChannel.sms,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _channelDescription(_selectedChannel),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Pre-defined Message Templates
            Text(
              'Quick Templates',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ProCommunicationTemplate.defaultTemplates.map((template) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.text_snippet_outlined, size: 16),
                      label: Text(template.name),
                      onPressed: () => _applyTemplate(template),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Target Audience & Urgency (for In-App & Omnichannel)
            if (_selectedChannel == CommunicationChannel.inApp ||
                _selectedChannel == CommunicationChannel.omnichannel) ...[
              DropdownButtonFormField<String>(
                initialValue: _targetAudience,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  prefixIcon: Icon(Icons.people_outline),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Members', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'branch',
                    child: Text('My Branch Only', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'executives',
                    child: Text('Executives Only', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _targetAudience = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _urgency,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Urgency',
                  prefixIcon: Icon(Icons.priority_high),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'normal',
                    child: Text('Normal Notice', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'important',
                    child: Text('Important', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'urgent',
                    child: Text('Urgent Advisory', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _urgency = val);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin this announcement to top'),
                subtitle: const Text('Keeps the notice pinned at the top of members’ feed'),
                value: _isPinned,
                onChanged: (val) => setState(() => _isPinned = val),
              ),
              const SizedBox(height: 12),
            ],

            // Optional direct member targeting (for WhatsApp & SMS)
            if (_selectedChannel == CommunicationChannel.whatsApp ||
                _selectedChannel == CommunicationChannel.sms) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _selectedDirectMember == null
                            ? Icons.group
                            : Icons.person,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedDirectMember == null
                                  ? 'Broadcasting to all $validPhoneCount members'
                                  : 'Direct message to: ${_selectedDirectMember!.fullName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _selectedDirectMember == null
                                  ? 'Tap to select an individual recipient'
                                  : _selectedDirectMember!.phoneNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedDirectMember != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear individual recipient',
                          onPressed: () => setState(() => _selectedDirectMember = null),
                        )
                      else
                        TextButton(
                          onPressed: () => _pickDirectMember(context, members),
                          child: const Text('Pick Member'),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // 4. Message Inputs
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Announcement Title *',
                hintText: 'e.g., General Assembly Roll Call & Agenda',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Title is required';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message Body *',
                hintText: 'Compose your announcement or dispatch message...',
                prefixIcon: Icon(Icons.edit_note),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Message body is required';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${_bodyController.text.length} characters',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Approx. ${(_bodyController.text.length / 160).ceil().clamp(1, 10)} SMS page(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Live Message Preview Box
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.preview_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Formatted Dispatch Preview',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      _titleController.text.isEmpty && _bodyController.text.isEmpty
                          ? 'Your formatted message preview will appear here as you type...'
                          : ref.read(proCommunicationServiceProvider).formatBroadcastMessage(
                                title: _titleController.text.isEmpty
                                    ? 'Untitled Announcement'
                                    : _titleController.text,
                                body: _bodyController.text.isEmpty
                                    ? 'No message content yet.'
                                    : _bodyController.text,
                                organizationName: user.organizationId,
                                branchName: user.branchName,
                                senderName: user.displayName,
                                urgency: _urgency,
                              ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 6. Dispatch Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSending ? null : () => _handleDispatch(user, members),
                icon: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_actionButtonIcon(_selectedChannel)),
                label: Text(
                  _actionButtonLabel(_selectedChannel),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDirectMember(BuildContext context, List<MemberModel> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = members.where((m) {
              final q = filter.toLowerCase();
              return m.fullName.toLowerCase().contains(q) ||
                  m.phoneNumber.contains(q);
            }).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  const Text(
                    'Select Recipient Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by name or phone...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setModalState(() => filter = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final m = filtered[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(m.fullName.isNotEmpty ? m.fullName[0] : '?'),
                          ),
                          title: Text(m.fullName),
                          subtitle: Text(m.phoneNumber.isNotEmpty ? m.phoneNumber : 'No phone number'),
                          onTap: () {
                            setState(() => _selectedDirectMember = m);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _channelDescription(CommunicationChannel channel) {
    switch (channel) {
      case CommunicationChannel.omnichannel:
        return 'Publishes in-app to all members, sends instant notification chimes, and opens WhatsApp for community broadcast.';
      case CommunicationChannel.inApp:
        return 'Posts directly to the in-app announcement board and delivers an immediate notification banner and audio chime to all members.';
      case CommunicationChannel.whatsApp:
        return 'Opens WhatsApp with a structured, pre-formatted announcement ready to share with community groups or individual members.';
      case CommunicationChannel.sms:
        return 'Launches your device’s default SMS messenger pre-populated with member phone numbers and message content.';
    }
  }

  IconData _actionButtonIcon(CommunicationChannel channel) {
    switch (channel) {
      case CommunicationChannel.omnichannel:
        return Icons.rocket_launch;
      case CommunicationChannel.inApp:
        return Icons.campaign;
      case CommunicationChannel.whatsApp:
        return Icons.chat;
      case CommunicationChannel.sms:
        return Icons.sms;
    }
  }

  String _actionButtonLabel(CommunicationChannel channel) {
    switch (channel) {
      case CommunicationChannel.omnichannel:
        return 'Launch Omnichannel Blast';
      case CommunicationChannel.inApp:
        return 'Publish In-App Broadcast';
      case CommunicationChannel.whatsApp:
        return _selectedDirectMember != null
            ? 'Send WhatsApp to ${_selectedDirectMember!.fullName}'
            : 'Dispatch via WhatsApp';
      case CommunicationChannel.sms:
        return _selectedDirectMember != null
            ? 'Send SMS to ${_selectedDirectMember!.fullName}'
            : 'Send SMS to All Members';
    }
  }
}
