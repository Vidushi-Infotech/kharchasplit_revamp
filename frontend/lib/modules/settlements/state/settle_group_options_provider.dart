import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/group_model.dart';
import '../../groups/state/group_detail_provider.dart';
import '../../groups/state/groups_provider.dart';

/// Groups the Record payment screen offers for paying [recipientId]: every
/// group in the groups list that they're in, plus [initialGroupId] when
/// it's not one of them — the hidden non-group ("direct") group with that
/// friend is never in [groupsProvider], so it's resolved from its detail.
///
/// Empty until the groups list has loaded, so the dropdown never swaps one
/// instance of a group for another (it requires its value to be one of the
/// items).
final settleGroupOptionsProvider = Provider.autoDispose
    .family<List<GroupModel>, ({String recipientId, String? initialGroupId})>((
      ref,
      args,
    ) {
      final groups = ref.watch(groupsProvider).value;
      if (groups == null) return const [];
      bool hasRecipient(GroupModel g) =>
          g.members.any((m) => m.id == args.recipientId);
      final options = groups.where(hasRecipient).toList();
      final initialId = args.initialGroupId;
      if (initialId != null && !groups.any((g) => g.id == initialId)) {
        final extra = ref.watch(groupDetailProvider(initialId)).value?.group;
        if (extra != null && hasRecipient(extra)) options.insert(0, extra);
      }
      return options;
    });
