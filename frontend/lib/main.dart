import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Status bar: transparent background with DARK icons/text across all screens
  // so the system clock/battery read against the app's light backgrounds.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android: dark icons
      statusBarBrightness: Brightness.light, // iOS: light bg → dark content
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    const ProviderScope(
      child: KharchaSplitApp(),
    ),
  );
}

/// Main app widget wrapped in Consumer to watch theme changes
class KharchaSplitApp extends ConsumerWidget {
  const KharchaSplitApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme mode changes from Riverpod provider
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Kharcha Split',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.read(themeModeProvider.notifier).toThemeMode(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
