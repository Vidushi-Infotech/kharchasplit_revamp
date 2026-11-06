# KharchaSplit — Member (Regular User) Features

This document describes everything a **regular signed-in user** can do.
For features available only to **group creators / admins**, see
[ADMIN_FEATURES.md](ADMIN_FEATURES.md).

> Roles in KharchaSplit are scoped to a **group**, not the platform. Every user
> is a "member" by default. A user becomes an **admin** of a group only by
> creating it, or by being promoted by an existing admin (`role` column on
> `group_members`). The features below apply to a user who is a *plain
> member* of a given group.

---

## 1. User Types

| Type            | How they're created                                | Notes                                                                  |
|-----------------|----------------------------------------------------|------------------------------------------------------------------------|
| Registered user | Signs up with phone + OTP, sets a name             | Full read/write access to anything they're a member of                 |
| Placeholder     | Auto-created when added to a group by phone number | Counts in splits/balances; cannot log in until they verify their phone |

A registered user can be a **group creator/admin** in some groups and a **plain
member** in others — permissions are evaluated per-group.

---

## 2. Account & Profile

| Feature                         | Where                              | Notes                                                       |
|---------------------------------|------------------------------------|-------------------------------------------------------------|
| Sign up / sign in via phone OTP | Login & Register screens           | Dev master OTP `123456` (non-prod only)                     |
| Set display name                | Register / Edit profile            | Used everywhere a user appears                              |
| Update profile (name, email, avatar, preferred currency) | Profile screen | `PUT /users/:id` (own ID only)                              |
| Switch theme (System / Light / Dark) | Profile → Appearance          | Persisted in `SharedPreferences`                            |
| Sign out                        | Profile screen                     | Clears local token + user blob                              |
| Deactivate / delete own account | `DELETE /users/:id/deactivate`     | Soft delete                                                 |
| Manage push notification token  | Auto on login / FCM refresh        | `PUT/DELETE /users/:id/fcm-token`                           |

---

## 3. Dashboard

| Feature                   | Where             | Notes                                                                  |
|---------------------------|-------------------|------------------------------------------------------------------------|
| See total balance         | Dashboard         | Net of all debts across all groups (settlements applied)               |
| See "You owe" total       | Dashboard / I owe | Summed positive debts to others                                        |
| See "Owed to you" total   | Dashboard / Owed to me | Summed positive debts owed to you                                  |
| See recent expenses (across groups) | Dashboard | Latest N expenses, paid-by + group context                          |
| Per-group mini balance card | Dashboard       | Tap → group detail                                                     |

---

## 4. Groups

| Feature                | Where                  | Notes                                                                              |
|------------------------|------------------------|------------------------------------------------------------------------------------|
| Create a new group     | Groups → +             | Pick a name, optional cover image, currency (default ₹), invite members            |
| Join a group           | Auto on invite accept  | Backend places user in `group_members` when their phone matches a pending invite   |
| List my groups         | Groups screen          | With per-group balance & member count                                              |
| Open group detail      | Tap a group card       | Shows expenses, balances, pending settlements, members                             |
| **Add member** to a group I'm in | Group detail → ⋮ → Add member | Picker pulls device contacts (live), shows "On KharchaSplit" first, "Added" chip on existing members. Auto-adds registered users; sends WhatsApp invite (via WATI) for unregistered numbers. |
| **Leave a group**      | Group detail → ⋮ → Leave group | **Allowed only when all my pairwise balances with other members are settled.** Backend rejects with 409 otherwise. |
| Tap any member         | Group detail           | Opens action sheet with name + phone                                               |

---

## 5. Expenses

| Feature                       | Where                  | Notes                                                                      |
|-------------------------------|------------------------|----------------------------------------------------------------------------|
| Add an expense                | Group detail → + (FAB) | Amount, description, category, date, who paid, split method                |
| Pick split method             | Add expense screen     | **Equally / Exact / By % / By Shares** (Adjustment removed)                |
| Auto-scroll to breakdown      | Add expense            | Tapping Exact / % / Shares scrolls to the per-member input section         |
| Equal-split member selection  | Add expense breakdown  | Search + Select All / Deselect All                                         |
| Scan invoice (OCR)            | Add expense            | Pre-fills amount / category / date / title                                 |
| View expense detail           | Tap any expense card   | Hero amount, paid-by, splits, notes, split-method label                    |
| See split working             | Detail → Splits card   | Tap card to expand: shows `30% × ₹X = ₹Y` or `2 / 5 × ₹X = ₹Y`             |
| **Delete an expense**         | Detail → ⋮ → Delete    | **Only the person who added the expense (the payer) can delete it.** Backend returns 403 to anyone else; UI hides the menu item & disables swipe-to-delete on the card. |
| Edit an expense               | Detail → ⋮ → Edit      | Wired but not yet implemented (snackbar)                                   |

---

## 6. Settlements

| Feature                          | Where                       | Notes                                                              |
|----------------------------------|-----------------------------|--------------------------------------------------------------------|
| See "You owe X to Y" rows        | Group → Balances tab        | Pairwise, personalised. Hidden third-party debts.                  |
| See "Owed to you" rows           | Group → Balances tab        | Pairwise, who owes me directly                                     |
| Settle Up                        | Each "you owe" row → button | Pre-fills exact pairwise amount. Records a settlement (status=`pending` until counterparty confirms). |
| Confirm an incoming settlement   | Group → top of Balances     | The other side paid me; tap Confirm to mark `completed`            |
| See pending outgoing settlements | Group → top of Balances     | Settlements I started, awaiting other side                         |
| Settlement history with a person | Tap any balance row         | Per-pair history within the group, with status badges              |
| Cancel my own pending settlement | History row                 | Marks `failed` (no longer affects balances)                        |

---

## 7. Personal expenses (private wallet)

| Feature                       | Where                      | Notes                                                          |
|-------------------------------|----------------------------|----------------------------------------------------------------|
| Set wallet balance + sources  | Personal Expenses tab      | Local-only via `SharedPreferences` (no group context)          |
| Add a personal expense        | + button                   | Amount → description → pay-from source                         |
| Edit / delete personal expense | Tile actions              | Owner-only                                                     |
| View list grouped by date     | Personal Expenses screen   | Today / Yesterday / older with timestamps                      |

---

## 8. Activity & Notifications

| Feature                                     | Where             | Notes                              |
|---------------------------------------------|-------------------|------------------------------------|
| Activity feed (own actions + group events)  | Activity tab      | `GET /activities`                  |
| Per-group activity                          | Group detail      | `GET /activities/group/:groupId`   |
| Unread count badge                          | Activity icon     | `GET /activities/unread/count`     |
| Mark single / group activities as read      | Tile / overflow   | `PATCH /activities/:id/read`       |
| Push notifications                          | OS-level          | Triggered on member events, expense add/delete, settlement requests/confirmations |

---

## 9. Reports (read-only)

- Reports tab — month/category breakdowns of your expenses across groups.

---

## 10. What a member CANNOT do

| Action                                 | Why                                                       |
|----------------------------------------|-----------------------------------------------------------|
| Delete the group                       | Admin-only — see [ADMIN_FEATURES.md](ADMIN_FEATURES.md)   |
| Remove other members from a group      | Admin-only                                                |
| Change another member's role           | Admin-only                                                |
| Archive / unarchive / complete a group | Admin-only                                                |
| Delete an expense someone else added   | Only the payer can delete it                              |
| Leave a group with unsettled debts     | Backend enforces 409 — settle first                       |
| Edit/delete another user's profile     | Auth interceptor restricts to own user ID                 |
