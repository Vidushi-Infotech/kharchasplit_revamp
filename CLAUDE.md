# Flutter UI Master Prompt — Rules Claude Code Must Always Follow

> ⚠️ These are **non-negotiable rules**. Follow every point in every response. Never skip or simplify these guidelines.

---

## 1. Folder Structure (Always Use This)

```
lib/
├── core/
│   ├── theme/
│   ├── constants/
│   └── responsive/
├── presentation/
│   ├── screens/
│   ├── widgets/
│   ├── layouts/
│   └── state/
├── components/
│   ├── buttons/
│   ├── cards/
│   ├── dialogs/
│   └── loaders/
├── modules/
│   ├── auth/
│   ├── dashboard/
│   ├── expenses/
│   ├── groups/
│   ├── settlements/
│   ├── reports/
│   └── profile/
└── layouts/
    ├── mobile/
    ├── tablet/
    └── web/
```

### Module Structure (Each Module)
```
modules/
└── expenses/
    ├── screens/
    ├── widgets/
    └── state/
```

---

## 2. Architecture Rules

- **Screens** → Full pages only
- **Widgets** → Reusable UI blocks
- **Components** → Shared elements used across modules
- **Max file length: 300 lines** — split into smaller widgets if exceeded
- **Never put business logic inside UI/screen files**

### ❌ Wrong
```dart
onPressed() {
  api.login(); // business logic in UI
}
```

### ✅ Correct
```dart
onPressed() {
  ref.read(loginController).login();
}
```

---

## 3. State Management — Always Use Riverpod

| Option   | When to Use  |
|----------|--------------|
| Provider | Small apps   |
| Bloc     | Enterprise   |
| **Riverpod** | **Default choice** |

- Never use `setState` for app-level state
- Create dedicated providers per module:
  ```
  authProvider
  expenseProvider
  groupProvider
  reportProvider
  ```

---

## 4. Navigation — Always Use `go_router`

```yaml
dependencies:
  go_router: latest
```

Example routes:
```
/
/login
/dashboard
/groups
/groups/:groupId
/expenses
/expense/:id
/reports
/profile
```

Benefits: Deep linking, web URL support, route guards.

---

## 5. Responsive Layout — Always Handle 3 Breakpoints

| Device      | Width       | Layout              |
|-------------|-------------|---------------------|
| Mobile      | < 600px     | Bottom navigation   |
| Tablet      | 600–1100px  | Side navigation     |
| Desktop/Web | > 1100px    | Sidebar + content   |

```dart
if (width < 600) {
  return MobileLayout();
} else if (width < 1100) {
  return TabletLayout();
} else {
  return WebLayout();
}
```

**Never use fixed widths.** Always use:
- `MediaQuery.of(context).size.width * 0.x`
- `Expanded` / `Flexible` / `FractionallySizedBox`

---

## 6. Widget Performance Rules

### Always Use `const` Widgets
```dart
// ❌ Wrong
Text("Hello")

// ✅ Correct
const Text("Hello")
```

### Always Use Lazy List Builders
```dart
// ❌ Wrong — causes memory issues
Column(children: list.map(...).toList())

// ✅ Correct
ListView.builder(itemBuilder: ...)
```

### Avoid Full Screen Rebuilds
Use scoped rebuild widgets:
- `Consumer`
- `Selector`
- `ValueListenableBuilder`

### Advanced Optimization
- `RepaintBoundary` around heavy widgets
- `AutomaticKeepAliveClientMixin` for tab persistence
- `PageStorage` for scroll position

---

## 7. Memory Management — Always Dispose Controllers

```dart
@override
void dispose() {
  textController.dispose();
  scrollController.dispose();
  animationController.dispose();
  streamSubscription.cancel();
  super.dispose();
}
```

Always dispose:
- `TextEditingController`
- `ScrollController`
- `AnimationController`
- `StreamSubscription`

---

