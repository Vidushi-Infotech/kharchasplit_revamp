# KharchaSplit — Backend Architecture

Express + PostgreSQL REST API. Phone+OTP auth, JWT bearer tokens, in-process
cache, FCM push, WhatsApp invites via WATI.

> See also [FRONTEND_ARCHITECTURE.md](FRONTEND_ARCHITECTURE.md) and
> [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md). For endpoint details see
> [API_REFERENCE.md](API_REFERENCE.md).

---

## 1. Stack

| Layer            | Choice                                                              |
|------------------|---------------------------------------------------------------------|
| Runtime          | Node.js (ESM modules — `"type": "module"`)                          |
| Framework        | Express `^4.18`                                                     |
| Database         | PostgreSQL via `pg` (raw SQL, no ORM)                               |
| Auth             | `jsonwebtoken` (access + refresh), `bcryptjs` (password hashing)    |
| Validation       | `express-validator`                                                 |
| Security         | `helmet`, `cors`, `express-rate-limit`                              |
| Logging          | `morgan` (request logs)                                             |
| Performance      | `compression`, in-process LRU cache (`cacheService`)                |
| Push             | Firebase Admin SDK (`firebase-admin`)                               |
| WhatsApp         | WATI HTTP API (template messages for invites)                       |
| Dev              | `nodemon` (auto-reload), `dotenv`                                   |

---

## 2. Folder layout

```
backend/
├── src/
│   ├── server.js              Express bootstrap, middleware chain, route mounting
│   ├── config/
│   │   ├── database.js        pg Pool + query() helper + transaction()
│   │   └── initDatabase.js    Idempotent table/column/index creator (runs at boot)
│   ├── middleware/
│   │   ├── auth.js            authenticate() — JWT bearer check + req.user
│   │   ├── validation.js      reusable express-validator chains
│   │   └── errorHandler.js    central error formatter + 404 handler
│   ├── routes/                One file per resource — pure HTTP shape
│   │   ├── authRoutes.js
│   │   ├── userRoutes.js
│   │   ├── groupRoutes.js
│   │   ├── expenseRoutes.js
│   │   ├── settlementRoutes.js
│   │   ├── personalExpenseRoutes.js
│   │   ├── activityRoutes.js
│   │   ├── inviteRoutes.js
│   │   └── syncRoutes.js
│   ├── controllers/           Route handlers — request → service/model → response
│   │   └── (one per route file, mirroring names)
│   ├── services/              Cross-controller business logic
│   │   ├── groupService.js    Balance math + admin/access guards + pairwise debts
│   │   ├── activityService.js Activity log emitters (logExpenseAdded, …)
│   │   ├── notificationService.js  FCM dispatch (notifyMemberLeft, …)
│   │   ├── cacheService.js    In-memory LRU + TTL
│   │   └── watiService.js     WhatsApp template send
│   ├── models/                Thin DAOs — raw SQL grouped per table
│   │   ├── User.js  Group.js  Expense.js  Settlement.js
│   │   ├── PersonalExpense.js  Activity.js
│   └── utils/
│       ├── jwt.js             generateAccessToken / generateRefreshToken
│       └── otp.js             generateOTP, getOTPExpiry, sendOTPviaSMS (stub)
├── migrations/                Numbered .sql migration files + migrate.js
└── documentation/             This folder
```

---

## 3. Request lifecycle

```
HTTP request
   │
   ▼
[helmet]              security headers
[cors]                allow-list origins
[morgan]              access log
[compression]         gzip
[express.json]        body parsing (with size limit)
[rate-limit]          per-IP throttle
   │
   ▼
[router]              maps URL → controller
   │
   ▼
[authenticate]        (per-route) — verifies JWT, hydrates req.user
   │
   ▼
[validation]          (per-route) — express-validator chain
   │
   ▼
[controller]          orchestrates: validate → call service/model → respond
   │
   ▼
[service / model]     SQL query / business rule
   │
   ▼
[cacheService]        (optional) getOrSet / invalidate
   │
   ▼
JSON response  { success, data, … }
   │
   ▼
[errorHandler]        catches throws → uniform error envelope
```

Every successful response is wrapped:
```json
{ "success": true, "data": <payload>, "message": "Optional human message" }
```
Every failure:
```json
{ "success": false, "error": "Human readable" }
```
HTTP status codes carry the semantics (`400`, `401`, `403`, `404`, `409`,
`500`).

