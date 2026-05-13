---
name: cache-audit
description: Use when the user reports stale data after a write (e.g. "expense added but list shows old data", "I archived a group, still shows in dashboard", "balance is wrong after settlement"), or asks for a cache-correctness review. Audits backend/src/models/ + controllers for read keys that aren't invalidated on writes, using the in-memory cache from backend/src/services/cacheService.js.
allowed-tools: Read, Grep, Glob, Bash
---

# Audit cache invalidation correctness

The backend uses a single-process in-memory LRU cache ([backend/src/services/cacheService.js](backend/src/services/cacheService.js)). Read paths use `cache.getOrSet(key, TTL.X, fn)`; write paths MUST call `cache.del(key)` or `cache.invalidate(prefix)` to evict stale entries. If a write forgets, users see old data until the TTL (30s–5min) expires.

This skill systematically finds gaps.

## Mental model

```
Read path:  cache.getOrSet(<key>, TTL.X, () => SELECT ...)
                                  ↑
                                  | must be invalidated
                                  ↓
Write path: INSERT / UPDATE / DELETE → cache.del(<key>) OR cache.invalidate(<prefix>)
```

A correctness check is just:
1. List every key produced by `cache.getOrSet(...)`.
2. For each, find every code path that mutates the underlying data.
3. Confirm each write path calls a matching `cache.del` / `cache.invalidate`.

## Step-by-step audit

### 1. Enumerate every cache READ key

```bash
grep -rn "cache.getOrSet" backend/src/
```

For each hit, jot down:
- File:line
- The key pattern (e.g. `group:${id}:members`)
- The TTL constant

### 2. Enumerate every cache WRITE invalidation

```bash
grep -rn "cache.del\|cache.invalidate" backend/src/
```

### 3. Enumerate every SQL mutation

```bash
grep -rnE "INSERT INTO|UPDATE\s+\w+|DELETE FROM" backend/src/models/
```

### 4. For each mutation, ask three questions

a) **What read keys could now be stale?**
   - Same table → check every `getOrSet` that selects from it.
   - JOIN dependency → does any cached key SELECT through a JOIN that involves this table? (e.g. `Expense.findByGroupId` JOINs `users` — if a user renames, the cached name is stale until TTL expires; that's an accepted-by-design tradeoff in this codebase, but flag it.)
   - Aggregate caches → did `member_count`, `expense_count`, `total_expenses` change? Those live on `group:<id>`.

b) **Does the model method follow with invalidation?**
   - Inside the model? (Preferred — see `Group.update` which ends with `cache.del('group:'+id)`.)
   - Inside the controller via `<Model>.invalidate*()`? (Acceptable — see `expenseController.createExpense` calling `Expense.invalidateGroupExpenses(groupId)`.)

c) **Is the invalidation prefix wide enough?**
   - `cache.del('group:123')` only deletes that one key. Reads under `group:123:members`, `group:123:expenses:50:0`, `group:123:balances` STAY.
   - `cache.invalidate('group:123')` deletes ALL keys starting with `group:123` — the heavy hammer.
   - `cache.invalidate('group:123:expenses')` is precise — only kills expense pages, leaves `:members` warm.

### 5. Produce a report

For each suspected gap, produce one row like this:

```
GAP: file:line  Write at <SQL statement> doesn't invalidate <key pattern>
     Symptom: stale <feature> until TTL.<NAME> expires (<seconds>s)
     Fix:     Call <Model>.invalidate<scope>(<args>) after the write OR add cache.invalidate(<prefix>)
```

Show the actual lines from each file as context — Read both files when reporting so the user can verify.

## Known-good patterns in this codebase (use as reference)

Expense write → invalidates everything group-scoped on that group, including derived aggregates:
- [backend/src/controllers/expenseController.js](backend/src/controllers/expenseController.js) calls `Expense.invalidateGroupExpenses(groupId)` after `create`, `update`, `delete`.
- [backend/src/models/Expense.js](backend/src/models/Expense.js) `invalidateGroupExpenses` does:
  ```js
  cache.invalidate(`group:${groupId}:expenses`); // every paginated page
  cache.invalidate(`group:${groupId}:balances`); // dependent aggregate
  cache.del(`group:${groupId}`);                 // expense_count/total_expenses
  ```

Member write → invalidates membership + group aggregate:
- [backend/src/models/Group.js](backend/src/models/Group.js) `invalidateMembers(groupId, userId)`:
  ```js
  cache.del(`group:${groupId}:members`);
  cache.del(`group:${groupId}`);
  cache.del(`group:${groupId}:access:${userId}`);
  cache.del(`group:${groupId}:admin:${userId}`);
  ```

User-profile update → invalidates auth cache only:
- `cache.del(`auth:user:${userId}`)`

## Red flags to call out automatically

- A write method that returns the new row but does NOT touch the cache.
- A `transaction(...)` block that performs multiple mutations but invalidates only one of them.
- A new endpoint added to `routes/` without a corresponding `cache.invalidate` somewhere in the call graph.
- A read key with `TTL.GROUP_BALANCES` (or any `_BALANCES` key) that isn't paired with a settlement-flow invalidation.
- A new role-changing operation that misses `cache.del('group:<id>:admin:<userId>')`.
- An invalidation key with a typo — e.g. `cache.invalidate('groups:<id>')` (note the plural) when readers write `group:<id>`. Cache keys are strings; typos silently no-op.

## Output format

Lead with:
1. **Confirmed gaps** — write → missing invalidation, with file:line links.
2. **Suspected gaps** — needs human judgment (e.g. JOIN-derived staleness that may be acceptable).
3. **Clean paths** — what's verified correct, so the user knows what you covered.

Keep the report scannable. Use file:line links so the user can jump straight to the code.
