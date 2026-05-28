# BRICKS_TS – keoni-custom Branch

This branch contains Keoni's custom extensions and modifications on top of the upstream BRICKS Transaction Server.

## Purpose

The goal of `keoni-custom` is to stay as close as possible to the official upstream while carrying a set of practical enhancements and a hierarchical role-based menu system for day-to-day use.

## Current Status (as of 27 May 2026)

- **Upstream base**: `c98fa43` (version 2.5.6)
- **This branch tip**: `be7cb4e`
- Fork `main` has been reset to exactly match upstream `main`.
- This branch (`keoni-custom`) has been rebased cleanly on top of the latest upstream with no conflicts.

All custom work now sits on the most recent stable upstream (2.5.6 as of this update).

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

## How This Branch Was Updated (27 May 2026)

1. Full safety backup created:
   - Local branch `keoni-custom-backup`
   - Tag `backup-before-upstream-sync-20260527-203256`
   - Tarball `~/bricks-custom-backup-20260527-203256.tgz`

2. Fork `main` was force-reset to exactly match `upstream/main` at 2.5.6.

3. `keoni-custom` was rebased onto the new upstream base. The rebase completed with **zero conflicts** because the majority of the custom work consists of new files and additive changes.

4. Updated branch was force-pushed to the fork (`origin/keoni-custom`).

The five custom commits that were replayed on top of upstream 2.5.6 are:

- `f4b90a8` Add custom COBOL/REXX programs, maps, transactions, zapp config
- `81d7d37` Add hierarchical role-based menu system with PF9 help
- `e421a98` fix: align TXID values in all menu REXX files to match transactions.conf
- `c43c8b6` chore: add runtime/tmp/ to .gitignore
- `be7cb4e` chore: untrack data/files.boltdb (runtime database)

## Safety Backups Created During This Sync

These still exist locally unless deliberately deleted:

- Branch: `keoni-custom-backup`
- Tag: `backup-before-upstream-sync-20260527-203256`
- Tarball: `~/bricks-custom-backup-20260527-203256.tgz`

The tarball contains the core custom artifacts (`bricks_menus/`, `zapp.yaml`, modified `transactions.conf`, `bricks.cnf`, and `.gitignore`) as of the moment before the rebase.

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
| `runtime/transactions.conf`   | Contains the 6 custom menu transaction registrations |
| `runtime/zapp.yaml`           | Custom deployment/config artifact |
| `bricks.cnf`                  | May contain local tuning (web ports, NTP, etc.) |
| `.gitignore`                  | Must continue to ignore the runtime database and tmp dir |

---

**Last updated**: 27 May 2026 (during the 2.5.6 rebase)
**Maintainer**: Keoni (keonipkim fork)

This file lives on the `keoni-custom` branch only and should be updated whenever significant custom work is added or the branch is rebased against upstream.