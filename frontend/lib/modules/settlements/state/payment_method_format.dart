import '../../../models/settlement_model.dart';

/// Appends the payment method to a payment line — "Rahul paid you ₹500 ·
/// UPI". Unchanged when no method was recorded (older payments), so we
/// never show a guessed method.
String withPaymentMethod(String text, SettlementMethod? method) =>
    method == null ? text : '$text · ${method.label}';
