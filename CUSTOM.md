# BRICKS_TS – keoni-custom Branch

This branch contains Keoni's custom extensions and modifications on top of the upstream BRICKS Transaction Server.

## Purpose

The goal of `keoni-custom` is to stay as close as possible to the official upstream while carrying a set of practical enhancements and a hierarchical role-based menu system for day-to-day use.

## Current Status (as of 30 May 2026)

- **Upstream base**: `19d8b99` (version 2.6.6)
- **This branch tip**: `aeab70c`
- Fork `main` has been reset to exactly match upstream `main`.
- This branch (`keoni-custom`) has been rebased cleanly on top of the latest upstream with **zero conflicts**.

All custom work now sits on the most recent stable upstream (2.6.6 as of this update).

**Previous status** (28 May 2026) is preserved below for history.

## Custom Work Included

### 1. Hierarchical Role-Based Menu System (`bricks_menus/`)

A complete set of role-aware menus with PF9 help, including:

- `MYMENU` – Main user menu
- `REXMENU` – REXX area
- `COBMENU` – COBOL area  
- `CUSMENU` – Customer-related functions
- `QUEMENU` – Queue / SQL menu
- `SYSMENU` – System / admin functions
- `SQLMENU` – SQL-specific operations (admin only)
- Supporting help maps and navigation

These are registered in `runtime/transactions.conf` with `*` or appropriate group ACLs so they are reachable by signed-on users.

The menus live in two places for convenience:
- `bricks_menus/` (primary custom source)
- `runtime/rexx/` + `runtime/map/` (deployed copies)

### 2. Additional Programs, Maps, and Configuration

- Custom or extended COBOL programs (`persl.cob`, `persv.cob`, `dodfr.cob`, etc.)
- Supporting BMS-style maps (`pers*.map`, `dodf1.map`, etc.)
- `runtime/zapp.yaml` – custom configuration / deployment artifact
- Various small enhancements and fixes to existing sample programs

### 3. Hygiene & Operational Improvements

- `.gitignore` updates to properly ignore `data/files.boltdb` and `runtime/tmp/`
- `data/files.boltdb` explicitly untracked (runtime database should never be committed)

## How This Branch Was Updated (28 May 2026)

1. Full safety backup created:
   - Local branch `keoni-custom-backup-20260528`
   - Tag `backup-before-2.6.2-rebase-20260528-*`
   - Tarball `~/bricks-keoni-backup-2.6.2-*.tgz`

2. Fork `main` was force-reset to exactly match `upstream/main` at 2.6.2.

3. `keoni-custom` was rebased onto the new upstream base. The rebase completed with **zero conflicts** (again) because the majority of the custom work consists of new files and additive changes.

4. Updated branch was force-pushed to the fork (`origin/keoni-custom`).

The six custom commits (including this document) that were replayed on top of upstream 2.6.2 are:

- `dbfb9d1` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `c457a30` chore: untrack data/files.boltdb (runtime database)
- `ba521f6` chore: add runtime/tmp/ to .gitignore
- `d6ad6db` fix: align TXID values in all menu REXX files to match transactions.conf
- `d53bd07` Add hierarchical role-based menu system with PF9 help
- `6de4f6c` Add custom COBOL/REXX programs, maps, transactions, zapp config

**Upstream 2.6.x highlights** (why we rebased):
- 2.6.2: New IDCAMS CLI + IDCA transaction
- 2.6.1: Major EXEC CICS compatibility improvements
- 2.6.0: 20+ EXEC CICS verbs updated for full CICS compatibility

## How This Branch Was Updated (30 May 2026) — 2.6.6 Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260530-193614`
   - Tag `backup-before-2.6.6-rebase-20260530-193614`
   - Tarball `~/bricks-keoni-backup-2.6.6-pre-rebase-20260530-193614.tgz`

2. Fork `main` was force-reset (`--force-with-lease`) to exactly match `upstream/main` at 2.6.6.

3. `keoni-custom` was rebased onto the new upstream base (`19d8b99`). The rebase completed with **zero conflicts** — all 7 custom commits replayed cleanly.

4. Updated branch was force-pushed to the fork (`origin/keoni-custom`).

The 7 custom commits (with new SHAs after rebase) that now sit on top of upstream 2.6.6 are:
- `aeab70c` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `dd63e0f` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `bef1ec9` chore: untrack data/files.boltdb (runtime database)
- `0162193` chore: add runtime/tmp/ to .gitignore
- `12e11ad` fix: align TXID values in all menu REXX files to match transactions.conf
- `4fd6af3` Add hierarchical role-based menu system with PF9 help
- `e3a9045` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (2.6.3–2.6.6)**:
- 2.6.3: Fix level 08 bug in maps conversion
- 2.6.4: Add welcome to connection + binary release fixes
- 2.6.6: Allow change of map colors from COBOL + UNDERLINE support (BALC transaction)

## Safety Backups Created During This Sync (30 May 2026)

These still exist locally unless deliberately deleted:

- Branch: `keoni-custom-backup-20260530-193614`
- Tag: `backup-before-2.6.6-rebase-20260530-193614`
- Tarball: `~/bricks-keoni-backup-2.6.6-pre-rebase-20260530-193614.tgz`

All **previous** backups from the 28 May and 27 May syncs are also still present for extra safety.

The 30 May tarball contains the core custom artifacts (`bricks_menus/`, all deployed `runtime/map/` + `runtime/rexx/` menu + custom programs, `runtime/transactions.conf`, `runtime/zapp.yaml`, `CUSTOM.md`, `bricks.cnf`, and `.gitignore`) as of the moment before this rebase.

## Future Maintenance

### Recommended Workflow

- Keep `main` as a pure mirror of `upstream/main`. Never put custom work directly on `main`.
- Do all new development on `keoni-custom` (or short-lived topic branches forked from it).
- Periodically rebase `keoni-custom` onto the latest `upstream/main` (or `origin/main` once it is in sync).

### To bring this branch up to date again in the future

```bash
git fetch upstream
git checkout main
git reset --hard upstream/main
git push origin main --force-with-lease

git checkout keoni-custom
git rebase upstream/main
# resolve any conflicts, then:
git push origin keoni-custom --force-with-lease
```

### After a successful rebase

- Test that the custom menu transactions (MYMU, REXM, COBM, SYSM, etc.) still load and render correctly.
- Verify any custom COBOL/REXX programs you rely on still compile and run under the new upstream.
- Consider creating a fresh backup tag/tarball before the next major rebase.

## Key Files to Watch

| File / Directory              | Notes |
|-------------------------------|-------|
| `bricks_menus/`               | Source of truth for the custom menu system |
| `runtime/transactions.conf`   | Contains the 7 custom menu transaction registrations (MYMU, REXM, COBM, CUSM, QUEM, SQLM, SYSM) |
| `runtime/zapp.yaml`           | Custom deployment/config artifact |
| `bricks.cnf`                  | May contain local tuning (web ports, NTP, etc.) |
| `.gitignore`                  | Must continue to ignore the runtime database and tmp dir |

---

**Last updated**: 30 May 2026 (during the 2.6.6 rebase)
**Maintainer**: Keoni (keonipkim fork)

This file lives on the `keoni-custom` branch only and should be updated whenever significant custom work is added or the branch is rebased against upstream.