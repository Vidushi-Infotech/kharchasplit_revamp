---
name: backend-endpoint
description: Use when adding a new REST endpoint to the KharchaSplit Node/Express backend (e.g. "add a POST /expenses/recurring", "create endpoint to archive a group", "expose total spending per category"). Wires up route + controller + model + express-validator validation + JWT auth + cache invalidation + activity logging in the project's exact MVC layout under backend/src/.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Add a backend REST endpoint

This skill scaffolds a new endpoint that matches the existing patterns in `backend/src/`. It is opinionated — do NOT invent new conventions. Everything below is anchored in real files in this repo.

## Layout you must follow

```
backend/src/
├── routes/<resource>Routes.js          # express.Router, validators, attaches authenticate + validate
├── controllers/<resource>Controller.js # async (req, res, next) handlers, returns { success, data }
├── models/<Resource>.js                # static methods over `query` / `transaction` from config/database.js
├── services/<resource>Service.js       # cross-resource business logic (optional, only if needed)
└── server.js                            # mount the new route under /api/${API_VERSION}/<resource>
```

## Non-negotiable conventions (verified in this repo)

1. **ESM modules only** — `import x from './y.js'` with the `.js` extension. `type: "module"` is set in [backend/package.json](backend/package.json).
2. **Auth** — every authenticated endpoint must put `authenticate` from [backend/src/middleware/auth.js](backend/src/middleware/auth.js) as the FIRST middleware after the path. `req.user = { id, phone_number, name, email }` is set by it.
3. **Validation** — use `express-validator` body/query/param chains + `validate` middleware from [backend/src/middleware/validation.js](backend/src/middleware/validation.js). Place validation as a middleware ARRAY before `validate`, then the controller.
4. **Response shape** — success: `{ success: true, data, message?, pagination? }`. Error from controller: `{ success: false, error }` with appropriate HTTP status. Never throw 500 by hand — call `next(error)` so the global handler in [backend/src/middleware/errorHandler.js](backend/src/middleware/errorHandler.js) catches it.
5. **Database access** — use `query` and `transaction` from [backend/src/config/database.js](backend/src/config/database.js). NEVER `pool.query` directly from controllers. Multi-row writes belong in `transaction(async (client) => { ... })`.
6. **Soft delete everywhere** — tables use `deleted_at TIMESTAMP`. Every SELECT must filter `WHERE ... AND deleted_at IS NULL`. Deletes do `UPDATE ... SET deleted_at = NOW()`.
7. **Access control** — to verify the caller can touch a group resource, call `await GroupService.validateGroupAccess(groupId, req.user.id)` (throws `'User is not a member of this group'` → translate to 403). For admin-only actions, also check `Group.isAdmin(groupId, userId)`.
8. **Caching** — read paths that are hot should use `cache.getOrSet(key, TTL.<NAME>, fn)` from [backend/src/services/cacheService.js](backend/src/services/cacheService.js). On WRITE paths, you MUST invalidate. See cache key conventions in `reference.md`.
9. **Activity log** — user-visible mutations (expense added, member added, settled) MUST call the corresponding `ActivityService.log*` method. See `examples.md`.
10. **N+1 hygiene** — when returning a list of parents with nested children, batch the children with `WHERE x IN ($1, $2, ...)` (see [backend/src/models/Expense.js:42-89](backend/src/models/Expense.js#L42-L89) for the canonical pattern).

## Step-by-step

### 1. Find the closest existing endpoint and read it end-to-end

Look up an analogous endpoint and read its route + controller + model. Examples:
- Group-scoped resource that paginates? → `expenseRoutes.js` / `expenseController.js` / `Expense.js`.
- Single-row update with admin guard? → `groupController.js` (archive/unarchive).
- Resource with WhatsApp side-effect? → `inviteController.js`.

```bash
ls backend/src/routes
ls backend/src/controllers
ls backend/src/models
```

### 2. Write the route file

Use `templates/route.template.js`. The validator array MUST appear between `authenticate` and `validate`. Use `body()` for POST/PUT, `query()` for GET filters, `param()` for path params.

### 3. Write the controller

Use `templates/controller.template.js`. Each handler:
- Wraps body in `try/catch` and falls back to `next(error)`.
- Returns access-denied as 403 by checking the error message from `GroupService.validateGroupAccess`.
- Calls `Model.invalidate*()` after every mutating call.
- Calls `ActivityService.log*` after user-visible mutations.

### 4. Write or extend the model

Use `templates/model.template.js`. Static methods only. Read methods may use `cache.getOrSet`. Write methods MUST end with `cache.invalidate(prefix)` or `cache.del(key)` calls that match every read key.

### 5. Mount the route in `server.js`

Add an import alongside the others and `app.use(`/api/${API_VERSION}/<resource>`, <resource>Routes);`. Keep them in the same order as the existing block.

### 6. If schema changes are needed

Invoke the **db-migration** skill. Do NOT alter [backend/migrations/001_initial_schema.sql](backend/migrations/001_initial_schema.sql) for new changes — always create a new numbered file.

### 7. Verify

```bash
cd backend && npm run lint
cd backend && node --check src/routes/<resource>Routes.js
cd backend && node --check src/controllers/<resource>Controller.js
cd backend && node --check src/models/<Resource>.js
```

If `dev` is already running with nodemon, the new route is hot-reloaded — hit it with `curl -H "Authorization: Bearer <token>" http://localhost:3000/api/v1/<resource>` to sanity-check.

## Common mistakes — refuse to commit any of these

| ❌ Wrong | ✅ Correct |
|---------|----------|
| `res.status(500).json(...)` in controller | `next(error)` — let errorHandler.js handle it |
| `pool.query(...)` in controller | Move the SQL into the model |
| `SELECT * FROM expenses WHERE group_id = $1` | Explicit columns; add `AND deleted_at IS NULL` |
| Write method without cache invalidation | Always pair writes with `cache.invalidate` / `cache.del` |
| Hand-rolled validation `if (!req.body.x) ...` | `express-validator` chain + `validate` middleware |
| `.findOne({...})` Mongoose-style helper | Plain SQL via `query()` — this is `pg`, not an ORM |
| `req.userId` | `req.user.id` (the middleware uses `req.user`) |
| Forgetting `.js` extension on imports | ESM requires it: `import x from './y.js'` |

See `examples.md` for two complete, working endpoint diffs that exactly mirror this repo's style. See `reference.md` for cache-key conventions and the response-shape contract.
