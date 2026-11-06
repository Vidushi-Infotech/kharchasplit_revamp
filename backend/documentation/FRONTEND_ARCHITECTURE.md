# KharchaSplit — Frontend Architecture

Flutter mobile/web client. Built around Riverpod for state, go_router for
navigation, and Dio for HTTP. Single-codebase, three responsive layouts.

> See also [BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md) and
> [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md).

---

## 1. Stack

| Layer            | Choice                                                         |
|------------------|----------------------------------------------------------------|
| Framework        | Flutter (Dart `^3.11`)                                         |
| State management | `flutter_riverpod` `^3.2` (NotifierProvider, FutureProvider, AsyncNotifierProvider, Consumer) |
| Navigation       | `go_router` `^17.1` (declarative routes, deep-links, web URL)  |
| HTTP             | `dio` `^5.3` + custom `ApiClient` with auth interceptor        |
| Persistence      | `flutter_secure_storage` (token + user blob), `shared_preferences` (wallet, theme), `hive` (cache scaffolding) |
| Push notifications | Firebase Messaging                                           |
| Contacts         | `flutter_contacts` (real device contacts)                      |
| Charts           | `fl_chart`                                                     |
| Image handling   | `image_picker`, `cached_network_image`                         |

---

## 2. Folder layout

```
lib/
├── main.dart                   App entry — boots ProviderScope + MaterialApp.router
├── core/
│   ├── constants/              App-wide constants (onboarding pages, etc.)
│   ├── network/                ApiClient (Dio), TokenStorage, AuthInterceptor
│   ├── responsive/             Breakpoint helpers (isMobile, isTablet, isWeb)
│   ├── routing/                go_router config + redirects
│   ├── services/               Image processor, invoice scanner (OCR stub)
│   ├── theme/                  AppColors, AppTextStyles, AppTheme, ThemeProvider
│   └── utils/                  CurrencyFormatter, DateFormatter, etc.
├── components/                 Cross-module reusable UI (avatars, cards,
│                               buttons, loaders, error states)
├── data/                       Repositories — one folder per domain
│   ├── auth/                   AuthRepository (login, OTP, refresh, logout)
│   ├── activities/             ActivitiesRepository
│   ├── contacts/               DeviceContactsProvider
│   ├── dashboard/              DashboardRepository
│   ├── expenses/               ExpensesRepository
│   ├── groups/                 GroupsRepository
│   ├── personal_expenses/      PersonalExpensesRepository
│   ├── settlements/            SettlementsRepository
│   ├── users/                  UsersRepository
│   └── wallet/                 WalletStore (SharedPreferences-only)
├── models/                     Plain Dart models (Equatable). fromJson/toJson.
├── modules/                    Feature modules — one folder per domain
│   ├── auth/  dashboard/  expenses/  groups/  settlements/
│   ├── personal_expenses/  activity/  profile/  reports/  onboarding/
│   └── friends/                Each module: screens/, widgets/, state/
├── layouts/                    (placeholder for mobile/tablet/web shells)
└── presentation/
    └── screens/                Splash + onboarding (legacy location, kept)
```

---

## 3. Layered architecture

```
       ┌────────────────────────────────────────┐
       │   UI (modules/<feature>/screens)       │
       │   ConsumerWidget / ConsumerStatefulWidget │
       └──────────────┬─────────────────────────┘
                      │ ref.watch / ref.read
                      ▼
       ┌────────────────────────────────────────┐
       │   State providers (modules/<feature>/state) │
       │   Riverpod (Notifier / FutureProvider) │
       └──────────────┬─────────────────────────┘
                      │ ref.read(repoProvider)
                      ▼
       ┌────────────────────────────────────────┐
       │   Repositories (data/<feature>)        │
       │   Dio calls, JSON → Model              │
       └──────────────┬─────────────────────────┘
                      │ ApiClient (Dio + interceptors)
                      ▼
       ┌────────────────────────────────────────┐
       │   Models (models/)                     │
       │   Equatable, immutable, fromJson()     │
       └────────────────────────────────────────┘
```

