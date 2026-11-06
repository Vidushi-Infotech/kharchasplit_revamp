import 'dart:async';

import '../../../models/models.dart';

/// Auto category for the Add expense form: a local keyword map first, then
/// the server's "what you used last time for this description" (user
/// history wins). Only ever maps to categories that exist in
/// [CategoryModel.all].

/// Whole-word keywords per category, checked in this order — so "dinner at
/// the hotel" is food, not accommodation.
final List<(RegExp, CategoryModel)> _keywordRules = [
  (
    _words(
      'swiggy|zomato|restaurants?|dinner|lunch|breakfast|cafe|coffee|tea|'
      'pizza|burger|biryani|snacks?|food|dominos|kfc|mcdonalds?|eatsure',
    ),
    CategoryModel.food,
  ),
  (_words('petrol|diesel|fuel|cng'), CategoryModel.fuel),
  (
    _words(
      'uber|ola|rapido|cab|taxi|auto|rickshaw|metro|bus|train|irctc|'
      'flights?|airport|toll|parking',
    ),
    CategoryModel.travel,
  ),
  (_words('rent|hotel|airbnb|oyo|hostel|pg|stay'), CategoryModel.accommodation),
  (
    _words(
      'electricity|wifi|wi-fi|internet|broadband|recharge|dth|lpg|cylinder|'
      'water bill|gas bill|phone bill|mobile bill|maintenance',
    ),
    CategoryModel.utilities,
  ),
  (
    _words(
      'movies?|netflix|hotstar|prime video|spotify|cinema|pvr|inox|'
      'bookmyshow|concert|party',
    ),
    CategoryModel.entertainment,
  ),
  (
    _words(
      'grocery|groceries|blinkit|zepto|bigbasket|instamart|dmart|vegetables|'
      'amazon|flipkart|myntra|shopping',
    ),
    CategoryModel.shopping,
  ),
  (
    _words('medicines?|pharmacy|chemist|doctor|hospital|clinic|apollo'),
    CategoryModel.medical,
  ),
];

RegExp _words(String alternatives) =>
    RegExp('\\b($alternatives)\\b', caseSensitive: false);

/// Category the description's keywords point to, or null.
CategoryModel? categoryFromKeywords(String description) {
  for (final (pattern, category) in _keywordRules) {
    if (pattern.hasMatch(description)) return category;
  }
  return null;
}

/// A server category id as a known [CategoryModel], or null for an unknown
/// id ([CategoryModel.fromId] would turn it into "Other").
CategoryModel? knownCategory(String? id) {
  if (id == null) return null;
  for (final c in CategoryModel.all) {
    if (c.id == id) return c;
  }
  return null;
}

/// Debounced suggester driven by the title field. [apply] is called with
/// each suggestion (keyword match at once, then the server's, which wins);
/// it decides whether the form may still take it (the user hasn't picked a
/// category by hand). Responses for an older description are dropped.
class CategoryAutoSuggester {
  CategoryAutoSuggester({required this.fetchRemote, required this.apply});

  final Future<String?> Function(String description) fetchRemote;
  final void Function(CategoryModel category) apply;

  static const debounce = Duration(milliseconds: 400);
  Timer? _timer;
  int _generation = 0;

  void onDescriptionChanged(String value) {
    _timer?.cancel();
    final generation = ++_generation;
    final text = value.trim();
    if (text.length < 2) return;
    _timer = Timer(debounce, () async {
      final local = categoryFromKeywords(text);
      if (local != null) apply(local);
      final remote = knownCategory(await fetchRemote(text));
      if (remote != null && generation == _generation) apply(remote);
    });
  }

  void dispose() {
    _timer?.cancel();
    _generation++;
  }
}
