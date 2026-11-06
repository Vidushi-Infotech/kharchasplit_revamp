# Android Performance Concepts → KharchaSplit Flutter

> Companion to `android-performance-amp-architecture-concepts.md`.
> Maps each of the 30 concepts onto the Flutter app in `frontend/` as it stands on
> branch `Shoaib-Dev` (7 Sep 2026). Paths are relative to `frontend/`.
>
> Legend: ✅ handled · ⚠️ partial / risky · ❌ missing · ➖ not applicable to Flutter

Flutter vocabulary for the Android terms used below:

| Android term | Flutter equivalent |
|---|---|
| Main / UI thread | Dart **main isolate** (UI + platform thread; Flutter 3.29+ merges them) |
| Background thread / coroutine | `compute()` / `Isolate.run()` for CPU work; plain `async` does **not** leave the main isolate |
| Activity lifecycle | `WidgetsBindingObserver.didChangeAppLifecycleState` |
| Process death restore | `RestorationMixin` / `restorationId` / `MaterialApp.restorationScopeId` |
| ViewModel scope | Riverpod provider lifetime (`autoDispose` vs kept-alive) |
| Recomposition | Widget **rebuild** (`build()` re-run) |
| RecyclerView / LazyColumn | `ListView.builder` / `SliverList.builder` |
| WorkManager | `workmanager` package (not used) |
| R8 / DEX / Baseline Profiles | Still apply to the Android host (`android/`), plus Dart AOT `--obfuscate` |

---

## Part A — Launch & responsiveness

### 1. Startup Time — ⚠️
**What we do:** `lib/main.dart:25-67` runs strictly sequential `await`s before `runApp`:
Firebase init → Crashlytics toggle → `PushService.init()` → `runApp`. After the first
frame, `main.dart:102-106` fires a network `GET /app-version` and the connectivity plugin starts.

**Problems:**
- `PushService.init()` (`lib/core/services/push_service.dart:67-102`) is on the critical
  path and includes `fcm.requestPermission(...)` at `:80`. On Android 13+ the notification
  permission dialog appears **before the first Flutter frame**.
- `splash_provider.dart:21` has an unconditional `Future.delayed(2 s)`. Every cold start
  pays 2 s of pure latency.
- Hive is declared in `pubspec.yaml` but never used; it still costs plugin registration.
- `api_client.dart:133` reads secure storage (platform channel) on **every** HTTP request.

**Action:** delete the 2 s delay; move `PushService.init()` after `runApp` (post-frame);
only `Firebase.initializeApp()` truly needs to be awaited; cache the access token in memory.

### 2. Cold Start — ⚠️
Native splash is configured (`pubspec.yaml:126-138`) so the shell paints early, but
perceived cold start ≈ native splash + Firebase/FCM init + 2 s + first dashboard fetch +
optional permission dialog. See §1 for the fixes. Also: `main.dart:102` update check hits
the network on frame 1 of every cold start.

### 3. Warm Start — ⚠️
Process is alive, Riverpod state is intact, so warm start is cheap. But nothing refreshes
on resume (see §20), so a user returning after an hour sees stale balances until they
pull-to-refresh or a reconnect event fires.

### 4. ANR — ✅ (no direct risk found)
Flutter gets an ANR only when the platform thread is blocked. No synchronous platform
calls of that kind found. The main-isolate stalls in §23 cause jank, not ANRs.

### 5. Jank — ⚠️
Sources found, in order of cost:
1. `lib/layouts/shell/floating_bottom_bar.dart:33-42` — `LiquidGlassLayer` backdrop
   shader on the bottom nav, mounted with `extendBody: true` (`mobile_shell.dart:66`).
   It re-samples scrolling content every frame on **every tab**. Single largest GPU cost.
2. Balances tab rebuild work in `group_detail_screen.dart:1825-1851` (see §23).
3. `NumberFormat.currency(...)` constructed inside `build` at 13 sites, several per list
   item (`group_grid_card.dart:33`, `group_row_card.dart:33`, `group_mini_card.dart:193`,
   `recent_expenses_section.dart:211`, `group_activity_tab.dart:760,1023`).
   `lib/core/utils/date_formatter.dart` builds a fresh `DateFormat` on every call.
