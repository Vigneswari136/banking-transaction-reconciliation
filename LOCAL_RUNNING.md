# Local application running

Verified on 3 November 2026 (Asia/Calcutta). Frontend, backend, PostgreSQL connection and the installed local AI runtime are running.

| Service | URL |
|---|---|
| React frontend | http://localhost:5173/ |
| Spring Boot backend | http://localhost:8080/ |
| API base | http://localhost:8080/api |
| Backend health | http://localhost:8080/api/health |
| API through frontend proxy | http://localhost:5173/api/health |
| Swagger UI | http://localhost:8080/swagger-ui.html |
| OpenAPI JSON | http://localhost:8080/v3/api-docs |

The backend root is a REST service, not the React interface. Use the frontend URL for the application and the health or Swagger URL to inspect the backend.

## Verification completed

- Browser sign-out/sign-in with the existing administrator account returned to the populated dashboard.
- Reconciliation workbench, bank transactions, centralized imports, cash book, reports, audit log and settings/user management rendered successfully.
- The consolidated report loaded persisted transaction data through the frontend proxy.
- 26 final health/API/security/documentation checks passed. Successful JSON responses were parsed strictly; unauthenticated and malformed-token requests were blocked as expected.
- Excel previews accepted 11 bank rows, 12 ledger rows and 11 cash rows without saving any test financial records.
- The AI assistant returned a model-generated answer from cached `qwen2.5:3b` in the browser. The confirmed Ollama generation completed in approximately 38 seconds.
- Backend regression suite: 36 tests, 0 failures, 0 errors, 0 skipped. Production backend package rebuilt.
- Frontend console contained no captured errors in the final browser check.
- The configured PostgreSQL database is connected, Flyway is validated through V6, and startup used strict Hibernate schema validation.

## Startup/API fix

When Ollama was unavailable, the AI service incorrectly interrupted the servlet thread on an ordinary connection IOException. Tomcat then appended an error object while flushing the fallback response, producing invalid JSON despite HTTP 200. The IOException and actual interruption paths are now separate, with a regression test for the failure case.

The local model requires more than 30 seconds for prompt processing. The model request now has a configurable 90-second timeout and a bounded 256-token response. Override with `AI_OLLAMA_TIMEOUT_SECONDS` and `AI_OLLAMA_MAX_RESPONSE_TOKENS` if needed. No model was downloaded; the already-installed Ollama runtime and cached model were used.

Changed application files: `backend/src/main/java/com/finrecon/backend/service/AiAssistantService.java`, `backend/src/main/resources/application.yml`, and the new `AiAssistantServiceTest.java`. Existing features and financial records were retained.

## Running processes and logs

- Backend Java process: 20764.
- Frontend Vite process: 19636.
- Local Ollama process: 6232.

Both application services were launched as hidden background processes and left running. The running dashboard was left open in the browser.

Logs and process metadata are in `.local-run/`: `backend.stdout.log`, `backend.stderr.log`, `frontend.stdout.log`, `frontend.stderr.log`, `ollama.stdout.log`, `ollama.stderr.log`, `services.json`, and `verification.json`. This folder is ignored by its own `.gitignore`.

## Restarting later

Run `./start-local.ps1` in PowerShell from the project root. It reuses healthy existing services and starts missing services using the installed executables, existing frontend dependencies and packaged backend. It does not install packages or download models. PostgreSQL must be running first.

After future backend source changes, rebuild from `backend` with `mvn -o package -q` (or normal Maven if new dependencies are required) before restarting that backend. The script never terminates unrelated processes.

## Requires attention

TallyPrime is not running at the saved local endpoint and a licensed instance is not available. Live Tally synchronization remains unavailable until TallyPrime is installed/licensed, running with the correct company loaded, and its XML/HTTP server enabled. Bank, ledger and cash file imports remain available.
