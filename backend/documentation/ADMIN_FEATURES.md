# KharchaSplit — Group Admin Features

This document covers everything a **group admin** can do that a regular member
cannot. For the baseline feature set every signed-in user has, see
[USER_FEATURES.md](USER_FEATURES.md).

> KharchaSplit has **no platform-wide admin role**. "Admin" here always means
> *admin/creator of a specific group*. The same user can be admin of one
> group and a plain member of another — permissions are evaluated per-group.

---

## 1. How someone becomes an admin

| Path                | Mechanism                                                                          |
|---------------------|------------------------------------------------------------------------------------|
| Group creator       | The user who calls `POST /groups` is inserted into `group_members` with `role='creator'` |
| Promoted by an admin| An existing admin can call `PUT /groups/:id/members/:userId` with `{role: 'admin'}` |

The backend's `Group.isAdmin(groupId, userId)` returns true when the row's
`role IN ('creator', 'admin')`. The mobile UI currently treats
`group.createdBy == myUserId` as the admin signal, which covers the creator
case; promoted admins are also accepted by the backend on every gated
endpoint.

---

## 2. Admin-only group actions

| Action                         | Where (UI)                              | Endpoint                                    | Gating                                                      |
|--------------------------------|-----------------------------------------|---------------------------------------------|-------------------------------------------------------------|
| **Delete group**               | Group detail → ⋮ → Delete group         | `DELETE /groups/:id`                        | Admin **and** every pairwise balance in the group is zero. Backend returns 409 with "Cannot delete group with unsettled balances. Settle all dues first." otherwise. UI hides the menu item entirely for non-admins. |
| **Remove a member**            | Group detail → tap member → Remove from group (or trailing icon in large layout) | `DELETE /groups/:id/members/:userId` (target ≠ self) | Admin only. The bottom-sheet "Remove from group" button only renders when `isAdmin && !isSelf`. |
| Update group metadata          | (Currently no UI — endpoint exists)     | `PUT /groups/:id`                           | Admin only                                                  |
| Change a member's role         | (No UI yet — endpoint exists)           | `PUT /groups/:id/members/:userId` body `{role}` | Admin only; valid roles `admin` / `member`              |
| Archive / unarchive group      | (No UI yet — endpoint exists)           | `PUT /groups/:id/archive` / `/unarchive`    | Admin only                                                  |
| Mark group as completed        | (No UI yet — endpoint exists)           | `PUT /groups/:id/complete`                  | Admin only                                                  |
| Resend pending invite          | Group detail (admin view) → pending list| `POST /groups/:id/pending-members/:phoneNumber/resend` | Admin only                                       |
| Remove a pending invite        | Group detail (admin view) → pending list| `DELETE /groups/:id/pending-members/:phoneNumber` | Admin only                                            |

---

## 3. What admins **share** with regular members

Admins do not get extra privileges over expenses they didn't create. In
particular:

- An admin **cannot delete an expense** added by another member. The rule is
  `paid_by_id == req.user.id` only — see
  [USER_FEATURES.md §5](USER_FEATURES.md#5-expenses).
- An admin **cannot leave the group with unsettled balances** either. The
  same 409 gate applies. (Admins can sidestep this by promoting another
  member to admin and then deleting the group, but only if all balances are
  zero.)
- Adding members, viewing balances, settling up, viewing expenses, and
  scanning invoices behave identically for admins and members.

---

## 4. UI signals

- **Admin-only menu items** in the group ⋮ menu:
  - "Delete group" (red icon) — only rendered when `group.createdBy == myId`.
  - "Leave group" — rendered for every member; the backend enforces the
    settlement gate.
- **Admin-only member actions**:
  - Tapping a member opens an action sheet with their name + phone for
    everyone, but the **Remove from group** button only appears for an admin
    looking at someone else's row.
  - In the large-layout member list, a trailing `person_remove_outlined`
    icon button appears for admins on every non-self row.

---

## 5. Implementation references

- Backend admin check: `Group.isAdmin` in
  [`backend/src/models/Group.js`](../src/models/Group.js)
- Reusable validator: `GroupService.validateAdminAccess` in
  [`backend/src/services/groupService.js`](../src/services/groupService.js)
- Pairwise-debt helper used by the leave/delete gates:
  `GroupService.getUserPairwiseDebts` (same file)
- Mobile gating: `group_detail_screen.dart` — `isAdmin` flag + popup menu
  conditionals + `_confirmDeleteGroup` / `_confirmRemoveMember`
