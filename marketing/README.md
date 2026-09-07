# KharchaSplit Marketing — Files

| File | What it is |
|---|---|
| `KharchaSplit-Growth-Master-Plan.md` | The full strategy document. Source of truth for task content, budgets, roadmap, team and metrics. |
| `KharchaSplit-Tasks-Import.csv` | All 223 tasks, full field set. For **Notion** (and Jira via CSV import). |
| `KharchaSplit-Tasks-ClickUp.csv` | Same tasks with ClickUp-native column names. |
| `generate_task_import.py` | Regenerates both CSVs. Edit task data here, not in the CSVs. |

## Regenerating with a different kickoff date

```bash
python3 generate_task_import.py 2026-09-07   # any Monday
```

All 223 start/end dates recompute from that kickoff. The script runs a
forward-pass scheduler, so **no task can ever be dated before its dependencies** —
if you change a duration or add a link, downstream dates shift automatically and
a cycle raises an error instead of producing a silently broken plan.

Dependency syntax in the task data:
- `P1-03` — strict: predecessor must **finish** first
- `~P3-19` — soft: predecessor must have **started** (for long rollouts)
- Tasks with `EndDay = 999` are always-on/recurring; they show `Recurring = Yes`
  and are capped at Day 90 for display purposes.

## Importing

**Notion** — New page → Import → CSV → `KharchaSplit-Tasks-Import.csv`. Then set
property types: `Priority` / `Status` / `Phase` / `Epic` / `Sprint` / `Owner` → Select,
`Start Date` / `End Date` → Date, `Duration (days)` → Number. Add a Board view
grouped by `Status` and a Timeline view using Start/End Date.

**ClickUp** — Settings → Imports → CSV → `KharchaSplit-Tasks-ClickUp.csv`.
Map `Lists` to your List field so tasks land in the right Epic list.
Priority is pre-encoded (1=Urgent/High, 2=Normal, 3=Low).

**Jira** — Use `KharchaSplit-Tasks-Import.csv` via System → External System Import → CSV.
Map `Epic` → Epic Link, `Task ID` → a custom "External ID" field, `Owner` → Assignee.

## Notes

- Dates in the CSV are **calendar days** from kickoff, not working days. If your
  team works 5-day weeks, add ~40% to elapsed calendar time or set
  `KICKOFF` and treat durations as working-day estimates when loading into a
  scheduler that understands weekends.
- `Owner` holds role names, not people. Map roles to names on import
  (see Phase 16 of the plan for role definitions).
- Costs are labelled `Rs` rather than `₹` so the CSV survives Excel's default
  encoding. The plan document uses `₹`.
