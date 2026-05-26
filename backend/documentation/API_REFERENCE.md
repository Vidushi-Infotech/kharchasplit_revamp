# KharchaSplit API Reference

Tabular reference of every HTTP endpoint exposed by the backend, with input and output schemas. Generated from the live route + controller files at `backend/src/`.

- **Base URL (dev)**: `http://localhost:3000/api/v1`
- **Auth header**: `Authorization: Bearer <accessToken>`
- **Standard response envelope**: `{ "success": boolean, "data": ..., "message"?: string, "error"?: string, "pagination"?: { ... } }`
- **Total endpoints**: **63** across 10 sections

## Table of contents

| Section | Count |
|---|---|
| [Auth](#auth) | 6 |
| [Users](#users) | 9 |
| [Groups](#groups) | 16 |
| [Expenses](#expenses) | 5 |
| [Settlements](#settlements) | 4 |
| [Personal Expenses](#personal-expenses) | 5 |
| [Activities](#activities) | 9 |
| [Invites](#invites) | 6 |
| [Sync](#sync) | 2 |
| [Misc / Health](#misc--health) | 1 |

---

## Auth

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | Public | Register a user (name + phone, email optional). Sends OTP. |
| POST | `/auth/send-otp` | Public | Request login OTP for an existing user. |
| POST | `/auth/verify-otp` | Public | Verify OTP, return access + refresh tokens. |
| POST | `/auth/refresh` | Public | Trade a refresh token for a new access token. |
| POST | `/auth/logout` | Public | Revoke a refresh token. |
| POST | `/auth/simple-login` | Public | Dev-only phone-only login (skips OTP). |

### `POST /auth/register`

```jsonc
// request
{ "phoneNumber": "string (E.164, e.g. +919876543210)",
  "name": "string (2-255)",
  "email": "string (optional, valid email)" }

// response 201
{ "success": true,
  "message": "string",
  "data": {
    "user": { "id": "uuid", "phoneNumber": "string", "name": "string", "email": "string|null" },
    "addedGroups": [{ "groupId": "uuid", "groupName": "string" }],
    "convertedFromPlaceholder": "boolean"
  } }
```

Status: **409** if phone already registered.

### `POST /auth/send-otp`

```jsonc
// request
{ "phoneNumber": "string (E.164)" }

// response 200
{ "success": true, "message": "OTP sent successfully" }
```

Status: **404** if user not found.

### `POST /auth/verify-otp`

```jsonc
// request
{ "phoneNumber": "string", "otp": "string (4-10 chars)" }

// response 200
{ "success": true,
  "message": "Login successful",
  "data": {
    "user": { "id": "uuid", "phoneNumber": "string", "name": "string", "email": "string|null",
              "profileImageBase64": "string|null", "preferredCurrency": "string|null" },
    "accessToken": "string", "refreshToken": "string"
  } }
```

Status: **401** if invalid/expired OTP. In dev mode (`NODE_ENV !== 'production'`), the literal `123456` is accepted as a master OTP for any phone.

### `POST /auth/refresh`

```jsonc
// request
{ "refreshToken": "string" }

// response 200
{ "success": true, "data": { "accessToken": "string" } }
```

Status: **401** if invalid/expired refresh token.

### `POST /auth/logout`

```jsonc
// request
{ "refreshToken": "string (optional)" }

// response 200
{ "success": true, "message": "Logged out successfully" }
```

### `POST /auth/simple-login`

```jsonc
// request
{ "phoneNumber": "string (E.164)" }

// response 200
{ "success": true,
  "message": "Login successful",
  "data": {
    "user": { "id": "uuid", "phoneNumber": "string", "name": "string", "email": "string|null",
              "profileImageBase64": "string|null", "preferredCurrency": "string|null",
              "createdAt": "ISO8601" },
    "accessToken": "string", "refreshToken": "string"
  } }
```

Status: **404** if user not found. Skips OTP entirely — intended for dev only.

---

## Users

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/users/check-registration` | Required | Check which of a list of phone numbers are registered. |
| GET | `/users/by-phone/:phoneNumber` | Required | Look up a user by phone. |
| GET | `/users/:id/dashboard` | Required | Aggregate balances + recent expenses for the dashboard. |
| GET | `/users/:id` | Required | Get a user by id. |
| PUT | `/users/:id` | Required | Update profile (own only). |
| DELETE | `/users/:id` | Required | Hard delete user (own only). |
| DELETE | `/users/:id/deactivate` | Required | Soft-delete user. |
| PUT | `/users/:id/fcm-token` | Required | Set push-notification token. |
| DELETE | `/users/:id/fcm-token` | Required | Remove push-notification token. |

### `POST /users/check-registration`

```jsonc
// request
{ "phoneNumbers": ["string", ...] }

// response 200
{ "success": true,
  "data": {
    "registered": [{ "phoneNumber": "string", "userId": "uuid", "name": "string",
                     "email": "string|null", "profileImage": "string|null" }],
    "unregistered": ["string", ...]
  } }
```

### `GET /users/:id/dashboard`

```jsonc
// query: ?recentLimit=10  (max 50)

// response 200
{ "success": true,
  "data": {
    "youAreOwed":   "number",   // sum of positive net balances
    "youOwe":       "number",   // sum of |negative net balances|
    "totalBalance": "number",   // youAreOwed - youOwe
    "recentExpenses": [{
      "id": "uuid", "groupId": "uuid", "groupName": "string",
      "description": "string", "amount": "number", "currency": "string", "category": "string",
      "paidBy": { "id": "uuid", "name": "string", "phoneNumber": "string", "profileImage": "string|null" },
      "splitType": "string", "notes": "string|null",
      "expenseDate": "ISO8601|null", "createdAt": "ISO8601",
      "splits": [{ "userId": "uuid", "userName": "string", "owedShare": "number",
                   "percentage": "number|null", "shares": "number|null" }]
    }]
  } }
```

Status: **403** if `:id` ≠ caller. Aggregates expenses across every group the caller belongs to.

### `GET /users/by-phone/:phoneNumber`

```jsonc
// response 200 — same shape as GET /users/:id
```

### `GET /users/:id`

```jsonc
// response 200
{ "success": true,
  "data": { "id": "uuid", "phoneNumber": "string", "name": "string",
            "email": "string|null", "profileImage": "string|null",
            "preferredCurrency": "string|null", "createdAt": "ISO8601" } }
```

Status: **404** if not found.

### `PUT /users/:id`

```jsonc
// request — every field optional
{ "name": "string (2-255)",
  "email": "string (valid email)",
  "profileImageBase64": "string",
  "preferredCurrency": "string" }

// response 200 — updated user object
```

Status: **403** if `:id` ≠ caller.

### `PUT /users/:id/fcm-token`

```jsonc
// request
{ "fcmToken": "string" }

// response 200
{ "success": true, "message": "FCM token updated successfully" }
```

### `DELETE /users/:id/fcm-token`

```jsonc
// response 200
{ "success": true, "message": "FCM token removed successfully" }
```

### `DELETE /users/:id` and `DELETE /users/:id/deactivate`

No body. Returns `{ "success": true, "message": "..." }`.

---

## Groups

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/groups` | Required | List user's groups (paginated). Includes `myBalance`. |
| POST | `/groups` | Required | Create a group. |
| GET | `/groups/:id` | Required | Group detail with members + balances. |
| PUT | `/groups/:id` | Required | Update group (admin only). |
| DELETE | `/groups/:id` | Required | Delete group (admin only). |
| GET | `/groups/:id/members` | Required | List members. |
| POST | `/groups/:id/members` | Required | Add an existing registered user as a member. |
| DELETE | `/groups/:id/members/:userId` | Required | Remove member or self-leave. |
| PUT | `/groups/:id/members/:userId` | Required | Change role (admin only). |
| GET | `/groups/:id/pending-members` | Required | List pending invites. |
| POST | `/groups/:id/pending-members` | Required | Invite by phone (also adds registered users directly). |
| POST | `/groups/:id/pending-members/:phoneNumber/resend` | Required | Resend WhatsApp invite. |
| DELETE | `/groups/:id/pending-members/:phoneNumber` | Required | Cancel pending invite. |
| PUT | `/groups/:id/archive` | Required | Archive (admin only). |
| PUT | `/groups/:id/unarchive` | Required | Unarchive (admin only). |
| PUT | `/groups/:id/complete` | Required | Mark complete (admin only). |

### `GET /groups`

```jsonc
// query: ?userId=<uuid>&page=1&limit=20  (userId is required)

// response 200
{ "success": true,
  "data": [{
    "id": "uuid", "name": "string", "description": "string|null", "currency": "string",
    "createdBy": "uuid", "createdAt": "ISO8601", "updatedAt": "ISO8601",
    "isArchived": "boolean",
    "memberCount": "number", "expenseCount": "number", "totalExpenses": "number",
    "myBalance": "number",   // positive = others owe me; negative = I owe
    "members": [{
      "userId": "uuid", "name": "string", "phoneNumber": "string", "email": "string|null",
      "profileImage": "string|null", "role": "creator|admin|member",
      "joinedAt": "ISO8601", "addedBy": "uuid|null", "isPlaceholder": "boolean"
    }]
  }],
  "pagination": { "page": "number", "limit": "number", "hasMore": "boolean" } }
```

### `POST /groups`

```jsonc
// request
{ "name": "string (2-255)",
  "description": "string (optional)",
  "coverImageBase64": "string (optional)",
  "currency": "string (optional, default 'INR')",
  "members": [
    { "userId": "uuid", "name": "string",
      "phoneNumber": "string (optional)", "email": "string (optional)" }
  ] }

// response 201 — group object (raw SQL row, snake_case)
```

Note: `members` here requires existing user IDs. To invite by phone (registered or not), use `POST /groups/:id/pending-members`.

### `GET /groups/:id`

```jsonc
// response 200
{ "success": true,
  "data": {
    "id": "uuid", "name": "string", "description": "string|null", "currency": "string",
    "createdBy": "uuid", "coverImageBase64": "string|null",
    "createdAt": "ISO8601", "updatedAt": "ISO8601", "isArchived": "boolean",
    "memberCount": "number", "expenseCount": "number", "totalExpenses": "number",
    "members": [/* see GET /groups */],
    "balances": { /* simplified-debt result */ }
  } }
```

Status: **403** if caller not a member, **404** if not found.

### `PUT /groups/:id`

```jsonc
// request — all optional
{ "name": "string", "description": "string",
  "coverImageBase64": "string", "currency": "string" }

// response 200 — updated group
```

Status: **403** if not admin, **404** if not found.

### `DELETE /groups/:id`

No body. Returns `{ "success": true, "message": "Group deleted successfully" }`. **403** if not admin.

### `GET /groups/:id/members`

Returns `{ "success": true, "data": [/* members */] }` — same shape as members in `GET /groups/:id`.

### `POST /groups/:id/members`

```jsonc
// request
{ "userId": "uuid",
  "name": "string (2-255)",
  "phoneNumber": "string (optional)",
  "email": "string (optional)" }

// response 201
{ "success": true, "message": "Member added successfully", "data": { /* member */ } }
```

Status: **400** if duplicate, **403** if caller not a member.

### `DELETE /groups/:id/members/:userId`

No body. Returns `{ "success": true, "message": "..." }`. Self-removal is allowed; otherwise admin-only.

### `PUT /groups/:id/members/:userId`

```jsonc
// request
{ "role": "admin | member" }

// response 200 — updated member
```

Status: **403** if not admin.

### `GET /groups/:id/pending-members`

```jsonc
// response 200
{ "success": true,
  "data": [{
    "id": "uuid", "phoneNumber": "string", "name": "string", "email": "string|null",
    "inviteCount": "number", "watiStatus": "string", "createdAt": "ISO8601"
  }] }
```

### `POST /groups/:id/pending-members`

```jsonc
// request
{ "name": "string (1-255)",
  "phoneNumber": "string (auto-normalised to +91XXXXXXXXXX if 10 digits)",
  "email": "string (optional)" }

// response 201 — when invitee is already registered
{ "success": true,
  "message": "Member added successfully (user was already registered)",
  "data": { "type": "registered", "member": { /* … */ } } }

// response 201 — when invitee isn't registered
{ "success": true,
  "message": "Pending member added to group and WhatsApp invite sent",
  "data": {
    "type": "placeholder",
    "member": { "userId": "uuid (placeholder)", "name": "string", "phoneNumber": "string",
                "email": "string|null", "isPlaceholder": true },
    "pendingInvite": { "id": "uuid", "phoneNumber": "string", "name": "string",
                       "email": "string|null", "inviteCount": "number",
                       "watiStatus": "string", "createdAt": "ISO8601" },
    "watiResult": { "success": "boolean", "error": "string|null" }
  } }
```

Status: **400** if duplicate member, **403** if caller not a member, **404** if group not found.

### `POST /groups/:id/pending-members/:phoneNumber/resend`

No body. Returns `{ "success": true, "message": "Invite resent" }`.

### `DELETE /groups/:id/pending-members/:phoneNumber`

No body. Returns `{ "success": true, "message": "Pending member removed" }`.

### `PUT /groups/:id/archive`, `/unarchive`, `/complete`

No body. Returns `{ "success": true, "message": "..." }`. **403** if not admin.

---

## Expenses

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/expenses` | Required | List expenses for a group (paginated). |
| POST | `/expenses` | Required | Create an expense + splits. |
| GET | `/expenses/:id` | Required | Get expense with participants (and receipt). |
| PUT | `/expenses/:id` | Required | Update an expense (payer only). |
| DELETE | `/expenses/:id` | Required | Delete an expense (payer or admin). |

### `GET /expenses`

```jsonc
// query: ?groupId=<uuid>&page=1&limit=50  (groupId required)

// response 200 — RAW SQL ROWS (snake_case)
{ "success": true,
  "data": [{
    "id": "uuid", "group_id": "uuid", "description": "string",
    "amount": "string (DECIMAL)", "currency": "string", "category": "string|null",
    "paid_by": "uuid", "paid_by_name": "string",
    "split_type": "equal|unequal|percentage|shares",
    "notes": "string|null",
    "expense_date": "ISO8601|null", "created_at": "ISO8601", "updated_at": "ISO8601",
    "participants": [{
      "expense_id": "uuid", "user_id": "uuid", "name": "string",
      "amount": "string (DECIMAL)", "percentage": "number|null", "shares": "number|null"
    }]
  }],
  "pagination": { "page": "number", "limit": "number", "total": "number", "hasMore": "boolean" } }
```

Status: **403** if caller not a member.

### `POST /expenses`

```jsonc
// request
{ "groupId": "uuid",
  "description": "string (1-500)",
  "amount": "number (>=0)",
  "currency": "string (3-letter code, optional)",
  "category": "string (optional)",
  "paidById": "uuid",
  "paidByName": "string",
  "splitType": "equal|unequal|percentage|shares",
  "receiptBase64": "string (optional)",
  "notes": "string (optional)",
  "expenseDate": "ISO8601 (optional)",
  "participants": [
    { "userId": "uuid", "name": "string", "amount": "number",
      "percentage": "number (optional)", "shares": "number (optional)" }
  ] }

// response 201 — created expense (raw SQL row)
```

Status: **403** if caller not a member.

### `GET /expenses/:id`

```jsonc
// response 200
{ "success": true,
  "data": { /* same shape as GET /expenses item, with receipt_base64 included */ } }
```

Status: **403** if caller not a member of the expense's group, **404** if not found.

### `PUT /expenses/:id`

```jsonc
// request — all optional
{ "description": "string",
  "amount": "number",
  "currency": "string",
  "category": "string",
  "receiptBase64": "string",
  "notes": "string",
  "expenseDate": "ISO8601" }

// response 200 — updated expense
```

Status: **403** if caller is not the payer, **404** if not found.

### `DELETE /expenses/:id`

No body. Returns `{ "success": true, "message": "Expense deleted successfully" }`. **403** if caller is not the payer or a group admin.

---

## Settlements

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/settlements` | Required | List settlements for a group. |
| POST | `/settlements` | Required | Record a settlement payment. |
| PATCH | `/settlements/:id/confirm` | Required | Confirm a pending settlement (counterparty). |
| DELETE | `/settlements/:id` | Required | Delete a settlement. |

### `GET /settlements`

```jsonc
// query: ?groupId=<uuid>&page=1&limit=50  (groupId required)

// response 200
{ "success": true,
  "data": [{
    "id": "uuid", "group_id": "uuid",
    "from_user_id": "uuid", "to_user_id": "uuid",
    "amount": "string (DECIMAL)", "currency": "string",
    "status": "pending|completed|failed",
    "notes": "string|null",
    "settled_at": "ISO8601", "confirmed_at": "ISO8601|null",
    "created_at": "ISO8601"
  }],
  "pagination": { "page": "number", "limit": "number", "total": "number", "hasMore": "boolean" } }
```

Status: **403** if caller not a member.

### `POST /settlements`

```jsonc
// request
{ "groupId": "uuid",
  "fromUserId": "uuid (must equal caller)",
  "toUserId": "uuid",
  "amount": "number (>=0)",
  "currency": "string (optional, defaults to group currency)",
  "notes": "string (optional)" }

// response 201 — created settlement (raw SQL row)
```

Status: **403** if caller is not the payer or not a group member, **409** if a pending settlement already exists between the same pair.

### `PATCH /settlements/:id/confirm`

No body. Returns the confirmed settlement. **403** if caller is not the recipient.

### `DELETE /settlements/:id`

No body. Returns `{ "success": true, "message": "Settlement deleted successfully" }`.

---

## Personal Expenses

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/personal-expenses` | Required | List own personal expenses. |
| POST | `/personal-expenses` | Required | Create a personal expense. |
| GET | `/personal-expenses/:id` | Required | Get one personal expense. |
| PUT | `/personal-expenses/:id` | Required | Update a personal expense. |
| DELETE | `/personal-expenses/:id` | Required | Delete a personal expense. |

### `GET /personal-expenses`

```jsonc
// query: ?userId=<uuid>&page=1&limit=50

// response 200
{ "success": true,
  "data": [{ /* personal expense rows */ }],
  "pagination": { "page": "number", "limit": "number", "total": "number", "hasMore": "boolean" } }
```

Status: **403** if `userId` ≠ caller.

### `POST /personal-expenses`

```jsonc
// request
{ "description": "string (1-500)",
  "amount": "number (>=0)",
  "currency": "string (optional)",
  "category": "string (optional)",
  "receiptBase64": "string (optional)",
  "notes": "string (optional)",
  "expenseDate": "ISO8601 (optional)" }

// response 201 — created expense
```

### `GET /personal-expenses/:id`, `PUT`, `DELETE`

Standard CRUD. **403** if not own expense, **404** if not found.

---

## Activities

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/activities` | Required | List own activities. |
| GET | `/activities/unread/count` | Required | Unread count for current user. |
| POST | `/activities` | Required | Create an activity (typically used internally). |
| GET | `/activities/:id` | Required | Get a single activity. |
| PATCH | `/activities/:id/read` | Required | Mark one activity read. |
| PATCH | `/activities/read-all` | Required | Mark all of caller's activities read. |
| GET | `/activities/group/:groupId` | Required | List a group's activities. ⚠️ TODO: missing membership check. |
| PATCH | `/activities/group/:groupId/read-all` | Required | Mark group activities read. ⚠️ TODO: missing membership check. |
| DELETE | `/activities/:id` | Required | Delete an activity. |

### `GET /activities`

```jsonc
// query: ?userId=<uuid>&page=1&limit=50

// response 200
{ "success": true,
  "data": [{
    "id": "uuid", "userId": "uuid", "groupId": "uuid|null",
    "activityType": "expense_added|expense_updated|expense_deleted|settlement_added|group_created|group_updated|member_added|member_removed|comment_added",
    "entityType": "string", "entityId": "uuid",
    "title": "string", "description": "string|null",
    "metadata": "object|null", "isRead": "boolean", "createdAt": "ISO8601",
    "actorName": "string|null", "groupName": "string|null"
  }],
  "pagination": { "page": "number", "limit": "number", "total": "number", "hasMore": "boolean" },
  "unreadCount": "number" }
```

Status: **403** if `userId` ≠ caller.

### `GET /activities/unread/count`

```jsonc
// query: ?userId=<uuid>

// response 200
{ "success": true, "data": { "unreadCount": "number" } }
```

### `POST /activities`

```jsonc
// request
{ "userId": "uuid (must equal caller)",
  "activityType": "string", "entityType": "string", "entityId": "uuid",
  "title": "string",
  "description": "string (optional)",
  "metadata": "object (optional)",
  "groupId": "uuid (optional)" }

// response 201 — created activity (camelCase)
```

### `PATCH /activities/:id/read`

No body. Returns the updated activity. **404** if not found.

### `PATCH /activities/read-all`

```jsonc
// request
{ "userId": "uuid (must equal caller)" }

// response 200
{ "success": true, "message": "All activities marked as read" }
```

### `GET /activities/group/:groupId` and `PATCH /activities/group/:groupId/read-all`

⚠️ Group membership is **not yet enforced** (`// TODO: Verify user is member of the group` in controller). Treat as a known security gap until patched.

### `DELETE /activities/:id`

No body. **403** if not own activity, **404** if not found.

---

## Invites

The legacy invite-code flow (separate from `pending-members`).

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/invites/create` | Required | Generate share-able invite codes for a list of phone numbers. |
| GET | `/invites/status` | Required | Look up an invite by its code. |
| POST | `/invites/accept` | Required | Accept an invite. |
| GET | `/invites/my-invites` | Required | List invites received by the caller. |
| POST | `/invites/resend` | Required | Resend an invite. |
| POST | `/invites/cancel` | Required | Cancel an invite. |

### `POST /invites/create`

```jsonc
// request
{ "phoneNumbers": ["string", ...],
  "context": { "groupName": "string (optional)" } }

// response 200
{ "success": true,
  "data": {
    "invites": [{
      "phoneNumber": "string", "inviteCode": "string",
      "shareUrl": "string", "shareMessage": "string"
    }]
  } }
```

### `GET /invites/status`

```jsonc
// query: ?inviteCode=<string>

// response 200 — invite record with status
```

Status: **400** if `inviteCode` missing.

### `POST /invites/accept`

```jsonc
// request
{ "inviteCode": "string" }

// response 200 — accepted invite + group join confirmation
```

### `GET /invites/my-invites`

No body. Returns invites where the recipient phone matches the caller.

### `POST /invites/resend`

```jsonc
// request
{ "inviteId": "uuid" }
```

### `POST /invites/cancel`

```jsonc
// request
{ "inviteId": "uuid" }
```

---

## Sync

Used by the offline-first mobile flow to push queued mutations once connectivity returns.

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/sync` | Required | Bulk apply CREATE / UPDATE / DELETE operations. |
| GET | `/sync/last` | Required | Last successful sync timestamp for a user. |

### `POST /sync`

```jsonc
// request
{ "operations": [
    { "type": "CREATE | UPDATE | DELETE",
      "table": "string (table/resource name)",
      "data": "object",
      "recordId": "uuid" }
  ] }

// response 200
{ "success": true,
  "message": "Sync completed",
  "data": {
    "processed": "number",
    "successful": "number",
    "failed": "number",
    "results": [{ "recordId": "uuid", "success": "boolean", "id": "uuid (on CREATE)" }],
    "errors":  [{ "recordId": "uuid", "error": "string" }]
  } }
```

### `GET /sync/last`

```jsonc
// query: ?userId=<uuid>

// response 200
{ "success": true, "data": { "lastSyncedAt": "ISO8601|null" } }
```

Status: **403** if `userId` ≠ caller.

---

## Misc / Health

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/health` | Public | Liveness check with pool + cache metrics. (Note: `/health` is **not** under `/api/v1`.) |

```jsonc
// response 200
{ "status": "ok",
  "uptime": "number (seconds)",
  "timestamp": "ISO8601",
  "version": "string",
  "pool": { /* pg pool stats */ },
  "cache": { /* in-memory cache stats */ } }
```

---

## Cross-cutting notes

- **camelCase vs snake_case**: most controllers transform DB rows into camelCase before responding, but a few list endpoints (`GET /expenses`, `GET /settlements`, raw create/update returns) leak snake_case fields straight from the SQL row. The Flutter `ExpenseModel.fromJson` and `SettlementModel.fromJson` accept both.
- **Pagination**: every paginated list endpoint accepts `?page=1&limit=N` and returns `pagination: { page, limit, total?, hasMore }`. `total` is omitted on a few endpoints to save a `COUNT(*)`.
- **Rate limiting**: 200 req/min per IP on every `/api/*` route ([server.js:50](backend/src/server.js#L50)).
- **Auth middleware** (`authenticate`): reads `Authorization: Bearer <jwt>`, decodes, sets `req.user.id`. On expiry returns 401 — the Flutter Dio interceptor auto-refreshes once before failing.
- **Phone-number normalisation**: client-side, the Flutter side prepends `+91` to bare 10-digit numbers; backend regex `^\+?[1-9]\d{1,14}$` enforces E.164.
- **Dev-mode master OTP**: `123456` is accepted for any phone when `NODE_ENV !== 'production'` (auth controller). Real SMS/WATI delivery is still a TODO stub in `src/utils/otp.js`.
- **Schema duplication**: the live schema is created by `src/config/initDatabase.js`, **not** by `migrations/001_initial_schema.sql` — the two files use different table names (`expense_splits` vs `expense_participants`). All controller code uses `expense_splits`.
