# Haptic Feedback Integration Plan — KharchaSplit Flutter App

A complete plan to add tasteful, accessible haptic feedback across the
Flutter app. Includes research on what haptics are, Flutter's API
surface, design principles ("where they help vs annoy"), an exhaustive
interaction → haptic map, file-level recommendations for **every**
module in this codebase, a central architecture, a user-controlled
settings toggle, phased rollout, and a QA matrix.

**Current state:** zero haptic calls anywhere in `frontend/lib/`.
**Scope:** Android + iOS (no-op on web).

---

## 1. What "haptics" means in a Flutter app

Haptic feedback is the small physical vibration / tap a phone produces
when you interact with the UI. It's a non-visual confirmation that
something happened — pressing a button, completing an action, or
crossing a boundary. Done right, the app feels **responsive and
premium**; done wrong, it's annoying and drains battery.

Flutter exposes haptics through `package:flutter/services.dart`:

```dart
import 'package:flutter/services.dart';

HapticFeedback.lightImpact();    // short, subtle tap (~10 ms)
HapticFeedback.mediumImpact();   // medium tap
HapticFeedback.heavyImpact();    // strong, deliberate thump
HapticFeedback.selectionClick(); // crisp UI "click" (slider/picker)
HapticFeedback.vibrate();        // legacy long buzz (~500 ms) — avoid
```

| Flutter API          | iOS mapping                | Android mapping          | When to use                                    |
| -------------------- | -------------------------- | ------------------------ | ---------------------------------------------- |
| `selectionClick()`   | `UISelectionFeedback`      | `CLOCK_TICK`             | Crossing a discrete boundary (toggle, picker). |
| `lightImpact()`      | `UIImpactFeedback.light`   | `KEYBOARD_TAP`           | Most button presses, nav taps.                 |
| `mediumImpact()`     | `UIImpactFeedback.medium`  | `LONG_PRESS`             | Confirming a non-trivial action.               |
| `heavyImpact()`      | `UIImpactFeedback.heavy`   | `HEAVY_CLICK` (API 27+)  | Destructive confirm, errors.                   |
| `vibrate()`          | Generic                    | 500 ms vibration         | Last resort — too coarse for most cases.       |

Notes:

- **No "notification success" type** exists in Flutter today.
  Approximate with `mediumImpact()` (single confirm) or a `lightImpact()
  + lightImpact()` double-tap for success / failure differentiation.
  For full iOS-style success/warning/error patterns, add the
  `gaptic_feedback` or `flutter_vibrate` package — but the built-in API
  is enough for our needs.
- **Web build**: every call is a no-op, no crash. Safe to call
  unconditionally.

---

## 2. Design principles

A short rulebook the team can refer to when deciding whether to add a
haptic.

### 2.1 Add a haptic when

1. **The user can't see immediate visual feedback.** A button that
   instantly navigates? Visual is enough. A button that kicks off a
   background save? Add a tap.
2. **Crossing a meaningful threshold.** Toggle flips, segment changes,
   refresh threshold reached.
3. **An outcome is asymmetric.** Success vs failure, accepted vs
   rejected — distinct haptics help.
4. **A destructive or irreversible action is about to fire.** Heavier
   haptic gives the user a half-beat to reconsider.
5. **Long-press / drag begins.** Confirms the gesture engaged.

### 2.2 Skip the haptic when

1. **Scrolling.** Never haptic on scroll.
2. **Every keystroke.** OS handles keyboard haptics already.
3. **Rapid repeating taps** (e.g., number-pad while typing an amount —
   throttle to one haptic per ≥ 100 ms).
4. **Loading shimmer / passive state changes.**
5. **The user has explicitly disabled them in Settings.**

### 2.3 Intensity ladder

Use the lightest haptic that still communicates the event. Reserve
heavy impacts for genuinely consequential actions — overusing them
trains the user to ignore them.