4. Zero `itemExtent` / `prototypeItem` / `cacheExtent` anywhere — every row is measured.
5. `aurora_background.dart:72-81` draws ≈5,300 circles per paint; confirm `shouldRepaint`
   returns `false`.

**Good:** `RepaintBoundary` at 12 sensible spots; all long feeds use `.builder`.

### 6. Main Thread (main isolate) — ⚠️
Only one `compute()` in the app (`group_activity_tab.dart:1210`). Everything else runs on
the main isolate — see §23 for the list.

---

## Part B — Memory & resources

### 7. Memory Leak — ⚠️
**Good:** every `StatefulWidget` disposes its controllers, timers and subscriptions
(audited across ~25 files). `addListener`/`removeListener` are balanced.

**Real retention issues:**
- `FutureProvider.family` caches with no `autoDispose`: `group_detail_provider.dart:30`,
  `expense_detail_provider.dart:10`, `friend_detail_provider.dart:26`,
  `pending_settlements_provider.dart:14,29`, `policy_provider.dart:56`. Each visited
  group keeps its full expense list (including `receiptBase64`) for the process lifetime.
  Only `add_expense_provider.dart:181,222` use `autoDispose`.
- `PushService.instance` (`push_service.dart:44-50`) owns broadcast streams; its
  `dispose()` at `:237` has no callers.
- Module-level LRU caches `avatar_widget.dart:13` and `group_cover_thumb.dart:10` key on
  the full base64 string, so each entry retains text **and** decoded bytes; never cleared,
  not even on logout.
- `split_breakdown_widget.dart:54-61` builds one controller per member once;
  `_controllers[member.id]!` at `:581` will throw if a member is added while mounted.

### 8. Battery Drain — ✅
No location, no wake locks, no polling, no periodic sync. Only `Timer.periodic` is the
OTP countdown (`forgot_password_screen.dart:68`), cancelled correctly.
Minor: each reconnect event triggers 3 full refetches (`groups_provider.dart:18`,
`dashboard_provider.dart:46`, `notifications_inbox_provider.dart:102`), throttled only by
a 500 ms debounce in `connectivity_service.dart:73`. Fine on stable networks, chatty on flaky ones.

### 22. GC Pressure — ⚠️
- Per-item `NumberFormat`/`DateFormat` allocation (§5).
- `MemoryImage(bytes)` created fresh on every avatar build (`avatar_widget.dart:136`) so
  the `ImageCache` key changes each time even though bytes are cached.
- `personal_expenses_screen.dart:949-964` copies + sorts the whole list on every build,
  including every search keystroke.

### 28. Overdraw — ⚠️
- Network avatar paints the same URL twice: `backgroundImage` **and** a child
  `CachedNetworkImage` (`avatar_widget.dart:139-162`).
- `Opacity` inside a list `itemBuilder` at `group_detail_screen.dart:1539` forces a
  `saveLayer` per placeholder member row.
- Shadows stacked on the liquid-glass shader (`floating_bottom_bar.dart:53,223`).
- Otherwise light: `ClipRRect` in only 5 files, no raw `BackdropFilter`.

---

## Part C — Stability

### 9. App Crash — ✅ / ⚠️
**Good:** `main.dart:25-56` wires `runZonedGuarded`, `FlutterError.onError`,
`PlatformDispatcher.onError` into Crashlytics; zero `!.` force-unwraps in `lib/models/`.

**Remaining crash paths:**
- Unguarded `jsonDecode` on persisted data: `token_storage.dart:33`,
  `wallet_local_store.dart:20,36`. A schema change to stored wallet JSON then hits the
  hard `(json['balance'] as num)` cast at `wallet_source_model.dart:41` with no recovery.
- Hard `as String` on `id` in `activity_model.dart:67`, `expense_model.dart:87`,
  `personal_expense_model.dart:45`.
- `split_breakdown_widget.dart:581` null-check (see §7).
- `api_client.dart:101-116` token refresh only catches `DioException`; if secure storage
  throws, the completer never completes and every waiting request hangs.

### 11. Process Death — ❌
Zero use of `RestorationMixin` / `restorationId`; `MaterialApp.router` sets no
`restorationScopeId`; `initialLocation: '/'` (`app_router.dart:66`) so after process death
the user always lands on splash → 2 s → dashboard. Route, selected tab
(`group_detail_provider.dart:151`), scroll position and any in-progress form are lost.
The add-expense draft is explicitly discarded by design (`add_expense_provider.dart:177-181`).

