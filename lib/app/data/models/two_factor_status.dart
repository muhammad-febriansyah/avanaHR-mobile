/// Where the account stands on two-factor, as the server reports it.
///
/// The three states are exclusive: off, half-enrolled and waiting on a code,
/// or on. The setup material only arrives while enrolling and the recovery
/// codes only once it is on, so the fields are never both populated.
class TwoFactorStatus {
  final bool enabled;
  final bool confirming;

  /// The QR the authenticator app scans. Present only while [confirming].
  final String? qrSvg;

  /// The same secret in typeable form, for a phone that cannot scan itself.
  final String? setupKey;

  /// `otpauth://` — tapping it hands the account to the authenticator app so
  /// nobody has to copy the key by hand.
  final String? setupUrl;

  /// One-shot codes for the day the authenticator app is gone. Only once on.
  final List<String> recoveryCodes;

  const TwoFactorStatus({
    required this.enabled,
    required this.confirming,
    this.qrSvg,
    this.setupKey,
    this.setupUrl,
    this.recoveryCodes = const [],
  });

  const TwoFactorStatus.off() : this(enabled: false, confirming: false);

  factory TwoFactorStatus.fromJson(Map<String, dynamic> json) {
    final codes = json['recovery_codes'];

    return TwoFactorStatus(
      enabled: json['enabled'] == true,
      confirming: json['confirming'] == true,
      qrSvg: json['qr_svg'] as String?,
      setupKey: json['setup_key'] as String?,
      setupUrl: json['setup_url'] as String?,
      recoveryCodes: codes is List
          ? codes.map((c) => c.toString()).toList()
          : const [],
    );
  }
}
