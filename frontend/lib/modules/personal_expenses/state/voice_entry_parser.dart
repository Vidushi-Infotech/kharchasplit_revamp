import '../../../models/category_model.dart';
import '../../../models/wallet_source_model.dart';

/// What a spoken entry said, for the add form to fill in and the user to
/// check: "200 rupees petrol", "kal 450 ka khana from cash", "got salary
/// 50000". Anything not heard stays null.
class VoiceDraft {
  const VoiceDraft({
    required this.transcript,
    this.amount,
    this.isIncome = false,
    this.category,
    this.description = '',
    this.daysAgo = 0,
    this.accountId,
  });

  final String transcript;
  final double? amount;
  final bool isIncome;
  final CategoryModel? category;
  final String description;

  /// 0 today, 1 yesterday, 2 the day before.
  final int daysAgo;
  final String? accountId;
}

/// Turns a transcript (English, Hindi words in Latin script, or a mix)
/// into a [VoiceDraft]. Rules, not a model: amounts in digits or words
/// ("two hundred fifty", "1.5k", "2 lakh", "5 hazaar"), a keyword per
/// category, income words, today / yesterday, and an account by name or
/// kind ("from cash", "on card", "via gpay").
abstract final class VoiceEntryParser {
  static VoiceDraft parse(
    String transcript, {
    List<WalletSource> accounts = const [],
  }) {
    var text = ' ${_normalize(transcript)} ';

    final daysAgo = _daysAgo(text);
    text = _strip(text, _dayWords.keys);

    final account = _account(text, accounts);
    if (account != null) text = _strip(text, account.$2);

    final amount = _amount(text);
    if (amount != null) text = text.replaceFirst(amount.$2, ' ');

    final isIncome = _incomeWords.any((w) => _has(text, w));
    final category = isIncome
        ? _match(text, _incomeCategories) ?? CategoryModel.otherIncome
        : _match(text, _expenseCategories);

    return VoiceDraft(
      transcript: transcript.trim(),
      amount: amount?.$1,
      isIncome: isIncome,
      category: category,
      description: _description(text, category),
      daysAgo: daysAgo,
      accountId: account?.$1,
    );
  }

