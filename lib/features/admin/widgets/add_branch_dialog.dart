import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/nigerian_states.dart';
import '../controllers/admin_provider.dart';
import '../models/branch_model.dart';
import '../models/organization_model.dart';

class AddBranchDialog extends ConsumerStatefulWidget {
  final OrganizationModel organization;

  const AddBranchDialog({
    super.key,
    required this.organization,
  });

  static Future<void> show(BuildContext context, OrganizationModel organization) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddBranchDialog(organization: organization),
    );
  }

  @override
  ConsumerState<AddBranchDialog> createState() => _AddBranchDialogState();
}

class _AddBranchDialogState extends ConsumerState<AddBranchDialog> {
  int _selectedTabIndex = 0; // 0: Nigerian States Checkboxes, 1: Custom Branch
  final Set<String> _selectedStates = {};
  String _searchQuery = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  // Custom branch controllers
  final _customNameController = TextEditingController();
  final _customCityController = TextEditingController();
  String? _customSelectedState;
  final _customFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _customNameController.dispose();
    _customCityController.dispose();
    super.dispose();
  }

  bool _isStateAlreadyCreated(String state, List<BranchModel> existing) {
    final stateLower = state.toLowerCase().trim();
    final stdBranchName = getStandardBranchName(state).toLowerCase().trim();

    return existing.any((b) {
      final bState = b.state.toLowerCase().trim();
      final bName = b.name.toLowerCase().trim();
      return bState == stateLower ||
          bName == stateLower ||
          bName == stdBranchName ||
          bName == '$stateLower branch';
    });
  }

  void _toggleState(String state, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedStates.add(state);
      } else {
        _selectedStates.remove(state);
      }
    });
  }

  void _selectCommonHubs(List<BranchModel> existing) {
    setState(() {
      for (final hub in kCommonAgeGradeHubs) {
        if (!_isStateAlreadyCreated(hub, existing)) {
          _selectedStates.add(hub);
        }
      }
    });
  }

  void _selectAllFiltered(List<String> filtered, List<BranchModel> existing) {
    setState(() {
      for (final state in filtered) {
        if (!_isStateAlreadyCreated(state, existing)) {
          _selectedStates.add(state);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStates.clear();
    });
  }

  Future<void> _submitBatchStates() async {
    if (_selectedStates.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final newBranches = _selectedStates.map((state) {
        return BranchModel(
          id: '',
          organizationId: widget.organization.id,
          name: getStandardBranchName(state),
          state: state,
          city: '',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      await ref.read(branchRepositoryProvider).createBranches(newBranches);
      ref.invalidate(branchesStreamFamily(widget.organization.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${newBranches.length} branch${newBranches.length > 1 ? 'es' : ''} provisioned successfully for ${widget.organization.name}!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to provision branches: $e';
        });
      }
    }
  }

  Future<void> _submitCustomBranch() async {
    if (!_customFormKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final newBranch = BranchModel(
        id: '',
        organizationId: widget.organization.id,
        name: _customNameController.text.trim(),
        state: _customSelectedState?.trim() ?? '',
        city: _customCityController.text.trim(),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(branchRepositoryProvider).createBranch(newBranch);
      ref.invalidate(branchesStreamFamily(widget.organization.id));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Branch "${newBranch.name}" created for ${widget.organization.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to create branch: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(branchesStreamFamily(widget.organization.id));
    final existingBranches = branchesAsync.asData?.value ?? [];
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogHeight = (screenHeight * 0.65).clamp(380.0, 500.0);

    final filteredStates = kNigerianStates.where((state) {
      if (_searchQuery.isEmpty) return true;
      return state.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      actionsPadding: const EdgeInsets.all(12),
      actionsOverflowButtonSpacing: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hub_outlined, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Branches',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.organization.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tab Switcher
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.checklist_rtl_rounded, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('36 States (Checkboxes)', style: TextStyle(fontSize: 12)),
                  ),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Custom Branch', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              selected: {_selectedTabIndex},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedTabIndex = newSelection.first;
                  _errorMessage = null;
                });
              },
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: dialogHeight,
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildNigerianStatesView(filteredStates, existingBranches, theme)
                  : _buildCustomBranchView(theme),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_selectedTabIndex == 0)
          FilledButton.icon(
            onPressed: (_selectedStates.isEmpty || _isSubmitting)
                ? null
                : _submitBatchStates,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.playlist_add_check, size: 18),
            label: Text(
              _selectedStates.isEmpty
                  ? 'Select States'
                  : 'Provision ${_selectedStates.length} Branch${_selectedStates.length > 1 ? 'es' : ''}',
            ),
          )
        else
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitCustomBranch,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_location, size: 18),
            label: const Text('Add Branch'),
          ),
      ],
    );
  }

  Widget _buildNigerianStatesView(
    List<String> filteredStates,
    List<BranchModel> existingBranches,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search TextField
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search state (e.g. Lagos, Rivers, Abia)...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 8),

        // Quick helper chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.star_outline, size: 16),
                label: const Text('Major Hubs', style: TextStyle(fontSize: 12)),
                onPressed: () => _selectCommonHubs(existingBranches),
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.select_all, size: 16),
                label: const Text('Select All Filtered', style: TextStyle(fontSize: 12)),
                onPressed: () => _selectAllFiltered(filteredStates, existingBranches),
              ),
              if (_selectedStates.isNotEmpty) ...[
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.clear_all, size: 16),
                  label: Text('Clear (${_selectedStates.length})', style: const TextStyle(fontSize: 12)),
                  onPressed: _clearSelection,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Selection counter banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _selectedStates.isEmpty
                ? 'Check the states where ${widget.organization.name} has chapters.'
                : '${_selectedStates.length} state${_selectedStates.length > 1 ? 's' : ''} selected: ${_selectedStates.take(4).join(', ')}${_selectedStates.length > 4 ? ' +${_selectedStates.length - 4} more' : ''}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 36 States + FCT list
        Expanded(
          child: filteredStates.isEmpty
              ? Center(
                  child: Text(
                    'No states matching "$_searchQuery"',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredStates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final state = filteredStates[index];
                    final alreadyCreated = _isStateAlreadyCreated(state, existingBranches);
                    final isSelected = _selectedStates.contains(state);

                    return CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: alreadyCreated ? true : isSelected,
                      onChanged: alreadyCreated
                          ? null
                          : (checked) => _toggleState(state, checked),
                      title: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            state,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: alreadyCreated ? Colors.grey : null,
                            ),
                          ),
                          if (alreadyCreated)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Already added',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        alreadyCreated
                            ? 'Branch currently active in this state'
                            : 'Will provision: ${getStandardBranchName(state)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: alreadyCreated
                              ? Colors.grey
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomBranchView(ThemeData theme) {
    return Form(
      key: _customFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use this for custom chapters (e.g. Aba North Chapter, UK / Diaspora Chapter, etc.).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _customNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Branch Name *',
                hintText: 'e.g. Aba Chapter, London / Diaspora',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a branch name';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _customSelectedState,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'State (Optional)',
                hintText: 'Select state',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('None / Diaspora', overflow: TextOverflow.ellipsis),
                ),
                ...kNigerianStates.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _customSelectedState = val);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _customCityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'City / District (Optional)',
                hintText: 'e.g. Aba, Ikeja, London',
                prefixIcon: Icon(Icons.pin_drop_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
