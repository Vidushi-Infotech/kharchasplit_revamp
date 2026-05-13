---
name: flutter-screen
description: Use when creating ONE new Flutter screen file (not a whole module) and the user wants the project's standard 3-breakpoint responsive layout with loading/error/empty handling (e.g. "build a screen that shows X", "add a settings page", "create a screen for invite-link sharing"). Produces a ConsumerStatefulWidget under frontend/lib/modules/<existing-module>/screens/ that obeys frontend/CLAUDE.md (compact <600, standard 600–1100, large >1100; <300 lines; Riverpod; const everywhere; controllers disposed).
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Build a responsive Flutter screen

For a brand-new feature use the `flutter-module` skill (it also scaffolds state, widgets, and the route). Use THIS skill when you're adding one more screen to a module that already exists — e.g. `expenses/screens/expense_detail_screen.dart` already exists and you need to add `expense_split_audit_screen.dart`.

## The three layouts — width-based, not device-based

```
< 600 px       → Compact   bottom-nav era spacing, padding 16-20, single column
600 - 1100 px  → Standard  sidebar/centered, padding 24-32, maxWidth ~720
> 1100 px      → Large     sidebar + spacious, padding 32-48, maxWidth ~1080, multi-column allowed
```

This rule is mandatory per [frontend/CLAUDE.md](frontend/CLAUDE.md). Even tablets and foldables in compact mode hit `<600`, so device detection (`Platform.isIOS`) is the wrong primitive.

## Required structure

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final screenWidth = MediaQuery.of(context).size.width;

  if (screenWidth < 600) return _buildCompactLayout(isDark);
  if (screenWidth < 1100) return _buildStandardLayout(isDark);
  return _buildLargeLayout(isDark);
}
```

Each `_build*Layout` returns a `Scaffold`. Body work is delegated to a `_buildBody(...)` that all three layouts share — only `padding` and `maxWidth` differ.

## Required states

`asyncValue.when(...)` must cover all three:

```dart
asyncValue.when(
  loading: () => const ShimmerList(itemCount: 6),
  error: (err, _) => ErrorStateWidget(message: err.toString(), onRetry: ...),
  data: (items) => items.isEmpty
      ? const EmptyStateWidget(icon: ..., title: ..., message: ...)
      : ListView.builder(...),
);
```

Reusable widgets to use (already exist in this codebase):

- `frontend/lib/components/loaders/shimmer_list.dart` → `ShimmerList`
- `frontend/lib/components/states/error_state_widget.dart` → `ErrorStateWidget`
- `frontend/lib/components/states/empty_state_widget.dart` → `EmptyStateWidget`
- `frontend/lib/components/cards/...` for cards
- `frontend/lib/components/inputs/app_text_field.dart` for forms

Do NOT roll your own loader/error/empty — those four files are the canonical versions and tweaking them tweaks them everywhere.

## Step-by-step

1. **Decide which module owns the screen.** It must live under `frontend/lib/modules/<module>/screens/`.
2. **Pick the right Consumer base class:**
   - `ConsumerWidget` → no controllers, no local state
   - `ConsumerStatefulWidget` → has controllers (text fields, scroll, animation) or local state that doesn't belong in a provider
3. **Copy `templates/responsive_screen.template.dart`** to your destination path and replace the placeholders.
4. **Wire up a `GoRoute`** in [frontend/lib/core/routing/app_router.dart](frontend/lib/core/routing/app_router.dart). Detail screens go OUTSIDE the `ShellRoute` block; tab-level screens go inside.
5. **`flutter analyze`** to confirm.
6. **Hot-restart and test all three widths** — drag the desktop window or use Chrome devtools' responsive mode. Verify:
   - Compact: bottom nav visible, single column, padding ~16
   - Standard: sidebar visible, content centered, padding ~24
   - Large: sidebar visible, generous spacing, content clamped to readable width

## Common mistakes — refuse to commit any of these

| ❌ Wrong                                          | ✅ Correct                                           |
|--------------------------------------------------|-----------------------------------------------------|
| One layout that "looks fine" on all widths       | Three explicit `_build*Layout` methods               |
| `Theme.of(context).brightness == Brightness.dark` computed inside child widgets | Compute once in `build`, pass `isDark` down |
| `MediaQuery.of(context).size.width` recomputed in every helper | Compute once and pass it down (or use LayoutBuilder) |
| `Container(width: 360, ...)` in a body              | `ConstrainedBox(constraints: BoxConstraints(maxWidth: 720))` |
| `FutureBuilder` for async loading                 | Riverpod `AsyncValue.when`                          |
| Missing `dispose` for controllers                 | `controller.dispose()` in `dispose` override        |
| Title text built inline 6 times                    | Lift to `AppTextStyles.titleMedium(isDark)`         |
| `Image.network(...)` in a list                    | `CachedNetworkImage`                                |

See `templates/responsive_screen.template.dart` for a complete file you can copy.
