/**
 * SQL for a person's display name inside a group: their profile name, or —
 * for invited people who haven't set one (users.name is empty) — the name
 * they were added to the group with (group_members.name).
 *
 *   displayNameSql('u', 'es.user_id', 'e.group_id')
 */
export function displayNameSql(userAlias, userIdExpr, groupIdExpr) {
  return `COALESCE(NULLIF(${userAlias}.name, ''), (
    SELECT gmn.name FROM group_members gmn
     WHERE gmn.group_id = ${groupIdExpr} AND gmn.user_id = ${userIdExpr}
       AND NULLIF(gmn.name, '') IS NOT NULL
     ORDER BY gmn.joined_at DESC LIMIT 1))`;
}