### Why this split

- **Screens** never call repositories directly. They watch a provider; the
  provider owns the lifecycle (loading / data / error). This keeps widgets
  cheap to rebuild and easy to test.
- **Repositories** are the *only* place that knows about JSON shape, HTTP
  error envelopes, or Dio. They return clean `Model` objects or throw a
  typed `*ApiException`.
- **Models** are pure data. `fromJson` normalises field names (snake/camel),
  decodes timestamps, and runs currency code → symbol via
  `CurrencyFormatter.symbolFor`.

---

## 4. State management — Riverpod patterns used

| Provider type                       | Used for                                                         | Examples                                                  |
|-------------------------------------|------------------------------------------------------------------|-----------------------------------------------------------|
| `Provider<T>`                       | DI singletons (Dio client, repositories)                         | `apiClientProvider`, `groupsRepositoryProvider`           |
| `NotifierProvider<T, S>`            | Mutable in-memory state w/ methods                               | `authProvider`, `themeModeProvider`                       |
| `StateProvider<T>`                  | Trivial in-memory state                                          | `groupTabProvider`                                        |
| `FutureProvider.family<T, A>`       | Async fetch keyed by argument; auto-rebuild on `invalidate`      | `groupDetailProvider`, `pendingIncomingSettlementsProvider` |
| `AsyncNotifierProvider`             | Async state with controller methods                              | `dashboardProvider`                                       |

Cache invalidation pattern:

```dart
ref.invalidate(groupDetailProvider(groupId));   // re-fetch on next watch
await ref.read(groupDetailProvider(groupId).future); // await fresh value
```

`Consumer` is used inside larger widgets to scope rebuilds, avoiding
top-level `ConsumerWidget` rebuilds when only one section depends on state.

---

## 5. Networking — `ApiClient`

File: [lib/core/network/api_client.dart](../../frontend/lib/core/network/api_client.dart)

- Single `Dio` instance with base URL from `--dart-define API_BASE_URL`
  (defaulting to `http://localhost:3000/api/v1` for dev). Android device
  builds rely on `adb reverse tcp:3000 tcp:3000`.
- **AuthInterceptor**:
  - Adds `Authorization: Bearer <accessToken>` from `TokenStorage`
    (`flutter_secure_storage`).
  - On 401, attempts `POST /auth/refresh` once with the stored refresh
    token. If refresh succeeds, retries the original request transparently.
    If refresh fails, clears storage and lets the call surface the 401 —
    the auth provider routes the user to `/login`.
- Backend response envelope is uniform:
  ```json
  { "success": true,  "data": { ... }, "message": "..." }
  { "success": false, "error": "..." }
  ```
  Repositories use small `_ensureSuccess` / `_ensureSuccessMap` /
  `_ensureSuccessList` helpers to validate the envelope before mapping.

---

## 6. Routing — `go_router`

File: `lib/core/routing/app_router.dart`

Top-level routes:

| Path                          | Screen                                                         |
|-------------------------------|----------------------------------------------------------------|
| `/`                           | Splash (token check → redirect)                                |
| `/onboarding`                 | Onboarding tour                                                |
| `/login` / `/register`        | Phone auth                                                     |
| `/verify-otp`                 | 6-digit code entry                                             |
| `/forgot-password`            | (Currently OTP path)                                           |
| `/home/dashboard`             | Dashboard tab (in shell)                                       |
| `/home/groups`                | Groups list                                                    |
| `/home/personal`              | Personal Expenses                                              |
| `/home/friends`               | Friends                                                        |
| `/home/activity`              | Activity feed                                                  |
| `/home/profile`               | Profile + Appearance + sign out                                |
| `/home/owed-to-me`            | "They owe you" detail                                          |
| `/home/i-owe`                 | "You owe" detail                                               |
| `/home/groups/:groupId`       | Group detail                                                   |
| `/home/groups/:groupId/settlements-with/:userId` | Pair settlement history                     |
| `/expense/:id`                | Expense detail                                                 |
| `/settle/:userId?groupId=&amount=` | Settle Up screen (pre-filled)                             |
| `/add-expense/:groupId`       | Add expense                                                    |