**Survives:** tokens + cached user (secure storage), theme, haptics, onboarding flag,
wallet sources (SharedPreferences).

**Action:** persist add-expense / create-group drafts to SharedPreferences keyed by
group id; store last route; consider `restorationScopeId` for scroll/tab state.

### 20. Lifecycle — ❌
No `WidgetsBindingObserver` anywhere in `lib/`. Consequences: no refresh on resume, no
connectivity re-check on resume, the update gate runs once per process
(`main.dart:102`), and the OTP timer keeps ticking in the background.

**Action:** add one observer at the shell level; on `resumed` invalidate dashboard +
groups if last fetch is older than N minutes, re-run `checkForUpdate`.

---

## Part D — Data layer

### 12. Offline Support — ⚠️
**Have:** `ConnectivityService` (`lib/core/services/connectivity_service.dart`), global
offline banner via `MaterialApp.builder` (`main.dart:135`), `OfflineInterceptor`
fast-fails requests while offline, reconnect stream triggers refetches.

**Missing:**
- No local data cache. Hive is in `pubspec.yaml` but `Hive` never appears in `lib/`.
  Riverpod in-memory state is the only cache, so a cold start offline shows nothing.
- No offline mutation queue. Adding an expense offline returns a snackbar and keeps the
  form (`add_expense_screen.dart:1216-1227`). `CLAUDE.md:294` specifies
  "Expense added (Sync pending — offline)", which is not implemented.
- `hasRealInternet()` (`connectivity_service.dart:95`) captive-portal probe is dead code.
- `_last` starts as `unknown` (`:43`), so on cold start offline, requests still go out
  and wait the full 10 s connect timeout.

### 13. Caching — ⚠️
- Cache = Riverpod provider state, no TTL, no versioning.
- Invalidation is manual `ref.invalidate(...)` fan-out at ~45 call sites
  (e.g. `add_expense_screen.dart:1229-1237`, `settle_screen.dart:93-99`). A missed site
  means stale UI.
- Stale-while-revalidate exists in only three places: `auth_provider.dart:81-90`,
  `device_contacts_provider.dart:45-51`, `dashboard_provider.dart:51-58`. Every other
  `refresh()` flips to `AsyncLoading` first, so pull-to-refresh flashes a skeleton
  (`groups_provider.dart:31`, `activity_feed_provider.dart:23`,
  `notifications_inbox_provider.dart:141`, `personal_expenses_provider.dart:26`).
- `cached_network_image` used once (`avatar_widget.dart:142-147`) with no
  `memCacheWidth/Height`, decoding full-size images for 18–24 px circles.

**Action:** in `refresh()` keep the previous value (`state = AsyncData(old)` while
fetching, or use `AsyncValue.guard` without the loading flip); pick one persistent
cache (Hive is already a dependency) for groups + dashboard summary with a
`fetchedAt` timestamp.

### 14. Pagination — ❌
Every list repository accepts `page`/`limit` (default 50) but **no caller passes them**:
`groups_provider.dart:22,33`, `group_detail_provider.dart:41-42`,
`activity_feed_provider.dart:18`, `personal_expenses_provider.dart:22`,
`pending_settlements_provider.dart:18,33`. Notifications hardcode `?limit=50`
(`notifications_inbox_provider.dart:124`). No `hasMore`, no infinite scroll, no
`ScrollController` near-bottom detection.

**Correctness risk, not just performance:** `group_detail_provider.dart:70-90`
computes balances client-side from the fetched page, so a group with more than 50
expenses shows **wrong balances**.

**Action (priority):** either compute balances server-side, or have the detail
provider page through all expenses before computing. Then add infinite scroll to the
activity and group-expense feeds.

### 15. API Timeout — ⚠️
`api_config.dart:31-32`: connect 10 s, receive 20 s. **No `sendTimeout`** anywhere,
and receipts/covers upload as base64 JSON bodies, so a slow upload has no deadline.
The token-refresh Dio at `api_client.dart:101` is a bare instance with no timeouts,
pinning or offline interceptor.

**Action:** add `sendTimeout: 30 s`; reuse the configured `BaseOptions` for the refresh client.