```
selectionClick  →  toggles, segmented controls, picker reels
lightImpact     →  taps on most buttons, nav, list rows, tab change
mediumImpact    →  primary actions (Add expense, Save), pull-to-refresh
                   threshold, dismissible item triggered
heavyImpact     →  destructive confirm (Delete account), validation
                   error, "blocked by business rule" (e.g. 409s)
```

---

## 3. Where in this app (research summary)

Inventory taken from the current `frontend/lib/`:

| Surface                       | Count | Examples                                                   |
| ----------------------------- | ----- | ---------------------------------------------------------- |
| `PrimaryButton` (centralized) | 11    | Save, Login, Add expense, Confirm settlement.              |
| `IconButton`                  | 15    | Back, notification bell, edit pencil, theme toggle.        |
| `TextButton`                  | 49    | Cancel in dialogs, "Forgot password?", inline links.       |
| `ElevatedButton`              | 10    | Inline action buttons not migrated to `PrimaryButton`.     |
| `FloatingActionButton`        | 1     | New expense / add action.                                  |
| `InkWell`                     | 82    | List rows, cards, contact cells.                           |
| `GestureDetector`             | 28    | Custom tap surfaces (e.g. category chips, avatar picker).  |
| `Dismissible`                 | 3     | Swipe-to-delete (expense_card, personal_expense_tile, create_group_screen). |
| `RefreshIndicator`            | 9     | Dashboard, Groups, Group detail, Activities, Notifications, Reports, Personal expenses, Settlements, Expenses. |
| `Switch`                      | 1     | Notification preferences toggle.                           |
| `showDialog`                  | 13    | Confirm-delete dialogs, signout, errors.                   |
| `showModalBottomSheet`        | 15    | Contacts picker, category picker, edit-group sheet, etc.   |
| `showSnackBar`                | 64    | Success / error toasts across every flow.                  |
| `Navigator.push/pop`          | 19    | Route changes.                                             |
| `Slider`, `TabBar`            | 0 / 0 | Not used today (so no slider haptics needed yet).          |

---

## 4. Interaction → haptic mapping (the canonical table)

This is the **single source of truth** the team will follow. Anything
not on this list defaults to "no haptic."

| Interaction                                                            | Haptic              | Why                                            |
| ---------------------------------------------------------------------- | ------------------- | ---------------------------------------------- |
| Tap on `PrimaryButton` (Save, Login, Add expense, etc.)                | `lightImpact`       | Confirms tap was registered.                   |
| Tap on `FloatingActionButton`                                          | `lightImpact`       | Same.                                          |
| Tap on `IconButton` in app bars (back, edit, bell)                     | `lightImpact`       | Same.                                          |
| Tap on a list row / card that navigates                                | `lightImpact`       | Same.                                          |
| Bottom nav tab change                                                  | `selectionClick`    | Crossing a boundary between tabs.              |
| Theme toggle (dark ↔ light)                                            | `selectionClick`    | Discrete boundary.                             |
| `Switch` flip (notification prefs, etc.)                               | `selectionClick`    | Standard pattern.                              |
| Segmented control / period chip (Reports: Month / Quarter / Year)      | `selectionClick`    | Same.                                          |
| Category chip selection                                                | `selectionClick`    | Same.                                          |
| Avatar picker — selecting an avatar option                             | `selectionClick`    | Same.                                          |
| Pull-to-refresh **threshold reached** (before release)                 | `mediumImpact`      | Tells the user "release now to refresh."       |
| `Dismissible` — swipe crosses the dismiss threshold                    | `mediumImpact`      | Confirms the swipe will commit on release.     |
| Long-press on a row (when context menu opens)                          | `mediumImpact`      | Confirms long-press engaged.                   |
| Successful submit — expense added, settlement created, group saved     | `mediumImpact`      | Success confirmation.                          |
| Settlement **confirmed** by recipient                                  | `mediumImpact`      | Important milestone.                           |
| Validation error — form rejected client-side                           | `heavyImpact`       | Asymmetric: errors should feel different.      |
| Backend rejection — 4xx response shown as SnackBar                     | `heavyImpact`       | Same.                                          |
| Destructive confirm dialog — user taps "Delete" / "Sign out everywhere"| `heavyImpact`       | Reinforces the gravity.                        |
| Reminder rate-limit 429 ("Already reminded in last 6 h")               | `heavyImpact`       | The action was blocked.                        |
| OTP — successfully verified                                            | `mediumImpact`      | Crossing the threshold into the app.           |
| OTP — entered wrong / expired                                          | `heavyImpact`       | Same as validation error.                      |
| Login / Logout completed                                               | `mediumImpact`      | Major state transition.                        |
| Onboarding "I agree" / "Get started"                                   | `lightImpact`       | Normal tap; the next screen is the reward.     |
| Profile image picked + saved                                           | `lightImpact`       | Mild confirmation.                             |
| Active session revoked                                                 | `mediumImpact`      | Security-sensitive change.                     |
| Push notification tapped (in-app, deep-link follow)                    | `lightImpact`       | Normal tap.                                    |
| Modal bottom sheet **opens** programmatically                          | none                | The animation itself is the cue.               |
| `showSnackBar` (generic info)                                          | none                | SnackBar is its own affordance.                |
| `showSnackBar` (success-flavored — "Expense added")                    | `mediumImpact`      | Pair the haptic with the success toast.        |
| `showSnackBar` (error-flavored — "Failed to save")                     | `heavyImpact`       | Same.                                          |
| Scrolling lists                                                        | **never**           | Trains users to mute the app.                  |
| Typing into a TextField                                                | **never**           | OS handles keyboard haptics.                   |
| Idle background sync, polling                                          | **never**           | Not user-initiated.                            |

