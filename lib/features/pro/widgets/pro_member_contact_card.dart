// features/pro/widgets/pro_member_contact_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cls/core/theme/app_theme.dart';
import 'package:cls/features/members/models/member_model.dart';
import 'package:cls/features/pro/controllers/pro_communication_provider.dart';

class ProMemberContactCard extends ConsumerWidget {
  final MemberModel member;

  const ProMemberContactCard({
    super.key,
    required this.member,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasPhone = member.phoneNumber.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                member.fullName.isNotEmpty
                    ? member.fullName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPhone ? member.phoneNumber : 'No phone listed',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasPhone
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (hasPhone) ...[
              // WhatsApp button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chat, color: AppTheme.brandGreen, size: 20),
                tooltip: 'WhatsApp ${member.fullName}',
                onPressed: () {
                  ref.read(proCommunicationServiceProvider).shareToWhatsApp(
                    message: 'Hello ${member.fullName}, regarding our Age Grade community on AgePay:',
                    phoneNumber: member.phoneNumber,
                  );
                },
              ),
              // SMS button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.sms, color: Colors.blue, size: 20),
                tooltip: 'SMS ${member.fullName}',
                onPressed: () {
                  ref.read(proCommunicationServiceProvider).sendSms(
                    message: '',
                    recipients: [member.phoneNumber],
                  );
                },
              ),
              // Call button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.phone, color: Colors.teal, size: 20),
                tooltip: 'Call ${member.fullName}',
                onPressed: () {
                  ref.read(proCommunicationServiceProvider).makeCall(member.phoneNumber);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
