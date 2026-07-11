import 'package:flutter/material.dart';
import 'package:cls/features/admin/models/organization_model.dart';

class OrganizationListItem extends StatelessWidget {
  final OrganizationModel organization;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;

  const OrganizationListItem({super.key,
    required this.organization,
    required this.onToggleStatus,
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
        subtitle: Text(organization.slug),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
