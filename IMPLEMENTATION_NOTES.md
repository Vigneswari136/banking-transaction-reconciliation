# Banking enhancements handover

The existing React interface, authentication routes, domain tables, and legacy import routes were extended. Existing financial records were preserved. PostgreSQL migrations and application verification were subsequently completed as recorded in LIVE_VERIFICATION.md; the database was not reset.

## Delivered behavior

- Central bank, ledger, and cash imports with editable column mappings, preview validation, duplicate/rejected row counts, common history, uploader identity, source inspection, and authenticated template/error downloads.
- CSV quoting and multiline fields, XLS/XLSX extraction, structured text PDF extraction, and explicit scanned-PDF/OCR errors. Dates and monetary values are rejected when invalid; dates are never replaced with the current date.
- Transactional import retries, persisted duplicate checks, source snapshots, original Tally XML retention, and distinct imported cash receipts/payments/opening balances.
- Bank account metadata editing and activation controls. The policy is **five configured accounts, including inactive accounts**. Financial writes use a database row lock to protect account limits and funding/matching allocation decisions.
- Manual cash receipts, payments, opening entries, duplicate warnings, editing/deletion, before/after audit snapshots, source/category/date/type filters, paginated cash entries, and server-side decimal cash balances.
- Reference-based, direction-aware, unambiguous automatic matching; manual partial and split allocations; persisted rejection decisions; account isolation; and audited matching/unmatching.
- Explicit bank-withdrawal receipt creation/linking/unlinking, allocation limits across funding sources, and confirmed own-bank transfers. Detection does not create a cash receipt without a user action.
- Separate source accounting views, per-bank balances, daily/monthly/category breakdowns, paginated transaction reports, and authenticated CSV/XLSX/PDF exports. Monetary source views are never summed together as one income/expense total. Exports are capped at 10,000 records per filtered request.
- Actual backend Tally XML company/voucher export, exact selected bank-ledger filtering, voucher identity and company tracking, repeat-sync duplicate protection, time/response-size bounds, XML entity protections, and restricted outbound destinations. No voucher posting is implemented.
- Demo account/transaction creation is restricted to the `demo` and `test` profiles. Existing database users/accounts remain intact.

## Migrations

Existing V1-V3 files were preserved. Added:

- `backend/src/main/resources/db/migration/V4__import_sources_and_write_guards.sql`: retained source data, a financial-write lock, text fingerprints/idempotency keys, and indexes.
- `backend/src/main/resources/db/migration/V5__partial_reconciliation_and_decisions.sql`: partial allocations, decision notes, rejected suggestions, and transfer links.
- `backend/src/main/resources/db/migration/V6__legacy_cash_update_timestamp.sql`: adds the modification timestamp missing from Hibernate-created legacy cash tables. V4 also adds the legacy cash `batch_id` column before indexing it.

**Live PostgreSQL upgrade completed through V6 on 3 November 2026.** Spring Boot 4's Flyway starter and PostgreSQL module are now enabled. Startup migrates a versioned database normally. For an unversioned legacy database, the migration strategy verifies the expected V3 tables/columns before baselining at V3; an incomplete legacy schema stops with an explicit error. An empty database receives V1-V6. No existing migration checksum was changed.

Unit/integration tests use isolated H2 tables. PostgreSQL 18.2 migration compatibility and strict Hibernate schema validation were additionally verified on a restored copy before applying the remaining upgrade to the live database. All pre-existing row counts and column values were preserved. Existing Hibernate `ddl-auto: update` behavior was preserved.

## TallyPrime configuration

1. Enable the XML/HTTP server in the installed TallyPrime edition's connectivity settings and open the required company.
2. In the imports hub, set the backend-reachable URL, for example `http://127.0.0.1:9000`, then save and test it.
3. Select the exact company name returned by the test, enter the exact bank ledger name, select the destination bank account and a date range, and pull vouchers.
4. If Tally runs on another private LAN machine, the backend administrator must explicitly add its literal IP to `TALLY_ALLOWED_HOSTS` (comma-separated). DNS names and public/metadata endpoints are not accepted. No redirect is followed.
5. For manual bank-ledger exports from Tally, review direction mapping: accounting debits to the company's bank ledger are bank receipts (credit column in the bank-perspective import). Swap the mapped debit/credit columns when appropriate. Live XML sync performs this normalization itself.

The XML approach follows Tally's export/collection/company mechanism: https://help.tallysolutions.com/xml-integration/ and https://help.tallysolutions.com/integration-initiated-from-tpas/ . Automated tests use a local simulated Tally server. The real endpoint was tested and correctly reported unavailable. A successful company-specific export against a licensed TallyPrime instance remains unverified; see LIVE_VERIFICATION.md.

## Verification

Commands:

- `mvn -o package -q` from `backend`: runs backend unit/integration tests and builds the executable package.
- `npm.cmd run lint --prefix frontend`.
- `npm.cmd run build --prefix frontend`.

Final result: 35 backend tests; 0 failures, 0 errors, 0 skipped. Backend packaging, frontend lint (no warnings), and frontend production build passed.

