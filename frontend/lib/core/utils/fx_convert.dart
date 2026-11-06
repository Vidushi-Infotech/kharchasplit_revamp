/// Currency conversion maths, exact in paise. Mirrors the server
/// (backend/src/utils/fxConvert.js) so the "≈ ₹8,312.35" preview shows the
/// amount the server will store, and converts a saved expense's parts back
/// into the currency it was entered in for editing. Pure Dart.
class FxConvert {
  FxConvert._();

  /// [paise] of the original currency at [rate] (1 original = rate group
  /// currency) → group-currency paise, rounded once.
  static int totalPaise(int paise, double rate) => (paise * rate).round();

  /// Group-currency parts for original-currency [parts] (largest remainder,
  /// ties to the earlier part), adding up to exactly [totalPaise] — what
  /// the server stores for payers and split shares.
  static List<int> partsPaise(List<int> parts, double rate, int totalPaise) =>
      _largestRemainder([for (final p in parts) p * rate], totalPaise);

  /// Editing a converted expense: its stored parts (group-currency paise)
  /// back in the original currency, in proportion, adding up to exactly
  /// [originalTotalPaise] (largest remainder, like [partsPaise]).
  static List<int> backToOriginal(
    List<int> groupParts,
    int originalTotalPaise,
  ) {
    final sum = groupParts.fold<int>(0, (s, p) => s + (p > 0 ? p : 0));
    if (sum <= 0) return [for (final _ in groupParts) 0];
    return _largestRemainder(
      [for (final p in groupParts) p > 0 ? p * originalTotalPaise / sum : 0.0],
      originalTotalPaise,
      epsilon: 1e-9,
    );
  }

  /// Floors [exact], then hands out the paise still missing to the parts
  /// with the largest fractions (ties: the earlier part); takes from the
  /// smallest fractions when the floors overshoot.
  /// [epsilon] keeps 4999.9999… (double noise) from flooring to 4999; 0
  /// for [partsPaise], which must floor exactly like the server.
  static List<int> _largestRemainder(
    List<double> exact,
    int totalPaise, {
    double epsilon = 0,
  }) {
    if (exact.isEmpty) return const [];
    final out = [for (final v in exact) (v + epsilon).floor()];
    var left = totalPaise - out.fold<int>(0, (s, v) => s + v);
    double frac(int i) => exact[i] - out[i];
    final order = List.generate(exact.length, (i) => i)
      ..sort((a, b) {
        final c = frac(b).compareTo(frac(a));
        return c != 0 ? c : a.compareTo(b);
      });
    for (var k = 0; left > 0; k = (k + 1) % order.length, left--) {
      out[order[k]]++;
    }
    for (
      var k = order.length - 1;
      left < 0;
      k = (k - 1 + order.length) % order.length, left++
    ) {
      out[order[k]]--;
    }
    return out;
  }
}
