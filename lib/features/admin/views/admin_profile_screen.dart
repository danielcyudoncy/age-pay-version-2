import 'package:cls/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../auth/controllers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/identity_verification_service.dart';
import '../../auth/views/login_screen.dart';
import '../controllers/admin_provider.dart';

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ninController;

  String? _selectedOrganizationId;
  String? _selectedBranchId;
  String? _selectedBranchName;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _ninController = TextEditingController(text: user?.ninOrBvn ?? '');
    _selectedOrganizationId =
        user?.organizationId.isNotEmpty == true ? user!.organizationId : null;
    _selectedBranchId = user?.branchId;
    _selectedBranchName = user?.branchName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  void _enterEditMode(UserModel user) {
    setState(() {
      _isEditing = true;
      _errorMessage = null;
      _nameController.text = user.displayName;
      _phoneController.text = user.phoneNumber;
      _ninController.text = user.ninOrBvn ?? '';
      _selectedOrganizationId =
          user.organizationId.isNotEmpty ? user.organizationId : null;
      _selectedBranchId = user.branchId;
      _selectedBranchName = user.branchName;
    });
  }

  void _cancelEdit() {
    final user = ref.read(authProvider).valueOrNull;
    setState(() {
      _isEditing = false;
      _errorMessage = null;
      _selectedOrganizationId =
          user?.organizationId.isNotEmpty == true ? user!.organizationId : null;
      _selectedBranchId = user?.branchId;
      _selectedBranchName = user?.branchName;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final ninVal = _ninController.text.trim();
    if (ninVal.isNotEmpty) {
      final verify = IdentityVerificationService.verifyNinOrBvn(
        rawId: ninVal,
        fullName: _nameController.text.trim(),
      );
      if (!verify.isValid) {
        setState(() => _errorMessage = verify.message);
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).updateProfile(
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            ninOrBvn: ninVal.isNotEmpty ? ninVal : null,
            organizationId: _selectedOrganizationId ?? '',
            branchId: _selectedBranchId,
            branchName: _selectedBranchName,
          );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: const Text('Super Admin profile updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue.shade700,
            content: Text('Password reset instructions sent to $email'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to send reset email: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to end your Super Admin session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final navigator = Navigator.of(context);
      await ref.read(authProvider.notifier).signOut();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Super Admin Profile')),
        body: const Center(child: Text('No active administrative session.')),
      );
    }

    final createdAtFormatted = DateFormat('MMM dd, yyyy').format(user.createdAt);
    final maskedNin = user.ninOrBvn != null && user.ninOrBvn!.isNotEmpty
        ? IdentityVerificationService.maskNinOrBvn(user.ninOrBvn!)
        : 'Not recorded';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () => _enterEditMode(user),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Executive Header Card
            _buildExecutiveHeader(user, theme),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusBg(context, Colors.red),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.statusColor(context, Colors.red).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.statusColor(context, Colors.red), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.statusColor(context, Colors.red), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Edit Mode Form vs View Mode Details
            if (_isEditing)
              _buildEditForm(theme)
            else ...[
              _buildPersonalInfoSection(user, maskedNin, createdAtFormatted, theme),
              const SizedBox(height: 16),
              _buildHomeBranchCard(user, theme),
              const SizedBox(height: 16),
              _buildGovernancePrivilegesCard(theme),
              const SizedBox(height: 16),
              _buildSecurityAndAccountCard(user, theme),
              const SizedBox(height: 24),
              _buildSignOutButton(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(UserModel user, ThemeData theme) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
        : 'SA';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 41,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.black87,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName.isNotEmpty ? user.displayName : 'Super Admin',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.black87, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'SUPER ADMIN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Global Governance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(
    UserModel user,
    String maskedNin,
    String createdAtFormatted,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Personal Information',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _enterEditMode(user),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailTile(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: user.displayName.isNotEmpty ? user.displayName : 'Not set',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              value: user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not provided',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.email_outlined,
              label: 'Admin Email',
              value: user.email,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.fingerprint,
              label: 'NIN / BVN Verification',
              value: maskedNin,
              theme: theme,
              trailing: user.ninOrBvn != null && user.ninOrBvn!.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.statusBg(context, Colors.green),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.statusColor(context, Colors.green),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.calendar_today_outlined,
              label: 'Account Established',
              value: createdAtFormatted,
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.location_on_outlined,
              label: 'Local Branch Member',
              value: user.branchName?.isNotEmpty == true
                  ? user.branchName!
                  : 'Branch Member',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildDetailTile(
              icon: Icons.public_outlined,
              label: 'National Branch Standing',
              value: user.nationalRole != null
                  ? 'National Executive (${user.nationalRole!.displayName})'
                  : 'National Assembly & Council',
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBranchCard(UserModel user, ThemeData theme) {
    final orgsAsync = ref.watch(organizationsStreamProvider);
    final orgs = orgsAsync.valueOrNull ?? [];
    final affiliatedOrg = user.organizationId.isNotEmpty
        ? orgs.where((o) => o.id == user.organizationId).firstOrNull
        : null;
    final orgName = affiliatedOrg?.name ??
        (user.organizationId.isNotEmpty ? user.organizationId : null);
    final hasAffiliation = orgName != null && orgName.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.cardBorder(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        color: AppTheme.primary(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Home Community & Branch Membership',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _enterEditMode(user),
                  icon: Icon(hasAffiliation ? Icons.sync_alt : Icons.link, size: 14),
                  label: Text(
                    hasAffiliation ? 'Change' : 'Link Branch',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const Divider(height: 20),
            if (hasAffiliation) ...[
              _buildDetailTile(
                icon: Icons.corporate_fare,
                label: 'Affiliated Community Organisation',
                value: orgName,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.location_on_outlined,
                label: 'Home Branch',
                value: user.branchName?.isNotEmpty == true
                    ? user.branchName!
                    : 'Primary Branch',
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.how_to_reg_outlined,
                label: 'Community Membership Standing',
                value: 'Active Member (${user.duesStanding.name.toUpperCase()})',
                theme: theme,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.statusBg(context, Colors.green),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: AppTheme.statusColor(context, Colors.green),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.statusColor(context, Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusBg(context, Colors.amber),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.statusColor(context, Colors.amber).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.statusColor(context, Colors.amber),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Global Platform Mode Only',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.statusColor(context, Colors.amber),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You currently operate with global platform privileges across all organisations, but without an active home branch affiliation. Link your home community to view personal dues, levies, attendance, and member ID card.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.onSurface(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _enterEditMode(user),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Link Home Community & Branch'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGovernancePrivilegesCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Governance Privileges',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPrivilegeRow(
              Icons.domain_verification,
              'Multi-Tenant Organisation Verification & Platform Gate',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildPrivilegeRow(
              Icons.hub_outlined,
              '36 Nigerian States & National Branch Governance',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildPrivilegeRow(
              Icons.security,
              'Zero-Trust Fraud Mitigation & Bank Account Matching Audit',
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildPrivilegeRow(
              Icons.manage_accounts,
              'Global User Permissions, Roles & Suspension Authority',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivilegeRow(IconData icon, String text, MaterialColor color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.statusBg(context, color),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppTheme.statusColor(context, color), size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityAndAccountCard(UserModel user, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Security & Authentication',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Identification (UID)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        user.uid,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy UID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.uid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Super Admin UID copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _sendPasswordReset(user.email),
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Send Password Reset Email'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit, color: theme.colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Profile Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Chief Daniel Udoncy',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'e.g. 08012345678',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ninController,
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: const InputDecoration(
                  labelText: 'NIN / BVN (11 Digits)',
                  hintText: 'e.g. 22233344455',
                  prefixIcon: Icon(Icons.fingerprint),
                  border: OutlineInputBorder(),
                  helperText: 'Executive verification identity for platform audits',
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: AppTheme.primary(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Home Community & Branch Affiliation',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Affiliate your Super Admin account with a specific community organisation and branch to participate as an active member in dues, levies, and meetings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final orgsAsync = ref.watch(organizationsStreamProvider);
                  final orgs = orgsAsync.valueOrNull ?? [];
                  final isOrgValid =
                      orgs.any((o) => o.id == _selectedOrganizationId);
                  final effectiveOrgId = isOrgValid
                      ? _selectedOrganizationId
                      : (_selectedOrganizationId?.isEmpty == true ? '' : null);

                  return DropdownButtonFormField<String>(
                    key: ValueKey(effectiveOrgId),
                    initialValue: effectiveOrgId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Home Organisation',
                      hintText: orgsAsync.isLoading
                          ? 'Loading organisations...'
                          : (orgs.isEmpty
                              ? 'No organisations registered yet'
                              : 'Select community organisation'),
                      prefixIcon: const Icon(Icons.corporate_fare_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          'None (Global Platform Mode Only)',
                          style: TextStyle(fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...orgs.map((org) {
                        return DropdownMenuItem<String>(
                          value: org.id,
                          child: Text(
                            org.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedOrganizationId = val;
                        _selectedBranchId = null;
                        _selectedBranchName = null;
                      });
                    },
                  );
                },
              ),
              if (_selectedOrganizationId != null &&
                  _selectedOrganizationId!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final branchesAsync =
                        ref.watch(branchesStreamFamily(_selectedOrganizationId!));
                    final branches = branchesAsync.valueOrNull ?? [];
                    final isBranchValid =
                        branches.any((b) => b.id == _selectedBranchId);
                    String? effectiveBranchId =
                        isBranchValid ? _selectedBranchId : null;

                    if (effectiveBranchId == null &&
                        _selectedBranchName != null &&
                        branches.isNotEmpty) {
                      final match = branches
                          .where((b) =>
                              b.name.toLowerCase() ==
                              _selectedBranchName!.toLowerCase())
                          .firstOrNull;
                      if (match != null) {
                        effectiveBranchId = match.id;
                      }
                    }

                    return DropdownButtonFormField<String>(
                      key: ValueKey('$_selectedOrganizationId-$effectiveBranchId'),
                      initialValue: effectiveBranchId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Home Branch *',
                        hintText: branchesAsync.isLoading
                            ? 'Loading branches...'
                            : (branches.isEmpty
                                ? 'No branches in this organisation'
                                : 'Select your home branch'),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: const OutlineInputBorder(),
                        helperText:
                            'Your dues, obligations, and meetings will be scoped to this branch',
                      ),
                      items: branches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: branches.isEmpty
                          ? null
                          : (val) {
                              final chosen =
                                  branches.firstWhere((b) => b.id == val);
                              setState(() {
                                _selectedBranchId = chosen.id;
                                _selectedBranchName = chosen.name;
                              });
                            },
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEdit,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Save Changes',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildSignOutButton(ThemeData theme) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _confirmSignOut,
      icon: const Icon(Icons.logout, size: 18),
      label: const Text(
        'Sign Out of Super Admin Session',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
