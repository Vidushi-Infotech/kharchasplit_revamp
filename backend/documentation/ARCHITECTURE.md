# KharchaSplit — System Architecture

End-to-end view of how the KharchaSplit Flutter client, Node/Express
backend, PostgreSQL database, and external services fit together.

Diagrams in this document are written in **Mermaid** — they render
natively on GitHub, VS Code, and the generated PDF.

---

## 1. Elevator pitch

A multi-device expense-splitting app. The Flutter client (Android, iOS,
and Web) talks to a single REST backend in Node/Express, which persists
to PostgreSQL. Authentication is phone-number + OTP (Twilio Verify).
Push notifications go through Firebase Cloud Messaging. Non-registered
group members are invited via WhatsApp through WATI. There are no
microservices — a single Express instance serves every request.

---

## 2. High-level system diagram

```mermaid
flowchart LR
  subgraph Clients["Clients"]
    A[Android app]
    I[iOS app]
    W[Web build]
  end

  subgraph Edge["Edge / TLS"]
    CF["Cloudflare or proxy<br/>HTTPS + HSTS"]
  end

  subgraph Backend["KharchaSplit Backend (Node 18 / Express 4)"]
    direction TB
    R["Routes<br/>(10 modules)"]
    MW["Middleware<br/>auth · rateLimit · validate · errorHandler"]
    C["Controllers<br/>(business logic)"]
    SV["Services<br/>group · activity · notification · twilio · wati · cache"]
    M["Models<br/>(SQL access layer)"]
    CK["In-process cache<br/>(LRU)"]
  end

  subgraph Data["PostgreSQL 13+"]
    DB[("users · groups · group_members<br/>expenses · expense_splits · settlements<br/>personal_expenses · activities<br/>notifications · refresh_tokens · …")]
  end

  subgraph External["External services"]
    TW[Twilio Verify<br/>SMS OTP]
    FB[Firebase Cloud Messaging<br/>push to devices]
    WA[WATI<br/>WhatsApp invites]
  end

  A & I & W --> CF --> R
  R --> MW --> C
  C --> SV
  C --> M
  SV --> M
  M --> DB
  SV --> CK
  M --> CK

  SV --> TW
  SV --> FB
  SV --> WA
```

---

## 3. Client layer (Flutter)

Single codebase, three targets (Android / iOS / Web), Riverpod for
state, Dio for HTTP, `go_router` for navigation, Hive for offline
cache.

```mermaid
flowchart TB
  subgraph FlutterApp["Flutter app (frontend/)"]
    direction TB
    UI["UI layer<br/>modules/<br/>(auth · groups · expenses · settlements · reports · profile)"]
    State["State layer<br/>Riverpod providers<br/>(NotifierProvider · AsyncNotifier)"]
    Repo["Data layer<br/>data/*/repository.dart<br/>(auth · users · groups · expenses · settlements · activities · dashboard · reports · personal_expenses)"]
    Net["Core/Network<br/>api_client.dart (Dio)<br/>↳ Bearer interceptor<br/>↳ 401 → /auth/refresh"]
    Tok["TokenStore (flutter_secure_storage)"]
    Push["PushService<br/>FCM token + foreground handler"]
  end

  UI --> State
  State --> Repo
  Repo --> Net
  Net --> Tok
  Push --> Net
```

**Key client rules** (per `frontend/CLAUDE.md`):

- 3 responsive layouts per screen: compact `<600`, standard `600–1100`, large `>1100`.
- Riverpod everywhere — no `setState` for app-level state.
- `go_router` for navigation (deep links + web URLs work).
- All HTTP through one `ApiClient` so the auth interceptor + refresh
  flow apply to every call.

---

## 4. Backend layer (Express)

Classic MVC layout. Routes mount validators + middleware, controllers
hold business logic, services encapsulate cross-cutting work
(notifications, external APIs, caching), models do SQL.

```mermaid
flowchart TB
  REQ([HTTP request]) --> A1
  A1["server.js<br/>helmet · cors · rate-limit · body-parser · pino-http"] --> A2
  A2["Route module<br/>routes/{auth,users,groups,expenses,…}Routes.js"] --> A3
  A3["express-validator<br/>middleware/validation.js"] --> A4
  A4["JWT middleware<br/>middleware/auth.js<br/>(populates req.user)"] --> A5
  A5["Targeted rate limit<br/>middleware/rateLimits.js<br/>(otp · expenseCreate)"] --> A6
  A6["Controller<br/>controllers/*.js<br/>(business rules + authz)"] --> A7

  A7 --> S1["Service<br/>(group · activity · notification · twilio · wati · cache)"]
  A7 --> M1["Model<br/>(SQL via pg pool)"]
  S1 --> M1
  M1 --> DB[(PostgreSQL)]
  S1 -.-> Cache[("In-process cache<br/>cacheService.js")]
  M1 -.-> Cache

  A7 --> RESP([JSON response<br/>"{success, data, …}"])
  A8["middleware/errorHandler.js"] -.-> RESP
```

