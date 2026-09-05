# BRICKS_TS – keoni-custom Branch

This branch contains Keoni's custom extensions and modifications on top of the upstream BRICKS Transaction Server.

## Purpose

The goal of `keoni-custom` is to stay as close as possible to the official upstream while carrying a set of practical enhancements and a hierarchical role-based menu system for day-to-day use.

## Current Status (as of 05 Sep 2026)

- **Upstream base**: `c59b188` (v3.2.3 source + three README-only commits; GitHub release 3.2.4 is a binary-only Safari web3270 fix tagged on the same SHA as v3.2.3, `6e9c916`)
- Menu system repaired so maps, PF keys, and `transactions.conf` ACLs agree (see below). Sign-on for live checks: userid `ADMIN` / password `ADMIN` (`runtime/users.conf` stores the id as `admin`).
- Last rebase tip: `7653ac1` (docs: update CUSTOM.md for 3.2.4 README rebase). Menu-system repair is the commit after that.
- Fork `main` has been reset to exactly match upstream `main`.
- This branch (`keoni-custom`) has been rebased cleanly on top of the latest upstream. **Zero conflicts** — all 21 custom commits replayed cleanly (simple `git rebase upstream/main`; no `--onto` needed — upstream was a clean 3-commit fast-forward from the prior 3.2.3 base). Custom additions (DODFMR/PERS + full menu system) preserved. Upstream STAR (3.2.1) is present in `runtime/transactions.conf` alongside the keoni-custom blocks.
- All prior custom work now sits on upstream `c59b188` (including 3.2.3 COBOL improvements, 3.2.0 COMP-3 / SEND MAP ERASE / 32-bit, 3.19 transaction aliases, 3.1.7/3.1.6/3.1.5 JSON + SABRE + binary/release changes + all previous 3.x/2.x work).

**Previous status** (12 Aug 2026 / 3.2.3) is preserved below for history.

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

These are registered in `runtime/transactions.conf` with `*` or appropriate group ACLs so they are reachable by signed-on users. Menu **help** is `MHLP` (`MYHELP.rexx`) — it does **not** replace the sample `HELP` transaction.

Menu behaviour (after the 05 Sep 2026 repair):

- `MYMENU.map` paints **dynamic** `Lxx` rows. The number the operator types matches the line on the screen for every role.
- Visibility uses `EXEC CICS QUERY SECURITY RESOURCE(transid) READ(...)`, not `LINEIN('users.conf')` (that file is outside `tmp_dir` and was making every caller look like PUBLIC).
- PF1 on the main menu exits to the TRANSID prompt. PF3 on submenus returns to `MYMU`. PF9 opens `MHLP`. PF7/PF8 page long REXX/COBOL/System lists.
- LINK-only helpers (`CUSV`, `CUSL`, `GUSV`, `GUSL`, `PERV`, `PERL`) are **not** on any menu and must `EXEC CICS RETURN` with no TRANSID so COMMAREA returns to CUST/GUST/PERS.
- Intentionally not listed as menu rows: those LINK helpers. Sign-off is `CSSF LOGOFF` at the blank prompt (main-menu option 07 / PF1 only drops to the prompt).

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

## How This Branch Was Updated (01 Jun 2026) — 2.7.4 Rebase

1. Safety backup had been created prior to the rebase attempt (from previous session):
   - Local branch `keoni-custom-backup-20260601-204810`
   - Tag `backup-before-2.7.4-rebase-20260601-204810`
   (No new tarball was created in this sync.)

2. Fork `main` was already at `upstream/main` (2.7.4).

3. `keoni-custom` was rebased onto the new upstream base (`c1b5cf3`). There were content conflicts in `runtime/transactions.conf` (the first two custom commits that touch it: initial customs + align step), caused by upstream's updates to the file header, comments, group casing conventions, and new built-in transactions (CSGM, MNDL/MNDU, TIME, etc.) between 2.6.6 and 2.7.4. Conflicts were resolved by preserving the current upstream format + re-adding the keoni custom transaction registrations (DODC/PERL/PERV/PERS/DODF + the 7 menu ones). All other 8 custom commits (including recent DODFMR work, menus, samples, .gitignore, CUSTOM.md) applied with zero conflicts.

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and will force-push the branch to the fork (`origin/keoni-custom`).