---

## 4. Layered responsibilities

| Layer        | Knows about                              | Doesn't know about         |
|--------------|------------------------------------------|----------------------------|
| **route**    | URL shape, middleware order              | DB schema, business rules  |
| **controller** | `req`/`res` shape, status codes        | SQL, low-level pg          |
| **service**  | Business rules, multi-table operations   | Express, JSON envelope     |
| **model**    | A single table's SQL                     | Other tables, HTTP         |

When a controller mixes business logic with SQL, it's a refactor candidate
to extract into a service (e.g. `groupService.calculateBalances`,
`groupService.getUserPairwiseDebts`).

---

## 5. Database — PostgreSQL

- Connection pool via `pg.Pool`. Helper:
  ```js
  import { query, transaction } from './config/database.js';
  await query('SELECT * FROM users WHERE id = $1', [id]);
  await transaction(async (client) => { /* multi-statement work */ });
  ```
- **Schema bootstrap**: `initializeDatabase()` runs at server start and
  creates any missing tables / columns / indexes idempotently. This makes
  spinning up a fresh dev DB a single `npm run dev`.
- **Migrations**: numbered `.sql` files in `backend/migrations/` for
  schema evolutions (e.g. adding `is_archived`, `pending_invites`).
  `npm run migrate` applies them in order.
- **Soft deletes**: most tables have a `deleted_at TIMESTAMP` column.
  Queries always include `deleted_at IS NULL`. The corresponding model's
  `delete()` method is an `UPDATE … SET deleted_at = NOW()`.

### Core tables

| Table                | Purpose                                                                  |
|----------------------|--------------------------------------------------------------------------|
| `users`              | Phone-keyed accounts; `is_placeholder` flag for invite placeholders      |
| `groups`             | Per-group metadata, `created_by`, currency, archive/complete flags       |
| `group_members`      | Many-to-many w/ `role` (`creator`/`admin`/`member`)                      |
| `expenses`           | Per-group expense; `paid_by_id` (= "creator"); `split_type`              |
| `expense_splits`     | Per-member share; stores `amount`, `percentage`, `shares` (nullable)     |
| `settlements`        | Direct payment between two members of a group; `status`                  |
| `personal_expenses`  | Single-user wallet expenses                                              |
| `pending_invites`    | Phone-keyed group invitations awaiting registration                      |
| `otps`               | One-time passcodes w/ expiry + verified flag                             |
| `refresh_tokens`     | Long-lived JWT refresh tokens (rotated on use)                           |
| `activities`         | Per-user activity feed; emitted by `activityService`                     |
| `sync_metadata`      | Last-sync timestamps for the optional sync endpoint                      |

---

## 6. Authentication

Phone-first, no passwords:

1. `POST /auth/register` — creates user + dispatches OTP. Reconciles
   pending invites by phone.
2. `POST /auth/send-otp` — for returning users.
3. `POST /auth/verify-otp` — issues access + refresh tokens.
4. `POST /auth/refresh` — rotates the refresh token, returns new access.
5. `POST /auth/logout` — revokes refresh.

`auth.js` middleware:
- Reads `Authorization: Bearer <jwt>`.
- `jsonwebtoken.verify` against `JWT_SECRET`.
- Loads user, attaches to `req.user`. Returns `401` on missing/invalid.

Dev shortcut: when `NODE_ENV !== 'production'`, the OTP `123456` is accepted
for any phone. SMS dispatch is currently a stub
(`utils/otp.js → sendOTPviaSMS`).

---

## 7. Authorization (per-group roles)

Two helpers in `services/groupService.js`:

| Helper                                  | Used by                                       |
|-----------------------------------------|-----------------------------------------------|
| `validateGroupAccess(groupId, userId)`  | Most read endpoints                            |
| `validateAdminAccess(groupId, userId)`  | Group delete, member remove (target ≠ self), role change, archive/complete |

Admin = row in `group_members` with `role IN ('creator', 'admin')`.

Two settlement gates added on top:

- `deleteGroup`: must be admin **and** `groupService.calculateBalances(id)`
  returns an empty list (= every pair settled). Returns 409 otherwise.
- `removeGroupMember(self)` (a.k.a. leave): every entry of
  `getUserPairwiseDebts(groupId, userId)` must be `~0`. Returns 409
  otherwise.

Other invariants:

- `deleteExpense`: only the payer (`paid_by_id == req.user.id`). Even group
  admins can't delete someone else's expense. (Returns 403.)

