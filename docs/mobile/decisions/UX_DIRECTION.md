# Mobile UX Direction

> Owned by `/mobile-ux`. Completed: 2026-04-16 (Phase 1)

---

## Design Philosophy: "Elevated Minimal"

Vittio's mobile experience takes the web app's clean, data-forward aesthetic and elevates it with native mobile patterns. The design language is **precision meets warmth** — rigorous enough for serious financial tracking, approachable enough that you open it daily.

**Three guiding principles**:
1. **Data clarity first** — financial numbers must be readable at a glance, no decorative noise
2. **Purposeful motion** — every animation communicates something (not decoration)
3. **Confident simplicity** — one action per moment, no overwhelm

**Inspired by**: Revolut's clean cards and progressive disclosure + Copilot's beautiful financial charts + Monzo's feed-based transaction list + Mercury's restrained typographic hierarchy.

**Not inspired by**: Cleo's playfulness (Vittio is a serious tool), YNAB's complexity (too budget-envelope heavy for our model).

---

## Color System

### Brand Colors (inherited from web, refined for mobile)

```
Primary:    #4f46e5  (indigo-600)   — CTAs, active states, links
Primary +1: #6366f1  (indigo-500)   — Hover states, lighter accents
Primary -1: #4338ca  (indigo-700)   — Pressed states
```

### Semantic Colors

```
Income:     #10b981  (emerald-500)  — Income amounts, positive values
Expense:    #f43f5e  (rose-500)     — Expense amounts, negative values
Transfer:   #8b5cf6  (violet-500)   — Transfer transactions
Warning:    #f59e0b  (amber-500)    — Warnings, trial notices
Destructive:#ef4444  (red-500)      — Delete actions
```

### Neutral Palette (warm slate)

```
Background:   #f8fafc  — Screen background (slate-50, very slightly warm)
Surface:      #ffffff  — Cards, sheets, modals
Surface-2:    #f1f5f9  — Secondary surfaces, input backgrounds (slate-100)
Border:       #e2e8f0  — Card borders, dividers (slate-200)
Border-focus: #c7d2fe  — Focused input borders (indigo-200)

Text-primary:   #0f172a  — Main text, headings (slate-900)
Text-secondary: #475569  — Labels, captions (slate-600)
Text-muted:     #94a3b8  — Placeholders, disabled (slate-400)
Text-inverse:   #ffffff  — Text on dark/colored backgrounds
```

### Hero Gradient (Balance Card)

```
Background gradient: linear from #3b82f6 (blue-500) → #4f46e5 (indigo-600)
This matches the web dashboard's ".dashboard-metric-icon" gradient exactly.
Used exclusively on: Balance hero card on dashboard
```

### Account Type Colors

```
Debit account:  #0ea5e9  (sky-500)     — Sky blue
Credit account: #8b5cf6  (violet-500)  — Violet
Cash account:   #10b981  (emerald-500) — Emerald
```

---

## Typography

**Font family**: Inter (matching web app exactly)
- iOS: SF Pro Display as fallback
- Android: Roboto as fallback

### Type Scale

| Role | Size | Weight | Line Height | Usage |
|------|------|--------|-------------|-------|
| `display-xl` | 32pt | 700 Bold | 38pt | Balance hero number |
| `display-lg` | 28pt | 700 Bold | 34pt | Screen title (e.g. "Dashboard") |
| `display-md` | 24pt | 600 SemiBold | 30pt | Section totals |
| `heading-lg` | 20pt | 600 SemiBold | 26pt | Card titles, group headers |
| `heading-md` | 17pt | 600 SemiBold | 22pt | Row titles, form labels |
| `body-lg` | 16pt | 400 Regular | 22pt | Body text, descriptions |
| `body-md` | 15pt | 400 Regular | 20pt | Transaction descriptions |
| `body-sm` | 13pt | 400 Regular | 18pt | Secondary text, metadata |
| `caption` | 12pt | 400 Regular | 16pt | Timestamps, tags |
| `label` | 11pt | 500 Medium | 14pt | Tab bar labels, badges |

**Amount typography**: Monospaced treatment for financial amounts using tabular nums (`fontVariant: ['tabular-nums']`). Income in emerald-500, expense in rose-500.

---

## Navigation Architecture

### Bottom Tab Bar (5 tabs + center FAB)

```
[  Home  ] [  Txns  ] [   +   ] [ Accounts ] [ Profile ]
  house     receipt    FAB       credit-card    user
```