### 4.1 Layered responsibilities

| Layer       | Folder                    | Responsibility                                                                |
| ----------- | ------------------------- | ----------------------------------------------------------------------------- |
| Routes      | `src/routes/`             | Path → controller mapping. Validators + per-route rate limiters live here.    |
| Middleware  | `src/middleware/`         | `auth` (JWT), `validation` (express-validator), `rateLimits`, `errorHandler`. |
| Controllers | `src/controllers/`        | Request → response. Authorization checks, business rules, side-effect orchestration. |
| Services    | `src/services/`           | Reusable cross-cutting logic (notifications, external APIs, caching, balance math). |
| Models      | `src/models/`             | SQL queries against the `pg` pool. No business logic, just data access.       |
| Config      | `src/config/`             | Pool, init script (`initDatabase.js`), Firebase Admin init.                   |
| Utils       | `src/utils/`              | JWT helpers, OTP generator, logger (pino).                                    |

### 4.2 What's mounted in `server.js`

```
/api/v1/auth              → authRoutes
/api/v1/users             → userRoutes
/api/v1/groups            → groupRoutes
/api/v1/expenses          → expenseRoutes
/api/v1/settlements       → settlementRoutes
/api/v1/personal-expenses → personalExpenseRoutes
/api/v1/sync              → syncRoutes
/api/v1/activities        → activityRoutes
/api/v1/invites           → inviteRoutes
/api/v1/policies          → policiesRoutes
/health                   → inline handler
```

---

## 5. Data layer

```mermaid
flowchart LR
  CTRL[Controllers] --> MDL[Models]
  CTRL --> SVC[Services]
  SVC --> MDL

  MDL --> POOL["pg Pool<br/>(20 connections)"]
  POOL --> PG[(PostgreSQL)]

  MDL -.read.-> CACHE[("In-process LRU cache<br/>cacheService.js")]
  MDL -.write+invalidate.-> CACHE

  PG -.-> INIT["initDatabase.js<br/>(idempotent boot:<br/>CREATE TABLE IF NOT EXISTS,<br/>ALTER ADD COLUMN IF NOT EXISTS,<br/>CREATE INDEX IF NOT EXISTS)"]
```

**Notes**

- The cache is process-local (a single Map with TTL + LRU eviction).
  Fine for a single instance, **not safe** across multiple replicas —
  swap for Redis (`rate-limit-redis` + a Redis-backed cache) before
  horizontally scaling.
- `initDatabase.js` is the source of truth at runtime. The `migrations/`
  folder is historical — migrations have already been folded into the
  init script.

See `SCHEMA.md` for the full table inventory and ER diagram.

---

## 6. External services

| Service                       | Purpose                                | Where it's called from                          |
| ----------------------------- | -------------------------------------- | ----------------------------------------------- |
| **Twilio Verify**             | Phone OTP for sign-in (`send-otp` / `verify-otp`). | `src/services/twilioService.js`                |
| **Firebase Cloud Messaging**  | Push notifications to user devices.    | `src/services/notificationService.js` (uses `firebase-admin`). |
| **WATI**                      | WhatsApp invites for non-registered users when added to a group. | `src/services/watiService.js`                  |

All three are **non-fatal** at boot — if env vars are missing, the
server still starts; the corresponding feature short-circuits with a
clean error response (Twilio: `OTP service not configured`; WATI:
silently skipped; FCM: push delivery is a no-op).

---

## 7. Request lifecycle — authenticated GET

```mermaid
sequenceDiagram
  participant App as Flutter app
  participant Cf as Cloudflare/proxy
  participant Ex as Express
  participant Mw as auth middleware
  participant Ck as Cache
  participant Co as Controller
  participant DB as Postgres

  App->>Cf: GET /api/v1/users/:id/dashboard<br/>Authorization: Bearer <jwt>
  Cf->>Ex: HTTPS upgrade + forward
  Ex->>Ex: helmet · cors · rate-limit · pino-http
  Ex->>Mw: authenticate()
  Mw->>Ck: get auth:user:<id>
  alt cache miss
    Mw->>DB: SELECT id, phone, name, email FROM users
    DB-->>Mw: row
    Mw->>Ck: set auth:user:<id> (5 min TTL)
  end
  Mw-->>Ex: req.user = {id, phone, name, email}
  Ex->>Co: dashboard controller
  Co->>DB: balances CTE + recent expenses
  DB-->>Co: rows
  Co-->>Ex: { success: true, data: { … } }
  Ex-->>App: JSON
```