The 10 custom commits (with new SHAs after rebase) that now sit on top of upstream 2.7.4 are:
- `5c517a5` Saved progress on DODFMR review flow (F4 path)
- `fe6edd6` Fix green underline bleed on DODFMR (DODF1 map)
- `0a47507` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `9c9b025` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `6e82baf` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `8c0b027` chore: untrack data/files.boltdb (runtime database)
- `1f4738d` chore: add runtime/tmp/ to .gitignore
- `4153ec8` fix: align TXID values in all menu REXX files to match transactions.conf
- `162ad30` Add hierarchical role-based menu system with PF9 help
- `4bb6188` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (2.6.7–2.7.4)**:
- 2.6.7: CEDA transaction small improvements
- 2.7.0: CECI supplied transaction for testing EXEC commands
- 2.7.1: fix SQL error forces rollback bug
- 2.7.2: STARTBR/READNEXT on tmp_dir sequential files (ESDS via decimal RBA) + ESDR/ESDC samples
- 2.7.3: EXEC CICS QUERY SECURITY and EXEC CICS VERIFY PASSWORD support and adapted GUST transaction to show it at work
- 2.7.4: XEC CICS INQUIRE SYSTEM GMMTEXT support, CSGM transaction added, add new COBOL transaction, show GMTEXT also in connection panel

### Menu System Extensions (post 2.7.4 rebase)
As a follow-up to the rebase + source sync:
- Synced `bricks_menus/rexx/*.rexx` and `bricks_menus/map/*MENU.map` (and MYHELP) to match the aligned/live versions in `runtime/` (the "fix: align TXID..." changes, USERSCONF path, PF key handling with C2X, etc.). This ensures `bricks_menus/deploy.sh` produces correct deployed copies.
- Extended the role-based menus to surface more registered transactions (classic samples + 2.7.x additions) so they are reachable via MYMU without typing TRANSIDs directly:
  - **REXM (REXX)**: BRDS, CHAT, CSGM (GMTEXT), MNDL/MNDU (fractals), TIME, WAPI + previous.
  - **COBM (COBOL)**: BANK (full demo), BALC (color/underline), ESDC, WHDR, WZEN + previous.
- Extended the corresponding menu maps (REXMENU.map, COBMENU.map) with additional Lxx fields to support the longer lists (now 14 and 13 items).
- All new items use the same role/group logic as existing entries and the aligned TXID values for XCTL/visibility.
- Result: far fewer "orphan" transactions; BANK, the new fun demos (MNDL etc.), chat/brds, web/api, esds, and whdr/wzen are now in the hierarchy (subject to role).

The menu sources in `bricks_menus/` are now the maintained truth; deploy or manual cp keeps runtime/ in sync.

## Safety Backups Created During This Sync (01 Jun 2026)

The pre-rebase backup for the 2.7.4 attempt still exists locally:

- Branch: `keoni-custom-backup-20260601-204810`
- Tag: `backup-before-2.7.4-rebase-20260601-204810`

All **previous** backups from the 30 May (2.6.6), 28 May (2.6.2), and 27 May syncs are also still present for extra safety.

The 01 Jun pre-rebase state (tagged) contains the core custom artifacts (`bricks_menus/`, all deployed `runtime/map/` + `runtime/rexx/` menu + custom programs, `runtime/transactions.conf`, `runtime/zapp.yaml`, `CUSTOM.md`, `bricks.cnf`, and `.gitignore`) plus the DODFMR work-in-progress as of the moment before this rebase.

## How This Branch Was Updated (06 Jun 2026) — 2.8.1 Rebase

1. Full safety backup created (following the established pattern, plus user-approved cleanup of older backups):
   - Local branch `keoni-custom-backup-20260606-095111`
   - Tag `backup-before-2.8.1-rebase-20260606-095111`
   (No new tarball was created in this sync.)

2. Fork `main` was force-reset (`--force-with-lease`) to exactly match `upstream/main` at 2.8.1.

3. `keoni-custom` was rebased onto the new upstream base (`956d963`). The rebase completed with **zero conflicts** — all 12 custom commits replayed cleanly. (Notable: `runtime/transactions.conf` required no manual resolution in this cycle, unlike the prior 2.7.4 rebase.)

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and force-pushed the branch to the fork (`origin/keoni-custom`).

The 12 custom commits (with new SHAs after rebase) that now sit on top of upstream 2.8.1 are:

- `0283ddf` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `b27191a` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `eda1e84` Saved progress on DODFMR review flow (F4 path)
- `4a98194` Fix green underline bleed on DODFMR (DODF1 map)
- `231e861` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `3b36021` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `bae3b33` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `33f811b` chore: untrack data/files.boltdb (runtime database)
- `465988a` chore: add runtime/tmp/ to .gitignore
- `2d12aa7` fix: align TXID values in all menu REXX files to match transactions.conf
- `b5a269f` Add hierarchical role-based menu system with PF9 help
- `f93d001` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (2.7.5–2.8.1)**:
- 2.8.1: fix for EIBLEN bug
- 2.8.0: smart start_bricks.bash script
- 2.8.0: add_brick_user.bash now uses pre-built binary brickspsw for users who don't know how to rename the appropriate binary
- 2.8.0: VSAM cache and cemt M V and CEMT M D
- 2.7.9: DBMON in CMET Monitor
- 2.7.8: BRICKS time altered log message
- 2.7.7: show INS in web3270 when in Insert mode
- 2.7.6: some fixes to web3270 terminal
- 2.7.5: small cosmetic fixes
- 2.7.5: udpate copybooks
- 2.7.5: fix multi-level LINK with pending AID

After rebase + cleanup: older backup branches from May 2026 (and the untimestamped `keoni-custom-backup`) were deleted locally; the most recent prior backup (`keoni-custom-backup-20260601-204810`) + this fresh pre-rebase backup were retained.

## How This Branch Was Updated (14 Jun 2026) — 2.8.6 Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260614-194236`
   - Tag `backup-before-2.8.6-rebase-20260614-194236`
   (No new tarball was created in this sync.)

2. Fork `main` was reset (`--hard`, followed by `--force-with-lease` push) to exactly match `upstream/main` at 2.8.6.

