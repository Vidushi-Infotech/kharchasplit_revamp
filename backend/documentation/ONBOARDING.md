# KharchaSplit — Onboarding Process

How a new user goes from app launch to having a usable account, and how an
existing user is reconnected on subsequent launches.

Audience: anyone working on the auth flow, splash logic, or invite-driven
join paths. See also [USER_FEATURES.md](USER_FEATURES.md) and
[ADMIN_FEATURES.md](ADMIN_FEATURES.md).

---

## 1. Flow at a glance

```
            ┌──────────────────────┐
            │ App launch           │
            │ /  (Splash)          │
            └─────────┬────────────┘
                      │ check stored token in flutter_secure_storage
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
   Authenticated              Unauthenticated / first run
   /home/dashboard            /onboarding (3 swipeable slides + Skip)
                                          │
                                          ▼
                                /login   ──or──   /register
                                      │
                                      ▼
                                /verify-otp   (6-digit code)
                                      │
                                      ▼
                                /home/dashboard
                                      │
                              (optional, lazy)
                                      ▼
                          Personal Expenses → Wallet setup sheet
```

---

## 2. Splash routing (`/`)

File: [splash_screen.dart](../../frontend/lib/presentation/screens/splash/splash_screen.dart)

- The splash provider boots, restores the secure-storage token, and resolves
  to one of three states: `initializing`, `authenticated`, or
  `unauthenticated`.
- A `ref.listen` redirects:
  - `authenticated` → `/home/dashboard`
  - `unauthenticated` / `ready` → `/onboarding`
- A logo + spinner is shown while the token check completes.

The token blob includes the access token, refresh token, and a cached
`UserModel` so the dashboard can render immediately after login on cold start.

---

## 3. Onboarding tour (`/onboarding`)

Files:
- [onboarding_screen.dart](../../frontend/lib/presentation/screens/onboarding/onboarding_screen.dart)
- [onboarding_constants.dart](../../frontend/lib/core/constants/onboarding_constants.dart)
- [onboarding_provider.dart](../../frontend/lib/presentation/screens/onboarding/onboarding_provider.dart)

A three-page swipeable carousel with a top-right **Skip Tour** button:

| # | Heading                       | Description                                             |
|---|-------------------------------|---------------------------------------------------------|
| 1 | Effortless Expense Sharing    | Easily split bills with friends and family              |
| 2 | Track Expenses                | Keep track of who owes what and settle up easily        |
| 3 | Manage Groups                 | Create groups for trips, events, and more               |

Layout adapts to width:
- < 600 px: full-width PageView with bottom dots indicator
- 600–1100 px: tablet PageView, larger illustrations
- > 1100 px: all three slides shown side-by-side (no swipe needed)

The dots indicator is interactive on mobile/tablet (tap any dot to jump).

> **Status note.** `OnboardingNotifier.skipOnboarding()` currently has a TODO
> — it doesn't actually navigate. The user must be navigated forward to
> `/login` or `/register` from the host shell after the tour completes; the
> splash router does this on next launch by recognising the unauthenticated
> state.

---

## 4. Authentication — phone + OTP

KharchaSplit is a **phone-first** app. Email is optional. There is no
password.

### 4.1 Register a brand-new account

Endpoint: `POST /api/v1/auth/register`
File: [authController.js → register](../src/controllers/authController.js)

Body:
```json
{
  "phoneNumber": "+919876543210",
  "name": "Atharv Prasad",
  "email": "atharv@example.com"
}
```

Behaviour:
1. Validates the phone is in E.164 form. The mobile client auto-prefixes
   `+91` to bare 10-digit Indian numbers.
2. Creates the `users` row.
3. **Invite reconciliation** — if any `pending_invites` row matches this
   `phoneNumber`, the user is auto-added to those groups (`group_members`
   inserted, pending invite row consumed). A note in the response indicates
   how many groups the user joined.
4. Generates a 6-digit OTP, stores it (hashed + expiry) in `otps`, and
   issues an SMS (currently a stub — see §4.4).
5. Returns success with a flag indicating an OTP has been sent.

### 4.2 Sign in (returning user)

Endpoint: `POST /api/v1/auth/send-otp`

Body:
```json
{ "phoneNumber": "+919876543210" }
```

- Finds the user row. Returns 404 with "User not found. Please register
  first." if no match.
- Generates and stores a fresh OTP. Old OTPs for the same phone remain
  valid until expiry but each new request issues a new code.

### 4.3 Verify OTP and exchange for tokens

Endpoint: `POST /api/v1/auth/verify-otp`
File: [authController.js → verifyOTP](../src/controllers/authController.js)

Body:
```json
{ "phoneNumber": "+919876543210", "otp": "123456" }
```

Returns on success:
```json
{
  "success": true,
  "data": {
    "user":          { /* UserModel JSON */ },
    "accessToken":   "<jwt>",
    "refreshToken":  "<opaque>"
  }
}
```

