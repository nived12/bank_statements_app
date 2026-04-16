# Vittio Mobile App — Master Plan

> **Living document** — updated as each phase is completed. Agents: read this before starting work.

## Project Overview

Building a native mobile app for Vittio (vitt.io), a personal finance app. The Rails 8 backend at `bank_statements_app/` already has a full REST API (`/api/v1/`). This plan covers mobile app development from framework selection through app store submission.

**MVP Scope**: Auth, Dashboard, Transactions (list/detail/create/edit), Bank Accounts

## Agent Team

| Agent | Slash Command | Role |
|-------|--------------|------|
| Senior Rails BE Dev | `/be-dev` | API audit, CORS, endpoint gaps, contracts, RSpec |
| Senior Rails FE Dev | `/fe-dev` | Guards web frontend, design tokens, alignment |
| Mobile Architect | `/mobile-arch` | Framework decision, architecture, implementation |
| UI/UX Mobile Expert | `/mobile-ux` | Screen specs, component specs, design direction |
| QA Engineer | `/qa` | Test plans, API contract validation, integration testing |

## Communication

All agent decisions and cross-agent communication live in `docs/mobile/decisions/`:
- `DECISIONS_LOG.md` — append-only log of all decisions and questions
- `ARCHITECTURE.md` — mobile framework and architecture decisions
- `API_GAPS.md` — API audit findings and gaps
- `UX_DIRECTION.md` — mobile design direction
- `FRONTEND_ALIGNMENT.md` — web design tokens and alignment
- `TEST_PLAN.md` — QA test plans

Current phase status: `docs/mobile/status/PHASE_STATUS.md`

---

## Phases

### ✅ Phase 0: Setup
**Status**: Complete  
**Goal**: Create agent skills, shared communication infrastructure  
**Deliverables**: 5 agent skills in `.claude/commands/`, `docs/mobile/` directory structure

---

### Phase 1: Discovery & Architecture
**Status**: Not Started  
**Goal**: API audit, mobile framework decision, UX direction established  

**Run in this order**:
1. `/be-dev` — Audit all 14 API controllers, document gaps in `API_GAPS.md`
2. `/mobile-arch` — Read `API_GAPS.md`, evaluate frameworks, write decision to `ARCHITECTURE.md`
3. `/mobile-ux` — Read `ARCHITECTURE.md`, establish design direction in `UX_DIRECTION.md`

**Known gaps to audit**:
- CORS: completely absent
- Goals API: no v1 controller
- User settings: no API endpoint
- Device tokens: no push notification registration

**Exit Criteria**:
- [ ] `API_GAPS.md` has complete audit of all 14 controllers
- [ ] `ARCHITECTURE.md` has framework decision with rationale
- [ ] `UX_DIRECTION.md` has design direction established
- [ ] All three agents have written to `DECISIONS_LOG.md`

---

### Phase 2: API Hardening
**Status**: Not Started  
**Goal**: Implement all API changes needed for mobile  

**Run in this order**:
1. `/be-dev` — Add CORS, missing endpoints, fix response consistency, write API contracts, update Swagger
2. `/fe-dev` — Review CORS config and API changes for web impact, extract design tokens

**Key tasks**:
- Add `rack-cors` gem and `config/initializers/cors.rb`
- Add `GET/PATCH /api/v1/user/settings`
- Add `POST/DELETE /api/v1/devices` (push notification tokens)
- Add Goals API v1 controller
- Fix transaction Jbuilder partial (add `concept`, `merchant`, confidence scores)
- Ensure all endpoints use `{ data: {}, meta: {}, message: "" }` envelope
- Write API contracts to `docs/mobile/specs/api-contracts/`
- Run `RAILS_ENV=test rails rswag:specs:swaggerize`

**Exit Criteria**:
- [ ] CORS configured and tested
- [ ] All MVP API endpoints exist with consistent responses
- [ ] API contracts in `docs/mobile/specs/api-contracts/`
- [ ] RSpec tests pass
- [ ] FE dev confirms no web breakage
- [ ] Swagger docs regenerated

