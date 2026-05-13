---
name: debug-api
description: Use when the user reports an API failure — 400/401/403/404/500 from the Flutter app, "endpoint not working", "got Malformed response — expected object in data", "Validation failed", auth refresh issues, currency mismatch (₹ vs INR), CORS errors, or general Flutter↔backend disagreement. Walks the request through Dio → interceptor → Express → controller → response envelope, isolating where the contract breaks, and proposes the correct fix on the right side.
allowed-tools: Read, Grep, Glob, Bash
---

# Debug a Flutter ↔ backend API mismatch

This skill systematically isolates which side of the wire is broken and proposes the right fix. It depends on knowing the standard pieces in this stack — see `flowchart.md` for the canonical request flow and `cheatsheet.md` for the response envelope contract.

## Quick triage by symptom

| Symptom (in Flutter)                                    | First place to look                                              |
|---------------------------------------------------------|------------------------------------------------------------------|
| `Malformed response — expected object/list in data`     | Backend response shape — must be `{ success, data, ... }`        |
| `Request failed (status 400)` + "Validation failed"     | `body['details']` lists which fields — backend `route` validators|
| 401 that DOESN'T retry                                  | `/auth/refresh` returns non-200 — token store is stale          |
| 401 that retries then 401s again                        | Refresh token expired — user needs to log in again              |
| 403 "User is not a member of this group"                | `GroupService.validateGroupAccess` failed — auth user vs groupId|
| 404 on a path you just added                            | Route not mounted in `server.js` OR placed AFTER `/:id` catch-all|
| 409 "Resource already exists"                           | PG unique constraint — check the `UNIQUE(...)` on the table     |
| 500 with stack trace in dev                             | `errorHandler.js` — read the original error in server logs      |
| `connection refused` / `CONNECTION_TIMEOUT`             | Server not running on `:3000` OR `adb reverse` not set up       |
| `CORS error` in Flutter web                              | `process.env.CORS_ORIGIN` doesn't include the web host          |
| Currency comes back as `₹` instead of code              | Repo skipped `_normalizeCurrency` on POST                       |
| Field arrives `null` despite being sent                 | Field name mismatch (camelCase vs snake_case)                   |
| Old data after write                                     | Missing `cache.invalidate(...)` — invoke `cache-audit` skill   |

## Investigation flowchart

```
                  ┌─────────────────────────────┐
                  │ User reports API failure    │
                  └─────────────────────────────┘
                                │
                                ▼
                  ┌─────────────────────────────┐
                  │ Reproduce with `curl` or    │
                  │ the same call from Flutter  │
                  └─────────────────────────────┘
                                │
                                ▼
                  ┌─────────────────────────────┐
                  │ Is it a network-level error │
                  │ (timeout / refused)?        │
                  └─────────────────────────────┘
                       Yes │            │ No
                           ▼            ▼
                   ┌──────────────┐  ┌───────────────────────┐
                   │ Server up?   │  │ Status code?          │
                   │ ADB reverse? │  └───────────────────────┘
                   │ Base URL?    │            │
                   └──────────────┘            ▼
                                    400 / 401 / 403 / 404 / 409 / 500
                                              │
                                              ▼
                                   See table above
```

## Step-by-step

### 1. Reproduce with `curl`

This removes Dio, interceptors, and Flutter from the picture. Copy the exact request the app would make.

```bash
TOKEN="<paste access token>"

# Replace with the actual path the Flutter code calls.
curl -i -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"groupId":"...","description":"...","amount":100,"paidById":"...","participants":[{"userId":"...","amount":100}]}' \
  http://localhost:3000/api/v1/expenses
```

If `curl` succeeds but Flutter fails → bug on the Flutter side.
If `curl` fails too → bug on the backend.

### 2. If backend bug — read the validator, controller, model in that order

```bash
# Route + validators
sed -n '1,200p' backend/src/routes/<resource>Routes.js | less

# Controller — find the method
grep -n "<methodName>" backend/src/controllers/<resource>Controller.js
```