---

## 5. Screen-by-screen recommendations

Concrete spots to wire up haptics, walking through every module.

### 5.1 `modules/auth/`

| Screen                            | Trigger                                             | Haptic           |
| --------------------------------- | --------------------------------------------------- | ---------------- |
| `login_screen.dart`               | Send OTP tap                                         | `lightImpact`    |
| `login_screen.dart`               | OTP digit pad tap (throttle to 1 per 100 ms)         | `selectionClick` |
| `login_screen.dart`               | Verify OTP success → next screen                     | `mediumImpact`   |
| `login_screen.dart`               | Verify OTP wrong / expired                           | `heavyImpact`    |
| `forgot_password_screen.dart`     | Send email tap                                       | `lightImpact`    |
| `profile_setup_screen.dart`       | "Continue" with empty name (validation)              | `heavyImpact`    |
| `profile_setup_screen.dart`       | Successfully saved profile → home                    | `mediumImpact`   |

### 5.2 `modules/onboarding/`

| Screen                            | Trigger                                             | Haptic           |
| --------------------------------- | --------------------------------------------------- | ---------------- |
| `onboarding_screen.dart`          | Next / Skip button taps                              | `lightImpact`    |
| `onboarding_screen.dart`          | "Get started" final CTA                              | `mediumImpact`   |

### 5.3 `modules/dashboard/`

| Surface                                       | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `dashboard_screen.dart`                       | Pull-to-refresh threshold                | `mediumImpact`   |
| `dashboard_screen.dart`                       | Tap balance card (drill-down)            | `lightImpact`    |
| `dashboard_screen.dart`                       | Tap recent expense row                   | `lightImpact`    |
| `dashboard_screen.dart`                       | FAB (Add expense)                        | `lightImpact`    |
| `friends_screen.dart`                         | Tap friend row → friend detail           | `lightImpact`    |

### 5.4 `modules/groups/`