3. `keoni-custom` was rebased onto the new upstream base (`8be9688`). The rebase completed with **zero conflicts** — all 13 custom commits replayed cleanly. (Notable: `runtime/transactions.conf` had upstream additions for BOOK/SABR/FUNC/UPPR inserted mid-file; Git's merge handled the re-application of the keoni append block + prior align/menu patches without manual intervention this cycle.)

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and force-pushed the branch to the fork (`origin/keoni-custom`).

The 13 custom commits (with new SHAs after rebase) that now sit on top of upstream 2.8.6 are:

- `f497a7d` docs: update CUSTOM.md for 2.8.1 rebase (clean rebase on new upstream base)
- `f79a77a` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `9d9f55d` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `8df08be` Saved progress on DODFMR review flow (F4 path)
- `31cfc98` Fix green underline bleed on DODFMR (DODF1 map)
- `e6ffaff` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `3f23054` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `0cbb42b` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `313d16f` chore: untrack data/files.boltdb (runtime database)
- `2bd346a` chore: add runtime/tmp/ to .gitignore
- `bd3f7cc` fix: align TXID values in all menu REXX files to match transactions.conf
- `06953cd` Add hierarchical role-based menu system with PF9 help
- `ec18d1b` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (2.8.2–2.8.6)**:
- 2.8.6: REDEFINES syntax for COBOL and TOPX transaction for access to 3270BBS database
- 2.8.5: clear DFHCOMMAREA after RETURN
- 2.8.4: extended REXX with more PARSE, internal function calls and SABR and FUNC transactions
- 2.8.3: add UPPR transaction showing UPPR:cobol:uppr.cob:PUBLIC; INSPECT CONVERTING to COBOL
- 2.8.2: show web3270 cursor also in browser incognito mode

After rebase: the fresh pre-rebase backup branch + tag were created and retained (plus prior recent backups). No older May backups were present to clean in this cycle.

## How This Branch Was Updated (21 Jun 2026) — 3.1.4 Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260621-093639`
   - Tag `backup-before-3.1.4-rebase-20260621-093639`
   (No new tarball was created in this sync.)

2. Fork `main` was reset (`--hard`, followed by push) to exactly match `upstream/main` at 3.1.4.

3. `keoni-custom` was rebased onto the new upstream base (`7c8a9ad`). The rebase completed with **one resolved conflict** in `runtime/transactions.conf` (the very first custom commit's addition overlapped because upstream now includes several transactions previously added in custom work such as TIME). Conflict resolved by taking full upstream content + appending the unique keoni-custom additions (DODC/PERL/PERV/PERS/DODF). All remaining 13 custom commits replayed cleanly (zero conflicts).

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and will force-push the branch to the fork (`origin/keoni-custom`).

The 14 custom commits (with new SHAs after rebase) that now sit on top of upstream 3.1.4 are:

- `9243b46` docs: update CUSTOM.md for 2.8.6 rebase (clean rebase on new upstream base)
- `b8cea11` docs: update CUSTOM.md for 2.8.1 rebase (clean rebase on new upstream base)
- `42f25cd` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `440e60f` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `de1a199` Saved progress on DODFMR review flow (F4 path)
- `63484d9` Fix green underline bleed on DODFMR (DODF1 map)
- `b779bd3` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `4a52a37` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `ab57bda` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `c2aeb43` chore: untrack data/files.boltdb (runtime database)
- `ea09f5c` chore: add runtime/tmp/ to .gitignore
- `7bdf4f0` fix: align TXID values in all menu REXX files to match transactions.conf
- `1abb3af` Add hierarchical role-based menu system with PF9 help
- `9dd6500` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (2.8.7–3.1.4)**:
- 3.1.4: shorten time-out for MRO region probes
- 3.1.3: implicit syncpoint is now a task-termination function
- 3.x: SET ptr UP/DOWN BY n for pointer arithmetic in COBOL; new PGMT/INQR test transactions; fixes for freemain, INQR, GMPT
- 3.0.6: improve MRO protocol resilience with dual channel comms
- 3.0.3: Multi Region Operation (MRO) now enabled — see mro.conf and new bricks.cnf options
- 2.9.2 / 2.9.1: major REXX performance wins (integer fast path ~3x faster, split compound variable access 70% faster)
- 2.8.9: COMMAREA on EXEC CICS RETURN now only reaches the immediate next transaction when you explicitly code the COMMAREA option

After rebase: the fresh pre-rebase backup branch + tag were created and retained.

## How This Branch Was Updated (02 Jul 2026) — 3.1.7 Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260702-202520`
   - Tag `backup-before-3.1.7-rebase-20260702-202520`
   (No new tarball was created in this sync.)

2. Fork `main` was reset (`--hard`) to exactly match `upstream/main` at v3.1.7 (fd1e7fc).

3. `keoni-custom` was rebased onto the new upstream base using:
   `git rebase --onto upstream/main 7c8a9ad keoni-custom`
   (The `--onto` form was required because upstream/main had a forced history update since the prior base.)
   The rebase completed with **zero conflicts** — all 14 custom commits replayed cleanly.

4. Updated this `CUSTOM.md` (current status + new rebase section), will commit the update, and (pending user confirmation) force-push the branch to the fork (`origin/keoni-custom`).

The custom commits (with new SHAs after this rebase) that now sit on top of upstream v3.1.7 are:

- `a8d0d79` docs: update CUSTOM.md for 3.1.7 rebase (clean rebase on new upstream base)
- `c1df621` docs: update CUSTOM.md for 3.1.4 rebase (clean rebase on new upstream base)
- `292edeb` docs: update CUSTOM.md for 2.8.6 rebase (clean rebase on new upstream base)
- `489585f` docs: update CUSTOM.md for 2.8.1 rebase (clean rebase on new upstream base)
- `ae23b88` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `66dd281` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `452a2d0` Saved progress on DODFMR review flow (F4 path)
- `51884c7` Fix green underline bleed on DODFMR (DODF1 map)
- `7a973d3` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `86e107b` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `20284d9` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `27c06cb` chore: untrack data/files.boltdb (runtime database)
- `c4b36f3` chore: add runtime/tmp/ to .gitignore
- `b9df688` fix: align TXID values in all menu REXX files to match transactions.conf
- `93b0154` Add hierarchical role-based menu system with PF9 help
- `41648f6` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (3.1.5–3.1.7)**:
- v3.1.7 / 3.1.6: smarter start_bricks.bash script and README update; scripts now automagically select the correct binaries; LICENSE update; binaries moved to GitHub Releases (with re-add + cleanup); add JSON parser for REXX
- 3.1.5: Advanced SABRE dialog in SABR transaction; multiple SABRE doc updates; CEDA / CEMT / CECI / IDCA color theme changes

After rebase: the fresh pre-rebase backup branch + tag were created and retained.

## How This Branch Was Updated (25 Jul 2026) — 3.2.0 Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260725-181435` (at pre-rebase tip `6570b3b`)
   - Tag `backup-before-3.2.0-rebase-20260725-181435`
   (No new tarball was created in this sync.)

2. Fork `main` was reset (`--hard`) to exactly match `upstream/main` at v3.2.0 (`774af94`).

3. `keoni-custom` was rebased onto the new upstream base using:
   `git rebase upstream/main`
   (Simple rebase — upstream/main was a clean 2-commit fast-forward from the prior base `fd1e7fc`; no history rewrite / `--onto` required.)
   The rebase completed with **zero conflicts** — all 17 custom commits replayed cleanly.

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and force-pushed the branch to the fork (`origin/keoni-custom`).

The custom commits (with new SHAs after this rebase) that now sit on top of upstream v3.2.0 are:

- `6ffeeb3` docs: pin correct tip SHA in CUSTOM.md
- `7e68e71` docs: update CUSTOM.md for 3.1.7 rebase (clean rebase on new upstream base)
- `8700b47` docs: update CUSTOM.md for 3.1.4 rebase (clean rebase on new upstream base)
- `fe0fd7e` docs: update CUSTOM.md for 2.8.6 rebase (clean rebase on new upstream base)
- `f052558` docs: update CUSTOM.md for 2.8.1 rebase (clean rebase on new upstream base)
- `9346314` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `be20c70` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `f69e457` Saved progress on DODFMR review flow (F4 path)
- `ae23fbf` Fix green underline bleed on DODFMR (DODF1 map)
- `5cb9035` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `554d0f1` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `097baf8` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `25c90a8` chore: untrack data/files.boltdb (runtime database)
- `d244f18` chore: add runtime/tmp/ to .gitignore
- `693ff4d` fix: align TXID values in all menu REXX files to match transactions.conf
- `05c621d` Add hierarchical role-based menu system with PF9 help
- `ce4eeb1` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (3.19–3.2.0)**:
- v3.2.0: fixes for COMP-3, SEND MAP ERASE, add 32-bit support, and fix `start_bricks.bash`
- v3.19: aliases for transactions in `runtime/aliases.conf`

After rebase: the fresh pre-rebase backup branch + tag were created and retained.

## How This Branch Was Updated (12 Aug 2026) — 3.2.3 Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260812-192741` (at pre-rebase tip `2833b55`)
   - Tag `backup-before-3.2.3-rebase-20260812-192741`
   (No new tarball was created in this sync.)

2. Fork `main` was reset (`--hard`) to exactly match `upstream/main` at v3.2.3 (`6e9c916`).

3. `keoni-custom` was rebased onto the new upstream base using:
   `git rebase upstream/main`
   (Simple rebase — upstream/main was a clean 3-commit fast-forward from the prior base `774af94`; no history rewrite / `--onto` required.)
   The rebase completed with **zero conflicts** — all 19 custom commits replayed cleanly. (`runtime/transactions.conf` auto-merged: upstream's `STAR` line plus the existing keoni-custom DODFMR/PERS and menu blocks.)

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and force-pushed the branch to the fork (`origin/keoni-custom`).

The custom commits (with new SHAs after this rebase) that now sit on top of upstream v3.2.3 are:

- `11c4338` docs: update CUSTOM.md for 3.2.3 rebase (clean rebase on new upstream base)
- `0cf6658` docs: pin correct tip SHA in CUSTOM.md
- `57e883e` docs: update CUSTOM.md for 3.2.0 rebase (clean rebase on new upstream base)
- `4e3523e` docs: pin correct tip SHA in CUSTOM.md
- `463fbee` docs: update CUSTOM.md for 3.1.7 rebase (clean rebase on new upstream base)
- `3957c17` docs: update CUSTOM.md for 3.1.4 rebase (clean rebase on new upstream base)
- `1f3b442` docs: update CUSTOM.md for 2.8.6 rebase (clean rebase on new upstream base)
- `744eb57` docs: update CUSTOM.md for 2.8.1 rebase (clean rebase on new upstream base)
- `f63a12f` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `941ec45` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `907b6a6` Saved progress on DODFMR review flow (F4 path)
- `afd9f8e` Fix green underline bleed on DODFMR (DODF1 map)
- `8677e0f` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `45439a7` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `71b7813` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `5c2db6c` chore: untrack data/files.boltdb (runtime database)
- `29305df` chore: add runtime/tmp/ to .gitignore
- `ffc22e9` fix: align TXID values in all menu REXX files to match transactions.conf
- `a1b4721` Add hierarchical role-based menu system with PF9 help
- `720530d` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase (3.2.1–3.2.3)**:
- v3.2.3: MOVE -1 allowed, in-line PERFORM … END-PERFORM, some COBOL improvements
- v3.2.2: reference modification for COBOL fixed
- v3.2.1: millisecond-resolution scheduler for COBOL and STAR transaction (Star Wars)

After rebase: the fresh pre-rebase backup branch + tag were created and retained (plus prior 3.2.0 / 3.1.7 backups).

## How This Branch Was Updated (02 Sep 2026) — 3.2.4 README Rebase

1. Full safety backup created (following the established pattern):
   - Local branch `keoni-custom-backup-20260902-195743` (at pre-rebase tip `888566e`)
   - Tag `backup-before-3.2.4-readme-rebase-20260902-195743`
   (No new tarball was created in this sync.)

2. Fork `main` was reset (`--hard`) to exactly match `upstream/main` at `c59b188`. This was a clean fast-forward of the three README-only commits (`e34a1e7`, `4fbd60f`, `c59b188`).

3. `keoni-custom` was rebased onto the new upstream base using:
   `git rebase upstream/main`
   (Simple rebase — upstream/main was a clean 3-commit fast-forward from the prior base `6e9c916`; no history rewrite / `--onto` required.)
   The rebase completed with **zero conflicts** — all 21 custom commits replayed cleanly. `keoni-custom` does not touch `README.md`, so the upstream README delta applied with no overlap. Custom DODFMR/PERS and menu blocks in `runtime/transactions.conf` were unchanged.

4. Updated this `CUSTOM.md` (current status + new rebase section), committed the update, and force-pushed the branch to the fork (`origin/keoni-custom`).

The custom commits (with new SHAs after this rebase) that now sit on top of upstream `c59b188` are:

- `7653ac1` docs: update CUSTOM.md for 3.2.4 README rebase (clean rebase on new upstream base)
- `7038da9` docs: pin correct tip SHA in CUSTOM.md
- `8576730` docs: update CUSTOM.md for 3.2.3 rebase (clean rebase on new upstream base)
- `31c7310` docs: pin correct tip SHA in CUSTOM.md
- `04cc579` docs: update CUSTOM.md for 3.2.0 rebase (clean rebase on new upstream base)
- `58f871b` docs: pin correct tip SHA in CUSTOM.md
- `367fcdb` docs: update CUSTOM.md for 3.1.7 rebase (clean rebase on new upstream base)
- `73d38cd` docs: update CUSTOM.md for 3.1.4 rebase (clean rebase on new upstream base)
- `f236f49` docs: update CUSTOM.md for 2.8.6 rebase (clean rebase on new upstream base)
- `d3d3449` docs: update CUSTOM.md for 2.8.1 rebase (clean rebase on new upstream base)
- `5b1a424` feat(menus): sync bricks_menus/ sources to aligned runtime (post-align TXID fix); extend MYMU/REXM/COBM with missing txns (BANK,BALC,BRDS,CHAT,CSGM,MNDL/MNDU,TIME,WAPI,ESDC,WHDR,WZEN); update CUSTOM.md
- `db1b339` docs: update CUSTOM.md for 2.7.4 rebase (clean rebase on new upstream base)
- `cde28c6` Saved progress on DODFMR review flow (F4 path)
- `6cb3265` Fix green underline bleed on DODFMR (DODF1 map)
- `6778428` docs: update CUSTOM.md for 2.6.6 rebase (clean rebase on new upstream base)
- `36a6671` docs: update CUSTOM.md for 2.6.2 rebase (new upstream base + 2.6.x highlights)
- `f8dd818` docs: add CUSTOM.md documenting keoni-custom branch purpose, history, and maintenance
- `b081429` chore: untrack data/files.boltdb (runtime database)
- `be93d6c` chore: add runtime/tmp/ to .gitignore
- `527d1a1` fix: align TXID values in all menu REXX files to match transactions.conf
- `3b90771` Add hierarchical role-based menu system with PF9 help
- `af02906` Add custom COBOL/REXX programs, maps, transactions, zapp config

**New upstream highlights included in this rebase**:
- Three README-only commits on `main` (26 Aug 2026): Discord/developer-notes links and README wording
- GitHub release **3.2.4** (published 14 Aug 2026): Safari web3270 selection bugfix. Tag `3.2.4` points at the same source commit as `3.2.3` (`6e9c916`) — binary-only, not a source bump. Download `bricks-3.2.4-*` from GitHub Releases if you run the compiled server locally.

After rebase: the fresh pre-rebase backup branch + tag were created and retained (plus prior 3.2.3 / 3.2.0 / 3.1.7 backups).

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

**Last updated**: 12 Aug 2026 (3.2.3 rebase, zero conflicts; simple rebase on fast-forward upstream)
**Maintainer**: Keoni (keonipkim fork)

This file lives on the `keoni-custom` branch only and should be updated whenever significant custom work is added or the branch is rebased against upstream.