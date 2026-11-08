import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static const MethodChannel _installerChannel =
      MethodChannel('com.agegrade.cls/installer');

  /// Downloads an APK from [downloadUrl] and yields progress updates between `0.0` and `1.0`.
  /// Returns the saved [File] when the download finishes.
  Future<File> downloadApk({
    required String downloadUrl,
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
  }) async {
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl.trim()));
      request.followRedirects = true;
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Download server responded with status: ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength;
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/agepay_update.apk');

      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      sink = targetFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        final progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      return targetFile;
    } catch (e) {
      debugPrint('AppUpdateService download error: $e');
      rethrow;
    } finally {
      await sink?.close();
      client.close();
    }
  }

  /// Triggers Android's package installer sheet to install the downloaded APK.
  Future<bool> installApk(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Direct APK installation is only supported on Android devices.');
      return false;
    }
    try {
      final result = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to trigger APK install: ${e.message}');
      return false;
    }
  }

  /// Checks if the app has permission to request package installs on Android 8.0+.
  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _installerChannel
          .invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the device settings page to allow AgePay to install unknown apps.
  Future<void> openInstallSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('openInstallSettings');
    } catch (e) {
      debugPrint('Could not open install settings: $e');
    }
  }
}
