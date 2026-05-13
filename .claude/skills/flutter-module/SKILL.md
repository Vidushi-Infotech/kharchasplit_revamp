---
name: flutter-module
description: Use when adding a new feature module to the Flutter app under frontend/lib/modules/ (e.g. "add a budgets module", "create a notifications feature", "build the recurring-expenses screen and state"). Scaffolds the module's screens/, widgets/, state/ subfolders, a Riverpod NotifierProvider, a registered go_router route, and ties it into the appropriate shell (mobile/tablet/web). Follows the rules in frontend/CLAUDE.md.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Add a Flutter feature module

This skill scaffolds a new module in `frontend/lib/modules/<feature>/` exactly the way every other module in this app is structured. The non-negotiable rulebook lives in [frontend/CLAUDE.md](frontend/CLAUDE.md) — read it before writing UI code.

## Module folder shape (mandatory)

```
frontend/lib/modules/<feature>/
├── screens/
│   └── <feature>_screen.dart             # ConsumerStatefulWidget, 3-breakpoint, <300 lines
├── widgets/
│   └── <feature>_xyz_widget.dart         # Reusable UI blocks scoped to this module
└── state/
    └── <feature>_provider.dart           # Riverpod Notifier / AsyncNotifier / StateProvider
```

Cross-module reusable widgets live in `frontend/lib/components/<group>/` instead. Cross-module data lives in `frontend/lib/data/<resource>/<resource>_repository.dart`. Models in `frontend/lib/models/`.

## Sister files that almost always change

| File                                                           | Why                                                                    |
|----------------------------------------------------------------|------------------------------------------------------------------------|
| [frontend/lib/core/routing/app_router.dart](frontend/lib/core/routing/app_router.dart) | Add the `GoRoute` so the screen is reachable                          |
| [frontend/lib/layouts/shell/mobile_shell.dart](frontend/lib/layouts/shell/mobile_shell.dart) `/tablet_shell.dart` / `/web_shell.dart` | Add a bottom-nav / sidebar entry if it's a top-level destination     |
| [frontend/lib/models/](frontend/lib/models/)                   | If the feature has a backend resource, add the model here              |
| [frontend/lib/data/](frontend/lib/data/)                       | If the feature talks to the API, add a repository (use the `api-repository` skill) |

## Step-by-step

### 1. Confirm the module belongs as a top-level module

If it's purely UI inside an existing module, prefer adding a widget to the existing module instead of a new top-level module. Top-level modules so far:

```
auth, dashboard, expenses, groups, friends, activity, settlements, reports, profile, onboarding
```

### 2. Decide the Riverpod provider shape

| Provider type             | When to use it                                                     |
|---------------------------|--------------------------------------------------------------------|
| `StateProvider<T>`        | Simple ephemeral form state (see `add_expense_provider.dart`)      |
| `NotifierProvider`        | Sync state with explicit methods (see `auth_provider.dart`)        |
| `AsyncNotifierProvider`   | Async data with loading/error (see `activity_feed_provider.dart`)  |
| `Provider`                | Pure derived values, no internal state                             |
| family variant            | When the provider depends on an id (e.g. `groupDetailProvider(id)`)|

Riverpod 3.x is used here — `StateProvider` lives in `package:flutter_riverpod/legacy.dart`, not the main export.

### 3. Create the files from the templates in `templates/`

- `screen.template.dart` — 3-breakpoint `ConsumerStatefulWidget`, loading/error/empty, theme-aware.
- `provider.template.dart` — `AsyncNotifierProvider` skeleton that watches `authProvider` for the user.
- `widget.template.dart` — Stateless reusable widget that takes data, no business logic.

Replace `<Feature>` / `<feature>` placeholders consistently (PascalCase / snake_case).

### 4. Register the route

Open [frontend/lib/core/routing/app_router.dart](frontend/lib/core/routing/app_router.dart) and add:

- If it's an AUTHENTICATED top-level destination → add the `GoRoute` inside the `ShellRoute` block (so it gets the bottom-nav/sidebar shell).
- If it's a detail screen (no bottom nav) → add it OUTSIDE the `ShellRoute` block, like `/expense/:expenseId` and `/settle/:userId`.

```dart
GoRoute(
  path: '/home/<feature>',
  name: '<feature>',
  builder: (context, state) => const <Feature>Screen(),
),
```

Path conventions in this codebase:
- Top-level tabs live under `/home/...` (see `dashboard`, `groups`, `friends`, `activity`).
- Detail screens use `/<resource>/:id` directly (see `/expense/:expenseId`, `/settle/:userId`).
- Modals/full-screen forms use `/<action>` (see `/add-expense`).

### 5. (If top-level) wire up the nav entries

Open `mobile_shell.dart`, `tablet_shell.dart`, `web_shell.dart` and add an icon + label that routes to your new screen. Watch the `shell_state.dart` index logic so the highlighted tab matches the route.

### 6. Run the analyzer

```bash
cd frontend && flutter analyze
```

Then build to make sure nothing's missing:

```bash
cd frontend && flutter build apk --debug   # or whichever target
```

For a UI-only smoke test, hot-reload with the app running and tap into the new route.

## Non-negotiable rules (from frontend/CLAUDE.md)

These will be enforced — call them out if a user asks you to violate them:

1. **Max 300 lines per file.** Split widgets out.
2. **No business logic in screen/widget files.** Everything funnels through Riverpod providers.
3. **Three breakpoints, always.** `<600px`, `600-1100px`, `>1100px`. Width-based, NOT device-type-based.
4. **Loading / Error / Empty must all be handled** for every async view.
5. **No `setState` for app state.** Use Riverpod.
6. **`const` everything** that can be const. `ListView.builder`, not `Column(children: list.map(...))`.
7. **`CachedNetworkImage`**, never raw `Image.network` in lists.
8. **Always dispose** `TextEditingController`, `ScrollController`, `AnimationController`, `StreamSubscription`.
9. **Currency** — always go through `NumberFormat.currency(locale: 'en_IN', symbol: '₹')` or the helpers in `core/utils/currency_formatter.dart`.
10. **Theme** — never hardcode colors. Pull from `Theme.of(context).colorScheme` or `core/theme/app_colors.dart`.

## Common mistakes — refuse to commit any of these

| ❌ Wrong                                          | ✅ Correct                                         |
|--------------------------------------------------|---------------------------------------------------|
| `final controller = ...` at top of widget body   | Move to `initState`, dispose in `dispose`          |
| `if (Platform.isAndroid) ...` for layout        | Use `MediaQuery.of(context).size.width`           |
| `setState(() => count++)`                        | `ref.read(<feature>Provider.notifier).increment()`|
| `width: 300` hardcoded                            | `Expanded` / `FractionallySizedBox` / `ConstrainedBox`|
| `Column(children: list.map(...).toList())`       | `ListView.builder(itemBuilder: ...)`              |
| Importing `package:riverpod/riverpod.dart` in UI | `package:flutter_riverpod/flutter_riverpod.dart`  |
| `StateProvider` from main riverpod import        | `import 'package:flutter_riverpod/legacy.dart';`  |
| Single layout fallback                            | All three layouts must be implemented              |

See `examples.md` for a complete worked example.