### 16. Retry Logic — ❌
No retry interceptor, no backoff. The only retry is the single 401 replay at
`api_client.dart:152`, guarded by `extra['_retried']`. It is idempotency-blind: a
`POST /expenses` that 401s is replayed identically. No `Idempotency-Key` header.

Also note `validateStatus: s < 500` (`api_client.dart:34`) delivers all 4xx as
successful responses, making these `on DioException` branches unreachable:
`groups_repository.dart:243-259` (`UNSETTLED_BALANCES` write-off flow, so the dialog
at `group_detail_screen.dart:693` cannot trigger) and `users_repository.dart:101-109`
(404 → "not registered" in the contacts picker).

**Action:** add a small retry interceptor for GET only (2 attempts, 1 s / 2 s backoff,
on connect/receive timeouts and 502/503/504); fix the two dead 4xx branches.

### 24. Backpressure — ⚠️
Ad-hoc `Timer` debounces, no shared util:

| Site | Delay | Hits API? |
|---|---|---|
| `contacts_picker_sheet.dart:170-185` | 400 ms | yes, plus `_phoneCache` + 429 handling — the model to copy |
| `notification_prefs_provider.dart:165-167` | 350 ms | yes, coalesces toggles into one PUT |
| `groups_screen.dart:61-70` | 250 ms | no (local filter) |
| `add_expense_screen.dart:414-416` | 200 ms | no |
| `connectivity_service.dart:71-74` | 500 ms | n/a |

Gaps: `notifications_inbox_provider.dart:110-113` uses `Future.microtask(refresh)` per
foreground push. A microtask does not debounce, so N pushes → N full refreshes.
`group_activity_tab.dart:72-81` invalidates the whole group detail per matching push.

**Action:** add `lib/core/utils/debouncer.dart` and use it in both push handlers.

---

## Part E — Concurrency & state

### 17. Race Condition — ⚠️
- **Good:** token refresh is single-flighted (`api_client.dart:85-95`); settle-up and
  confirm-settlement have re-entrancy guards (`settle_screen.dart:48,79`,
  `group_detail_screen.dart:2940`); phone lookup discards stale responses
  (`contacts_picker_sheet.dart:196,205,218`).
- **Gaps:** `_handleSave` in `add_expense_screen.dart:1069` relies only on the button's
  `enabled` flag; cancel-settlement at `group_detail_screen.dart:3111` sets `_busy` but
  never checks it; overlapping `refresh()` calls on groups/dashboard/notifications are
  last-writer-wins.
- **Read-modify-write:** `WalletNotifier` (`wallet_provider.dart:69-153`) reads
  `state.value`, awaits two SharedPreferences writes, then writes state. A delete-expense
  refund racing a manual source edit clobbers one of them. Same shape in
  `sessions_provider.dart:82-87`.

### 18. Thread Safety — ✅ (by construction)
Dart's single main isolate means no data races on provider state. The only cross-isolate
boundary is the `compute()` call at `group_activity_tab.dart:1210`, which passes an
immutable `String` in and `Uint8List` out. The FCM background isolate
(`push_service.dart:14-19`) touches no shared state.

### 19. State Management — ⚠️
Riverpod 3 with `Notifier`/`AsyncNotifier`/`FutureProvider.family`/`StreamProvider`;
no `ChangeNotifier`, no `StateNotifier`. Single source of truth is mostly respected.

Anti-patterns:
- `refresh()` calls `build()` manually (`dashboard_provider.dart:74`,
  `activity_feed_provider.dart:24`, `device_contacts_provider.dart:39,46`). `build()`
  registers `ref.listen(...)`, so each refresh adds another listener.
- `dashboard_provider.dart:69-75` refreshes groups, then re-runs `build` which watches
  groups again → two sequential fetch waves per pull-to-refresh.
- **Duplicate provider name:** `selectedNavIndexProvider` is declared in both
  `layouts/shell/shell_state.dart:4` and `modules/dashboard/screens/home_screen.dart:14`.
  These are two independent states; which one a widget reads depends on its import.
- `shell_state.dart:7` seeds `unreadActivityCountProvider` with a hardcoded `3`.
- State written during `build`: `offline_banner.dart:44-46`, `mobile_shell.dart:44-50`,
  `settle_screen.dart:125-136`.
- Auth hydration runs twice from two paths reading the same key
  (`splash_provider.dart:19-29` and `auth_provider.dart:82-94`).