**Tab 1 — Home** (Dashboard): `house` icon
**Tab 2 — Transactions**: `receipt` icon
**Tab 3 — FAB** (center, elevated): `plus` icon — opens Add Transaction modal
**Tab 4 — Accounts**: `credit-card` icon
**Tab 5 — Profile / Settings**: `user` icon

**Tab bar styling**:
- Background: `#ffffff` with top border `#e2e8f0`
- Active tab: indigo-600 icon + label
- Inactive tab: slate-400 icon + label
- Height: 83pt (includes safe area)
- FAB: 56pt circle, indigo-600 background, white plus icon, 4pt shadow elevation

**No drawer, no hamburger** — everything is in the tab bar or inline. This is the right call for an app with 4-5 main sections.

### Navigation Stacks

Each tab owns its own navigation stack:

```
Home tab:
  Dashboard → [no drill-down in MVP beyond transaction detail]

Transactions tab:
  Transactions List → Transaction Detail (push)
                   → New Transaction (modal, FAB)
                   → Edit Transaction (modal from detail)

Accounts tab:
  Bank Accounts List → Bank Account Detail (push)
                    → New Bank Account (modal)

Profile tab:
  Profile / Settings (flat, no deep stack in MVP)
```

**Modal presentation**: New/Edit forms slide up from bottom as sheets (native iOS/Android bottom sheet pattern). No full-screen push for forms.

---

## Interaction Patterns

### Pull-to-Refresh
- All list screens support pull-to-refresh
- Custom indicator: indigo spinner matching brand color
- Haptic: light impact on trigger point, success on completion

### Swipe Actions on Transaction Rows

```
← Swipe left (destructive zone, red):
  [Delete] — only shown for manual transactions
  
→ Swipe right (action zone, indigo):
  [Categorize] — opens category picker sheet
```
- Reveal threshold: 80pt
- Snap-to-reveal with spring animation
- Haptic: medium impact on full reveal

### Tap Targets
- Minimum 44×44pt for all interactive elements
- Transaction rows: full-width tap target, 72pt min height
- Account cards: full card tappable

### Long Press
- Transaction row: show quick-action menu (Edit / Delete / Share)
- Haptic: impact feedback on trigger

### Keyboard Handling
- Amount fields: numeric keypad (no letters)
- All forms scroll to keep focused field above keyboard
- Done button dismisses keyboard

### Loading Patterns

**Skeleton shimmer** (preferred over spinners):
- Transaction list: 5 ghost rows with animated shimmer
- Dashboard: ghost balance card + 3 ghost chart bars + ghost transaction rows
- Account list: ghost cards

**Inline progress**: Long operations (e.g., statement upload) use a progress bar, not a modal blocker.

---

## Animation Guidelines

### Principles
1. **Duration**: 200-350ms for most transitions. Never over 500ms.
2. **Easing**: Spring physics for interactive elements; ease-out for enter; ease-in for exit
3. **No decorative animations** — every motion must communicate state change

### Standard Transitions

| Transition | Duration | Easing |
|-----------|---------|--------|
| Screen push (React Nav) | 350ms | Spring (damping: 20, stiffness: 180) |
| Modal slide-up | 300ms | Ease-out cubic |
| Tab switch | 0ms | Instant (no cross-fade) |
| Toast appear | 250ms | Spring up from bottom |
| Skeleton shimmer cycle | 1200ms | Linear loop |
| Row swipe reveal | Spring | Damping: 15, stiffness: 200 |

### Micro-interactions
- **Amount field focus**: Subtle border glow (indigo-200 → indigo-400, 150ms)
- **Button press**: Scale 0.97, 100ms ease-in
- **Delete confirmation**: Row collapses with spring (height: 72 → 0, 250ms)
- **Success toast**: Slides up, holds 2.5s, fades out 200ms
- **FAB tap**: Slight rotate (+45°, 150ms) when sheet opens, back on close

### Chart Animations (Dashboard)
- **Spending bar chart**: Bars grow from 0 on first load (staggered: 50ms delay per bar)
- **Category pie/donut**: Draws in clockwise from 0 (800ms, ease-out)
- No loop animations — charts are static after entering

---

## Haptic Feedback Map