Common backend bugs (each verified in this codebase's style):

- **Validation mismatch.** Flutter sends `paidById`; route validates `body('paidByID')`. The `validate` middleware emits 400 with `details: [{ field: 'paidByID', message: ... }]`.
- **Missing access check.** `await GroupService.validateGroupAccess(groupId, req.user.id)` — if not awaited, the throw is swallowed.
- **Wrong error mapping.** Throwing `'User is not a member of this group'` MUST be caught and turned into 403 in the controller's catch block (template in `backend-endpoint` skill).
- **N+1.** Slow response on a list endpoint → check that `findByGroupId` batches children with `WHERE x IN (...)` instead of per-row queries.
- **SQL injection vector.** All params must go via `query(sql, [...params])` — string concatenation in SQL is a bug. Audit any new model code.
- **Forgot to add `AND deleted_at IS NULL`.** Reads will return soft-deleted rows.

### 3. If Flutter bug — read repository → provider → screen

```bash
cat frontend/lib/data/<resource>/<resource>_repository.dart
```

Common Flutter bugs:

- **Path includes `/api/v1`.** Base URL already has it — strip from `dio.get('/api/v1/x')` → `dio.get('/x')`.
- **Skipped `_normalizeCurrency`.** Sending `'currency': '₹'` → backend's `VARCHAR(3)` CHECK fails → 400/500.
- **Field shape mismatch.** Backend's `participants` is `[{userId, amount, percentage?, shares?}]`. If Flutter sends `[{ user_id, amount }]`, the validator says "participants must be a non-empty array" but the data is wrong → expense saved with weird splits.
- **Skipped `_ensureMap`/`_ensureList`.** Direct `res.data['data']` instead of going through the envelope helpers — if the backend returns an error, the Flutter side reports the wrong type instead of the human-readable message.
- **State refresh missing.** After a successful write, the provider's data isn't invalidated. Add `ref.invalidate(<feature>Provider)` after the POST.
- **`validateStatus` set lower than 500 in a local Dio instance.** Always use `ref.read(apiClientProvider).dio`, not a fresh `Dio()`, so the global config (and auth interceptor) apply.

### 4. Auth-specific debugging

The `_AuthInterceptor` in [frontend/lib/core/network/api_client.dart](frontend/lib/core/network/api_client.dart) does this on every 401:

1. Calls `POST /auth/refresh` with the stored refresh token.
2. On success, retries the original request ONCE (using `_retried` extra flag to prevent loops).
3. On failure, clears tokens and emits an `onUnauthorized` event.

If you see:
- **Repeated 401 + refresh loop** → backend's refresh endpoint is returning 200 with the wrong body, or the new access token isn't being saved. Check `_doRefresh` is reading `data?['accessToken']` (the actual response key).
- **401 even on first request** → access token never made it into secure storage; check `verifyOtp` saves tokens after success.
- **`TokenExpiredError` from backend** → JWT expired and refresh isn't working; verify `process.env.JWT_SECRET` matches across processes.

### 5. Connectivity-specific debugging

- **Android device:** `localhost:3000` works ONLY if `adb reverse tcp:3000 tcp:3000` is set. Otherwise use the host machine's LAN IP.
- **iOS simulator:** `localhost:3000` works directly.
- **Web (Chrome):** CORS — backend allows `process.env.CORS_ORIGIN || '*'`. In production, lock this down.

```bash
# Verify the backend is reachable
curl http://localhost:3000/health
# Expected: { success: true, message: "KharchaSplit API is running", ... }
```

### 6. Compare response with what Flutter expects

Side-by-side the actual `curl` response with the model's `fromJson` factory. Mismatches surface here. Example for `ExpenseModel`:

```dart
// frontend/lib/models/expense_model.dart accepts EITHER:
{ "paidBy": { "id": "...", "name": "..." }, "splits": [...] }
// OR
{ "paid_by": "uuid", "paid_by_name": "...", "participants": [...] }
```

If the backend returns yet a third shape (e.g. `{ payer: {...} }`), the model returns `'Unknown'` silently — the UI looks broken but no error is thrown.

## When the answer is "the contract needs to change"

Sometimes the right fix is to change the response shape on the backend AND the parser on the frontend in one commit. In that case:

1. Update the controller to match the desired shape.
2. Update the model `fromJson` to parse it.
3. Keep backwards-compat for ONE release if the API is shared with other clients (this app currently isn't).

Hand off the actual edit to `backend-endpoint` (server side) and `api-repository` (client side).

## Output format

Diagnose, then suggest a single concrete fix:

```
**Diagnosis:** <one sentence — what's wrong and where>
**Evidence:**
  - <repro curl output / file:line>
  - <opposite side file:line>
**Fix:** <which file changes, in 1-2 lines>
**Verify:** <command or step the user can run>
```

Avoid speculation. Only claim a root cause when the evidence is two-sided (both sides of the wire).