### 25. Structured Concurrency — ⚠️
Riverpod scopes async work to provider lifetime, but:
- `auth_provider.dart:89` `unawaited(_refreshFromServer(...))` writes `state` at `:115`
  with no disposed-guard; Riverpod 3 throws on post-dispose writes.
- `create_group_screen.dart:59` pre-warms `deviceContactsProvider` unawaited, which
  triggers the READ_CONTACTS permission dialog and a full contact scan as a side effect
  of opening the screen.
- `PushService` emits the cold-start notification tap via `scheduleMicrotask`
  (`push_service.dart:97-101`) before `main.dart:95` subscribes → cold-start tap routing
  is racy.
- Async callbacks are otherwise well guarded with `mounted` / `context.mounted`
  (verified across `group_detail_screen`, `add_expense_screen`, `contacts_picker_sheet`).

### 29. Recomposition (widget rebuilds) — ⚠️
- `.select()` used **once** in ~90 `ref.watch` calls (`add_expense_screen.dart:757`).
- `lib/components/cards/expense_card.dart:13,50` is a `ConsumerWidget` that watches
  `myIdProvider` per row, used in three unbounded lists. Every auth-state emission
  rebuilds every visible card, each re-scanning `expense.splits`.
- `group_activity_tab.dart:171-180` calls `setState` on the entire 1,251-line tab to
  expand one card, re-running the flatten loop at `:169-179`.
- 20 `Widget _buildX()` helpers in `group_detail_screen.dart` alone; these cannot be
  `const` and rebuild with the parent. Extract the big ones (`_buildMembersList:1519`,
  `_buildExpensesList:1791`, `_buildBalancesTab:1860`) into widgets.
- `main.dart:117-120` watches theme and connectivity on the root `MaterialApp.router`.
- **Good:** `group_detail_screen.dart:115-121` deliberately scopes the tab watch to inner
  `Consumer`s; `const` used ~2,500 times.

---

## Part F — Main-isolate blocking

### 23. Main Thread Blocking — ⚠️
Work that should be moved off the main isolate or into a provider:

| Site | Work |
|---|---|
| `add_expense_screen.dart:965-966` | `File.readAsBytes()` + `base64Encode` of a full receipt |
| `create_group_screen.dart:173`, `edit_group_sheet.dart:151` | `base64Encode` of cover images |
| `expense_detail_screen.dart:1146-1154` | synchronous `base64Decode` of a multi-MB receipt in `initState` |
| `avatar_widget.dart:25`, `group_cover_thumb.dart:23` | `base64Decode` during build (LRU-mitigated) |
| `image_processor_service.dart:106` | `img.decodeImage(bytes)` in pure Dart to read dimensions, files up to 50 MB |
| `group_detail_screen.dart:1825-1851` | `computePendingOutgoing`, `_balanceCardData`, `computePairwiseDebts`, `buildSplitLogEntries` on every Balances-tab rebuild |
| `settlement_history_screen.dart:60-97` | filter + sort + `computePairwiseDebts` + two folds inside `build` |
| `personal_expenses_screen.dart:949-964` | copy + sort + per-element `DateFormat` on every build |

`compute()` is already used correctly at `group_activity_tab.dart:1210`; copy that
pattern for the base64 sites and move the balance maths into `group_detail_provider`.

---

## Part G — Background work

### 10. Background Tasks — ⚠️
Only background execution is the FCM isolate (`push_service.dart:14-19`), which just
calls `Firebase.initializeApp()`. All sync is foreground-event-driven: reconnect stream,
foreground push, pull-to-refresh. No periodic sync, no analytics upload. iOS declares
`UIBackgroundModes: fetch` (`ios/Runner/Info.plist:59-63`) with no handler; vestigial.
Image compression runs natively via `flutter_image_compress` (`image_processor_service.dart:45`),
but note `minWidth: 1080, minHeight: 1920` are *minimums*, so large captures are not downscaled.

### 30. WorkManager Constraints — ➖ / ❌
Not used. Would only matter if an offline outbox (§12) is built; then use the
`workmanager` package with `NetworkType.connected` to drain the queue.

---

## Part H — Android host build

