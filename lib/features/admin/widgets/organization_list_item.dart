import 'package:flutter/material.dart';
import 'package:cls/features/admin/models/organization_model.dart';

class OrganizationListItem extends StatelessWidget {
  final OrganizationModel organization;
  final VoidCallback onToggleStatus;
  final VoidCallback onToggleJoin;
  final VoidCallback onEdit;

  const OrganizationListItem({super.key,
    required this.organization,
    required this.onToggleStatus,
    required this.onToggleJoin,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: organization.isActive
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.red.withValues(alpha: 0.15),
          child: Icon(
            organization.isActive ? Icons.check_circle : Icons.cancel,
            color: organization.isActive ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          organization.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(organization.slug),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: organization.openForJoin
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                organization.openForJoin ? 'Open for join' : 'Join closed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: organization.openForJoin ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                organization.openForJoin
                    ? Icons.login
                    : Icons.no_accounts,
                color: organization.openForJoin ? Colors.blue : null,
              ),
              tooltip: organization.openForJoin
                  ? 'Close join'
                  : 'Open for join',
              onPressed: onToggleJoin,
            ),
            IconButton(
              icon: Icon(
                organization.isActive
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              tooltip: organization.isActive ? 'Deactivate' : 'Activate',
              onPressed: onToggleStatus,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