---

## 8. Auth + refresh-token flow

```mermaid
sequenceDiagram
  participant App as Flutter app
  participant Api as ApiClient (Dio)
  participant TS as TokenStore (secure storage)
  participant Be as Backend

  Note over App,Be: First sign-in
  App->>Be: POST /auth/send-otp { phoneNumber }
  Be-->>App: 200 OK (Twilio SMS sent)
  App->>Be: POST /auth/verify-otp { phoneNumber, otp, device }
  Be-->>App: 200 { accessToken, refreshToken, user }
  App->>TS: save tokens (secure_storage)

  Note over App,Be: Normal request
  App->>Api: GET /groups
  Api->>TS: read accessToken
  Api->>Be: GET /groups (Authorization: Bearer …)
  Be-->>Api: 200 / 401

  alt 401 returned
    Api->>TS: read refreshToken
    Api->>Be: POST /auth/refresh { refreshToken }
    Be->>Be: verify + bump last_used_at
    Be-->>Api: 200 { accessToken }
    Api->>TS: save new accessToken
    Api->>Be: retry original GET /groups
    Be-->>Api: 200 data
  end
  Api-->>App: result
```

The interceptor lives in `frontend/lib/core/network/api_client.dart` —
**every** Dio call benefits from automatic refresh. Refresh tokens
expire after 30 days of inactivity (`last_used_at` is bumped on each
use).

---

## 9. Placeholder user + WATI invite flow

The "invite by phone" flow is one of the more interesting domain pieces
— it lets users build a group with friends who haven't installed the
app yet, and lets expenses reference those friends immediately. When
the friend later signs up, the same row is converted in place so they
keep all their history.

```mermaid
sequenceDiagram
  participant Inv as Inviter (app)
  participant Be as Backend
  participant DB as Postgres
  participant WT as WATI
  participant Fr as Friend

  Inv->>Be: POST /groups/:id/pending-members<br/>{ name, phoneNumber }
  Be->>DB: SELECT user by phone
  alt already a real user
    Be->>DB: INSERT group_members (real user)
    Be-->>Inv: 201 { type: "registered" }
  else not registered
    Be->>DB: INSERT users (is_placeholder = TRUE)
    Be->>DB: INSERT group_members (placeholder)
    Be->>WT: POST WhatsApp message
    WT-->>Fr: WhatsApp invite
    Be->>DB: INSERT pending_group_invites
    Be-->>Inv: 201 { type: "placeholder", watiStatus }
  end

  Note over Fr,Be: Later — friend signs up

  Fr->>Be: POST /auth/register or /auth/verify-otp
  Be->>DB: SELECT user by phone
  alt is_placeholder = TRUE
    Be->>DB: UPDATE users SET is_placeholder=FALSE,<br/>name=…, email=…
    Be->>DB: DELETE pending_group_invites for that phone
    Be-->>Fr: 200 { user, addedGroups: [...] }
    Note over Fr: User is already a group member<br/>and shows up in past expenses
  end
```

---

## 10. Push notification flow

```mermaid
sequenceDiagram
  participant App as Flutter app
  participant Be as Backend
  participant DB as Postgres
  participant FCM as Firebase

  Note over App,Be: Device registration
  App->>Be: POST /users/:id/devices<br/>{ fcmToken, platform, deviceName, … }
  Be->>DB: INSERT user_devices ON CONFLICT (fcm_token)<br/>DO UPDATE last_seen_at = NOW()

  Note over Be,FCM: Send (e.g. expense added)
  Be->>DB: SELECT * FROM notification_prefs WHERE user_id = …
  alt push_enabled AND new_expense
    Be->>DB: SELECT fcm_token FROM user_devices WHERE user_id = …
    Be->>FCM: sendEachForMulticast(tokens, payload)
    FCM-->>App: push to every signed-in device
    Be->>DB: INSERT notifications (inbox row)
  end

  Note over App: User opens app
  App->>Be: GET /users/:id/notifications?limit=50
  Be-->>App: inbox list
```

**Reminder rate limit (data-driven):**

`POST /groups/:id/remind/:userId` checks the `notifications` table for
any row in the last 6 h with the same `(target user, type='SETTLEMENT_REMINDER', fromUserId, groupId)` — if found, returns
429. So the rate-limit lives in the data, not in middleware.

---

## 11. Reads / writes — what hits the cache