### 26. R8 — ⚠️
`android/app/build.gradle.kts:74-75`: `isMinifyEnabled` and `isShrinkResources` are
gated on **keystore presence** (`hasReleaseKeystore`), not build type. A CI runner or
fresh clone without `key.properties` silently produces an unminified, unshrunk release.
`proguard-rules.pro` keeps are broad (`-keep class io.flutter.** { *; }` at `:13`,
all of Firebase/GMS at `:27-28`), which caps shrink gains. No `--obfuscate` /
`--split-debug-info` for the Dart side anywhere; there is no CI directory at all.

**Action:** gate R8 on `buildTypes.release` and fail the build if the keystore is
missing; add `flutter build appbundle --obfuscate --split-debug-info=build/symbols`
to the release script and upload symbols to Crashlytics.

### 27. DEX — ✅
`multiDexEnabled = true` (`build.gradle.kts:50`), minSdk 24 (native multidex),
core-library desugaring on. Nothing to do.

### 21. Baseline Profiles — ❌ (low priority)
Flutter release builds include the engine's own profile automatically. No app-level
`androidx.baselineprofile` module exists. Gains for a Flutter app are limited to the
Android host and plugins; revisit only after §1–§2 startup fixes.

---

## Progress (7 Sep 2026)

Local branches, not yet pushed. Each stacks on the previous one.

| Branch | Items | Status |
|---|---|---|
| `perf/pr1-cold-start-and-balances` | 1, 2, 3 | committed, analyzer clean |
| `perf/pr2-refresh-cache-resume` | 4, 5, 6 | committed, analyzer clean, refresh pattern verified with a throwaway Riverpod test |
| `perf/pr3-network-isolates-r8` | 7 (partial), 8, 9, 12 (Android manifest only) | committed, analyzer clean |

Still open from item 7: hoisting the Balances-tab maths out of
`group_detail_screen.dart` build() — deferred because that file has unrelated
uncommitted edits. Items 10, 11, 13–16 not started.

## Prioritised action list

Ordered by user impact ÷ effort.

1. **Wrong balances beyond 50 expenses** — `group_detail_provider.dart:41,70-90`. Correctness bug. (§14)
2. **Remove the 2 s splash delay** — `splash_provider.dart:21`. (§1)
3. **Move `PushService.init()` after `runApp`** so the permission dialog never blocks the first frame — `main.dart:60`. (§1)
4. **Keep old data during `refresh()`** instead of flipping to `AsyncLoading` — 5 providers. (§13)
5. **`autoDispose` on the detail family providers** — `group_detail_provider.dart:30` first. (§7)
6. **Add `WidgetsBindingObserver`** for refresh-on-resume. (§20)
7. **Move base64 encode/decode to `compute()`** at the 5 sites listed in §23; hoist balance maths into the provider.
8. **Retry interceptor for GET + `sendTimeout`**; fix the two unreachable 4xx branches. (§15, §16)
9. **Gate R8 on build type**, add `--obfuscate --split-debug-info`. (§26)
10. **Reduce rebuild scope**: drop `ref.watch` from `ExpenseCard`, use `.select()`, extract `_buildX` helpers. (§29)
11. **Format caches**: static `NumberFormat`/`DateFormat` instances in `currency_formatter.dart` / `date_formatter.dart`. (§5, §22)
12. **Guard `jsonDecode` on persisted data** — `token_storage.dart:33`, `wallet_local_store.dart:20,36`. (§9)
13. **Shared `Debouncer`** and use it in both push-triggered refresh paths. (§24)
14. **Fix duplicate `selectedNavIndexProvider`** and the hardcoded unread count `3`. (§19)
15. **Measure the liquid-glass nav bar** on a low-end device before deciding whether to keep it. (§5)
16. Later: offline outbox + Hive cache (§12), draft persistence (§11), infinite scroll (§14).

## Verification ideas

- Startup: `flutter run --profile --trace-startup` before/after items 2–3; compare
  `timeToFirstFrameMicros` in `build/start_up_info.json`.
- Jank: DevTools Performance tab while scrolling the group Expenses and Balances tabs on
  a mid-range Android; look for frames >16 ms and `saveLayer` calls.
- Balances bug: seed a group with 60 expenses via the backend and compare app total vs DB.
- Memory: DevTools Memory tab, open 10 groups, confirm `GroupDetail` instances drop
  after adding `autoDispose`.
- Release build: `flutter build apk --release` on a clone without `key.properties`
  and check whether `mapping.txt` is produced.
