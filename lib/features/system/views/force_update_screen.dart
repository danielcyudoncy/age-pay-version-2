import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/services/app_update_service.dart';
import '../../admin/models/system_settings_model.dart';

class ForceUpdateScreen extends StatefulWidget {
  final SystemSettingsModel settings;
  final bool autoStartDownload;

  const ForceUpdateScreen({
    super.key,
    required this.settings,
    this.autoStartDownload = true,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  final AppUpdateService _updateService = AppUpdateService();

  bool _isDownloading = false;
  bool _isInstalling = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  File? _downloadedFile;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartDownload && widget.settings.hasValidApkUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startUpdate();
        }
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _startUpdate() async {
    final apkUrl = widget.settings.apkDownloadUrl.trim();
    if (apkUrl.isEmpty) {
      setState(() {
        _errorMessage =
            'Update download link is not configured. Please contact your system administrator.';
      });
      return;
    }

    // On Web or non-Android platforms, open the URL in the browser
    if (kIsWeb || !Platform.isAndroid) {
      final uri = Uri.tryParse(apkUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() {
          _errorMessage = 'Could not open download URL: $apkUrl';
        });
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _isInstalling = false;
      _errorMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
    });

    try {
      final file = await _updateService.downloadApk(
        downloadUrl: apkUrl,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _isInstalling = true;
        _downloadedFile = file;
      });

      await _installDownloadedApk(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _isInstalling = false;
        _errorMessage = 'Download failed: ${e.toString()}';
      });
    }
  }

  Future<void> _installDownloadedApk(File file) async {
    final canInstall = await _updateService.canRequestPackageInstalls();
    if (!canInstall) {
      if (!mounted) return;
      _showInstallPermissionDialog();
      setState(() => _isInstalling = false);
      return;
    }

    final success = await _updateService.installApk(file.path);
    if (!mounted) return;
    setState(() => _isInstalling = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Package installer could not be launched. Check app install permissions.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => _updateService.openInstallSettings(),
          ),
        ),
      );
    }
  }

  void _showInstallPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.security, size: 36, color: Colors.orange),
        title: const Text('Permission Required'),
        content: const Text(
          'Android requires your permission to install applications from AgePay. '
          'Please allow "Install unknown apps" in the device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateService.openInstallSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = widget.settings.releaseNotes.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Badge
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.system_security_update_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Update Required',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'A mandatory update is required to continue using AgePay. '
                      'Please install the latest version to ensure financial integrity and security.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Version comparison chips
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Version',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                'v${AppVersion.currentVersion}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Required Version',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'v${widget.settings.latestAppVersion}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Release notes card
                    if (notes.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "What's New in v${widget.settings.latestAppVersion}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          notes,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Progress or Actions
                    if (_isDownloading) ...[
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Downloading update... ${(_progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _totalBytes > 0
                                    ? '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}'
                                    : _formatBytes(_receivedBytes),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The installer will open automatically when finished.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ] else if (_isInstalling) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Opening package installer...',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ] else ...[
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Update action buttons
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          icon: Icon(
                            _downloadedFile != null
                                ? Icons.system_security_update_rounded
                                : (_errorMessage != null
                                    ? Icons.refresh_rounded
                                    : Icons.download_rounded),
                          ),
                          label: Text(
                            _downloadedFile != null
                                ? 'Open Package Installer'
                                : (_errorMessage != null
                                    ? 'Retry Download'
                                    : 'Update Now'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            if (_downloadedFile != null &&
                                await _downloadedFile!.exists()) {
                              setState(() => _isInstalling = true);
                              await _installDownloadedApk(_downloadedFile!);
                            } else {
                              await _startUpdate();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Manual browser download fallback
                      if (widget.settings.hasValidApkUrl) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_browser, size: 16),
                          label: const Text('Download via Web Browser'),
                          onPressed: () async {
                            final uri = Uri.tryParse(
                              widget.settings.apkDownloadUrl.trim(),
                            );
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
