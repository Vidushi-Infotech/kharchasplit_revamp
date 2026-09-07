import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp straight into the chat with [phone], with [message]
/// pre-filled so the user only has to hit Send.
///
/// Order of attempts:
/// 1. `whatsapp://send?phone=…&text=…` — the app's own scheme. Lands in the
///    chat immediately, no browser, no "Continue to chat" interstitial.
///    Needs the `com.whatsapp` / `com.whatsapp.w4b` `<queries>` entries in
///    the Android manifest (package visibility, Android 11+).
/// 2. `https://wa.me/…` — universal link fallback. If WhatsApp isn't
///    installed this opens the web page, which at least offers the install.
///
/// Returns `false` only when neither could be launched.
Future<bool> openWhatsAppChat({
  required String phone,
  required String message,
}) async {
  // wa.me / whatsapp:// want the number as bare digits with country code:
  // "+91 99166-55600" → "919916655600".
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return false;
  final text = Uri.encodeComponent(message);

  final attempts = <Uri>[
    Uri.parse('whatsapp://send?phone=$digits&text=$text'),
    Uri.parse('https://wa.me/$digits?text=$text'),
  ];
  for (final uri in attempts) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (e) {
      debugPrint('[whatsapp] ${uri.scheme} launch failed: $e');
    }
  }
  return false;
}