---

### Phase 3: Mobile Project Setup
**Status**: Not Started  
**Goal**: Scaffold mobile project, implement auth flow end-to-end  

**Run in parallel then sequence**:
1. `/mobile-ux` — Write screen specs for login, signup; define navigation structure
2. `/mobile-arch` — Scaffold project, set up networking + auth interceptor, implement auth screens
3. `/qa` — Write initial test plan, manually test auth endpoints

**Exit Criteria**:
- [ ] Mobile project builds and runs on simulator/emulator
- [ ] Auth flow works end-to-end (login → use tokens → refresh → logout)
- [ ] Navigation skeleton with placeholder screens

---

### Phase 4: Core Screens
**Status**: Not Started  
**Goal**: Dashboard, transactions, bank accounts with real API data  

**Run in order**:
1. `/mobile-ux` — Write screen and component specs for all core screens
2. `/mobile-arch` — Implement all core screens per specs
3. `/be-dev` — Fix any API issues discovered during implementation

**Screens**: Dashboard, Transactions List, Transaction Detail, Bank Accounts List, Bank Account Detail

**Exit Criteria**:
- [ ] All 4 core screen areas work with real API data
- [ ] Navigation between screens works
- [ ] Pull-to-refresh, pagination, error states handled

---

### Phase 5: Integration Testing & Polish
**Status**: Not Started  
**Goal**: QA validates everything, fix bugs, polish  

**Run**:
1. `/qa` — Execute full test plan, file bugs
2. `/mobile-arch` — Fix bugs, add polish (skeletons, transitions, haptics)
3. `/mobile-ux` — Review screens against specs
4. `/fe-dev` — Final web regression check

**Exit Criteria**:
- [ ] All QA test cases pass
- [ ] App works on both iOS and Android
- [ ] Web RSpec suite passes

---

### Phase 6+: Future Features
Each phase follows: UX specs → BE dev API → Architect implements → QA validates

- **Phase 6**: Statement file upload + processing status
- **Phase 7**: Savings tracking
- **Phase 8**: Debt tracking
- **Phase 9**: Goals
- **Phase 10**: Push notifications
- **Phase 11**: Biometric auth + app lock
- **Phase 12**: Advanced analytics
- **Phase 13**: App store submission

---

## Key Technical Facts

| Aspect | Value |
|--------|-------|
| Rails version | 8.0.4 |
| API base path | `/api/v1/` |
| Auth | JWT: 15min access, 7day refresh, JTI revocation |
| CORS | **Not configured** — must add `rack-cors` |
| Goals API | **Missing** from v1 |
| Dashboard API | Rich — 10 data sections |
| Error format | `{ error: { message, code, details } }` SCREAMING_SNAKE_CASE |
| i18n | Client-side from error codes (en + es) |
| Response envelope | `{ data: {}, meta: {}, message: "" }` |
| Pagination | Pagy: `page`/`page_size` params |
| Swagger docs | `http://localhost:3000/api/docs` |

## Critical File Paths

```
bank_statements_app/
  app/controllers/api/v1/base_controller.rb   # Base API controller
  app/controllers/concerns/api_authenticatable.rb  # JWT validation
  app/views/api/v1/dashboard/show.json.jbuilder    # Richest API response
  app/views/api/v1/shared/                    # Reusable Jbuilder partials
  config/routes.rb                            # All routes
  config/initializers/rack_attack.rb          # Rate limiting
  lib/json_web_token.rb                       # JWT encode/decode
  CLAUDE.md                                   # Project conventions
  API_DEVELOPMENT.md                          # API conventions
  spec/requests/api/v1/                       # Request specs
  spec/integration/api/v1/                    # Swagger specs
  swagger/v1/swagger.yaml                     # Generated API docs
```
