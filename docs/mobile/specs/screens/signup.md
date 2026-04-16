# Signup Screen

## Purpose
New user registration. Collects name, email, password. After signup, user can use the app but should confirm email to unlock all features.

## Data Source
- `POST /api/v1/signup` with `{ user: { first_name, last_name, email, password, password_confirmation } }`
- Success (201) → same shape as login: `{ data: { access_token, refresh_token, user: {} } }`
- Error codes: `VALIDATION_ERROR` with `details` array (field-level), `TOKEN_GENERATION_FAILED`

## Layout

```
┌─────────────────────────────┐
│  [safe area top]            │
│  ←  (back button)           │  ← Back to login
│                             │
│  Create account             │  ← display-lg, slate-900
│  Start managing your        │
│  finances today             │  ← body-md, slate-500, 2 lines
│                             │
│  ─────── 32pt gap ──────── │
│                             │
│  ┌──────────┐ ┌──────────┐ │
│  │First name│ │Last name │ │  ← Side-by-side, half width each
│  └──────────┘ └──────────┘ │
│                             │
│  Email                      │
│  ┌─────────────────────┐   │
│  │ email@example.com   │   │
│  └─────────────────────┘   │
│                             │
│  Password                   │
│  ┌─────────────────────┐   │
│  │ ••••••••••    [Show]│   │
│  └─────────────────────┘   │
│  ○○○○● Strength indicator  │  ← 4-dot strength bar
│                             │
│  Confirm password           │
│  ┌─────────────────────┐   │
│  │ ••••••••••    [Show]│   │
│  └─────────────────────┘   │
│                             │
│  ─────── 24pt gap ──────── │
│                             │
│  ┌─────────────────────┐   │
│  │    Create account   │   │  ← Primary button
│  └─────────────────────┘   │
│                             │
│  By creating an account,    │
│  you agree to our Terms and │
│  Privacy Policy             │  ← caption, slate-500, links indigo
│                             │
│  [safe area bottom]         │
└─────────────────────────────┘
```

## Components

### First / Last Name Row
- Two equal-width inputs, 8pt gap between them
- `autoCapitalize="words"`
- `returnKeyType="next"` (advances focus)

### Password Strength Indicator
- 4 segments, fill left to right
- Weak (1): rose-500 | Fair (2): amber-500 | Good (3): blue-500 | Strong (4): emerald-500
- Appears only after first character typed in password field
- Rules: length ≥ 8, has uppercase, has number, has special char (1 point each)

### Field-Level Error Display
- Each field shows its own inline error below
- Source: `details` array from `VALIDATION_ERROR` response
- Map `field` → display under the relevant input
- Example: `{ field: "email", message: "has already been taken" }` → under email field in rose-500

### Terms Notice
- caption size (12pt), slate-500
- "Terms" and "Privacy Policy" are indigo-600 links → open in-app WebView (future)

## States

- **Default**: All fields empty, button disabled
- **Filling**: Button enables when all required fields non-empty
- **Loading**: Button spinner, inputs disabled
- **Validation error**: Field-level errors shown inline, scroll to first error
- **Success**: Navigate to Dashboard. Show email confirmation banner at top of dashboard (non-blocking — user can use the app)

## Post-signup Email Confirmation Banner (Dashboard)
When `user.confirmed === false`:
```
┌─────────────────────────────┐
│ 📧 Confirm your email       │
│ Check your inbox to verify  │  ← amber-50 bg, amber-600 text
│ [Resend]  [Dismiss]         │
└─────────────────────────────┘
```
- Persists until `user.confirmed` becomes true
- "Resend" calls `POST /api/v1/email_confirmations`
- "Dismiss" hides for current session only

## Interactions
- Back button → login screen
- Field focus sequence: first_name → last_name → email → password → confirm_password → submit
- `returnKeyType="done"` on last field triggers submit

## Animations
- Screen entrance: slide up from bottom (signup is often presented as a modal over login)
- Field errors appear with fade-in (150ms)

## Accessibility
- First/Last name fields: `accessibilityLabel="First name"` / `"Last name"` (not just placeholder)
- Password strength: `accessibilityValue` announces "Password strength: weak/fair/good/strong"
- Error fields: `accessibilityLiveRegion="polite"` so VoiceOver reads errors on appearance