Navigation uses `context.push` for stackable routes and `context.go` for
shell switches.

---

## 7. Theming

`core/theme/`:
- `AppColors` — exported as static getters (`brand`, `surface(isDark)`,
  `background(isDark)`, `cardBg(isDark)`, `success`, `warning`, etc.). Every
  color has a dark variant; widgets call `Theme.of(context).brightness` to
  pick.
- `AppTextStyles` — `headline1/2/3`, `body1/2`, `caption`, all parameterised
  by `isDark`.
- `AppTheme` — Material `ThemeData` for light + dark.
- `themeModeProvider` (`NotifierProvider<ThemeModeNotifier, AppThemeMode>`)
  — `system` / `light` / `dark`, persisted in `SharedPreferences`. The
  Profile screen exposes a 3-segment selector.

The MaterialApp watches the provider so theme switches are instant.

---

## 8. Responsive layout

CLAUDE.md mandates three breakpoints, used everywhere:

| Width band      | Layout name | Pattern                                              |
|-----------------|-------------|------------------------------------------------------|
| `< 600 px`      | Compact     | Bottom-nav shell; full-width content; 16-20 px padding |
| `600–1100 px`   | Standard    | Sidebar nav; centered content; 24-32 px padding      |
| `> 1100 px`     | Large       | Sidebar + max-width container; 32-48 px padding      |

Decision is per-screen: every screen reads `MediaQuery.of(context).size.width`
and dispatches to `_buildCompactLayout` / `_buildStandardLayout` /
`_buildLargeLayout`.

---

## 9. Persistence

| Storage              | What it holds                                       |
|----------------------|-----------------------------------------------------|
| `flutter_secure_storage` | accessToken, refreshToken, cached user blob         |
| `shared_preferences` | theme mode, wallet sources + balance, onboarding-seen flag |
| `hive`               | (scaffolded — future offline cache)                 |

Hive is wired into `pubspec.yaml` but the offline-cache layer isn't fully in
use yet. All current data flows live (Dio → repo → provider).

---

## 10. Notable cross-cutting concerns

- **Currency normalisation** — every model's `fromJson` runs the currency
  field through `CurrencyFormatter.symbolFor` so widgets never see "INR".
  The save path inverts this with `_normalizeCurrency` so the DB constraint
  (`VARCHAR(3)`) is satisfied.
- **Authentication gating** — the auth provider exposes `user` (nullable);
  most screens redirect to `/login` when null.
- **Pairwise debt math** — both the Balances tab and the dashboard "you
  owe" rows compute pairwise debts on the client from
  `expenses + settlements`, mirroring the backend's `_computeBalances`.
- **Settlement state machine** — settlements have `pending` / `completed` /
  `failed`. A pending outgoing settlement counts in pairwise totals; the
  recipient confirms via the Balances tab to mark completed. Failed
  settlements are excluded.

---

## 11. Where to add a new feature

1. **Model** in `lib/models/<thing>_model.dart` — add `fromJson`, `copyWith`,
   `props` (for Equatable).
2. **Repository** in `lib/data/<thing>/<thing>_repository.dart` — call
   `_client.dio.<method>`, return models, throw a typed exception on
   failure.
3. **Provider** in `lib/modules/<thing>/state/<thing>_provider.dart` — pick
   the smallest provider type that fits.
4. **Screen + widgets** in `lib/modules/<thing>/screens/` &
   `widgets/`. Watch the provider.
5. **Route** in `lib/core/routing/app_router.dart`.
6. **Tests** (when present) under `test/` mirroring the same module path.
