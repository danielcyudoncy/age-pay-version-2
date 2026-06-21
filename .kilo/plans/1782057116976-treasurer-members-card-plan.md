# Treasurer Dashboard UI Modernization

## Goal
Modernize the Treasurer Dashboard UI with tinted summary cards, a gradient header, improved list items, updated empty states, and polished QuickActionButton visuals — without changing code structure, providers, models, navigation, or tests.

## Scope
- **Modify:** `lib/features/dashboard/screens/treasurer_dashboard.dart` and `lib/core/widgets/quick_action_button.dart`
- **Preserve:** All providers, data flow, navigation patterns, and existing test assertions
- **No new files, no new models, no new providers**

## Implementation Tasks

### 1. Tinted Summary Cards
In `_OverviewCard`:
- Card background: `color: color.withValues(alpha: 0.06)`
- Icon container alpha: increase from `0.12` to `0.15`
- Keep same icon padding, sizing, value/label text styles
- Keep existing `onTap` InkWell behavior

### 2. Modern Dashboard Header
Replace greeting block (lines 77–84) with:
- `Container` with `BoxDecoration` gradient: top-left `colorScheme.primary.withValues(alpha: 0.08)` → bottom-right `Colors.transparent`
- `BorderRadius.circular(20)`, padding `EdgeInsets.all(16)`
- Inner `Row`:
  - `Expanded`: existing greeting `Text('Welcome, ${displayName}')` in `headlineSmall` bold
  - Trailing `Chip`: small summary (e.g., current month label like "Jun 2026" or simple status)
- Keep exact greeting string so existing text expectations remain valid

### 3. Member Arrears Custom Rows
Replace `ListTile` in `_MemberArrearsSection` with custom `Row`:
- Left: same `CircleAvatar` with initial
- Middle: `Expanded` `Column` — name (`Text` bold fontSize 14), subtitle (`Text` fontSize 12, grey, same "X unpaid obligation(s)")
- Right: amount pill — `Container` with `BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12))`, padding `EdgeInsets.symmetric(horizontal: 12, vertical: 6)`, bold red amount text
- Card margin: `EdgeInsets.only(bottom: 12)`
- Keep same `onTap` (currently empty)

### 4. Recent Activity Status Badges
Replace plain colored status `Text` with pill container:
- `Container` with `BoxDecoration(color: _statusColor(p.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12))`
- `Padding`: `EdgeInsets.symmetric(horizontal: 10, vertical: 4)`
- `Text`: same `_statusLabel(p.status)` value, fontSize 12, fontWeight w600, color `_statusColor(p.status)`

### 5. Updated Empty States
For all three empty state cards (members in arrears, levy collection, recent activity):
- Add `SizedBox(height: 8)` before icon
- Card background tint: `color: Colors.grey.shade50`
- Keep same icon, same text message, same padding
- Preserve exact text strings so test assertions at `test/treasurer_dashboard_test.dart:624` pass

### 6. QuickActionButton Visual Update
In `lib/core/widgets/quick_action_button.dart`:
- Public API unchanged
- Replace outer `Material` with `Card`:
  - `Card(elevation: isPrimary ? 1 : 0, color: isPrimary ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias)`
  - Keep inner `InkWell` + `Padding` + `Row` as-is

## Validation
1. `flutter analyze` — expect zero issues
2. `flutter test` — expect all tests pass without modifications
3. Manual check: tinted cards render, header gradient visible, arrears show amount pills, activity shows rounded badges, primary quick actions have elevation

## Risks
- **Low risk**: All changes are visual-only; no data flow, provider, or navigation changes
- Test impact: None expected — all text strings and widget types matched by tests remain unchanged
