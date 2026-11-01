enum BankMatchStatus {
  verifiedAssociation,
  mismatched,
  personalAccountBlocked,
  invalidNumber,
}

class BankMatchResult {
  final BankMatchStatus status;
  final String message;
  final bool isApproved;
  final double similarityScore;

  const BankMatchResult({
    required this.status,
    required this.message,
    required this.isApproved,
    required this.similarityScore,
  });
}

class BankVerificationService {
  static const List<String> _orgKeywords = [
    'AGE',
    'GRADE',
    'ASSOCIATION',
    'UNION',
    'COMMUNITY',
    'DEVELOPMENT',
    'CLUB',
    'BRANCH',
    'NATIONAL',
    'TRUSTEES',
    'INITIATIVE',
    'SOCIETY',
    'ASSEMBLY',
    'CORP',
    'LIMITED',
    'LTD',
  ];

  static BankMatchResult verifyAccount({
    required String bankName,
    required String accountNumber,
    required String organizationName,
    required String accountName,
  }) {
    final cleanAccNum = accountNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanAccNum.length != 10) {
      return const BankMatchResult(
        status: BankMatchStatus.invalidNumber,
        message: 'Account number must be exactly 10 digits (NUBAN format).',
        isApproved: false,
        similarityScore: 0.0,
      );
    }

    final normAccName = accountName.trim().toUpperCase();
    final normOrgName = organizationName.trim().toUpperCase();

    if (normAccName.isEmpty) {
      return const BankMatchResult(
        status: BankMatchStatus.mismatched,
        message: 'Account name cannot be empty.',
        isApproved: false,
        similarityScore: 0.0,
      );
    }

    // Tokenize names
    final orgTokens = normOrgName
        .split(RegExp(r'[\s\-_,./]+'))
        .where((t) => t.length > 2)
        .toSet();

    final accTokens = normAccName
        .split(RegExp(r'[\s\-_,./]+'))
        .where((t) => t.length > 2)
        .toSet();

    // Check shared tokens
    final intersection = orgTokens.intersection(accTokens);
    final hasOrgKeyword = accTokens.any((t) => _orgKeywords.contains(t));

    // If account name is 2 words and contains zero org keywords and zero shared tokens with the org
    final isLikelyPersonal = accTokens.length <= 3 && !hasOrgKeyword && intersection.isEmpty;

    if (isLikelyPersonal) {
      return BankMatchResult(
        status: BankMatchStatus.personalAccountBlocked,
        message:
            'Security Warning: Personal bank accounts are prohibited for community funds. The account name ("$accountName") does not match your Age Grade ("$organizationName"). Corporate/Association account required.',
        isApproved: false,
        similarityScore: 0.0,
      );
    }

    // Calculate match score
    final score = orgTokens.isEmpty
        ? 0.0
        : (intersection.length / orgTokens.length).clamp(0.0, 1.0);

    final isAcceptable = hasOrgKeyword || intersection.isNotEmpty || normAccName.contains(normOrgName);

    if (isAcceptable) {
      return BankMatchResult(
        status: BankMatchStatus.verifiedAssociation,
        message:
            'Verified Association Account: Account name matches registered Age Grade entity.',
        isApproved: true,
        similarityScore: score > 0 ? score : 0.85,
      );
    }

    return BankMatchResult(
      status: BankMatchStatus.mismatched,
      message:
          'Account name ("$accountName") does not sufficiently match "$organizationName". Please ensure the bank account was opened in the name of the Age Grade.',
      isApproved: false,
      similarityScore: score,
    );
  }
}