## 8. Theme System — Always Centralized

```
core/theme/
├── app_colors.dart
├── app_text_styles.dart
└── app_theme.dart
```

- Never hardcode colors or text styles inline
- Always use `Theme.of(context).colorScheme.xxx`
- Support dark mode from the start

Standard color semantics (for finance apps):
```
green  → positive balance / money received
red    → negative balance / money owed
gray   → neutral / pending
```

---

## 9. Reusable Components — Always Create These

```
components/
├── primary_button.dart
├── custom_text_field.dart
├── app_card.dart
├── shimmer_loader.dart
├── empty_state.dart
└── error_state.dart
```

Never duplicate UI code. If a widget is used more than once → move to `components/`.

---

## 10. Image Handling — Always Use Caching

```yaml
dependencies:
  cached_network_image: latest
```

```dart
CachedNetworkImage(imageUrl: url)
```

Never use raw `Image.network()` in lists.

---

## 11. Error & Loading States — Always Handle All 3 States

Every screen must handle:
1. **Loading** → Shimmer / skeleton loader
2. **Error** → `ErrorView` with retry button
3. **Empty** → `EmptyStateView` with message

```
components/
├── error_widget.dart
├── retry_widget.dart
└── empty_state.dart
```

---

## 12. Offline Support UI

Every data-mutating action must show sync state:

```
✅ Expense added (Syncing...)
⚠️  Expense added (Sync pending — offline)
```

Always provide:
- Offline indicator
- Pending sync state
- Retry option

---

## 13. Web-Specific Considerations

```dart
// Hover support
MouseRegion(...)

// Keyboard navigation
FocusNode(...)

// URL routing
go_router
```

---

## 14. Accessibility — Always Add

```dart
Semantics(
  label: "Submit Button",
  child: PrimaryButton(),
)
```

Requirements:
- Semantic labels on interactive widgets
- Proper color contrast
- Scalable fonts (no hardcoded `fontSize` without `TextScaler` support)
- Screen reader compatibility

---

## 15. Currency & Number Formatting

Always use the `intl` package for financial values:

```yaml
dependencies:
  intl: latest
```

```dart
NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount)
```

Never display raw `double.toString()` for money.

---

## 16. Security (Finance App Rules)

- Hide balances when app is backgrounded
- Mask sensitive data in logs
- Implement session timeout
- Never log financial data to console in production

---

## 17. UI Testing — Always Write Tests for Critical Flows

```yaml
dev_dependencies:
  flutter_test:
  golden_toolkit:
```

Must-test screens:
- Add expense
- Group creation
- Settlement flow
- Login / Signup

---

## 18. Common Mistakes — Never Do These

| ❌ Never | ✅ Always |
|---------|---------|
| `setState` for app state | Riverpod providers |
| 1000-line widget files | Max 300 lines, split widgets |
| Hardcoded `width: 300` | Responsive sizing |
| `Image.network()` in lists | `CachedNetworkImage` |
| No error/empty state | Handle all 3 UI states |
| No theme system | Centralized `app_theme.dart` |
| Business logic in UI | Separate controllers/providers |
| `Column` for long lists | `ListView.builder` |

---

## 19. Packages — Approved List

| Purpose            | Package                  |
|--------------------|--------------------------|
| State management   | `riverpod` / `flutter_riverpod` |
| Navigation         | `go_router`              |
| Image caching      | `cached_network_image`   |
| Formatting         | `intl`                   |
| Loading shimmer    | `shimmer`                |
| Local storage      | `hive` / `isar`          |
| HTTP client        | `dio`                    |

---

## 20. Future-Proof Module Placeholders

When structuring folders, always leave room for:
```
modules/
├── ai_insights/
├── budget_planner/
├── receipt_scanner/
├── subscription_tracker/
└── tax_reports/
```

---

*This file is the single source of truth for all Flutter UI decisions in this project. Always reference it before writing any UI code.*
