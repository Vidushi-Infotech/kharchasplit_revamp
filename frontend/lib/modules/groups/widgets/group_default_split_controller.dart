import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/groups/groups_repository.dart';
import '../../../models/group_model.dart';
import '../state/group_detail_provider.dart';
import '../state/groups_provider.dart';

/// 'percentage' or 'shares' — the two kinds of default split the server
/// accepts (PUT /groups/:id/default-split).
enum DefaultSplitType {
  percentage('percentage'),
  shares('shares');

  const DefaultSplitType(this.wire);
  final String wire;
}

/// Starting values for the editor: the group's saved default split, else
/// an equal one (percentages that add up to exactly 100, or 1 share each).
/// Members missing from a saved split start at 0.
({DefaultSplitType type, Map<String, double> values}) initialDefaultSplit(
  GroupModel group,
  List<String> memberIds,
) {
  final saved = group.defaultSplit;
  if (saved != null) {
    final type = saved['type'] == 'shares'
        ? DefaultSplitType.shares
        : DefaultSplitType.percentage;
    final raw = saved['values'] is Map ? saved['values'] as Map : const {};
    return (
      type: type,
      values: {
        for (final id in memberIds)
          id: raw[id] is num ? (raw[id] as num).toDouble() : 0,
      },
    );
  }
  return (
    type: DefaultSplitType.percentage,
    values: equalValues(DefaultSplitType.percentage, memberIds),
  );
}

/// Equal values for [type]: 1 share each, or percentages rounded to 2
/// decimals with the rounding remainder on the last person.
Map<String, double> equalValues(DefaultSplitType type, List<String> ids) {
  if (ids.isEmpty) return {};
  if (type == DefaultSplitType.shares) return {for (final id in ids) id: 1};
  final each = (10000 / ids.length).floor() / 100;
  final last = ((100 - each * (ids.length - 1)) * 100).round() / 100;
  return {
    for (var i = 0; i < ids.length; i++)
      ids[i]: i == ids.length - 1 ? last : each,
  };
}

double defaultSplitTotal(Map<String, double> values) =>
    values.values.fold(0, (s, v) => s + v);

/// Why [values] can't be saved yet, or null when they can.
String? defaultSplitError(DefaultSplitType type, Map<String, double> values) {
  final total = defaultSplitTotal(values);
  if (type == DefaultSplitType.percentage) {
    return (total * 100).round() == 10000
        ? null
        : AppStrings.percentagesMustTotal100;
  }
  return total > 0 ? null : AppStrings.sharesMustBePositive;
}

/// Saves (or clears, with null [values]) the group's default split and
/// refetches the group. Returns a user-facing error, or null on success.
Future<String?> saveDefaultSplit(
  WidgetRef ref,
  String groupId, {
  DefaultSplitType? type,
  Map<String, double>? values,
}) async {
  try {
    await ref.read(groupsRepositoryProvider).setDefaultSplit(
          groupId,
          values == null || type == null
              ? null
              : {'type': type.wire, 'values': values},
        );
  } on GroupsApiException catch (e) {
    // 403 non-admin, 400 bad total / not a member — readable as is.
    return e.message;
  } catch (e) {
    return 'Could not save the default split: $e';
  }
  ref.invalidate(groupDetailProvider(groupId));
  ref.invalidate(groupsProvider);
  return null;
}
