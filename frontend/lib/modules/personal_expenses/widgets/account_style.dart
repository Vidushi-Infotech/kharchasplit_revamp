import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/wallet_source_model.dart';

/// How each kind of account looks: its icon and name.
extension AccountTypeStyle on WalletSourceType {
  IconData get icon => switch (this) {
    WalletSourceType.cash => Icons.payments_rounded,
    WalletSourceType.bank => Icons.account_balance_rounded,
    WalletSourceType.card => Icons.credit_card_rounded,
    WalletSourceType.wallet => Icons.account_balance_wallet_rounded,
  };

  String get label => switch (this) {
    WalletSourceType.cash => AppStrings.accountCash,
    WalletSourceType.bank => AppStrings.accountBank,
    WalletSourceType.card => AppStrings.accountCard,
    WalletSourceType.wallet => AppStrings.accountWallet,
  };
}

/// A balance as people read it: a card that's owed shows "₹X due".
String accountBalanceText(WalletSource s) =>
    s.type == WalletSourceType.card && s.balance < 0
    ? '${CurrencyFormatter.format(-s.balance, currency: '₹')} ${AppStrings.accountDue}'
    : CurrencyFormatter.format(s.balance, currency: '₹');
