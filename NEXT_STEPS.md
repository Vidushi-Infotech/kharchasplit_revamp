# KharchaSplit Build — Next Steps

## ✅ COMPLETED (Commits: 3 major commits)

### Foundation Layers
1. **Data Models** (7 classes): UserModel, CategoryModel, SplitModel, ExpenseModel, GroupModel, SettlementModel, ActivityModel
2. **Core Utilities** (3 classes): CurrencyFormatter, DateFormatter, SplitCalculator
3. **Reusable Components** (8 widgets): AvatarWidget, CurrencyText, EmptyStateWidget, ShimmerList, BalanceCard, ExpenseCard, GroupCard
4. **Shell Infrastructure** (partial): shell_state.dart, mobile_shell.dart
5. **Dashboard Provider** with mock data

---

## 🎯 IMMEDIATE NEXT STEPS (Priority Order)

### 1. Complete Dashboard Screen (Most Critical)
**File**: `lib/modules/dashboard/screens/dashboard_screen.dart`

```dart
// Structure:
// 1. TopBar: "Good morning" greeting + notification bell + avatar
// 2. BalanceSummaryCard: Show totalBalance, youAreOwed, youOwe
// 3. Recent Groups: Horizontal scroll GroupCardHorizontal + AddGroupCard
// 4. Recent Expenses: Vertical list ExpenseCard grouped by date
// 5. Quick Settle: Show largest debts first

// Use:
// - final dashboardData = ref.watch(dashboardProvider);
// - BalanceCard(totalBalance, youAreOwed, youOwe)
// - Responsive: screenWidth < 600 (column) vs >= 600 (2-col grid)
```

### 2. Update Router (lib/core/routing/app_router.dart)
Replace entire file with expanded GoRouter:
```
Routes to add:
- /home → shell wrapper (all routes below are wrapped)
  - /home/dashboard
  - /home/groups
  - /home/groups/:groupId
  - /home/friends
  - /home/activity
  - /home/profile
- /add-expense (full-screen modal)
- /settle/:userId (full-screen modal)
- Plus existing: /, /onboarding, /login, /register, /forgot-password
```

### 3. Tablet & Web Shell Layouts
**Files**:
- `lib/layouts/shell/tablet_shell.dart` → NavigationRail sidebar (collapsed with labels on hover)
- `lib/layouts/shell/web_shell.dart` → Fixed 240px sidebar + top bar

**Key**: Both use same routing, just different layout

### 4. Create Placeholder Screens (Placeholder All 10 Feature Screens)
Each follows same pattern:
```
lib/modules/{module}/screens/{screen}.dart
lib/modules/{module}/state/{provider}.dart (empty provider stub)
lib/modules/{module}/widgets/{custom_widgets}.dart (if needed)
```

Screens to create (stubbed with Scaffold + AppBar):
1. GroupsListScreen
2. GroupDetailScreen
3. AddExpenseScreen (most complex)
4. ExpenseDetailScreen
5. FriendsListScreen
6. FriendDetailScreen
7. ActivityFeedScreen
8. ReportsScreen
9. ProfileScreen
10. SettingsScreen

---

## 📝 CRITICAL RULES (From CLAUDE.md)

**ALWAYS**:
- Use `screenWidth = MediaQuery.of(context).size.width` for responsive decisions
- Format amounts via `CurrencyFormatter` → display via `CurrencyText`
- Format dates via `DateFormatter`
- Use `AppColors.x(isDark)` for all colors
- Use `AppTextStyles.x(isDark)` for all text
- Dispose all controllers: TextEditingController, AnimationController, etc.
- Use `const` on all widgets
- Use `ListView.builder` for lists (never Column.map())
- State management: Riverpod ONLY (no setState)
- Max 300 lines per file (split into widgets if exceeded)

**NEVER**:
- Hardcode colors, text styles, widths
- Use device type checks (isMobile, isTablet, isWeb)
- Raw `toString()` for money amounts
- `Image.network()` in lists (use CachedNetworkImage)
- Business logic in screens (use providers/state)

---

## 🏗️ Architecture Pattern (Copy for Each Feature Screen)

```dart
// 1. Create provider (lib/modules/{feature}/state/{provider}.dart)
final featureProvider = StateProvider<FeatureData>((ref) {
  return FeatureData(); // load data
});

// 2. Create screen (lib/modules/{feature}/screens/{screen}.dart)
class FeatureScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = ref.watch(featureProvider);

    if (screenWidth < 600) {
      return _buildCompactLayout(data);
    } else if (screenWidth < 1100) {
      return _buildStandardLayout(data);
    } else {
      return _buildLargeLayout(data);
    }
  }
}

// 3. Create widgets (lib/modules/{feature}/widgets/{widget}.dart)
// Extract anything >50 lines into separate widget files
```

---

## 💡 Key Implementation Tips

1. **Always start with mock data** → DashboardProvider shows pattern
2. **Use _build{Layout}() methods** → keeps code clean, <300 lines
3. **Group by date** → Wrap ExpenseCard list with DateFormatter.groupHeader()
4. **Handle empty/loading** → Use EmptyStateWidget + ShimmerList
5. **Animate balance updates** → Use `animated: true` on CurrencyText
6. **Responsive padding** → 16-20px (compact), 24-32px (standard), 32-48px (large)

---

## 📦 Packages Already Added
```yaml
flutter_riverpod, go_router, fl_chart, hive_flutter, cached_network_image,
shimmer, intl, equatable, uuid, connectivity_plus, share_plus, pdf,
path_provider, image_picker, google_sign_in, flutter_facebook_auth, dio
```

---

## 🧪 Testing Checklist (Per Screen)

- [ ] Loads with mock data
- [ ] Responsive at all 3 breakpoints (<600, 600-1100, >1100)
- [ ] Dark/light mode works (all colors via AppColors)
- [ ] No hardcoded values (widths, colors, fonts, amounts)
- [ ] All amounts formatted via CurrencyFormatter
- [ ] All dates formatted via DateFormatter
- [ ] Lists use ListView.builder (not Column)
- [ ] No errors in `flutter analyze`
- [ ] All imports organized (models, utils, components, etc.)

---

## 🚀 Build Velocity

Following this architecture, each screen should take:
- **Stub layout**: 30 minutes (structure only)
- **Feature implementation**: 1-2 hours (UI + logic)
- **Polish**: 30 minutes (animations, edge cases)

Target: All 13 steps complete in 3-4 focused sessions.