| Screen                                        | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `groups_screen.dart`                          | Pull-to-refresh threshold                | `mediumImpact`   |
| `groups_screen.dart`                          | Tap a group card                         | `lightImpact`    |
| `create_group_screen.dart`                    | "Add member from contacts"               | `lightImpact`    |
| `create_group_screen.dart`                    | Dismissible swipe (remove pending member) crosses threshold | `mediumImpact`   |
| `create_group_screen.dart`                    | "Create group" success                   | `mediumImpact`   |
| `create_group_screen.dart`                    | Validation failed (name empty)           | `heavyImpact`    |
| `group_detail_screen.dart`                    | Tab/segment change inside the screen     | `selectionClick` |
| `group_detail_screen.dart`                    | "Settle up" / "Add expense" inside group | `lightImpact`    |
| `group_detail_screen.dart`                    | Reminder sent successfully               | `mediumImpact`   |
| `group_detail_screen.dart`                    | Reminder 429 (too soon)                  | `heavyImpact`    |
| `group_detail_screen.dart`                    | Leave-group confirm                      | `heavyImpact`    |
| `contacts_picker_sheet.dart` (widget)         | Toggle a contact (selecting / deselecting)| `selectionClick`|

### 5.5 `modules/expenses/`

| Screen                                        | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `expenses_screen.dart`                        | Pull-to-refresh threshold                | `mediumImpact`   |
| `expenses_screen.dart`                        | Tap an expense row                       | `lightImpact`    |
| `add_expense_screen.dart`                     | Category chip selected                   | `selectionClick` |
| `add_expense_screen.dart`                     | Split-type segment change                | `selectionClick` |
| `add_expense_screen.dart`                     | Participant toggled on/off               | `selectionClick` |
| `add_expense_screen.dart`                     | "Save expense" success                   | `mediumImpact`   |
| `add_expense_screen.dart`                     | Validation failed (splits don't sum)     | `heavyImpact`    |
| `expense_card.dart` (component)               | Dismissible crosses delete threshold     | `mediumImpact`   |
| `expense_card.dart` (component)               | Delete confirm tap                       | `heavyImpact`    |

### 5.6 `modules/settlements/`

| Screen                                        | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `settlements_screen.dart`                     | Pull-to-refresh threshold                | `mediumImpact`   |
| `settlements_screen.dart`                     | Tap a settlement row                     | `lightImpact`    |
| `create_settlement_screen.dart`               | Amount input → "Mark as paid" tap        | `lightImpact`    |
| `create_settlement_screen.dart`               | Successful create                        | `mediumImpact`   |
| `create_settlement_screen.dart`               | 409 conflict (pending exists)            | `heavyImpact`    |
| Settlement detail / confirm row               | Recipient confirms                       | `mediumImpact`   |
| Settlement detail / confirm row               | Delete settlement                        | `heavyImpact`    |

### 5.7 `modules/personal_expenses/`

| Screen / Widget                               | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `personal_expenses_screen.dart`               | Pull-to-refresh threshold                | `mediumImpact`   |
| `personal_expenses_screen.dart`               | Tap row                                  | `lightImpact`    |
| `add_personal_expense_screen.dart`            | Save success / validation error          | medium / heavy   |
| `personal_expense_tile.dart`                  | Dismissible threshold                    | `mediumImpact`   |

### 5.8 `modules/activity/` and `modules/notifications/`

| Surface                                       | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| Activities list                               | Pull-to-refresh threshold                | `mediumImpact`   |
| Activity row tap                              | Mark read + open deep link               | `lightImpact`    |
| "Mark all read" tap                           |                                          | `lightImpact`    |
| Notifications inbox row                       | Tap                                      | `lightImpact`    |

### 5.9 `modules/reports/`

| Surface                                       | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `reports_screen.dart`                         | Period chip change (Month / Quarter / Year) | `selectionClick` |
| `reports_screen.dart`                         | Pull-to-refresh threshold                | `mediumImpact`   |
| `reports_screen.dart`                         | Category drill-down tap                  | `lightImpact`    |

### 5.10 `modules/profile/`

| Screen                                        | Trigger                                  | Haptic           |
| --------------------------------------------- | ---------------------------------------- | ---------------- |
| `profile_screen.dart`                         | Theme toggle (dark/light)                | `selectionClick` |
| `profile_screen.dart`                         | Any row tap (Edit profile, Security, etc.) | `lightImpact`  |
| `edit_profile_screen.dart`                    | Save success / validation                | medium / heavy   |
| `edit_profile_screen.dart`                    | Avatar picked                            | `lightImpact`    |
| `notifications_settings_screen.dart`          | Each toggle flip                         | `selectionClick` |
| `notifications_settings_screen.dart`          | **NEW**: "Haptic feedback" master toggle | `selectionClick` |
| `security_screen.dart`                        | Open Active sessions / Download data     | `lightImpact`    |
| `security_screen.dart`                        | "Delete account" confirm                 | `heavyImpact`    |
| `active_sessions_screen.dart`                 | Pull-to-refresh threshold                | `mediumImpact`   |
| `active_sessions_screen.dart`                 | Revoke one session                       | `mediumImpact`   |
| `active_sessions_screen.dart`                 | "Sign out everywhere" confirm            | `heavyImpact`    |
| `policy_screen.dart`                          | Pure-read screen                         | (none)           |

### 5.11 Shared components (single touch-point per pattern)

These are the highest-leverage places — one edit fans out everywhere.

| File                                            | Add                                                                |
| ----------------------------------------------- | ------------------------------------------------------------------ |
| `components/buttons/primary_button.dart`        | `lightImpact` wrapped around `onPressed` (covers 11 sites).        |
| `components/bottom_navigation_bar.dart`         | `selectionClick` when index changes.                               |
| `components/cards/expense_card.dart`            | `mediumImpact` at Dismissible's `confirmDismiss`.                  |
| `components/states/error_state.dart` (if any)   | `heavyImpact` on appearance (debounced once per mount).            |
| Snackbar helper (if one exists, else create)    | Variants: `showSuccessSnack` → medium, `showErrorSnack` → heavy.    |

---

## 6. Architecture — central `HapticService`

Do **not** sprinkle `HapticFeedback.lightImpact()` directly across the
codebase. We need a single throttled, preference-aware service so that:

- The user-level toggle (Settings → Haptic feedback) is honored
  consistently.
- Per-event haptics are throttled (rapid repeats collapse into one).
- Web / unsupported platforms are short-circuited cheaply.
- Future swap to a richer library (e.g. `gaptic_feedback` with iOS
  success/warning patterns) is a one-file change.

### 6.1 Files to add

```
frontend/lib/core/services/haptic_service.dart      # the service
frontend/lib/core/state/haptic_provider.dart        # Riverpod NotifierProvider
frontend/lib/core/persistence/haptic_prefs.dart     # SharedPreferences-backed flag
```

### 6.2 Public API (sketch)

```dart
class HapticService {
  HapticService(this._ref);
  final Ref _ref;

  // Semantic methods (preferred — they encode intent, not intensity)
  void tap()       => _fire(HapticIntensity.light);
  void selection() => _fire(HapticIntensity.selection);
  void success()   => _fire(HapticIntensity.medium);
  void warning()   => _fire(HapticIntensity.medium);
  void error()     => _fire(HapticIntensity.heavy);
  void destructive() => _fire(HapticIntensity.heavy);

  // For pull-to-refresh threshold, Dismissible threshold, long-press start
  void thresholdCrossed() => _fire(HapticIntensity.medium);

  // Lower-level escape hatch (use semantic methods above whenever possible)
  void custom(HapticIntensity intensity) => _fire(intensity);

  void _fire(HapticIntensity intensity) {
    if (!_ref.read(hapticEnabledProvider)) return;       // user opt-out
    if (kIsWeb) return;                                  // no-op on web
    if (!_throttle(intensity)) return;                   // 80 ms throttle
    switch (intensity) {
      case HapticIntensity.selection: HapticFeedback.selectionClick(); break;
      case HapticIntensity.light:     HapticFeedback.lightImpact();    break;
      case HapticIntensity.medium:    HapticFeedback.mediumImpact();   break;
      case HapticIntensity.heavy:     HapticFeedback.heavyImpact();    break;
    }
  }
}
```

### 6.3 Usage in widgets

```dart
final haptic = ref.read(hapticServiceProvider);

PrimaryButton(
  label: 'Save',
  onPressed: () {
    haptic.tap();
    saveExpense();
  },
);
```

Or for the central wrappers:

```dart
// inside primary_button.dart
ElevatedButton(
  onPressed: onPressed == null ? null : () {
    HapticServiceLocator.instance.tap();
    onPressed!();
  },
  ...
);
```

> **Tip:** prefer Riverpod (`ref.read(hapticServiceProvider).tap()`)
> inside Consumer widgets so the toggle propagates reactively. Use a
> static locator only in components that don't already have `ref`
> access (the central buttons).

---

## 7. User-controlled setting

Add a master toggle so users who find haptics annoying can switch them
off in one place. Persist locally — this is a device preference, not a
cloud one.

- Location: **Profile → Notifications & feedback** (rename the existing
  "Notifications" screen sub-header, or add a sibling
  "Vibration & feedback" section under it).
- Storage: `SharedPreferences` key `pref.haptics_enabled` (default
  `true`).
- Exposed as `hapticEnabledProvider` (Riverpod
  `NotifierProvider<bool>`).
- When the user flips it OFF, fire **one** `selectionClick` first so
  they hear the goodbye click; then store `false`. When they flip it
  back ON, fire a `mediumImpact` ("welcome back").

Future iterations could add per-category toggles (Settings → Haptics →
"Success", "Errors", "Selection") — but ship the master switch first.

---

## 8. Accessibility considerations

- **Respect the OS-level setting.** On iOS, if the user has disabled
  System Haptics in Settings → Sounds & Haptics, our calls are
  effectively no-ops anyway — but we should not *also* show
  "Haptics: ON" in our UI in that case. Display the in-app toggle as
  the *cap*, with a helper line "Subject to your phone's haptic
  settings."
- **Vibration permission** on Android: the basic vibration API does
  NOT require the `VIBRATE` permission for `HapticFeedback.*` because
  Flutter routes through the `View.performHapticFeedback` channel.
  No `AndroidManifest.xml` change is needed.
- **Reduced motion / low-power mode**: iOS in Low Power Mode often
  suppresses non-essential haptics. That's fine — let the OS decide.
- **Hearing-impaired users**: keep haptics *additive*, never the *only*
  signal. Every haptic must pair with a visual cue (button press
  state, SnackBar, dialog, animation).

---

## 9. Implementation phases

Suggested rollout — ship something small first, expand only after we
see how it feels in real use.

### Phase 1 — Foundation (≈ 4 h)

- [ ] Add `core/services/haptic_service.dart` + Riverpod provider.
- [ ] Add `core/persistence/haptic_prefs.dart` (SharedPreferences).
- [ ] Wire master toggle into `notifications_settings_screen.dart`.
- [ ] Centralized hits — fan-out covers ~60% of interactions:
  - [ ] `components/buttons/primary_button.dart` → light tap.
  - [ ] `components/bottom_navigation_bar.dart` → selection click on index change.
  - [ ] `components/cards/expense_card.dart` → medium impact at Dismissible threshold.
- [ ] Sanity test on real Android + iOS device.

**Deliverable:** every PrimaryButton, every bottom-nav tab change, and
every swipe-to-delete on the expense card vibrates. The user can turn
it all off.

### Phase 2 — High-signal flows (≈ 4 h)

- [ ] `add_expense_screen.dart` (category chips, split-type segment, save success, validation error).
- [ ] `create_settlement_screen.dart` (success, 409 conflict).
- [ ] `group_detail_screen.dart` (reminder sent, reminder 429, leave-group confirm).
- [ ] All 9 `RefreshIndicator` screens → medium impact when threshold is crossed (use `RefreshIndicator.onRefresh` or a custom physics callback).
- [ ] OTP verify success / failure on `login_screen.dart`.

### Phase 3 — Polish (≈ 3 h)

- [ ] Theme toggle, profile rows, security destructive confirms.
- [ ] Avatar picker, category picker, contact picker bottom sheets.
- [ ] Snackbar helper variants (`showSuccessSnack` / `showErrorSnack`)
  with paired haptic — refactor the 64 existing `showSnackBar` call sites
  in pull requests of ≤ 10 sites each.

### Phase 4 — Optional richer haptics

- [ ] Evaluate the `gaptic_feedback` package for iOS-native
  success/warning/error patterns.
- [ ] If adopted, swap the implementation inside `HapticService` — no
  call-site changes needed.

---

## 10. QA matrix

Test on **both** platforms — iOS haptics feel very different from
Android's vibration motor.

| Device                                    | What to check                                                                 |
| ----------------------------------------- | ----------------------------------------------------------------------------- |
| iPhone (anything with Taptic Engine)      | All four intensities (`selectionClick`, `light`, `medium`, `heavy`) feel distinct. |
| Android — modern (Pixel 6+, S22+)         | All four feel distinct.                                                       |
| Android — budget (vibration motor only)   | Light + selection may feel similar — verify it's not annoying.                |
| iPhone with System Haptics OFF            | App makes no haptic sound; visual flows still work.                           |
| Android with vibration disabled           | Same.                                                                         |
| Master toggle OFF in app                   | Zero haptics anywhere, regardless of OS settings.                              |
| Master toggle ON, scrolling a long list    | NO haptics fire (regression guard).                                            |
| Master toggle ON, typing in TextField      | NO extra haptics (only the OS keyboard's own).                                 |
| Master toggle ON, rapid double-tap a button| Single haptic (throttle works).                                                |
| Web build                                  | No errors thrown; no haptic attempted.                                         |

---

## 11. Risks & open questions

| Risk                                                                | Mitigation                                                        |
| ------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Haptic fatigue if too many fire                                     | Strict mapping table (Section 4); only the listed events.         |
| Battery drain                                                       | Default ON but expose toggle; haptics themselves are very low-power. |
| Cheap Android motors feel buzzy / cheap                             | Manual QA on a budget device before shipping Phase 1.             |
| Pull-to-refresh haptic timing depends on physics                    | May need a custom `RefreshIndicator` wrapper that fires at the threshold; ship Phase 2 with a stopwatch test. |
| Dismissible threshold timing                                        | Same — use `confirmDismiss` callback, not `onDismissed`, so it fires *before* commit. |

### Open questions for the team

1. Default state of the master toggle — **ON** or **OFF**? Recommend
   ON (most modern apps ship with haptics on by default).
2. Do we want per-category toggles in Settings now, or after launch?
   Recommend later — start simple.
3. Do we want a Web-only fallback "flash" animation in lieu of haptics?
   Recommend no — keep web behavior plain.

---

## 12. Estimated effort

| Phase     | Effort   | Risk    | Outcome                                                |
| --------- | -------- | ------- | ------------------------------------------------------ |
| Phase 1   | ~4 h     | Low     | Service + master toggle + 3 central touch-points.      |
| Phase 2   | ~4 h     | Medium  | High-signal flows + 9 refresh threshold haptics.       |
| Phase 3   | ~3 h     | Low     | Polish + snackbar helper + remaining call sites.       |
| Phase 4   | optional | Low     | Richer iOS-native success/warning/error patterns.      |
| **Total (P1–P3)** | **~11 h** |       | App-wide tasteful haptic coverage.                     |

---

## 13. One-line summary

> Build a `HapticService` gated by a user-controlled toggle, wire it
> through the four central widgets (`PrimaryButton`,
> `BottomNavigationBar`, `expense_card`, snackbar helper) for instant
> 60% coverage, then layer in the per-screen events from the mapping
> table in Section 4. Ship it in three small phases.