The mobile client persists both tokens + the user blob to secure storage and
routes to `/home/dashboard`.

### 4.4 Dev OTP shortcut

`process.env.NODE_ENV !== 'production'` accepts the master OTP **`123456`**
for any phone, bypassing the `otps` table check. SMS delivery is currently a
stub, so without this every dev login would be blocked.

> ⚠️ Make sure to disable this in production by setting `NODE_ENV=production`.

### 4.5 Refresh & logout

| Endpoint                 | Purpose                                           |
|--------------------------|---------------------------------------------------|
| `POST /auth/refresh`     | Trade a valid refresh token for a new access JWT (auto-called by Dio interceptor on 401) |
| `POST /auth/logout`      | Revoke the refresh token; client clears storage    |
| `POST /auth/simple-login`| Dev-only password-less login by phone (no OTP) for QA |

Refresh tokens are stored server-side (`refresh_tokens` table) with a 30-day
expiry. Logout deletes the token row.

---

## 5. Invite-driven joining (zero-config onboarding for invitees)

Files:
- Backend: [groupController.js → addPendingMember](../src/controllers/groupController.js)
- Frontend: contacts picker → `groupsRepository.invitePhone()` → `POST /groups/:id/pending-members`

When a member taps **Add member** in a group:

1. The picker shows real device contacts. Numbers already on KharchaSplit
   are flagged with the **Add** chip; unregistered numbers get **Add &
   Invite**. Existing group members show a disabled **Added** chip.
2. For **registered** invitees: backend immediately inserts them into
   `group_members`. They appear in the group on their next sync.
3. For **unregistered** invitees:
   - A row is inserted into `pending_invites` keyed by phone number.
   - A **WhatsApp message** is dispatched via WATI (template message with a
     deep-link / share text).
   - A **placeholder** user is created so balances and splits can include
     them immediately, even before they sign up.
4. When the invitee later registers (§4.1), the auto-reconciliation step
   replaces the placeholder with the real user, consumes the pending invite,
   and they show up in the group with full edit access on their next refresh.

There is no separate "accept invite" UI to navigate — joining is implicit
once the phone numbers match.

---

## 6. First-time wallet setup (Personal Expenses)

The first time a user opens the **Personal Expenses** tab, a bottom sheet
prompts them to set their wallet balance and add at least one source
(Cash / UPI / Card / Bank). State is local-only via `SharedPreferences`; no
backend call.

After this one-time setup, the tab opens directly to the expenses list and
the keyboard auto-focuses on the amount field when adding a new expense.

---

## 7. Notifications & FCM token registration

After login, the mobile client:

1. Requests notification permission.
2. Fetches the FCM token from Firebase Messaging.
3. Calls `PUT /users/:id/fcm-token` to register it server-side.

Token refreshes (Firebase rotates them periodically) trigger the same
endpoint. On logout, the client calls `DELETE /users/:id/fcm-token` to stop
delivery.

---

## 8. Edge cases & error states handled

| Scenario                                  | Behaviour                                                    |
|-------------------------------------------|--------------------------------------------------------------|
| Phone not registered, user tries Send OTP | 404 "User not found. Please register first."                 |
| Wrong OTP                                 | 401 "Invalid or expired OTP"                                 |
| Expired access token mid-session          | Dio interceptor auto-refreshes; user never sees a logout    |
| Refresh token also expired                | Client clears storage, navigates to `/login`                 |
| Dashboard fails to load on cold start     | Shows error state with Retry; auth is preserved              |
| User on a stale group ID (deleted/removed) | 403 / 404 surfaced with "Back to Groups" action            |
| WhatsApp invite delivery fails (WATI)     | Member is still added (registered) or still placeheld; toast surfaces the WATI error to the inviter |

---

## 9. Implementation files

| Concern                    | File                                                                                  |
|----------------------------|---------------------------------------------------------------------------------------|
| Splash + auth bootstrap    | `frontend/lib/presentation/screens/splash/`                                           |
| Onboarding tour            | `frontend/lib/presentation/screens/onboarding/`                                       |
| Auth screens               | `frontend/lib/modules/auth/screens/` (login, register, otp, forgot)                   |
| Auth state / token storage | `frontend/lib/modules/auth/state/auth_provider.dart`                                  |
| Auth API client            | `frontend/lib/data/auth/auth_repository.dart`                                         |
| Backend auth routes        | `backend/src/routes/authRoutes.js` + `controllers/authController.js`                  |
| Pending-invite reconcile   | `backend/src/controllers/authController.js → register` + `controllers/inviteController.js` |
| WhatsApp delivery (WATI)   | `backend/src/services/whatsappService.js` (or wherever WATI client lives)             |
| FCM token register/remove  | `backend/src/controllers/userController.js → updateFcmToken / removeFcmToken`         |
