# QA Test Plan

> Owned by `/qa`. Updated as test plans are written and executed.

## Status: Awaiting Phase 3

This document will be populated by `/qa` starting in Phase 3.

---

## Phase 3: Auth Flow Tests

_To be written by /qa in Phase 3_

### Happy Path
- [ ] Login with valid credentials → receive access + refresh tokens
- [ ] Signup with valid data → account created, tokens received
- [ ] Use access token for protected request → 200 OK
- [ ] Refresh expired access token → new tokens received
- [ ] Logout → tokens invalidated

### Error Scenarios
- [ ] Login with wrong password → `INVALID_CREDENTIALS` (401)
- [ ] Login with unconfirmed email → `EMAIL_NOT_CONFIRMED` (401)
- [ ] Access protected route without token → 401
- [ ] Use expired access token without refresh → 401
- [ ] Use expired refresh token → 401
- [ ] Use invalidated token after logout → 401

### Edge Cases
- [ ] Concurrent requests when access token expires → all queue, one refresh occurs
- [ ] Refresh token used twice → second use returns 401 (JTI revoked)
- [ ] Login from two devices → both tokens valid simultaneously
- [ ] Logout from one device → only that device's tokens invalidated

---

## Phase 4: Core Screen Tests

_To be written by /qa in Phase 4_

### Dashboard
_Pending_

### Transactions
_Pending_

### Bank Accounts
_Pending_

---

## Phase 5: Integration Tests

_To be written by /qa in Phase 5_

### Error Scenario Matrix
- [ ] Network offline → graceful error state shown
- [ ] 401 during use → auto-refresh and retry
- [ ] 422 validation error → field-level errors displayed
- [ ] 404 not found → error state with back navigation
- [ ] 429 rate limited → retry-after message shown
- [ ] 500 server error → generic error with retry

### CORS Verification
- [ ] API accessible from development emulator
- [ ] API accessible from production mobile build
- [ ] Swagger UI still accessible at `/api/docs`

### i18n Tests
- [ ] App displays English by default
- [ ] Switch to Spanish → all strings update
- [ ] Error codes displayed in correct locale

---

## Test Results

_Updated by /qa after each test run_

| Phase | Tests Run | Passed | Failed | Blocked |
|-------|-----------|--------|--------|---------|
| Phase 3 | - | - | - | - |
| Phase 4 | - | - | - | - |
| Phase 5 | - | - | - | - |
