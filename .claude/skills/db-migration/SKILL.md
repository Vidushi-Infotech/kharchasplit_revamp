---
name: db-migration
description: Use when the KharchaSplit backend schema needs a change (e.g. "add a recurring flag to expenses", "create a categories table", "add an index for slow query X", "drop the unused referral_code column"). Creates a new numbered .sql file under backend/migrations/, registers it in migrate.js, and updates the matching Model.js where needed. PostgreSQL specifics: uuid_generate_v4, soft deletes via deleted_at, the existing update_updated_at_column trigger.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Add a PostgreSQL migration

This skill produces a new migration that fits the existing pattern in [backend/migrations/](backend/migrations/). The runner is [backend/migrations/migrate.js](backend/migrations/migrate.js) — a numbered list of `.sql` files executed in order.

## Migration file naming

```
backend/migrations/NNN_short_description.sql
```

- `NNN` is the next free three-digit number. Existing numbers in this repo: `001`–`008`. The next would be `009`.
- Description is snake_case. Past examples: `005_add_archived_at_to_groups.sql`, `007_add_pending_invites_table.sql`, `008_add_placeholder_user_support.sql`.

If you see two migrations with the same number (this repo has `004_add_invites_table.sql` AND `004_fix_duplicate_phone_numbers.sql`), check `migrate.js` for which one is actually executed — the OTHER one is a stranded duplicate. **Do not propagate that mistake** — use a fresh number.

## The runner (mandatory step)

Open [backend/migrations/migrate.js](backend/migrations/migrate.js) and add your filename to the `migrations` array, IN ORDER. If you forget this step, your migration is dead code.

```js
const migrations = [
  '001_initial_schema.sql',
  '002_add_currency_to_groups.sql',
  '003_add_preferred_currency_to_users.sql',
  '004_fix_duplicate_phone_numbers.sql',
  '007_add_pending_invites_table.sql',
  '008_add_placeholder_user_support.sql',
  '009_<your_migration>.sql',  // <-- ADD HERE
];
```

## Idempotency rules

Migrations re-run on every `npm run migrate`. Every statement MUST be safe to run twice. Use:

| Operation              | Guard                                                                  |
|------------------------|------------------------------------------------------------------------|
| `CREATE TABLE`         | `CREATE TABLE IF NOT EXISTS ...`                                       |
| `ALTER TABLE ADD COL`  | `ALTER TABLE x ADD COLUMN IF NOT EXISTS ...`                          |
| `CREATE INDEX`         | `CREATE INDEX IF NOT EXISTS ...`                                       |
| `CREATE TRIGGER`       | `DROP TRIGGER IF EXISTS x ON tbl; CREATE TRIGGER x ...` (no IF NOT EXISTS for triggers in Postgres) |
| `INSERT` of seed data  | `INSERT ... ON CONFLICT DO NOTHING`                                    |
| Backfill UPDATE        | `WHERE col IS NULL` so re-run is a no-op                                |

## Conventions verified in this codebase

1. **Primary key:** `id UUID PRIMARY KEY DEFAULT uuid_generate_v4()` — `uuid-ossp` extension is enabled in 001.
2. **Soft delete:** every domain table has `deleted_at TIMESTAMP WITH TIME ZONE` + `CREATE INDEX idx_<table>_deleted ON <table>(deleted_at)`.
3. **Audit columns:** `created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(), updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()`.
4. **`updated_at` trigger:** there's a shared `update_updated_at_column()` function. Attach it via `CREATE TRIGGER update_<table>_updated_at BEFORE UPDATE ON <table> FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();`.
5. **Foreign keys** to `users.id` use `REFERENCES users(id)` (no ON DELETE — soft deletes only). To `groups.id` use `REFERENCES groups(id) ON DELETE CASCADE`.
6. **Money:** `DECIMAL(15, 2)` with `CHECK (amount > 0)` or `>= 0` as appropriate.
7. **Currency:** `VARCHAR(3) DEFAULT 'INR'` (this app is INR-default; older code uses `'USD'` as default — when adding new tables prefer `'INR'`).
8. **Phone:** `VARCHAR(20)` with `CHECK (phone_number ~ '^\\+?[1-9]\\d{1,14}$')`.
9. **Enums via CHECK:** `role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('creator', 'admin', 'member'))`.
10. **Indexes:** always index FK columns and any column you `WHERE` on. Composite indexes for hot queries.
11. **`COMMENT ON TABLE/COLUMN`** when the purpose isn't obvious from the name (see `007_add_pending_invites_table.sql`).

## Step-by-step

### 1. Sanity-check the change against the live schema

```bash
grep -rn "CREATE TABLE" backend/migrations/
grep -rn "ALTER TABLE.*<your_table>" backend/migrations/
```

If you're adding a column, make sure none of the older migrations already added it (otherwise your migration will be a no-op thanks to `IF NOT EXISTS`).

### 2. Pick the right template

- **New table:** `templates/new_table.sql`
- **Add column:** `templates/add_column.sql`
- **Add index for slow query:** `templates/add_index.sql`
- **Backfill data:** `templates/backfill.sql`

### 3. Write the migration

Copy the template, replace placeholders, keep it idempotent.

### 4. Register it in `migrate.js`

```js
'009_<your_migration>.sql',
```

### 5. Update the matching Model

If you added a column, the model's SELECT statements (in `backend/src/models/*.js`) need to include it. The models use explicit column lists (NEVER `SELECT *`) — find every `SELECT ...` for that table and add the new column. Same for `INSERT` / `UPDATE`.

```bash
grep -n "FROM <table>" backend/src/models/<Model>.js
grep -n "INSERT INTO <table>" backend/src/models/<Model>.js
grep -n "UPDATE <table>" backend/src/models/<Model>.js
```

### 6. Run it locally

```bash
cd backend && npm run migrate
```

Watch for `✅ Completed: 009_...`. Then verify:

```bash
psql kharchasplit -c "\d <table>"
```

### 7. If you're adding an index for a slow query

After running, confirm the planner is using it:

```bash
psql kharchasplit -c "EXPLAIN ANALYZE SELECT ... your query ..."
```

Look for `Index Scan using <index_name>` (good) vs `Seq Scan` (bad — index unused).

## Things this skill will NOT do

- **No DROP without explicit confirmation.** Dropping columns or tables is destructive and often unrecoverable. If the user asks for a drop, surface the impact first (which models, controllers, repositories, and Flutter models touch the column) before producing the SQL.
- **No rewriting `001_initial_schema.sql`.** Always add a new file.
- **No DELETE migrations.** Use soft delete (`UPDATE ... SET deleted_at = NOW()`) — that's the project rule.
- **No `BEGIN; ... COMMIT;` wrapping.** `migrate.js` runs each file as one `pool.query(sql)` call which Postgres already treats atomically per statement. If you need multi-statement transactionality, wrap in `BEGIN; ... COMMIT;` inside the file explicitly and call it out.

## Common mistakes

| ❌ Wrong                                  | ✅ Correct                                                |
|------------------------------------------|----------------------------------------------------------|
| Adding a `NOT NULL` column without a default to a populated table | Add nullable → backfill → set NOT NULL in a follow-up migration |
| Creating an index without `IF NOT EXISTS`| Always idempotent                                         |
| Forgetting to update `migrate.js`        | The migration won't run                                   |
| Adding a column but not updating model SELECTs | Reads will silently miss the new column            |
| `CASCADE` ON delete for user references  | Users are soft-deleted; cascade would orphan group membership |
| Naming index `idx_groups_archived_at` AND another file named `archived` | Conflicts on re-run — check existing index names with `\di` |
