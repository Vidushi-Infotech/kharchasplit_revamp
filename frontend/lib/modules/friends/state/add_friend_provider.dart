import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/users/users_repository.dart';
import '../../groups/state/registered_users_provider.dart';
import 'friend_detail_provider.dart';
import 'friends_provider.dart';

export '../../../data/users/users_repository.dart' show PhoneLookupResult;

/// Same store links as the group invite sheet (member_actions_sheet.dart)
/// and the update prompt (app_version_repository.dart).
const _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.kharchasplit';
const _kAppStoreUrl = 'https://apps.apple.com/in/app/kharchasplit/id6754237285';

/// Text shared by the "Invite" button when the number isn't registered.
const String addFriendInviteText =
    '${AppStrings.inviteFriendMessage}\n\n'
    'Android: $_kPlayStoreUrl\n'
    'iOS: $_kAppStoreUrl';

enum AddFriendStatus { idle, looking, found, self, notFound, error, adding }

class AddFriendState {
  const AddFriendState({
    this.status = AddFriendStatus.idle,
    this.digits = '',
    this.result,
    this.error,
  });

  final AddFriendStatus status;

  /// The 10-digit number last looked up.
  final String digits;

  /// The registered user for [digits] (found / self / adding).
  final PhoneLookupResult? result;

  /// Message for [AddFriendStatus.error] (rate limit, network, server).
  final String? error;

  bool get busy =>
      status == AddFriendStatus.looking || status == AddFriendStatus.adding;
}

/// The "Add friend" sheet: phone lookup, then get-or-create the non-group
/// group with that person so they appear on the Friends tab.
final addFriendControllerProvider =
    NotifierProvider.autoDispose<AddFriendController, AddFriendState>(
      AddFriendController.new,
    );

class AddFriendController extends Notifier<AddFriendState> {
  @override
  AddFriendState build() => const AddFriendState();

  /// Back to the input state (e.g. the number was edited).
  void reset() => state = const AddFriendState();

  /// Looks up [raw] (any format; reduced to the last 10 digits). The lookup
  /// is rate-limited server-side (30/hour), so the UI only calls this on an
  /// explicit Find / contact pick, never per keystroke.
  Future<void> lookup(String raw) async {
    final digits = normalizePhone(raw);
    if (digits.length != 10) {
      state = AddFriendState(
        status: AddFriendStatus.error,
        digits: digits,
        error: AppStrings.enterTenDigitNumber,
      );
      return;
    }
    state = AddFriendState(status: AddFriendStatus.looking, digits: digits);
    try {
      final hit = await ref.read(usersRepositoryProvider).lookupByPhone(digits);
      if (!ref.mounted || state.digits != digits) return;
      state = AddFriendState(
        status: hit == null
            ? AddFriendStatus.notFound
            : (hit.isSelf ? AddFriendStatus.self : AddFriendStatus.found),
        digits: digits,
        result: hit,
      );
    } on UsersApiException catch (e) {
      if (!ref.mounted || state.digits != digits) return;
      state = AddFriendState(
        status: AddFriendStatus.error,
        digits: digits,
        error: e.statusCode == 429
            ? AppStrings.tooManySearches
            : AppStrings.lookupFailed,
      );
    } catch (_) {
      if (!ref.mounted || state.digits != digits) return;
      state = AddFriendState(
        status: AddFriendStatus.error,
        digits: digits,
        error: AppStrings.lookupFailed,
      );
    }
  }

  /// Adds the found user as a friend (unless they already are one):
  /// get-or-create the non-group group, then refresh the Friends list so the detail screen finds them. Returns
  /// the friend's user id, or null on failure (state carries the message).
  Future<String?> add() async {
    final hit = state.result;
    if (hit == null || state.status != AddFriendStatus.found) return null;
    final digits = state.digits;
    state = AddFriendState(
      status: AddFriendStatus.adding,
      digits: digits,
      result: hit,
    );
    try {
      // Already a friend (a shared group or an earlier add): just open them.
      if (ref.read(friendByIdProvider(hit.id)).value != null) return hit.id;
      final actions = ref.read(friendActionsProvider);
      await actions.directGroupFor(hit.id);
      await actions.refresh(hit.id);
      return hit.id;
    } catch (e) {
      if (ref.mounted) {
        state = AddFriendState(
          status: AddFriendStatus.found,
          digits: digits,
          result: hit,
          error: '$e',
        );
      }
      return null;
    }
  }
}
