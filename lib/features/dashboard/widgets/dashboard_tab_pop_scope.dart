import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable PopScope wrapper for multi-tab dashboards.
/// When the user is on a sub-tab (selectedIndex != 0), pressing the hardware
/// back button switches to the Home tab (index 0).
/// When on the Home tab, pressing back prompts "Press back again to exit"
/// with a 2-second debounce before exiting the app.
class DashboardTabPopScope extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final Widget child;

  const DashboardTabPopScope({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.child,
  });

  @override
  State<DashboardTabPopScope> createState() => _DashboardTabPopScopeState();
}

class _DashboardTabPopScopeState extends State<DashboardTabPopScope> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.selectedIndex != 0) {
          widget.onSelectTab(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
