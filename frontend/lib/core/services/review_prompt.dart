import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// Asks for a store rating at a good moment: right after something worked
/// (an expense saved, a payment recorded), once the user has come back to
/// the app over a few days.
///
/// It shows the store's own rating card straight away, with no "Do you like
/// the app?" question first: both stores forbid asking that before the card.
/// The OS decides whether the card really appears (iOS: at most 3 times a
/// year), so this only keeps us from asking too early or too often.
class ReviewPrompt {
  ReviewPrompt._();
  static final ReviewPrompt instance = ReviewPrompt._();

  /// The App Store id, for "Rate KharchaSplit" on iOS.
  static const appStoreId = '6754237285';

  static const minWins = 3;
  static const minAge = Duration(days: 3);
  static const cooldown = Duration(days: 120);
  static const maxAsks = 3;

  static const _kWins = 'review_wins';
  static const _kFirstWinMs = 'review_first_win_ms';
  static const _kLastAskedMs = 'review_last_asked_ms';
  static const _kAsks = 'review_asks';

  bool _busy = false;

  /// Something the user set out to do just worked. Counts it and, when the
  /// time is right, shows the rating card a moment later (after the
  /// screen has closed and its message is up).
  Future<void> recordWin() async {
    if (kIsWeb || _busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final wins = (prefs.getInt(_kWins) ?? 0) + 1;
      await prefs.setInt(_kWins, wins);
      final firstMs = prefs.getInt(_kFirstWinMs);
      if (firstMs == null) {
        await prefs.setInt(_kFirstWinMs, now.millisecondsSinceEpoch);
      }
      final lastMs = prefs.getInt(_kLastAskedMs);
      final asks = prefs.getInt(_kAsks) ?? 0;
      if (!shouldAsk(
        wins: wins,
        firstWin: firstMs == null
            ? now
            : DateTime.fromMillisecondsSinceEpoch(firstMs),
        lastAsked: lastMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastMs),
        asks: asks,
        now: now,
      )) {
        return;
      }
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await review.requestReview();
      await prefs.setInt(_kLastAskedMs, now.millisecondsSinceEpoch);
      await prefs.setInt(_kAsks, asks + 1);
    } catch (e) {
      AppLogger.warn('Review prompt skipped', tag: 'ReviewPrompt', error: e);
    } finally {
      _busy = false;
    }
  }

  /// Opens the app's store page (from "Rate KharchaSplit" in Account).
  Future<void> openStorePage() =>
      InAppReview.instance.openStoreListing(appStoreId: appStoreId);

  /// Whether now is a good time to ask.
  @visibleForTesting
  static bool shouldAsk({
    required int wins,
    required DateTime firstWin,
    required DateTime? lastAsked,
    required int asks,
    required DateTime now,
  }) {
    if (wins < minWins || asks >= maxAsks) return false;
    if (now.difference(firstWin) < minAge) return false;
    return lastAsked == null || now.difference(lastAsked) >= cooldown;
  }
}
