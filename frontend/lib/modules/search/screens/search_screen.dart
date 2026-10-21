import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../state/recent_searches_provider.dart';
import '../state/search_provider.dart';
import '../widgets/search_bar_header.dart';
import '../widgets/search_body.dart';

/// Global search across expenses, groups and friends (`/search?q=`).
///
/// Compact (<600): full width, 16px gutters. Standard (600–1100): centred
/// 720px column, 24px. Large (>1100): centred 860px column, 32px — inside
/// the web shell's sidebar.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Pre-filled query (e.g. from a deep link); searched straight away.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(searchProvider.notifier).submit(q);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String q) {
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    ref.read(searchProvider.notifier).submit(q);
    ref.read(recentSearchesProvider.notifier).add(q);
  }

  void _submitted(String q) {
    ref.read(searchProvider.notifier).submit(q);
    ref.read(recentSearchesProvider.notifier).add(q);
  }

  void _clear() {
    _controller.clear();
    ref.read(searchProvider.notifier).onQueryChanged('');
    _focusNode.requestFocus();
  }

  /// A result was tapped: remember what found it, then open it.
  void _open(String route) {
    ref.read(recentSearchesProvider.notifier).add(_controller.text);
    _focusNode.unfocus();
    context.push(route);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/groups');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final (double maxWidth, double pad) = width < 600
        ? (double.infinity, 16)
        : width < 1100
        ? (720, 24)
        : (860, 32);
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                SearchBarHeader(
                  controller: _controller,
                  focusNode: _focusNode,
                  isDark: isDark,
                  horizontalPadding: pad,
                  onChanged: ref.read(searchProvider.notifier).onQueryChanged,
                  onSubmitted: _submitted,
                  onClear: _clear,
                  onBack: _back,
                ),
                Expanded(
                  child: SearchBody(
                    isDark: isDark,
                    padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
                    onPickRecent: _search,
                    onOpen: _open,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
