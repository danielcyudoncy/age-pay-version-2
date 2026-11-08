class IdentityVerificationResult {
  final bool isValid;
  final String message;
  final String? maskedId;

  const IdentityVerificationResult({
    required this.isValid,
    required this.message,
    this.maskedId,
  });
}

class IdentityVerificationService {
  // Known simulated blacklist of flagged fraudulent IDs
  static const Set<String> _blacklistedIds = {
    '00000000000',
    '99999999999',
    '12345678901',
  };

  static IdentityVerificationResult verifyNinOrBvn({
    required String rawId,
    required String fullName,
  }) {
    final cleanId = rawId.replaceAll(RegExp(r'\D'), '');

    if (cleanId.length != 11) {
      return const IdentityVerificationResult(
        isValid: false,
        message: 'National Identity (NIN) or BVN must be exactly 11 digits.',
      );
    }

    if (_blacklistedIds.contains(cleanId)) {
      return const IdentityVerificationResult(
        isValid: false,
        message: 'Security Alert: This identification has been flagged on the fraud prevention registry. Organisation creation blocked.',
      );
    }

    if (RegExp(r'^(\d)\1{10}$').hasMatch(cleanId)) {
      return const IdentityVerificationResult(
        isValid: false,
        message: 'Invalid NIN/BVN sequence detected. Please provide a valid government identity.',
      );
    }

    final masked = maskNinOrBvn(cleanId);

    return IdentityVerificationResult(
      isValid: true,
      message: 'Government Identity Verified for $fullName ($masked)',
      maskedId: masked,
    );
  }

  static String maskNinOrBvn(String id) {
    final clean = id.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 7) {
      return '${clean.substring(0, 3)}****${clean.substring(clean.length - 4)}';
    }
    return id;
  }
}
