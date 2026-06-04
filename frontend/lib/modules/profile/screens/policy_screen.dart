import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../state/policy_provider.dart';

/// Generic policy viewer — fetches `GET /policies/:kind` from the backend
/// and renders the document. Used for both Privacy Policy and Terms.
class PolicyScreen extends ConsumerWidget {
  const PolicyScreen({
    super.key,
    required this.kind,
    required this.fallbackTitle,
  });

  /// One of `privacy` or `terms` (path segment of the API).
  final String kind;
  final String fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final policyAsync = ref.watch(policyProvider(kind));

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _TopBar(
        isDark: isDark,
        title: policyAsync.value?.title ?? fallbackTitle,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth < 1100 ? 720 : 840,
            ),
            child: policyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorView(
                isDark: isDark,
                message: err.toString(),
                onRetry: () => ref.invalidate(policyProvider(kind)),
              ),
              data: (doc) => _Body(doc: doc, isDark: isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.doc, required this.isDark});
  final PolicyDocument doc;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _MetaCard(doc: doc, isDark: isDark),
        const SizedBox(height: 20),
        if (doc.intro.isNotEmpty) ...[
          Text(
            doc.intro,
            style: AppTextStyles.body1(isDark).copyWith(
              color: AppColors.textPrimary(isDark),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
        ],
        ...List.generate(doc.sections.length, (i) {
          final s = doc.sections[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i == doc.sections.length - 1 ? 0 : 18),
            child: _Section(section: s, isDark: isDark),
          );
        }),
        const SizedBox(height: 24),
        Center(
          child: Text(
            doc.version.isEmpty
                ? '© KharchaSplit'
                : '© KharchaSplit · v${doc.version}',
            style: AppTextStyles.caption(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.doc, required this.isDark});
  final PolicyDocument doc;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tealDark.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tealDark.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc.title,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (doc.lastUpdatedAt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last updated · ${doc.lastUpdatedAt}',
                    style: AppTextStyles.caption(isDark).copyWith(
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.isDark});
  final PolicySection section;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.heading,
          style: AppTextStyles.body1(isDark).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(section.paragraphs.length, (i) {
          final p = section.paragraphs[i];
          return Padding(
            padding: EdgeInsets.only(
              bottom: i == section.paragraphs.length - 1 ? 0 : 8,
            ),
            child: Text(
              p,
              style: AppTextStyles.body2(isDark).copyWith(
                color: AppColors.textPrimary(isDark).withValues(alpha: 0.92),
                height: 1.5,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.isDark,
    required this.message,
    required this.onRetry,
  });
  final bool isDark;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.warning,
            ),
            const SizedBox(height: 10),
            Text(
              "Couldn't load this page",
              style: AppTextStyles.body1(isDark).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTextStyles.caption(isDark).copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.isDark,
    required this.title,
    required this.onBack,
  });

  final bool isDark;
  final String title;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background(isDark),
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Back',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg(isDark),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body1(isDark).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
