---
name: trace-feature
description: Use when the user wants to understand how an existing feature flows end-to-end across this Flutter + Express + PostgreSQL stack (e.g. "explain how adding an expense works", "trace the settlement flow", "where does the dashboard balance number come from?", "how is auth wired up?"). Walks the chain Flutter screen → Riverpod provider → repository → HTTP route → Express controller → model → cache → SQL → table, with file:line links the user can click.
allowed-tools: Read, Grep, Glob, Bash
---

# Trace a feature across the stack

This skill produces a top-to-bottom map of one feature, anchored in real files in this repo. The output is structured so the user can follow each hop and audit assumptions.

## The seven layers

Every user-visible feature in KharchaSplit travels through this exact pipeline:

```
1. SCREEN              frontend/lib/modules/<module>/screens/<name>_screen.dart
2. STATE (Riverpod)    frontend/lib/modules/<module>/state/<name>_provider.dart
3. REPOSITORY          frontend/lib/data/<resource>/<resource>_repository.dart
4. ROUTE               backend/src/routes/<resource>Routes.js
5. CONTROLLER          backend/src/controllers/<resource>Controller.js
6. MODEL               backend/src/models/<Resource>.js
7. SQL / TABLE         backend/migrations/*.sql
```

(Caching sits between 6 and 7 via [backend/src/services/cacheService.js](backend/src/services/cacheService.js). Activity logs are a side-effect from 5 into [backend/src/services/activityService.js](backend/src/services/activityService.js).)

## Step-by-step trace

### 1. Find the user-facing entry point

Ask: where does the user actually trigger this? Search for the label or screen they describe.

```bash
grep -rn "Add Expense\|Settle Up\|Archive" frontend/lib/modules/ --include='*.dart'
grep -rn "<button text or icon>" frontend/lib/
```

Open the screen file. Note the route name in [app_router.dart](frontend/lib/core/routing/app_router.dart) that points to it.

### 2. Find the Riverpod calls

In the screen, look for `ref.read(...)` and `ref.watch(...)`. These point you to providers in the `state/` folder.

```bash
grep -n "ref\.read\|ref\.watch" <screen file>
```

For each provider, open it and look at:
- `build()` — what does it return on first load? Usually a repository call.
- Mutation methods (`add`, `update`, `refresh`) — what repository method do they call?

### 3. Find the repository method

The repository is the boundary to the network. Open `frontend/lib/data/<resource>/<resource>_repository.dart`.

```bash
ls frontend/lib/data/
```

In the method:
- HTTP verb + path (e.g. `dio.post('/expenses', ...)`).
- Request body shape — note every field name (these must match the backend validator).
- Response parsing — `_ensureMap` returns a single object, `_ensureList` returns a list.

### 4. Find the matching Express route

`baseUrl` is `<host>/api/v1`. So `dio.post('/expenses')` hits the route registered in [backend/src/routes/expenseRoutes.js](backend/src/routes/expenseRoutes.js).

```bash
grep -n "router\." backend/src/routes/<resource>Routes.js
```

Note:
- Middleware chain — usually `authenticate, [validators], validate, controller.method`.
- Validator array tells you what fields the backend requires and what it normalises.

### 5. Open the controller method

```bash
grep -n "<method name>" backend/src/controllers/<resource>Controller.js
```

In the controller:
- Access checks (`GroupService.validateGroupAccess`, `Group.isAdmin`).
- Model calls (the actual mutation or fetch).
- Cache invalidation (`<Model>.invalidate<Scope>(...)`).
- Activity log calls (`ActivityService.log<Event>(...)`).
- Response shape.

### 6. Open the model method

```bash
grep -n "static async <method>" backend/src/models/<Resource>.js
```

In the model:
- `cache.getOrSet(key, TTL.X, ...)` for reads.
- `query(...)` for single-statement writes.
- `transaction(...)` for multi-statement writes.
- SQL itself — column list tells you the contract with the DB.

### 7. Open the schema

```bash
grep -rn "CREATE TABLE.*<table_name>\|ALTER TABLE <table_name>" backend/migrations/
```

The columns + constraints + indexes are the ultimate ground truth. Soft delete (`deleted_at`) and audit columns (`created_at`, `updated_at`) are universal.

## Reporting format

Output a structured trace with this layout — short, file:line links throughout:

```
## Trace: "<feature>"

### 1. Entry point
- Screen:       [<file>:<line>](path#L<line>)
- Route:        `<go_router path>` registered at [app_router.dart:<line>](frontend/lib/core/routing/app_router.dart#L<line>)
- Action:       Tap on `<widget>` → `ref.read(<provider>.notifier).<method>()`

### 2. Riverpod
- Provider:     [<provider file>:<line>](path#L<line>)
- Method:       `<method>()` calls `<repository>.<method>(...)`
- State after:  ...

### 3. Repository
- File:         [<repo file>:<line>](path#L<line>)
- HTTP:         `<VERB> <path>`
- Request:      ```json
                { ... }
                ```
- Response:     Parsed into `<Model>.fromJson(...)`.

### 4. Route + middleware
- File:         [<routes file>:<line>](path#L<line>)
- Middleware:   `authenticate → [validators] → validate → <controller>.<method>`
- Validators:   `body('x').notEmpty()...` (list each)

### 5. Controller
- File:         [<controller>:<line>](path#L<line>)
- Access:       `GroupService.validateGroupAccess(...)` etc.
- Model call:   `<Model>.<method>(...)`
- Cache:        `<Model>.invalidate<Scope>(...)`
- Activity:     `ActivityService.log<Event>(...)`
- Response:     `{ success, data, message? }` with status `<code>`.

### 6. Model
- File:         [<model>:<line>](path#L<line>)
- Cache key:    `<key pattern>` (TTL.<NAME>)
- SQL:          (paste the SQL)
- Tables hit:   `<table>` (FK to `<other table>`)

### 7. Schema
- Migration:    [<NNN_xxx.sql>](backend/migrations/NNN_xxx.sql)
- Columns:      (list relevant ones with constraints)
- Indexes:      `idx_<table>_<col>` etc.

### Side-effects / fan-out
- Activity feed (see ActivityService.log...)
- Cache invalidation cascade (group:<id>, group:<id>:expenses, group:<id>:balances, ...)
- Push notifications (notificationService.js — if applicable)
- WhatsApp / WATI (watiService.js — if applicable)
```

## Tips

- **Don't speculate.** If you can't find a file, say so — don't guess paths.
- **Use file:line links** so the user can click through. Markdown format: `[label](path#Lnn)`.
- **Highlight surprises** — e.g. "the screen uses `addExpenseProvider` (a `StateProvider`), NOT `expensesProvider` (the list). The list provider is invalidated AFTER the POST by `ref.invalidate(...)` in `_handleSave`."
- **Call out caching tradeoffs** — e.g. "balances are cached for 120s; this means the dashboard may lag a settlement by up to 2 minutes unless `Expense.invalidateGroupExpenses` runs."
- **Mention auth/permission gates** — e.g. "only the payer can edit; expense controller checks `existingExpense.paid_by_id !== req.user.id`."

## Limits / when to back off

This skill produces a description, not a diff. If the user wants you to CHANGE the feature, hand off to `backend-endpoint` / `flutter-module` / `api-repository` for the actual code.

If a feature is genuinely huge (auth + group creation + member invitation flow), trace ONE thread at a time and ask the user which slice they care about most.
