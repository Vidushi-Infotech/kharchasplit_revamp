import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_version/app_version_repository.dart';

/// Feature names the backend has switched on (GET /app-version → features).
///
/// Fetched once per app session. Any failure yields an empty set, so a
/// feature stays hidden unless the server explicitly enables it.
final featureFlagsProvider = FutureProvider<Set<String>>((ref) async {
  final config = await ref.read(appVersionRepositoryProvider).fetch();
  return config?.features ?? const <String>{};
});

/// Whether [name] is enabled. False while loading or on error.
bool isFeatureEnabled(Ref ref, String name) =>
    ref.watch(featureFlagsProvider).value?.contains(name) ?? false;

/// Widget-side variant of [isFeatureEnabled].
bool watchFeature(WidgetRef ref, String name) =>
    ref.watch(featureFlagsProvider).value?.contains(name) ?? false;
