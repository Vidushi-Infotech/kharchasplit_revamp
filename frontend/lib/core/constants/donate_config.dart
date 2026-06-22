/// Donation / "Support the app" configuration.
///
/// ⚠️ Replace [upiId] (and optionally [payeeName]) with the real values before
/// release — these are placeholders.
class DonateConfig {
  DonateConfig._();

  /// UPI VPA (Virtual Payment Address).
  static const String upiId = 'livinglifetothefullestatharv@okhdfcbank';

  /// Name shown to the payer in their UPI app.
  static const String payeeName = 'Atharv';

  /// Default note attached to the payment.
  static const String note = 'Support KharchaSplit';

  /// True once a real UPI id has been configured (so we can hide the feature
  /// until it's set, rather than show a broken QR).
  static bool get isConfigured =>
      upiId.isNotEmpty && upiId != 'kharchasplit@upi';

  /// Builds the `upi://pay` deep link. Amount is left blank by default so the
  /// donor picks any amount in their UPI app.
  static String upiUri({String? amount}) {
    final params = <String, String>{
      'pa': upiId,
      'pn': payeeName,
      'cu': 'INR',
      'tn': note,
      if (amount != null && amount.trim().isNotEmpty) 'am': amount.trim(),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }
}
