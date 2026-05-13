# Examples — adding a new endpoint

Two end-to-end examples that mirror code already in the repo.

---

## Example 1 — Simple GET aggregate: "spending per category for a group"

**Goal:** `GET /api/v1/expenses/by-category?groupId=:id` returning `[{ category: "food", total: 540.00 }, ...]`.

### 1. Extend the model — `backend/src/models/Expense.js`

Add this static method near the other read methods. Cache with the same TTL family as expense lists.

```js
static async sumByCategory(groupId) {
  return cache.getOrSet(
    `group:${groupId}:expenses:by-category`,
    TTL.GROUP_EXPENSES,
    async () => {
      const result = await query(
        `SELECT COALESCE(category, 'other') AS category,
                SUM(amount)::float AS total
         FROM expenses
         WHERE group_id = $1 AND deleted_at IS NULL
         GROUP BY category
         ORDER BY total DESC`,
        [groupId]
      );
      return result.rows;
    }
  );
}
```

Because the cache key starts with `group:<id>:expenses:`, the existing `Expense.invalidateGroupExpenses(groupId)` already covers it (it calls `cache.invalidate('group:<id>:expenses')` — prefix match).

### 2. Add the controller action — `backend/src/controllers/expenseController.js`

```js
const getByCategory = async (req, res, next) => {
  try {
    const { groupId } = req.query;
    if (!groupId) {
      return res.status(400).json({ success: false, error: 'groupId is required' });
    }
    await GroupService.validateGroupAccess(groupId, req.user.id);
    const rows = await Expense.sumByCategory(groupId);
    res.json({ success: true, data: rows });
  } catch (error) {
    if (error.message === 'User is not a member of this group') {
      return res.status(403).json({ success: false, error: error.message });
    }
    next(error);
  }
};
```

Don't forget to add `getByCategory` to the `export default { ... }` at the bottom.

### 3. Register the route — `backend/src/routes/expenseRoutes.js`

Place it BEFORE `/:id` so the path doesn't get captured by the param route.

```js
router.get(
  '/by-category',
  authenticate,
  [query('groupId').notEmpty().withMessage('groupId is required')],
  validate,
  expenseController.getByCategory
);
```

### 4. Done

No new migration needed. No new file. The Flutter side is then a simple repository method addition — invoke the **api-repository** skill for that.

---

## Example 2 — Mutating POST: "archive a group"

**Goal:** `POST /api/v1/groups/:id/archive` — only group admin can call it; logs activity; invalidates group cache.

### 1. Extend the model — `backend/src/models/Group.js`

Already exists (`Group.archive(id)`) — but if it didn't, this is the shape:

```js
static async archive(id) {
  const result = await query(
    `UPDATE groups SET is_archived = TRUE
     WHERE id = $1 AND deleted_at IS NULL AND is_archived = FALSE
     RETURNING id`,
    [id]
  );
  if (result.rows.length > 0) cache.del(`group:${id}`);
  return result.rows.length > 0;
}
```

### 2. Controller — `backend/src/controllers/groupController.js`

```js
const archiveGroup = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Admin guard
    const isAdmin = await Group.isAdmin(id, req.user.id);
    if (!isAdmin) {
      return res.status(403).json({ success: false, error: 'Only group admins can archive' });
    }

    const ok = await Group.archive(id);
    if (!ok) {
      return res.status(404).json({ success: false, error: 'Group not found or already archived' });
    }

    // Activity — group archived is user-visible
    await ActivityService.logGroupArchived(id, req.user.id);

    res.json({ success: true, message: 'Group archived' });
  } catch (error) {
    next(error);
  }
};
```

### 3. Route — `backend/src/routes/groupRoutes.js`

```js
router.post(
  '/:id/archive',
  authenticate,
  [param('id').isUUID().withMessage('id must be UUID')],
  validate,
  groupController.archiveGroup
);
```

### 4. Verify locally

```
curl -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/groups/<groupId>/archive
```

Expected: `{ "success": true, "message": "Group archived" }`

### 5. Frontend wiring

The matching change in Flutter:
- Add `archive(String groupId)` to `frontend/lib/data/groups/groups_repository.dart` calling `dio.post('/groups/$groupId/archive')`.
- After success, invalidate the Riverpod groups list with `ref.invalidate(groupsProvider)`.

Use the **api-repository** skill for the Flutter side.
