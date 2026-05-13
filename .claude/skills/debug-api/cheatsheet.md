# API contract cheatsheet

Quick reference while debugging. All paths verified against the running code in this repo.

## Response envelope

```json
// Success
{ "success": true, "data": <object|array>, "message": "...", "pagination": {...} }

// Error
{ "success": false, "error": "Human-readable message", "details": [ ... ] }
```

The Flutter side's `_ensureMap`/`_ensureList`/`_ensureSuccess` (in every repository) assert this shape. Break it and every repository call surfaces "Malformed response".

## Status code semantics

| Status | Means                                                       | Common triggers in this app                                       |
|--------|-------------------------------------------------------------|-------------------------------------------------------------------|
| 200    | OK                                                          | Default success                                                    |
| 201    | Created                                                     | POST that creates a row                                            |
| 400    | Bad request — validation or business logic                  | `validate` middleware, missing query params                       |
| 401    | No / invalid / expired token                                | `authenticate` middleware                                         |
| 403    | Authenticated but not allowed                                | `GroupService.validateGroupAccess` fail, `Group.isAdmin` fail    |
| 404    | Not found                                                    | `Model.findById` returned null OR no matching route               |
| 409    | Conflict (unique constraint)                                | PG error code `23505` — duplicate phone, duplicate membership    |
| 500    | Anything reaching `errorHandler.js` unhandled               | DB connection lost, unexpected throw                              |

## Backend base URL

```
ApiConfig.baseUrl = 'http://localhost:3000/api/v1'   // default for dev
                  = String.fromEnvironment('API_BASE_URL', ...)
```

Run Flutter with `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1` for Android emulator or your LAN IP for a physical device. `adb reverse tcp:3000 tcp:3000` lets `localhost:3000` work on a USB-connected device.

## Field-name conventions

| Flutter (camelCase)       | Backend incoming (request body, camelCase) | DB column (snake_case) |
|---------------------------|--------------------------------------------|------------------------|
| `groupId`                 | `groupId`                                  | `group_id`             |
| `paidById` / `paidByName` | `paidById` / `paidByName`                  | `paid_by` / -          |
| `expenseDate`             | `expenseDate`                              | `expense_date`         |
| `receiptBase64`           | `receiptBase64`                            | `receipt_base64`       |
| `phoneNumber`             | `phoneNumber`                              | `phone_number`         |
| `splitType`               | `splitType`                                | `split_type`           |
| `userId`                  | `userId`                                   | `user_id`              |

When the model returns a row, columns come back as snake_case from `pg`. Flutter model factories handle BOTH cases (see `expense_model.dart` for the pattern). If you add a new field, follow this exact triad.

## Currency normalization

| In Flutter state | Sent to backend | Stored in DB           |
|------------------|-----------------|------------------------|
| `₹`              | `INR`           | `INR` (`VARCHAR(3)`)    |
| `$`              | `USD`           | `USD`                  |
| `€`              | `EUR`           | `EUR`                  |
| `£`              | `GBP`           | `GBP`                  |
| `INR` (passthru) | `INR`           | `INR`                  |

If a repository skips `_normalizeCurrency`, the backend's `VARCHAR(3)` constraint trips on the symbol.

## Auth headers

```
Authorization: Bearer <accessToken>
```

Attached automatically by `_AuthInterceptor`. Never add manually.

## Refresh flow

1. Request → 401
2. Interceptor calls `POST /auth/refresh` with `{ refreshToken }`
3. Response: `{ success: true, data: { accessToken } }`
4. New access token saved; original request replayed once

Refresh tokens themselves don't rotate in this codebase. If the refresh fails, tokens are cleared and `onUnauthorized` is emitted (the auth provider should then log the user out).

## Validation error shape

```json
{
  "success": false,
  "error": "Validation failed",
  "details": [
    { "field": "amount", "message": "amount must be a non-negative number" }
  ]
}
```

If you see "Validation failed" without `details`, the backend version is old.

## Rate limit

`/api` is wrapped in `express-rate-limit` — 200 requests/minute per IP. Burst-tight tests will see:

```json
{ "success": false, "error": "Too many requests, please try again later" }
```

with status 429.

## Body size limit

`express.json({ limit: '2mb' })`. Receipt images > 2 MB after base64-encoding will hit this. Compress before sending (see `api-repository` examples).

## Health check

```bash
curl http://localhost:3000/health
```

Returns pool metrics and cache stats. If `pool.waiting > 0` repeatedly, the pool is saturated. If `cache.hitRate` is very low, look for invalidation bugs.
