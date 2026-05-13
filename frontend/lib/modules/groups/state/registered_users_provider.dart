import 'package:flutter_riverpod/flutter_riverpod.dart';

String normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

final registeredPhonesProvider = Provider<Set<String>>((ref) {
  return const {
    '7814024046',
    '8888874612',
    '9158899181',
  };
});
