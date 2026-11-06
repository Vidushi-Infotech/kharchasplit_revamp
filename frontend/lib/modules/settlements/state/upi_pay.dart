import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pay-by-UPI helpers (feature flag `upiPay`).
///
/// The app never moves money: it hands a `upi://pay` intent to the user's
/// UPI app and, once they come back, asks whether the payment went through.
/// No callback from the UPI app is trusted — only the user's "Yes" records
/// the payment.

/// NPCI per-transaction cap for regular P2P UPI payments.
const double kUpiMaxAmount = 100000;

/// Max length most UPI apps accept for the `tn` (note) field.
const int _kUpiNoteMaxChars = 50;

/// True when [currency] (ISO code or symbol, as GroupModel stores it) is INR.
bool isUpiCurrency(String currency) {
  final c = currency.trim().toUpperCase();
  return c == 'INR' || c == '₹';
}

/// Whether [amount] can be paid in one UPI transaction.
bool isUpiPayableAmount(double amount) => amount > 0 && amount <= kUpiMaxAmount;

/// Builds the `upi://pay` deep link. Values are percent-encoded by hand
/// (`%20`, not `+`, for spaces) because several UPI apps show a literal `+`.
String buildUpiPayUri({
  required String payeeVpa,
  required String payeeName,
  required double amount,
  required String note,
}) {
  final trimmedNote = note.characters.length > _kUpiNoteMaxChars
      ? note.characters.take(_kUpiNoteMaxChars).toString()
      : note;
  final params = <String, String>{
    'pa': payeeVpa.trim(),
    'pn': payeeName.trim(),
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    'tn': trimmedNote,
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'upi://pay?$query';
}

/// Whether this platform can hand a `upi://` link to a local UPI app.
/// Web and desktop go straight to the copy-ID / QR fallback.
bool get canLaunchUpiApps =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Opens [uri] in an external UPI app. False when no app took it (none
/// installed, or the platform refused) — callers then show the fallback.
Future<bool> launchUpiUri(String uri) async {
  if (!canLaunchUpiApps) return false;
  try {
    return await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
  } on PlatformException {
    return false;
  }
}