---

## 8. Caching — in-process LRU + TTL

File: `services/cacheService.js`

- LRU eviction at `maxSize = 1000`.
- Per-entry TTL (seconds), constants in `TTL = { GROUP_BALANCES, GROUP_EXPENSES, GROUP_SETTLEMENTS, … }`.
- Single API: `cache.getOrSet(key, ttlSeconds, fetcher)`.
- Prefix-based invalidation: `cache.invalidate('group:123')` clears
  `group:123`, `group:123:balances`, `group:123:expenses:50:0`, etc.
- Stats exposed at `/health` (size, hits, misses, hitRate).

Hot reads using the cache:

| Cache key prefix                        | What it stores                              |
|-----------------------------------------|---------------------------------------------|
| `group:<id>:balances`                   | Output of `_computeBalances` (simplified pairs) |
| `group:<id>:expenses:<limit>:<offset>`  | Page of expenses + participants             |
| `group:<id>`                            | Group meta (member_count, totals)           |

Writes that touch a group call
`Expense.invalidateGroupExpenses(groupId)` /
`cache.invalidate('group:<id>')` to keep reads consistent.

The cache is in-process (single instance). For horizontal scaling, swap to
Redis using the same `cache.get/set/del/invalidate` shape.

---

## 9. Background concerns

| Concern        | Service / file                                          | Notes                                                          |
|----------------|---------------------------------------------------------|----------------------------------------------------------------|
| Activity feed  | `activityService.js` + `activityController.js`          | Synchronously inserts an `activities` row from the request handler. Read endpoints unread-count + paginated feed. |
| Push (FCM)     | `notificationService.js`                                | Fires after the SQL write commits. Failures are logged + swallowed (won't fail the request). |
| WhatsApp invite| `watiService.js`                                        | Template send via WATI REST API. Failures surface in the response so the inviter sees them. |
| Cleanup        | (none scheduled yet)                                    | Expired OTPs / refresh tokens linger; a future cron should sweep them. |

---

## 10. Configuration / env

| Var                   | Purpose                                              |
|-----------------------|------------------------------------------------------|
| `PORT`                | HTTP port (default 3000)                             |
| `DATABASE_URL`        | Postgres connection string                           |
| `JWT_SECRET`          | Access token signing key                             |
| `JWT_REFRESH_SECRET`  | Refresh token signing key                            |
| `NODE_ENV`            | `development` / `production` (gates OTP shortcut)    |
| `FCM_*` / Firebase service account JSON | Push delivery                      |
| `WATI_API_URL`, `WATI_TOKEN`, `WATI_TEMPLATE` | WhatsApp invites             |

Loaded via `dotenv` at the top of `server.js`. Don't commit `.env`.

---

## 11. Health & observability

`GET /health` returns:
```json
{
  "success": true,
  "message": "KharchaSplit API is running",
  "version": "v1",
  "timestamp": "<ISO>",
  "pool":  { "total": N, "idle": N, "waiting": N },
  "cache": { "size": N, "maxSize": 1000, "hits": N, "misses": N, "hitRate": "82.3%" }
}
```

Use it to confirm the API is up and check pool/cache pressure.

---

## 12. Error handling

`middleware/errorHandler.js` catches anything thrown or `next(err)`-passed:

- Known thrown errors with a `.message` matching a guard
  (e.g. `'User is not an admin of this group'`) get mapped to the right
  status code in the controller before reaching the handler.
- Unknown errors → `500` with a generic message in production, full stack
  in dev.
- `notFound` adds the catch-all `404` for unmatched routes.

---

## 13. Testing

`jest` is wired up (`npm test`) with coverage. Test layout mirrors `src/`.
Today the suite is light — most verification has been manual via Postman
collection and the mobile client.

---

## 14. Where to add a new endpoint

1. **Model** — add SQL methods in `src/models/<Table>.js`.
2. **Service** — only if the logic spans multiple tables or is reused.
3. **Controller** — `(req, res, next)` handler; validate, call model/service,
   respond with the standard envelope.
4. **Route** — wire URL → controller; add `authenticate` + validation
   middleware as needed.
5. **Mount** — import the route in `server.js`.
6. **Cache** — if read-heavy, wrap with `cache.getOrSet`. Add an
   `invalidate` call on every write path that affects it.
7. **Doc** — update `API_REFERENCE.md`.
