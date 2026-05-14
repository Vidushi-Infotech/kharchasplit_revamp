import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory notification preferences. Future work: persist to Hive or sync
/// to the backend once a notifications API exists.
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.emailEnabled = true,
    // Activity
    this.newExpense = true,
    this.groupInvite = true,
    this.paymentReceived = true,
    this.settlementReminder = true,
    this.commentMention = false,
    // Summaries
    this.weeklySummary = false,
    this.monthlySummary = false,
    // Other
    this.productUpdates = false,
    this.tipsAndOffers = false,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool newExpense;
  final bool groupInvite;
  final bool paymentReceived;
  final bool settlementReminder;
  final bool commentMention;
  final bool weeklySummary;
  final bool monthlySummary;
  final bool productUpdates;
  final bool tipsAndOffers;

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? newExpense,
    bool? groupInvite,
    bool? paymentReceived,
    bool? settlementReminder,
    bool? commentMention,
    bool? weeklySummary,
    bool? monthlySummary,
    bool? productUpdates,
    bool? tipsAndOffers,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      newExpense: newExpense ?? this.newExpense,
      groupInvite: groupInvite ?? this.groupInvite,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      settlementReminder: settlementReminder ?? this.settlementReminder,
      commentMention: commentMention ?? this.commentMention,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      monthlySummary: monthlySummary ?? this.monthlySummary,
      productUpdates: productUpdates ?? this.productUpdates,
      tipsAndOffers: tipsAndOffers ?? this.tipsAndOffers,
    );
  }
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() => const NotificationPrefs();

  void update(NotificationPrefs Function(NotificationPrefs) mutator) {
    state = mutator(state);
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);