| Event | Haptic Type |
|-------|------------|
| FAB tap | Impact - medium |
| Swipe action reveal | Impact - light |
| Swipe action confirm | Impact - heavy |
| Transaction deleted | Notification - warning |
| Transaction saved | Notification - success |
| Form validation error | Notification - error |
| Pull-to-refresh trigger | Impact - light |
| Pull-to-refresh complete | Notification - success |
| Tab switch | Selection feedback |
| Amount input (each digit) | None (too noisy) |

---

## Component Design Patterns

### Cards
- `border-radius: 16pt`
- `border: 1pt solid #e2e8f0`
- `background: #ffffff`
- No drop shadow in default state (web matches this)
- Subtle shadow on press: `0 4px 12px rgba(0,0,0,0.08)`

### Balance Hero Card (Dashboard)
- Full-width card with gradient background (blue-500 → indigo-600)
- White text throughout
- Height: ~160pt
- Shows: total balance (large), month label, income/expense summary

### Transaction Row
- Height: 72pt min
- Left: Category icon circle (40pt, category color bg + white icon)
- Center: Description (body-md) + date/account (caption, slate-500)
- Right: Amount (heading-md, color-coded: emerald/rose) + transaction type badge

### Amount Display
- Always use `Intl.NumberFormat` with user's locale and currency
- Positive (income): emerald-500, no sign needed contextually, or show `+` prefix in summaries
- Negative (expense): rose-500, no explicit minus in transaction rows (implied by type)
- In summaries: always show explicit `+` / `-`

### Empty States
- Centered illustration (simple SVG, matches brand) + heading + subtext + optional CTA
- Example: Transactions empty → wallet icon (indigo-200) + "No transactions yet" + "Add your first transaction"
- Never show a raw empty list

### Form Fields
- Height: 52pt
- Background: slate-100 when resting, white when focused
- Border: transparent resting, indigo-200 focused
- Border-radius: 12pt
- Label above field (not placeholder-as-label)
- Error state: rose-500 border + rose-500 error text below

### Buttons
- **Primary**: indigo-600 bg, white text, 52pt height, 12pt radius, full-width in forms
- **Secondary**: white bg, indigo-600 text, indigo-200 border
- **Destructive**: rose-500 bg, white text
- **Ghost**: no bg, indigo-600 text (for inline actions)
- **Disabled**: slate-200 bg, slate-400 text

---

## MVP Screen Inventory

### Auth Flow
| Screen | Route | Priority |
|--------|-------|----------|
| Login | `(auth)/login` | MVP |
| Signup | `(auth)/signup` | MVP |
| Forgot Password | `(auth)/forgot-password` | MVP |
| Email Confirmation | `(auth)/confirm-email` | MVP |

### App Flow (MVP)
| Screen | Route | Priority |
|--------|-------|----------|
| Dashboard | `(app)/index` | MVP |
| Transactions List | `(app)/transactions/index` | MVP |
| Transaction Detail | `(app)/transactions/[id]` | MVP |
| New Transaction | Modal (FAB) | MVP |
| Edit Transaction | Modal (from detail) | MVP |
| Bank Accounts List | `(app)/accounts/index` | MVP |
| Bank Account Detail | `(app)/accounts/[id]` | MVP |
| Add Bank Account | Modal | MVP |
| Profile / Settings | `(app)/settings/index` | MVP |

### Post-MVP (Phase 6+)
| Screen | Priority |
|--------|----------|
| Statement Upload | Phase 6 |
| Savings List / Detail | Phase 7 |
| Debt List / Detail | Phase 8 |
| Goals List / Detail | Phase 9 |
| Notifications Settings | Phase 10 |
| Categories Management | Phase 6 |

---

## Accessibility Standards

- **Minimum contrast**: 4.5:1 for normal text, 3:1 for large text (WCAG AA)
- **Touch targets**: All interactive elements ≥ 44×44pt
- **VoiceOver/TalkBack labels**: All icons have `accessibilityLabel`. Amounts read as: "negative one thousand two hundred fifty pesos, expense"
- **Dynamic text**: Support iOS Dynamic Type and Android font scaling (use `sp` units via React Native's `sp` support)
- **Reduced motion**: Respect `useReducedMotion()` — skip all non-essential animations
- **Color blind**: Never use color alone to convey meaning — always pair with icon or text

---

## Dark Mode (Post-MVP Note)

Not in MVP scope but design with it in mind:
- Use semantic color tokens (not hardcoded hex) everywhere
- Background dark: `#0f172a` (slate-900)
- Surface dark: `#1e293b` (slate-800)
- The indigo primary works well on both light and dark
- Plan in Phase 5+ polish
