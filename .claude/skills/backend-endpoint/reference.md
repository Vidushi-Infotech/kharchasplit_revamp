# Reference — KharchaSplit backend conventions

## Cache keys (from real reads in `backend/src/models/`)

Every read that uses `cache.getOrSet(key, TTL.X, ...)` must have a matching invalidation on writes. These are the canonical key shapes in this codebase:

| Key pattern                                  | Used by                              | Invalidated by                                                    |
|----------------------------------------------|--------------------------------------|-------------------------------------------------------------------|
| `auth:user:<userId>`                         | `middleware/auth.js`                 | User profile update — `cache.del('auth:user:'+id)`               |
| `group:<groupId>`                            | `Group.findById`                     | Any group field/aggregate change — `cache.del('group:'+id)`       |
| `group:<groupId>:members`                    | `Group.getMembers`                   | `Group.invalidateMembers(groupId, userId)`                        |
| `group:<groupId>:access:<userId>`            | `Group.isMember`                     | `Group.invalidateMembers(groupId, userId)`                        |
| `group:<groupId>:admin:<userId>`             | `Group.isAdmin`                      | `Group.invalidateMembers(groupId, userId)` + role change          |
| `group:<groupId>:expenses:<limit>:<offset>`  | `Expense.findByGroupId`              | `Expense.invalidateGroupExpenses(groupId)`                        |
| `group:<groupId>:balances`                   | balance aggregates                   | `Expense.invalidateGroupExpenses(groupId)`                        |
| `group:<groupId>:settlements`                | settlements list                     | settlement model invalidation                                     |

**Wildcard rule:** `cache.invalidate('group:<id>')` deletes every key with that prefix — useful but heavy. Prefer `cache.invalidate('group:<id>:expenses')` if you only want to nuke expense pages, leaving `:members` warm.

## TTL constants (centralized in `cacheService.js`)

```
AUTH_USER          300 s   — user identity per request
USER_PROFILE       300 s
GROUP_DETAIL        60 s
GROUP_MEMBERS      120 s
GROUP_BALANCES     120 s   — most expensive computation
GROUP_EXPENSES      60 s
GROUP_SETTLEMENTS   60 s
MEMBER_ACCESS      120 s   — isMember / isAdmin checks
```

Add a new constant only if your read pattern is genuinely different. Otherwise reuse.

## Response shape contract

The Flutter client (`frontend/lib/data/**/_repository.dart`) all parses one of these two:

**Success:**
```json
{ "success": true, "message": "Optional", "data": <object|array>, "pagination": { "page": 1, "limit": 50, "total": 123, "hasMore": true } }
```

**Error:**
```json
{ "success": false, "error": "Human-readable message" }
```

The Flutter repositories assert `body['success'] == true` and pull `body['data']`. Do not nest data inside `result` or `payload` — that breaks every repository.

## HTTP status code conventions

| Status | When                                                            |
|--------|-----------------------------------------------------------------|
| 200    | Default success                                                  |
| 201    | After a successful POST that creates a resource                  |
| 400    | Validation failure (auto-emitted by `validate` middleware)       |
| 401    | No/invalid token (auto-emitted by `authenticate` middleware)     |
| 403    | Authenticated but not allowed (e.g. not a group member)          |
| 404    | Resource not found / route not found                             |
| 409    | Unique constraint violation (auto from `err.code === '23505'`)   |
| 500    | Anything that reaches the global error handler unhandled         |

## Authentication recipe

```js
import { authenticate } from '../middleware/auth.js';

router.post('/', authenticate, validatorArray, validate, controller.handler);
```

After `authenticate`, `req.user = { id, phone_number, name, email }`. Cached for 5 minutes per user.

## Validation recipe

```js
import { body, query, param } from 'express-validator';
import { validate } from '../middleware/validation.js';

router.post('/',
  authenticate,
  [
    body('groupId').notEmpty().withMessage('groupId is required'),
    body('amount').custom(v => {
      const n = typeof v === 'number' ? v : parseFloat(v);
      if (isNaN(n) || n < 0) throw new Error('amount must be a non-negative number');
      return true;
    }),
    body('participants').isArray({ min: 1 }).withMessage('participants must be a non-empty array'),
  ],
  validate,
  controller.create
);
```

Validation errors land as:
```json
{ "success": false, "error": "Validation failed", "details": [ { "field": "amount", "message": "amount must be a non-negative number" } ] }
```

## Access-control recipe

```js
// Group membership (most common)
await GroupService.validateGroupAccess(groupId, req.user.id);

// Admin-only
const isAdmin = await Group.isAdmin(groupId, req.user.id);
if (!isAdmin) return res.status(403).json({ success: false, error: 'Admin only' });

// Owner-only (e.g. only the payer can edit an expense)
if (existing.paid_by_id !== req.user.id) {
  return res.status(403).json({ success: false, error: 'Only the payer can edit' });
}
```

Translate `'User is not a member of this group'` errors to 403 in the catch block.

## Activity log recipe

User-facing mutations append a row to the activity feed. The catalogue of helpers lives in [backend/src/services/activityService.js](backend/src/services/activityService.js) — read it before adding a new event type.

```js
await ActivityService.logExpenseAdded(expense.id, groupId, req.user.id, group.name, description, amount, currency);
await ActivityService.logSettlement(settlement.id, groupId, fromUserId, toUserId, amount, currency);
await ActivityService.logMemberAdded(groupId, addedUserId, addedByUserId);
```

Activity logging is best-effort but should NOT swallow errors silently — let them bubble to `next(error)`.
