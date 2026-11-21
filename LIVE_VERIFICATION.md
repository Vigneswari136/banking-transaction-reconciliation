# Live database and application verification

Completed on **3 November 2026** (Asia/Calcutta).

## PostgreSQL upgrade

- Target: the existing local `bank_finance` database on PostgreSQL 18.2.
- Flyway history: version 3 baseline; V4, V5, and V6 applied successfully and validated.
- V4 repairs missing legacy cash import provenance (`batch_id`). V6 repairs the missing cash modification timestamp (`updated_at`). Previously applied V4/V5 were not rewritten after their application.
- A complete PostgreSQL custom-format backup was created and restored to an isolated database.
- The upgrade was rehearsed and strict Hibernate schema validation passed on that restored copy before V6 was applied live.
- Every pre-existing table's row count and original column values matched the pre-upgrade fingerprint. No financial records were reset or replaced.
- The temporary rehearsal database was removed. Backups remain excluded from version control.

Latest backup: `backend/backups/bank_finance-before-migration-20261103T084727Z.dump`.

Preservation evidence: `backend/backups/bank_finance-before-migration-20261103T084727Z.verification.json`.

## Test results

- Backend: **35 tests passed**, 0 failures, 0 errors, 0 skipped (`mvn -o package -q`).
- Production backend JAR built and verified to contain V6.
- Frontend lint passed without warnings (`npm.cmd run lint --prefix frontend`).
- Frontend production build passed (`npm.cmd run build --prefix frontend`).

## Live HTTP smoke checks

The application started temporarily on loopback with `spring.jpa.hibernate.ddl-auto=validate`, so the smoke test could not silently change the schema. It shut down cleanly after verification.

| Check | Result |
|---|---|
| Health | HTTP 200 |
| Authenticated bank accounts | HTTP 200 |
| Authenticated cash-book page | HTTP 200 |
| Authenticated activity report | HTTP 200 |
| Authenticated activity totals | HTTP 200 |
| Authenticated reconciliation workbench | HTTP 200 |
| Unauthenticated protected report | HTTP 403, expected |
| Malformed JWT | HTTP 401, expected |
| Tally connection test | HTTP 200 with `connected=false`, expected without a Tally server |

The smoke test used an existing enabled administrator's in-memory token to exercise the security filter without printing credentials or tokens. It made no financial-entry changes. The Tally status and its audit event were recorded as operational metadata.

Detailed runtime log: `backend/target/live-smoke.log`.

## TallyPrime availability

The configured `http://localhost:9000` endpoint has no TallyPrime server. A licensed instance was unavailable, as confirmed by the user. The real connection attempt returned a clear unavailable status with guidance to use file imports. No successful live voucher synchronization is claimed.

The implementation and simulated company/voucher export/retry tests pass. To verify actual voucher synchronization later, provide a licensed, running TallyPrime instance with its company loaded and XML/HTTP server enabled, then select the actual company, bank ledger, and date range in the integration screen.

## Repeatable procedures

- `python tools/verify_live_database.py` from `backend`: fresh backup, restored-copy migration and schema validation, original-value checks, live pending migrations, and cleanup of that exact temporary database.
- `python tools/run_live_smoke.py` from `backend`: strict live schema and API checks, including recording the current Tally connection result.

No application server was left running by the verification scripts.


Cash editor and Refresh fixes (2026-11-03): manual Edit scrolls/focuses the populated form; Cancel clears all fields; update preserves original account, timestamp precision, and decimal amount. Refresh reloads application datasets with loading/success/error feedback, preserving cash page, filters, and unsaved edits. Frontend: 7 regression tests, lint and production build pass. Backend isolated H2 integration verifies PUT persistence and invalid amount rejection; full suite passes. Browser verified Edit visibility, Cancel reset, Refresh success, preserved draft and MANUAL filter. Existing live records were not modified. Services remain running.


2026-11-03 — Date-only manual cash entry and monthly section reports: removed time input; existing transaction timestamps preserved when editing the same date, new/changed dates use local midnight. Added monthly performance panel with calendar month selection, inclusive custom dates in India time, account/source filters, currency-separated Sales/Services/Spares and recorded category sections, received/paid bars and exact displayed amounts. New authenticated GET /api/reports/activity/sections aggregates the entire filtered period independently of pagination, using recorded category/ledger name or description. Transfers/opening balances remain separate. No schema changes or live financial data modifications. Frontend 11 tests pass; lint and production build pass. Backend 38 tests pass, including full period >50 rows, decimal amounts, India day boundaries, classification, transfers, separate currencies and endpoint validation. Backend repackaged and restarted using existing PostgreSQL; frontend remains at localhost:5173, backend localhost:8080. Existing API smoke checks pass. Browser verified date-only edit, February month end, custom end date, November cash Sales amount 1500, category bar amounts, and refresh preserving the report filters.


2026-11-03 — One selected bank across the application
The top selector now controls overview, transactions, reconciliation, exceptions, cash entries/funding, import targets/history, Tally sync/history, monthly and detailed reports/exports, audit logs, and AI evidence. Removed independent all-bank/report/import selectors. Account switching cancels/guards stale responses, hides old data during loading, clears cash edits, pending import previews, reconciliation and withdrawal selections, and AI answers. Bank switching is disabled during financial writes. Account settings show the selected bank; user access and connection configuration remain company-wide.
V7 adds nullable bank attribution to audit and sync history and backfills only determinable legacy accounts. Unknown/global history is excluded from bank-specific lists. PostgreSQL migration preflight passed with rollback before deployment. V7 then applied successfully through Flyway on backend startup; checksums of every original row in nine financial tables are unchanged. No test records were created in the live database.
Validation: 40 backend tests passed (two-bank imports/reports/cash/audit/Tally/exceptions/export isolation, same references on separate banks, cash deletion audit attribution, and AI context filtering); 13 frontend tests passed; lint and production build passed. Live read-only API isolation checks passed for all four banks. Browser verified Treasury's three bank transactions, zero cash rows/import batches, scoped reports and reconciliation, cleared manual cash draft, rapid switching, and refresh. Backend and frontend remain running at localhost:8080 and localhost:5173.
