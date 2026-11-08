/// Defines the current client app version and semantic version comparison utilities.
class AppVersion {
  /// Current release version of the AgePay client application.
  static const String currentVersion = '1.0.0';

  /// Current build number of the AgePay client application.
  static const int currentBuildNumber = 1;

  /// Returns `true` if [current] is strictly older than [target].
  ///
  /// Examples:
  /// - `isVersionOlder('1.0.0', '1.0.1')` -> `true`
  /// - `isVersionOlder('1.1.0', '1.0.9')` -> `false`
  /// - `isVersionOlder('1.0.0', '1.0.0')` -> `false`
  static bool isVersionOlder(String current, String target) {
    final cClean = current.trim();
    final tClean = target.trim();
    if (cClean.isEmpty || tClean.isEmpty) return false;

    // Separate semver core from build number (e.g. "1.0.0+2" -> "1.0.0" and 2)
    final cSplit = cClean.split('+');
    final tSplit = tClean.split('+');

    final cCore = cSplit[0];
    final tCore = tSplit[0];
    final cBuild = cSplit.length > 1 ? (int.tryParse(cSplit[1]) ?? 0) : null;
    final tBuild = tSplit.length > 1 ? (int.tryParse(tSplit[1]) ?? 0) : null;

    final currentParts =
        cCore.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final targetParts =
        tCore.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = currentParts.length > targetParts.length
        ? currentParts.length
        : targetParts.length;

    for (int i = 0; i < maxLen; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final t = i < targetParts.length ? targetParts[i] : 0;
      if (c < t) return true;
      if (c > t) return false;
    }

    // If core semver numbers are equal and build numbers are provided, compare builds
    if (cBuild != null && tBuild != null) {
      return cBuild < tBuild;
    }

    return false;
  }
}
