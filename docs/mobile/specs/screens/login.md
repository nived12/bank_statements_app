# Login Screen

## Purpose
First screen users see when not authenticated. Allows login with email/password. Also entry point back after session expiry.

## Data Source
- `POST /api/v1/login` with `{ user: { email, password } }`
- Success → `{ data: { access_token, refresh_token, expires_in, token_type, user: {} } }`
- Error codes: `INVALID_CREDENTIALS`, `EMAIL_NOT_CONFIRMED`, `TOKEN_GENERATION_FAILED`

## Layout

```
┌─────────────────────────────┐
│  [safe area top]            │
│                             │
│         vittio              │  ← Logo (centered, 48pt tall)
│    Personal Finance         │  ← Tagline (body-sm, slate-500)
│                             │
│  ─────── 48pt gap ──────── │
│                             │
│  Welcome back               │  ← heading-lg, slate-900
│  Sign in to your account    │  ← body-md, slate-500
│                             │
│  ─────── 32pt gap ──────── │
│                             │
│  Email                      │  ← label
│  ┌─────────────────────┐   │
│  │ email@example.com   │   │  ← email input, 52pt
│  └─────────────────────┘   │
│                             │
│  Password           [Show]  │  ← label + show/hide toggle
│  ┌─────────────────────┐   │
│  │ ••••••••••          │   │  ← secure text input, 52pt
│  └─────────────────────┘   │
│                             │
│          Forgot password?   │  ← ghost link, right-aligned, indigo-600
│                             │
│  ─────── 24pt gap ──────── │
│                             │
│  ┌─────────────────────┐   │
│  │      Sign in        │   │  ← Primary button, 52pt
│  └─────────────────────┘   │
│                             │
│  ─────── OR divider ──────  │
│                             │
│  ┌─────────────────────┐   │
│  │  🌐  Continue with  │   │
│  │       Google        │   │  ← Secondary button (future Phase)
│  └─────────────────────┘   │
│                             │
│  Don't have an account?     │
│  Create one                 │  ← inline link to signup, indigo-600
│                             │
│  [safe area bottom]         │
└─────────────────────────────┘
```

## Components

### Logo
- Vitttio wordmark (SVG) — same as web `_logo.html.erb`
- Size: 48pt height, auto width
- Color: indigo-600

### Email Input
- `keyboardType="email-address"`
- `autoCapitalize="none"`
- `autoCorrect={false}`
- `returnKeyType="next"` (focuses password)
- Error state: rose-500 border + error message below

### Password Input
- `secureTextEntry={true}` (toggle with show/hide button)
- Show/hide: `eye` / `eye-off` Lucide icon, 20pt, slate-400
- `returnKeyType="done"` (submits form)

### Sign In Button
- Disabled until both fields have values
- Loading state: replace text with `ActivityIndicator` (white, size small)
- Width: full screen minus 32pt padding (16pt each side)

### Error Toast
- Appears below button area on error
- Background: rose-50, border: rose-200, text: rose-700
- Message from i18n map: `INVALID_CREDENTIALS` → "Invalid email or password"
- Special case: `EMAIL_NOT_CONFIRMED` → shows toast + "Resend confirmation email" link

## States

- **Default**: Empty form, button disabled
- **Filling**: Button enables when both fields non-empty
- **Loading**: Button shows spinner, inputs disabled, no double-submit
- **Error — invalid credentials**: Toast below button, form stays populated (don't clear on error)
- **Error — unconfirmed email**: Toast + resend link, navigates to confirm-email screen
- **Success**: Navigate to `(app)/index` (Dashboard), no back gesture to auth screens

## Interactions
- Tap "Forgot password?" → push `forgot-password.tsx`
- Tap "Create one" → replace stack with `signup.tsx`
- Submit on password `returnKeyType="done"` — triggers login if both fields filled
- Keyboard aware: screen scrolls to keep fields above keyboard

## Animations
- Screen entrance: fade-in (200ms ease-out) — no slide, this is the root screen
- Error toast: slide up from below (spring, 250ms)
- Button press: scale 0.97 (100ms)
- Loading → success: brief checkmark flash before navigation (optional)

## Accessibility
- `accessibilityLabel` on show/hide button: "Show password" / "Hide password"
- Error messages read by VoiceOver on appearance
- Sign in button: `accessibilityState={{ disabled: true }}` when disabled
- i18n: full English + Spanish support
