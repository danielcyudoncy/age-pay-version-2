import 'package:flutter/material.dart';

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final int badgeCount;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        isPrimary ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Card(
      elevation: isPrimary ? 1 : 0,
      color: isPrimary
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(badgeCount.toString()),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
