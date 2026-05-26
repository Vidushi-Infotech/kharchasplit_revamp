# Example — adding a "budgets" module

Walk through what gets created end-to-end. This mirrors how the `expenses`, `activity`, and `friends` modules are organized in this repo.

## Goal

Show monthly spending vs. a budget per group. Top-level destination under `/home/budgets`.

## Files created / changed

```
frontend/lib/
├── models/
│   └── budget_model.dart                              [NEW]
├── data/
│   └── budgets/
│       └── budgets_repository.dart                    [NEW — use api-repository skill]
├── modules/
│   └── budgets/                                       [NEW MODULE]
│       ├── screens/
│       │   └── budgets_screen.dart
│       ├── widgets/
│       │   └── budget_card_widget.dart
│       └── state/
│           └── budgets_provider.dart
├── core/routing/app_router.dart                       [EDIT — add GoRoute]
└── layouts/shell/
    ├── mobile_shell.dart                              [EDIT — add nav entry]
    ├── tablet_shell.dart                              [EDIT]
    └── web_shell.dart                                 [EDIT]
```

## 1. Model — `frontend/lib/models/budget_model.dart`

Uses Equatable + a `fromJson` factory that handles both snake_case (backend) and camelCase variants — same pattern as [frontend/lib/models/expense_model.dart](frontend/lib/models/expense_model.dart).

```dart
import 'package:equatable/equatable.dart';

class BudgetModel extends Equatable {
  const BudgetModel({
    required this.groupId,
    required this.month,
    required this.limit,
    required this.spent,
  });

  final String groupId;
  final DateTime month;
  final double limit;
  final double spent;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    double parse(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return BudgetModel(
      groupId: (json['groupId'] ?? json['group_id']) as String,
      month: DateTime.parse((json['month']) as String),
      limit: parse(json['limit']),
      spent: parse(json['spent']),
    );
  }

  double get remaining => limit - spent;
  bool get isOver => spent > limit;

  @override
  List<Object?> get props => [groupId, month, limit, spent];
}
```

## 2. Repository — invoke the `api-repository` skill

Creates `frontend/lib/data/budgets/budgets_repository.dart` with the `_ensureMap` / `_ensureList` helpers and the `budgetsRepositoryProvider`.

## 3. State — `frontend/lib/modules/budgets/state/budgets_provider.dart`

Use the `AsyncNotifierProvider` template. Watch `authProvider`.

## 4. Screen — `frontend/lib/modules/budgets/screens/budgets_screen.dart`

Use the screen template. Three layouts, `ShimmerList` while loading, `ErrorStateWidget` on error, `EmptyStateWidget` when empty.

## 5. Widget — `frontend/lib/modules/budgets/widgets/budget_card_widget.dart`

Use the widget template. Pulls colors from theme; `Theme.of(context).colorScheme.error` for `isOver == true`, `colorScheme.primary` otherwise.

## 6. Router — `frontend/lib/core/routing/app_router.dart`

Inside the `ShellRoute` block, append:

```dart
GoRoute(
  path: '/home/budgets',
  name: 'budgets',
  builder: (context, state) => const BudgetsScreen(),
),
```

Add the import alongside the others at the top of the file.

## 7. Shells — add the nav entry

In `mobile_shell.dart`, add a `BottomNavigationBarItem`:

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.pie_chart_outline),
  activeIcon: Icon(Icons.pie_chart),
  label: 'Budgets',
),
```

Update `shell_state.dart`'s index↔route mapping so tapping the new tab routes to `/home/budgets`. Mirror the entry in the tablet and web shells (those use sidebar items, not bottom nav).

## 8. Verify

```bash
cd frontend && flutter analyze
cd frontend && flutter run -d chrome      # quickest way to validate routing + 3 layouts
```

Visit `/home/budgets` — confirm the empty state renders, then plug in real data and re-test loading/error/data paths.

## What NOT to do

- Don't put `Dio` or `http` calls inside `budgets_screen.dart`. All API access goes through the repository.
- Don't render `Column(children: budgets.map(...).toList())` for the list — use `ListView.builder`.
- Don't `setState` for the budget list — that's what the `AsyncNotifierProvider` is for.
- Don't make `BudgetsScreen` work on only one screen size and leave the other two empty.