  // ── Text ───────────────────────────────────────────────────────────

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('₹', ' rupees ')
      .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}${m[2]}')
      .replaceAllMapped(RegExp(r'(\d)(k)\b'), (m) => '${m[1]} k')
      .replaceAll(RegExp(r'[^a-z0-9.\s]'), ' ')
      .replaceAll(RegExp(r'\brs\b\.?'), ' rupees ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _has(String text, String phrase) => text.contains(' $phrase ');

  static String _strip(String text, Iterable<String> phrases) {
    for (final p in phrases) {
      text = text.replaceAll(' $p ', ' ');
    }
    return text;
  }

  // ── Day ────────────────────────────────────────────────────────────

  /// Longest first, so "day before yesterday" wins over "yesterday".
  static const _dayWords = {
    'day before yesterday': 2,
    'parso': 2,
    'yesterday': 1,
    'kal': 1,
    'today': 0,
    'aaj': 0,
  };

  static int _daysAgo(String text) {
    for (final e in _dayWords.entries) {
      if (_has(text, e.key)) return e.value;
    }
    return 0;
  }

  // ── Account ────────────────────────────────────────────────────────

  static const _kindWords = {
    WalletSourceType.cash: ['cash', 'nakad'],
    WalletSourceType.card: ['card', 'credit card', 'debit card'],
    WalletSourceType.wallet: ['upi', 'gpay', 'google pay', 'phonepe', 'paytm'],
    WalletSourceType.bank: ['bank', 'account', 'net banking'],
  };

  static const _via = ['from', 'by', 'via', 'using', 'with', 'on', 'se'];

  /// The account and the words that named it (to leave out of the note).
  static (String, List<String>)? _account(
    String text,
    List<WalletSource> accounts,
  ) {
    if (accounts.isEmpty) return null;
    // By name first ("from hdfc"), then by kind ("by card").
    for (final a in accounts) {
      final name = _normalize(a.name);
      if (name.isNotEmpty && _has(text, name)) {
        return (a.id, [for (final v in _via) '$v $name', name]);
      }
    }
    for (final e in _kindWords.entries) {
      final match = accounts.where((a) => a.type == e.key).firstOrNull;
      if (match == null) continue;
      for (final w in e.value) {
        if (_has(text, w)) {
          return (match.id, [for (final v in _via) '$v $w', w]);
        }
      }
    }
    return null;
  }

  // ── Amount ─────────────────────────────────────────────────────────

  static const _units = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    // Hindi; not "a" / "do", which are everyday English words.
    'ek': 1, 'teen': 3, 'char': 4, 'paanch': 5, 'dedh': 1.5, 'dhai': 2.5,
  };

  static const _scales = {
    'hundred': 100,
    'sau': 100,
    'k': 1000,
    'thousand': 1000,
    'hazaar': 1000,
    'hazar': 1000,
    'lakh': 100000,
    'lac': 100000,
    'lakhs': 100000,
    'crore': 10000000,
  };

  static const _currency = ['rupees', 'rupee', 'rupaye', 'rupay', 'inr'];

  /// The amount and the exact text it was read from. Digits with an
  /// optional scale ("1.5 k", "2 lakh") or number words; the one next to
  /// a currency word wins when there are several.
  static (double, String)? _amount(String text) {
    final number = '(?:\\d+(?:\\.\\d+)?|${_units.keys.join('|')})';
    final scale = '(?:${_scales.keys.join('|')})';
    final re = RegExp(
      '(?<= )((?:$number|$scale)(?: (?:and )?(?:$number|$scale))*)'
      '(?: (?:${_currency.join('|')}))?(?= )',
    );
    (double, String)? best;
    for (final m in re.allMatches(text)) {
      final value = _value(m[1]!);
      if (value == null || value <= 0) continue;
      final withCurrency = _currency.any(
        (c) => m[0]!.endsWith(' $c') || text.contains(' $c ${m[1]} '),
      );
      if (best == null || withCurrency) {
        best = (value, m[0]!);
        if (withCurrency) break;
      }
    }
    return best;
  }

  /// "two hundred fifty" → 250, "1.5 k" → 1500, "one lakh fifty thousand"
  /// → 150000. Null when it isn't a number ("a" alone).
  static double? _value(String phrase) {
    double total = 0, current = 0;
    var sawNumber = false;
    for (final w in phrase.split(' ')) {
      if (w == 'and') continue;
      final n = double.tryParse(w) ?? _units[w]?.toDouble();
      if (n != null) {
        current += n;
        sawNumber = true;
        continue;
      }
      final s = _scales[w];
      if (s == null) return null;
      if (current == 0) current = 1;
      if (s == 100) {
        current *= s;
      } else {
        total += current * s;
        current = 0;
      }
    }
    if (!sawNumber) return null;
    return total + current;
  }

  // ── Kind and category ──────────────────────────────────────────────

  static const _incomeWords = [
    'salary',
    'received',
    'got paid',
    'credited',
    'earned',
    'income',
    'refund',
    'cashback',
    'mila',
    'mile',
    'tankha',
    'freelance',
    'interest',
  ];

  static final _incomeCategories = {
    CategoryModel.salary: ['salary', 'tankha'],
    CategoryModel.freelance: ['freelance', 'client', 'project'],
    CategoryModel.refund: ['refund', 'cashback', 'return'],
    CategoryModel.interest: ['interest', 'fd', 'dividend'],
    CategoryModel.business: ['business', 'sale', 'shop'],
    CategoryModel.giftReceived: ['gift', 'shagun'],
  };

  static final _expenseCategories = {
    CategoryModel.fuel: ['petrol', 'diesel', 'fuel', 'cng'],
    CategoryModel.food: [
      'food',
      'lunch',
      'dinner',
      'breakfast',
      'khana',
      'chai',
      'tea',
      'coffee',
      'snacks',
      'swiggy',
      'zomato',
      'groceries',
      'grocery',
      'sabzi',
      'restaurant',
      'pizza',
      'biryani',
    ],
    CategoryModel.travel: [
      'uber',
      'ola',
      'rapido',
      'auto',
      'cab',
      'taxi',
      'bus',
      'train',
      'metro',
      'flight',
      'ticket',
      'travel',
    ],
    CategoryModel.accommodation: ['rent', 'hotel', 'kiraya', 'pg', 'stay'],
    CategoryModel.entertainment: [
      'movie',
      'netflix',
      'spotify',
      'hotstar',
      'prime',
      'game',
      'concert',
    ],
    CategoryModel.shopping: [
      'amazon',
      'flipkart',
      'myntra',
      'clothes',
      'shoes',
      'shopping',
      'kapde',
    ],
    CategoryModel.utilities: [
      'electricity',
      'bijli',
      'water',
      'gas',
      'wifi',
      'internet',
      'recharge',
      'mobile',
      'bill',
      'dth',
    ],
    CategoryModel.medical: [
      'doctor',
      'medicine',
      'medicines',
      'dawai',
      'hospital',
      'pharmacy',
      'chemist',
    ],
    CategoryModel.education: [
      'school',
      'fees',
      'fee',
      'course',
      'books',
      'tuition',
    ],
    CategoryModel.gifts: ['gift', 'present'],
    CategoryModel.work: ['office', 'work', 'laptop'],
  };

  static CategoryModel? _match(
    String text,
    Map<CategoryModel, List<String>> map,
  ) {
    for (final e in map.entries) {
      // Plurals too: "pizzas", "medicines", "tickets".
      if (e.value.any((w) => _has(text, w) || _has(text, '${w}s'))) {
        return e.key;
      }
    }
    return null;
  }

  // ── Note ───────────────────────────────────────────────────────────

  static const _filler = {
    'spent',
    'spend',
    'paid',
    'pay',
    'for',
    'on',
    'of',
    'the',
    'a',
    'an',
    'to',
    'at',
    'in',
    'my',
    'i',
    'and',
    'ka',
    'ki',
    'ke',
    'ko',
    'mein',
    'me',
    'kharcha',
    'kharch',
    'diye',
    'diya',
    'kiya',
    'liye',
    'liya',
    'add',
    'expense',
    'got',
    'received',
    'credited',
    'earned',
    'mila',
    'mile',
    'from',
    'by',
    'via',
    'using',
    'with',
    'se',
    'rupees',
    'rupee',
    'rupaye',
    'rupay',
    'inr',
    'aaya',
    'aaye',
    'hai',
    'tha',
    'was',
  };

  /// What's left after the amount, day, account and filler words, as a
  /// short note ("Petrol", "Khana at office"); the category's name when
  /// nothing is left.
  static String _description(String text, CategoryModel? category) {
    final words = text
        .split(' ')
        .where((w) => w.isNotEmpty && !_filler.contains(w))
        .toList();
    if (words.isEmpty) return category?.name ?? '';
    final note = words.join(' ');
    return note[0].toUpperCase() + note.substring(1);
  }
}