Regression coverage includes Excel/legacy XLS, CSV quoting/multiline input, text/scanned PDF, invalid dates/amounts, persisted import retries, four initial banks and the fifth/sixth-account boundary, cash receipts/payments/balances, source labels, split matching, ambiguous/opposite-direction matches, rejected suggestions, withdrawal funding, login/permissions, malformed JWTs, report paging/exports, and simulated Tally pulls/retries.

## Files created or modified

New production files:

- `backend/src/main/java/com/finrecon/backend/config/MigrationConfiguration.java`
- `backend/src/main/java/com/finrecon/backend/service/ActivityReportService.java`
- `backend/src/main/java/com/finrecon/backend/api/ActivityReportController.java`
- `backend/src/main/java/com/finrecon/backend/api/FinancialDecisionController.java`
- V4/V5/V6 migrations listed above.
- Operational verification helpers in `backend/tools/`: `LiveDatabaseMaintenance.java`, `verify_live_database.py`, `LiveApplicationSmoke.java`, and `run_live_smoke.py`.
- Local credentials and database backups are excluded in `backend/.gitignore`.

Updated production files:

- `frontend/src/App.tsx` (existing styles and navigation retained).
- `backend/pom.xml`, `backend/src/main/resources/application.yml`.
- `backend/src/main/java/com/finrecon/backend/config/DemoDataInitializer.java`.
- API controllers: `BankAccountController`, `CashTransactionController`, `ImportController`, `ReconciliationController`, `BankWithdrawalAllocationController`, `TallyController`.
- DTOs: `CashExpenseRequest`, `ImportPreviewResponse`, `ImportBatchResponse`, `ManualMatchRequest`, `ReconciliationMatchResponse`, `BankWithdrawalAllocationResponse`, `TallySyncRequest`, `TransactionResponse`.
- Domain entities: `BankTransaction`, `LedgerTransaction`, `CashTransaction`, `ImportBatch`, `ReconciliationMatch`.
- Repositories: `BankAccountRepository`, `BankTransactionRepository`, `LedgerTransactionRepository`, `CashTransactionRepository`, `ReconciliationMatchRepository`.
- Services: `ImportService`, `FileExtractionService`, `CashTransactionService`, `ReconciliationService`, `BankWithdrawalAllocationService`, `TallyPrimeService`, `FinancialReportService`, `AuditLogService`.
- `backend/src/main/java/com/finrecon/backend/security/JwtAuthenticationFilter.java` and `common/GlobalExceptionHandler.java`.

Test files:

- Added `FinancialWorkflowsIntegrationTest`, `FileExtractionServiceTest`, and `TallyPrimeServiceTest`.
- Extended `ImportServiceTest` and isolated Flyway in `backend/src/test/resources/application-test.yml`.

## Operational limitations

- PostgreSQL upgrades were rehearsed on a restored backup and applied live with preservation checks. No browser-driven end-to-end session or licensed Tally instance was available. Frontend validation is TypeScript/build/lint plus backend API integration tests; live API verification is documented in LIVE_VERIFICATION.md.
- Complex PDF layouts may require Excel/CSV export and explicit mapping. OCR is not configured. PDF reports use basic font glyphs; CSV/XLSX preserve full text.
- Historical batches created before source retention cannot provide original source snapshots. Previously misclassified cash imports were not rewritten because their provenance cannot be inferred safely.
- This application currently uses a company cash book scoped by optional bank-account metadata, rather than independent named petty-cash books. Additional named cash-book accounting remains a future extension if required.
- The new activity/cash-book paths paginate/filter on the server. Legacy overview/reconciliation workbench/summary endpoints retain their original list-based behavior and may need further query optimization for very large datasets.
- Multi-currency conversion is not implemented. Keep monetary summaries within one currency; the legacy consolidated summary rejects mixed currencies.
- For a fresh demo-only database, explicitly enable the `demo` profile. Default production startup no longer inserts sample financial records or default users.


2026-11-03 — One selected bank across the application
The top selector now controls overview, transactions, reconciliation, exceptions, cash entries/funding, import targets/history, Tally sync/history, monthly and detailed reports/exports, audit logs, and AI evidence. Removed independent all-bank/report/import selectors. Account switching cancels/guards stale responses, hides old data during loading, clears cash edits, pending import previews, reconciliation and withdrawal selections, and AI answers. Bank switching is disabled during financial writes. Account settings show the selected bank; user access and connection configuration remain company-wide.
V7 adds nullable bank attribution to audit and sync history and backfills only determinable legacy accounts. Unknown/global history is excluded from bank-specific lists. PostgreSQL migration preflight passed with rollback before deployment. V7 then applied successfully through Flyway on backend startup; checksums of every original row in nine financial tables are unchanged. No test records were created in the live database.
Validation: 40 backend tests passed (two-bank imports/reports/cash/audit/Tally/exceptions/export isolation, same references on separate banks, cash deletion audit attribution, and AI context filtering); 13 frontend tests passed; lint and production build passed. Live read-only API isolation checks passed for all four banks. Browser verified Treasury's three bank transactions, zero cash rows/import batches, scoped reports and reconciliation, cleared manual cash draft, rapid switching, and refresh. Backend and frontend remain running at localhost:8080 and localhost:5173.
