# KharchaSplit — Full System Architecture

End-to-end view: how the Flutter client, Express API, PostgreSQL, and the
external services (Firebase Cloud Messaging, WATI WhatsApp) fit together.

For deeper component details:

- [FRONTEND_ARCHITECTURE.md](FRONTEND_ARCHITECTURE.md)
- [BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md)
- [API_REFERENCE.md](API_REFERENCE.md)
- [ONBOARDING.md](ONBOARDING.md)

---

## 1. Topology

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              Mobile device                               │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                  Flutter app (Android / iOS / Web)                 │  │
│  │                                                                    │  │
│  │   UI (Riverpod consumers) ─► State providers ─► Repositories       │  │
│  │                                                       │            │  │
│  │   ┌──────────── flutter_secure_storage ──────────────┘            │  │
│  │   │  accessToken / refreshToken / cached UserModel                  │  │
│  │   │                                                                 │  │
│  │   └─► Dio (ApiClient + AuthInterceptor) ─────► HTTPS / JSON         │  │
│  │                                                                    │  │
│  │   Firebase Messaging SDK ◄────────────── push notifications         │  │
│  └──────────┬─────────────────────────────────────────────────────────┘  │
└─────────────┼────────────────────────────────────────────────────────────┘
              │
              │ 1. REST   GET/POST/PUT/DELETE  /api/v1/*
              │           Authorization: Bearer <jwt>
              │           { success, data | error }
              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                          Backend (Node + Express)                        │
│                                                                          │
│  helmet → cors → morgan → compression → json → rate-limit                │
│       │                                                                  │
│       ▼                                                                  │
│   Routes ─► Controllers ─► Services / Models ─► pg.Pool ─► PostgreSQL    │
│                          │                                               │
│                          ├─► cacheService (in-process LRU + TTL)         │
│                          ├─► activityService (writes activities row)     │
│                          ├─► notificationService ─► Firebase Admin SDK   │
│                          └─► watiService ─► WATI HTTP API                │
└─────────────────┬────────────────────────────┬───────────────┬───────────┘
                  │                            │               │
                  ▼                            ▼               ▼
          ┌──────────────┐            ┌──────────────┐   ┌──────────────┐
          │  PostgreSQL  │            │  Firebase    │   │     WATI     │
          │  (pg pool)   │            │   FCM        │   │  WhatsApp    │
          └──────────────┘            └──────┬───────┘   └──────┬───────┘
                                             │                  │
                                             ▼                  ▼
                                       Mobile device        Invitee's
                                       (push)               WhatsApp
```

---

## 2. Components at a glance

| Component        | Owner / location                        | Responsibility                                     |
|------------------|-----------------------------------------|----------------------------------------------------|
| Flutter app      | `frontend/`                             | All UX; auth state; pairwise debt UI; offline-friendly local persistence (theme, wallet) |
| API server       | `backend/`                              | Source of truth for groups/expenses/settlements; auth; activity log emit; push + WhatsApp dispatch |
| PostgreSQL       | self-hosted / managed                   | Persistent state: users, groups, expenses, splits, settlements, activities, OTPs, refresh tokens |
| In-process cache | `backend/src/services/cacheService.js`  | Read amplification for hot reads (group balances, expenses)             |
| Firebase Admin   | external                                | Reliable push delivery to Android/iOS                                   |
| WATI             | external                                | Outbound WhatsApp template messages for invitations                     |
| flutter_secure_storage | OS keystore                       | Tokens + cached UserModel for cold-start UX                             |

The backend is **stateless** apart from the in-process cache. Two instances
behind a load balancer would work today, but the cache wouldn't be shared
between them — the documented Redis swap is the path to horizontal scale.

---

## 3. Request paths — three representative flows

### 3.1 Cold-start launch

```
[App opens]
  → Splash screen (Flutter)
  → flutter_secure_storage.read(accessToken, refreshToken, user)
  ├─ has token → context.go('/home/dashboard')
  │    → DashboardProvider.build() → GET /users/:id/dashboard (Authorization: Bearer)
  │    → ApiClient → AuthInterceptor adds header
  │    → backend authenticate() → query users → controller
  │    → balances + recent expenses (single SQL UNION ALL) → JSON
  │    → repo → model → provider → screen renders
  │
  └─ no token → context.go('/onboarding')
       → 3 swipeable slides → /login
       → POST /auth/send-otp → backend generates OTP → SMS stub
       → POST /auth/verify-otp { phoneNumber, otp }
       → backend issues access + refresh
       → secure_storage.write → context.go('/home/dashboard')
```

### 3.2 Add an expense

```
[User taps + on group screen]
  → AddExpenseScreen
  → user picks Equally / Unequally / By % / By Shares
  → tap Save
  → AddExpenseScreen._handleSave builds participants list including
    `percentage` / `shares` when relevant
  → ExpensesRepository.create()
  → POST /expenses { groupId, participants, splitType, … }
  → backend authenticate()
  → expenseController.create
       → Group.findById  (validate access)
       → Expense.create    (transaction: INSERT expense + INSERT splits)
       → Expense.invalidateGroupExpenses(groupId)  ← cache key sweep
       → ActivityService.logExpenseAdded
       → NotificationService.notifyExpenseAdded   (FCM async; failures swallowed)
  → JSON success
  → client invalidates groupDetailProvider + dashboardProvider
  → UI re-fetches → fresh card appears
```

### 3.3 Add a member from contacts (with WhatsApp invite)

```
[User taps Add member in group menu]
  → showContactsPicker (real device contacts via flutter_contacts)
  → existing-member phones tagged "Added" (disabled)
  → user selects N contacts → tap Add
  → for each contact → POST /groups/:id/pending-members { name, phoneNumber }
  → backend:
       case A: phoneNumber matches an existing user
              → Group.addMember (INSERT group_members)
              → ActivityService.logMemberAdded
              → NotificationService.notifyAddedToGroup → FCM
       case B: phoneNumber is new
              → User.createPlaceholder (is_placeholder = true)
              → Group.addMember (placeholder counts in splits)
              → pending_invites row created
              → watiService.sendInviteTemplate → WhatsApp
  → JSON success per contact
  → client invalidates groupDetailProvider + groupsProvider
  → snackbar: "N added · M failed" (with reasons)
```

When the placeholder later registers via `POST /auth/register`, the backend
auto-reconciles the pending invite (see [ONBOARDING.md §5](ONBOARDING.md#5-invite-driven-joining-zero-config-onboarding-for-invitees)).

---

## 4. Authentication & session model

```
Flutter                      Express                       Postgres
   │                            │                            │
   │ POST /auth/send-otp        │                            │
   │───────────────────────────►│ INSERT INTO otps           │
   │                            │───────────────────────────►│
   │                            │ (SMS stub or 123456 dev)   │
   │ POST /auth/verify-otp      │                            │
   │───────────────────────────►│ SELECT … FROM otps         │
   │                            │ UPDATE otps SET verified   │
   │                            │ INSERT INTO refresh_tokens │
   │                            │ jwt.sign(access, refresh)  │
   │  ◄─── { user, tokens } ────│                            │
   │                            │                            │
   │ secure_storage.write       │                            │
   │                            │                            │
   │ ── any authenticated call ►│ JWT verify (in middleware) │
   │                            │ load user → req.user       │
   │                            │                            │
   │ ── 401 from any call ─────►│ AuthInterceptor catches    │
   │ POST /auth/refresh         │ verify refresh             │
   │───────────────────────────►│ INSERT new refresh, revoke │
   │  ◄─── new tokens ──────────│                            │
   │ retry original request     │                            │
```

Tokens:
- **Access**: short-lived JWT, signed with `JWT_SECRET`. Sent on every request.
- **Refresh**: long-lived (30 days), persisted in `refresh_tokens` table so
  the server can revoke. Rotated on every successful refresh.

---

## 5. Data flow patterns

### 5.1 Read-heavy (dashboard / balances)

```
Client read ──► /api/v1/...
              │
              ├── controller hands key to cacheService
              │       │
              │       ├── HIT  → JSON
              │       └── MISS → SQL → cache.set(ttl) → JSON
              │
              └── client repo → model → provider → UI
```

Hot keys: `group:<id>:balances`, `group:<id>:expenses:<page>`. TTL ~60–120s.
Writes that can change them call `cache.invalidate('group:<id>')` so the
next read computes fresh.

### 5.2 Write-followed-by-effects

```
Write request
   │
   ▼
controller orchestrates:
   1. SQL write (transaction if multi-row)
   2. cache.invalidate(prefix)
   3. activityService.log...   (synchronous DB insert)
   4. notificationService.notify...   (async; errors logged + swallowed)
   │
   ▼
JSON response

(separately) FCM dispatches push to all relevant FCM tokens
```

`notifyXxx` calls are wrapped in `try/catch` — a failed FCM send never
fails the user-facing request. The activity log is in-band so the user can
see their own action in their feed immediately.

### 5.3 Pairwise debts (the core model)

Both client and server agree on this math (the client mirrors the server so
the Balances tab can re-render without a network round-trip after each
settlement):

```
For each non-deleted expense in the group:
    paidBy = expense.paid_by_id
    for each split (user_id, amount):
        if paidBy != user_id:
            balance[paidBy]   += amount   // they're owed this much
            balance[user_id]  -= amount   // they owe this much

For each non-failed/cancelled settlement:
    balance[from_user_id]  += amount     // they paid → their debt shrinks
    balance[to_user_id]    -= amount     // they received → their claim shrinks
```

The Balances tab on the client builds *pairwise* totals (me ↔ each other
member) using the same expense + settlement passes, then filters to
`> 0.01` for "You owe" and `< -0.01` for "Owed to you".

---

## 6. External integrations

| Integration | Direction | Trigger                                                            | Failure policy                              |
|-------------|-----------|--------------------------------------------------------------------|---------------------------------------------|
| Firebase FCM | Out      | `notificationService.*` after every group/expense/settlement event  | Logged + swallowed (UX request still succeeds) |
| WATI WhatsApp | Out      | `watiService.sendInviteTemplate` when adding an unregistered phone | Surfaced in response so the inviter sees it |
| SMS OTP     | Out (stub)| `otp.sendOTPviaSMS` during register / send-otp                      | Currently a no-op; dev OTP `123456` covers it |

Adding a new external integration: drop a service file under
`backend/src/services/` exposing a small async API; call it from the
controller; gate failure surfacing to the client based on whether the user
needs to know.

---

## 7. Persistence boundary

| What                          | Where                                          | Lifetime                  |
|-------------------------------|------------------------------------------------|---------------------------|
| Authoritative state           | PostgreSQL                                     | Forever (soft-deleted)    |
| Hot read cache                | Backend in-process LRU                         | TTL seconds, evicted on write |
| Auth tokens + cached user blob | flutter_secure_storage (OS keystore)          | Until logout / clear      |
| Theme preference              | shared_preferences                             | Per-device                |
| Wallet balance + sources      | shared_preferences                             | Per-device, never synced  |
| Onboarding-seen flag          | shared_preferences                             | Per-device                |

The **wallet** (Personal Expenses tab) is intentionally local-only — there
is no backend representation today. Expanding it to multi-device sync would
require a new `user_wallets` / `wallet_sources` schema.

---

## 8. Security posture

- HTTPS enforced at the deployment edge (assumed). Backend itself binds to
  HTTP; TLS termination is upstream.
- `helmet` adds standard security headers; `cors` is configured for the
  client origin(s) only.
- `express-rate-limit` throttles per-IP to bound brute-force OTP attempts.
- Tokens stored in OS keystore (not localStorage / Hive in clear).
- SQL exclusively via `pg` parameterised queries — no string interpolation.
- Soft deletes preserve audit trails; hard deletes only in dev tooling.
- Authorization is layered: `authenticate` → `validateGroupAccess` →
  `validateAdminAccess` (when admin-only).
- Sensitive endpoints add explicit business gates (delete-group only when
  all settled; leave only when own pairwise zero; delete-expense only by
  payer).

Known gaps to address before production:
- SMS dispatch is a stub.
- `simple-login` dev endpoint still exists; remove for prod build.
- No structured logging / metrics export.
- No background sweep of expired OTPs / refresh tokens.

---

## 9. Deployment shape

Target topology (suggested):

```
        Cloudflare / nginx (TLS termination, optional CDN)
                 │
                 ▼
        ┌─────────────────┐
        │  Express server │   stateless; can scale horizontally
        │  (node + pm2)   │   if cache is moved to Redis
        └────────┬────────┘
                 │
                 ▼
        ┌─────────────────┐
        │  PostgreSQL     │   single primary; read replica optional
        └─────────────────┘

        Firebase Admin (FCM)   external
        WATI                    external
```

Local dev:
- `cd backend && npm run dev` — nodemon, pg locally or via Docker.
- `cd frontend && flutter run` — emulator or USB device. Android device
  builds need `adb reverse tcp:3000 tcp:3000` so the device can reach the
  host backend.

---

## 10. Where to look for what

| Question                                | File                                                                |
|-----------------------------------------|---------------------------------------------------------------------|
| How does login work?                    | [ONBOARDING.md §4](ONBOARDING.md#4-authentication--phone--otp)      |
| What can a regular user do?             | [USER_FEATURES.md](USER_FEATURES.md)                                |
| What can a group admin do?              | [ADMIN_FEATURES.md](ADMIN_FEATURES.md)                              |
| Endpoint contracts                      | [API_REFERENCE.md](API_REFERENCE.md)                                |
| Frontend conventions / module layout    | [FRONTEND_ARCHITECTURE.md](FRONTEND_ARCHITECTURE.md)                |
| Backend layering / cache / db           | [BACKEND_ARCHITECTURE.md](BACKEND_ARCHITECTURE.md)                  |
| Balance math                            | `backend/src/services/groupService.js → _computeBalances`           |
| Pairwise debt UI                        | `frontend/lib/modules/groups/screens/group_detail_screen.dart → _pairwiseDebts` |
