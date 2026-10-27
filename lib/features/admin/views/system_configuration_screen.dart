import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/controllers/auth_provider.dart';
import '../controllers/admin_provider.dart';
import '../models/system_settings_model.dart';

class SystemConfigurationScreen extends ConsumerStatefulWidget {
  const SystemConfigurationScreen({super.key});

  @override
  ConsumerState<SystemConfigurationScreen> createState() =>
      _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState
    extends ConsumerState<SystemConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _initialized = false;
  late bool _maintenanceMode;
  late TextEditingController _maintenanceMsgController;
  late String _paymentEnv; // 'live' | 'test'
  late String _feeBearer; // 'member' | 'organization'
  late TextEditingController _thresholdController;
  late bool _requirePresidentApproval;
  late int _maxUploadSizeBytes;
  late int _sessionTimeoutMinutes;
  late bool _pushNotificationsEnabled;
  late bool _smsNotificationsEnabled;
  late String _smsProvider;
  late bool _emailNotificationsEnabled;
  bool _isSaving = false;

  void _initValues(SystemSettingsModel settings) {
    if (_initialized) return;
    _maintenanceMode = settings.maintenanceMode;
    _maintenanceMsgController = TextEditingController(
      text: settings.maintenanceMessage,
    );
    _paymentEnv = settings.paymentEnvironment;
    _feeBearer = settings.feeBearer;
    _thresholdController = TextEditingController(
      text: settings.dualApprovalExpenseThreshold.toStringAsFixed(0),
    );
    _requirePresidentApproval = settings.requirePresidentApproval;
    _maxUploadSizeBytes = settings.maxUploadSizeBytes;
    _sessionTimeoutMinutes = settings.sessionTimeoutMinutes;
    _pushNotificationsEnabled = settings.pushNotificationsEnabled;
    _smsNotificationsEnabled = settings.smsNotificationsEnabled;
    _smsProvider = settings.smsProvider;
    _emailNotificationsEnabled = settings.emailNotificationsEnabled;
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _maintenanceMsgController.dispose();
      _thresholdController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(systemSettingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('System Configuration')),
      body: settingsAsync.when(
        data: (settings) {
          _initValues(settings);
          return _buildForm(context, settings);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final fallback = SystemSettingsModel.defaults();
          _initValues(fallback);
          return _buildForm(
            context,
            fallback,
            notice:
                'Connecting to system settings... displaying active defaults.',
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.paddingOf(context).bottom + 10,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Saving Changes...' : 'Save Configuration'),
          onPressed: _isSaving ? null : _saveSettings,
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    SystemSettingsModel settings, {
    String? notice,
  }) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        children: [
          if (notice != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notice,
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Maintenance & Availability Section
          _buildSectionHeader(
            title: 'System Status & Maintenance',
            icon: Icons.power_settings_new,
            color: _maintenanceMode ? Colors.red : Colors.green,
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _maintenanceMode
                    ? Colors.red.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_maintenanceMode) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Maintenance mode is ACTIVE. Standard users will see a maintenance notice upon logging in.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Maintenance Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Temporarily restricts non-admin access for updates or migrations.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _maintenanceMode,
                    onChanged: (val) {
                      setState(() => _maintenanceMode = val);
                    },
                  ),
                  if (_maintenanceMode) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _maintenanceMsgController,
                      decoration: const InputDecoration(
                        labelText: 'Public Maintenance Message',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Payment & Financial Configuration
          _buildSectionHeader(
            title: 'Payment Gateway & Financial Policies',
            icon: Icons.payments_outlined,
            color: Colors.blue,
          ),
          Card(
            elevation: 0,
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
                  // Payment Environment
                  const Text(
                    'Payment Gateway Environment',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Live Production'),
                        selected: _paymentEnv == 'live',
                        onSelected: (selected) {
                          if (selected) setState(() => _paymentEnv = 'live');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Test Sandbox'),
                        selected: _paymentEnv == 'test',
                        onSelected: (selected) {
                          if (selected) setState(() => _paymentEnv = 'test');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fee Bearer Policy
                  const Text(
                    'Gateway Processing Fee Policy',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _feeBearer,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'member',
                        child: Text(
                          'Member Pays Processing Fee',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'organization',
                        child: Text(
                          'Organization Absorbs Fee',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _feeBearer = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dual Approval Threshold
                  const Text(
                    'Dual-Approval Expense Threshold',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Expenses exceeding this amount require dual executive approvals.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₦ ',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || double.tryParse(val.trim()) == null) {
                        return 'Please enter a valid numeric threshold';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Platform Policies & Security
          _buildSectionHeader(
            title: 'Platform Policies & Security',
            icon: Icons.security,
            color: Colors.purple,
          ),
          Card(
            elevation: 0,
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Require President Approval for New Members',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'When enabled, newly registered members remain pending until approved.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _requirePresidentApproval,
                    onChanged: (val) =>
                        setState(() => _requirePresidentApproval = val),
                  ),
                  const Divider(height: 16),

                  // Max Upload Size
                  const Text(
                    'Max Document / Receipt Upload Size',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _maxUploadSizeBytes,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 5242880,
                        child: Text('5 MB', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 10485760,
                        child: Text('10 MB', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 26214400,
                        child: Text('25 MB', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _maxUploadSizeBytes = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Session Timeout
                  const Text(
                    'Session Inactivity Timeout',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _sessionTimeoutMinutes,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 30,
                        child: Text('30 Minutes', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text('1 Hour (Default)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 120,
                        child: Text('2 Hours', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Never Expire', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sessionTimeoutMinutes = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Communication & Notifications
          _buildSectionHeader(
            title: 'Communication & Gateways',
            icon: Icons.notifications_active_outlined,
            color: Colors.orange,
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Push Notifications (FCM)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Enables instant push alerts for dues, announcements, and approvals.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _pushNotificationsEnabled,
                    onChanged: (val) =>
                        setState(() => _pushNotificationsEnabled = val),
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'SMS Broadcast Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Delivers OTPs and urgent meeting alerts via SMS.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _smsNotificationsEnabled,
                    onChanged: (val) =>
                        setState(() => _smsNotificationsEnabled = val),
                  ),
                  if (_smsNotificationsEnabled) ...[
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _smsProvider,
                      decoration: InputDecoration(
                        labelText: 'Active SMS Provider',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Termii',
                          child: Text(
                            'Termii (Nigeria / Africa Direct)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Twilio',
                          child: Text(
                            'Twilio (Global Telecom)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _smsProvider = val);
                      },
                    ),
                  ],
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Transactional Email Delivery',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Dispatches automated receipt PDFs and account emails.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _emailNotificationsEnabled,
                    onChanged: (val) =>
                        setState(() => _emailNotificationsEnabled = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Diagnostics & Audit Metadata
          _buildSectionHeader(
            title: 'System Diagnostics & Information',
            icon: Icons.info_outline,
            color: Colors.blueGrey,
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    'Platform Version',
                    'AgePay v1.0.0 (Production)',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Last Configured',
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(settings.updatedAt),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Updated By Admin', settings.updatedBy),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.cleaning_services_outlined,
                      size: 16,
                    ),
                    label: const Text('Refresh & Invalidate App Cache'),
                    onPressed: () {
                      ref.invalidate(systemSettingsStreamProvider);
                      ref.invalidate(organizationsStreamProvider);
                      ref.invalidate(allUsersStreamProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'System cache invalidated successfully.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final authUser = ref.read(authProvider).valueOrNull;
      final adminEmail = authUser?.email ?? 'Super Admin';
      final threshold = double.parse(_thresholdController.text.trim());

      final updated = SystemSettingsModel(
        paymentEnvironment: _paymentEnv,
        feeBearer: _feeBearer,
        dualApprovalExpenseThreshold: threshold,
        requirePresidentApproval: _requirePresidentApproval,
        maxUploadSizeBytes: _maxUploadSizeBytes,
        sessionTimeoutMinutes: _sessionTimeoutMinutes,
        pushNotificationsEnabled: _pushNotificationsEnabled,
        smsNotificationsEnabled: _smsNotificationsEnabled,
        smsProvider: _smsProvider,
        emailNotificationsEnabled: _emailNotificationsEnabled,
        maintenanceMode: _maintenanceMode,
        maintenanceMessage: _maintenanceMsgController.text.trim(),
        updatedAt: DateTime.now(),
        updatedBy: adminEmail,
      );

      await ref
          .read(systemSettingsRepositoryProvider)
          .updateSettings(updated, updatedBy: adminEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System configuration saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