```mermaid
flowchart LR
  subgraph Read["Reads (populate cache)"]
    R1[GET /groups/:id] --> K1[(group:&lt;id&gt;:balances)]
    R2[GET /settlements] --> K2[(group:&lt;id&gt;:settlements)]
    R3[GET /expenses] --> K3[(group:&lt;id&gt;:expenses)]
    R4[Authenticated request] --> K4[(auth:user:&lt;id&gt;)]
  end

  subgraph Write["Writes (invalidate)"]
    W1[POST/PUT/DELETE /expenses] -.invalidates.-> K1
    W1 -.invalidates.-> K3
    W2[POST settlement] -.invalidates.-> K1
    W2 -.invalidates.-> K2
    W3[PATCH settlements/:id/confirm] -.invalidates.-> K1
    W3 -.invalidates.-> K2
    W4[PUT users/:id] -.invalidates.-> K4
  end
```

---

## 12. Deployment topology

Single-region, single-instance Express container behind a TLS-terminating
proxy (Cloudflare / Render / nginx). PostgreSQL is managed (RDS / Render
Postgres / equivalent).

```mermaid
flowchart TB
  subgraph Devices["End-user devices"]
    A[Android] & I[iOS] & W[Web]
  end

  subgraph Edge["Edge"]
    CF["Cloudflare<br/>(TLS + HSTS + CORS)"]
  end

  subgraph PlatA["App Platform (single Express instance)"]
    APP["Node 18 process<br/>(PM2 / Render / Heroku-style runtime)"]
    LOG["pino-http → stdout<br/>(log collector)"]
  end

  subgraph PlatB["Managed Postgres"]
    PG[("PostgreSQL")]
  end

  subgraph Out["Outbound integrations"]
    TW[Twilio Verify]
    WA[WATI]
    FB[FCM]
  end

  A & I & W --> CF --> APP
  APP --> PG
  APP --> TW
  APP --> WA
  APP --> FB
  APP --> LOG
```

**Notes**

- `trust proxy = 1` in production so `req.secure` and `x-forwarded-*`
  reflect the real client.
- HTTP → HTTPS redirect (308) + HSTS (1 year, preload) is on in
  production.
- The body limit is 10 MB to accommodate base64 receipts.
- Graceful shutdown drains in-flight requests then closes the pg pool.
- The current setup is **not horizontally scaled** — the in-process
  rate limiter and cache make multi-instance unsafe. Move both to
  Redis before scaling out.

---

## 13. Failure modes and fallbacks

| Failure                                | Behavior                                                            |
| -------------------------------------- | ------------------------------------------------------------------- |
| Twilio not configured                  | `/auth/send-otp` returns 500 with a clear error; client falls back to dev flow. |
| Twilio Verify rejects code             | Mapped to 401 `Invalid OTP` (404 from Twilio = "OTP expired").       |
| WATI not configured / API failure       | `pending_group_invites` row still written with `wati_status = 'failed'`; user can resend later. The placeholder member is still added to the group. |
| FCM send fails                         | Logged + the inbox row is still written (so the user sees it in-app). |
| Postgres connection drop               | `pg` pool retries; if unreachable at boot, the server exits 1.       |
| Pre-signed access token expires (401)  | Dio interceptor refreshes silently and retries the original request. |
| Refresh token expired / revoked        | Client clears credentials and routes to login.                      |
| Body > 10 MB                           | Express returns 413 `Request body too large. Try a smaller image.`   |
| Rate limit tripped                     | 429 with a typed message (`Too many OTP requests…`, `Too many expenses…`, `You've already reminded this person…`). |

---

## 14. Tech stack at a glance

| Layer        | Choice                                                              |
| ------------ | ------------------------------------------------------------------- |
| Client       | Flutter (Dart) · Riverpod · Dio · go_router · Hive · cached_network_image · intl |
| Backend      | Node 18 · Express 4 · express-validator · express-rate-limit · helmet · compression · pino |
| Auth         | JWT (jsonwebtoken) · Twilio Verify · `flutter_secure_storage` (client) |
| Database     | PostgreSQL 13+ (`gen_random_uuid()`, `JSONB`, partial indexes)       |
| Push         | Firebase Cloud Messaging (firebase-admin)                            |
| WhatsApp     | WATI                                                                |
| Logging      | pino + pino-http (stdout, with redaction)                            |
| Hosting      | Single container behind Cloudflare; managed Postgres                 |
| Build / CI   | npm scripts, Jest for backend tests (currently stub)                 |

---

## 15. One-line summary

> Flutter client → HTTPS → single Express process → PostgreSQL.
> JWT for auth (with refresh). Twilio for OTP, FCM for push, WATI for
> WhatsApp invites. All caching, rate-limiting, and notification logic
> lives in the one Node process today — Redis is the next stop when
> we scale out.
