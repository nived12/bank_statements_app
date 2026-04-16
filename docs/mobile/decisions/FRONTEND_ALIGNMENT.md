# Frontend Alignment — Web ↔ Mobile

> Owned by `/fe-dev`. Completed: 2026-04-16 (Phase 2)
> Extracted from: `app/assets/stylesheets/`, `app/views/layouts/application.html.erb`, `app/helpers/icons_helper.rb`, representative dashboard + transaction views.

---

## Web Impact Assessment

| API Change | Web Impact | Status |
|-----------|------------|--------|
| CORS addition (`rack-cors`) | **None** — only affects `/api/*` routes; web same-origin requests go through Rack session auth and never hit CORS middleware | ✅ Confirmed safe |
| New endpoints (`/api/v1/banks`, `GET /api/v1/user` extensions) | **None** — purely additive, no web controller touched | ✅ Safe |
| `users/_user.json.jbuilder` field additions | **None** — web uses `current_user` helper, not the API partial | ✅ Safe |
| `_category_breakdown.html.erb` hash format | **Updated by /be-dev** — partial was already updated to use hash format | ✅ Confirmed |
| Destroy envelope change (Transactions + Categories) | **None** — web uses Turbo Streams for delete responses, not the JSON envelope | ✅ Safe |
| Dashboard error format change | **None** — web renders HTML errors, not API JSON responses | ✅ Safe |
| `Rack::Attack` → Rails.cache | **None** — same throttle rules, better shared state in production | ✅ Improvement |
| General API throttle (100 req/min) | **None** — web never sends Bearer tokens; throttle only fires on Bearer-authenticated requests | ✅ Confirmed safe |

**Overall verdict**: No web breakage from any Phase 2 API changes. The CORS config is scoped exclusively to `/api/*` — web same-origin requests (session-based, no `Origin` header for navigation) are completely unaffected.

---

## Design Tokens (Web)

### CSS Custom Properties (`:root` in `application.tailwind.css`)

The app defines a formal token system in `:root`. These are the authoritative values — use these for mobile color tokens.

#### Color System

##### Primary (Sky/Blue — used for nav active states, links, forms)
| Token | Hex | Tailwind |
|-------|-----|---------|
| `--color-primary-50` | `#f0f9ff` | `sky-50` |
| `--color-primary-100` | `#e0f2fe` | `sky-100` |
| `--color-primary-500` | `#0ea5e9` | `sky-500` |
| `--color-primary-600` | `#0284c7` | `sky-600` |
| `--color-primary-700` | `#0369a1` | `sky-700` |
| `--color-primary-900` | `#0c4a6e` | `sky-900` |

> **Note for mobile**: The web's CSS token says sky/blue, but CTA buttons, FAB, and hero card use **indigo-600** (`#4f46e5`) in actual component CSS and inline views. This is intentional — the hero card, bank account cards, and primary CTAs are consistently indigo. The sky color appears in form focus rings and sidebar active states. Mobile should use **indigo-600 as the brand primary** (matches UX_DIRECTION.md).

##### Indigo (True Brand Primary — CTAs, hero card, account icon)
| Usage | Hex | Tailwind |
|-------|-----|---------|
| Primary CTA, FAB, hero card bg | `#4f46e5` | `indigo-600` |
| Hover on CTA | `#4338ca` | `indigo-700` |
| Account icon gradient end | `#4f46e5` | `indigo-600` |
| Account bar fill | `#4f46e5` | `indigo-600` |
| Statement metric value | `#4f46e5` | `indigo-600` |
| Focus ring (select) | — | `focus:ring-indigo-500` |

##### Income / Success (Positive amounts, success states)
| Token | Hex | Tailwind |
|-------|-----|---------|
| `--color-income-50` | `#ecfdf5` | `emerald-50` |
| `--color-income-100` | `#d1fae5` | `emerald-100` |
| `--color-income-500` | `#10b981` | `emerald-500` |
| `--color-income-600` | `#059669` | `emerald-600` |
| `--color-income-700` | `#047857` | `emerald-700` |

> Web CSS uses `text-green-600` / `#059669` for income amounts, not emerald. In practice green-600 = emerald-600. Mobile should use `emerald-600` / `#059669`.

##### Danger / Expense (Negative amounts, errors, delete)
| Token | Hex | Tailwind |
|-------|-----|---------|
| `--color-danger-50` | `#fef2f2` | `red-50` |
| `--color-danger-100` | `#fee2e2` | `red-100` |
| `--color-danger-500` | `#ef4444` | `red-500` |
| `--color-danger-600` | `#dc2626` | `red-600` |
| `--color-danger-700` | `#b91c1c` | `red-700` |

##### Warning (Pending states, trial notices)
| Token | Hex | Tailwind |
|-------|-----|---------|
| `--color-warning-50` | `#fffbeb` | `amber-50` |
| `--color-warning-100` | `#fef3c7` | `amber-100` |
| `--color-warning-500` | `#f59e0b` | `amber-500` |
| `--color-warning-600` | `#d97706` | `amber-600` |
| `--color-warning-700` | `#b45309` | `amber-700` |

##### Neutral Palette (Slate — primary neutral for all UI)
| Token | Hex | Tailwind |
|-------|-----|---------|
| `--color-neutral-50` | `#f8fafc` | `slate-50` |
| `--color-neutral-100` | `#f1f5f9` | `slate-100` |
| `--color-neutral-200` | `#e2e8f0` | `slate-200` |
| `--color-neutral-300` | `#cbd5e1` | `slate-300` |
| `--color-neutral-400` | `#94a3b8` | `slate-400` |
| `--color-neutral-500` | `#64748b` | `slate-500` |
| `--color-neutral-600` | `#475569` | `slate-600` |
| `--color-neutral-700` | `#334155` | `slate-700` |
| `--color-neutral-800` | `#1e293b` | `slate-800` |
| `--color-neutral-900` | `#0f172a` | `slate-900` |

##### Semantic Backgrounds
| Context | Value | Source |
|---------|-------|--------|
| Page background | `#f9fafb` (gray-50) or `#f8fafc` (slate-50) | `body class="bg-slate-50"` |
| Card background | `#ffffff` | All `.dashboard-card`, `.bank-account-card` |
| Card border | `#e5e7eb` (gray-200) or `#e2e8f0` (slate-200) | Component CSS |
| Card hover border | `#d1d5db` (gray-300) or `#cbd5e1` (slate-300) | Component CSS |
| Table header | `#f9fafb` (gray-50) | `.transactions-table-header` |
| Input resting border | `#d1d5db` | Form inputs |
| Input focus border | `#3b82f6` / `#4f46e5` | Form inputs |

##### Semantic Text Colors
| Role | Value | Tailwind |
|------|-------|---------|
| Primary (headings, main text) | `#111827` / `#0f172a` | `gray-900` / `slate-900` |
| Secondary (descriptions) | `#6b7280` / `#475569` | `gray-500` / `slate-600` |
| Muted (metadata, captions) | `#9ca3af` / `#94a3b8` | `gray-400` / `slate-400` |
| Income amounts | `#059669` | `green-600` / `emerald-600` |
| Expense amounts | `#dc2626` | `red-600` |
| Links | `#2563eb` / `#0284c7` | `blue-600` / `sky-600` |
| Active nav (sidebar) | `#1d4ed8` | `blue-700` |

##### Status Badge Colors
| Status | Background | Text |
|--------|-----------|------|
| Completed / Success | `#d1fae5` | `#065f46` (emerald bg / dark emerald text) |
| Error | `#fee2e2` | `#991b1b` (red-100 / red-800) |
| Pending / Processing | `#fef3c7` | `#92400e` (amber-100 / amber-800) |
| Parsed / Info | `#dbeafe` | `#1e40af` (blue-100 / blue-800) |

##### Account Type Colors
| Type | Badge BG | Badge Text | Avatar BG | Avatar Text |
|------|---------|------------|-----------|-------------|
| Debit | `#dbeafe` | `#1e40af` | `#dbeafe` | `#1e40af` |
| Credit | `#ede9fe` | `#5b21b6` | `#ede9fe` | `#5b21b6` |
| Cash | `#d1fae5` | `#065f46` | `#d1fae5` | `#065f46` |

##### Hero / Balance Card Gradients
| Usage | Gradient |
|-------|---------|
| Desktop balance card | `from-slate-900 via-slate-800 to-slate-900` |
| Hero card (current web, most prominent) | `#4f46e5` solid (indigo-600) |
| Mobile balance section | `135deg, #3b82f6 0%, #2563eb 50%, #1d4ed8 100%` (blue gradient) |
| Account icon | `from-blue-500 to-indigo-600` |
| Auth card | `from-slate-900 via-slate-800 to-slate-900` |
| Auth submit button | `from-blue-600 to-indigo-600` |

---

### Typography

**Font family**: `Inter` loaded from Google Fonts (weights: 300, 400, 500, 600, 700)
**Font stack**: `'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif`
**Body base**: `font-sans antialiased` on `<body>`

#### Type Scale in Use

| CSS Class / Context | Size | Weight | Tailwind |
|--------------------|------|--------|---------|
| Page headings (`h1` dashboard) | `1.875rem` (30px) | 700 | `text-3xl font-bold` |
| Card titles | `1.25rem` (20px) | 600 | `text-xl font-semibold` |
| Section titles | `1.125rem` (18px) | 500 | `text-lg font-medium` |
| Metric values (large) | `1.75rem` (28px) | 600 | `text-2xl font-bold` |
| Balance hero amount | `2.25rem` (36px) | 600 | `text-4xl font-bold` (mobile: `text-5xl` desktop) |
| Body text | `0.875rem` (14px) | 400-500 | `text-sm` |
| Captions / metadata | `0.75rem` (12px) | 400 | `text-xs` |
| Labels (all-caps) | `0.7rem` (11.2px) | 500 | custom `font-size: 0.7rem` |
| Mobile nav label | `11px` | 500 | `text-xs font-medium` |
| File metadata chips | `11px` | 400 | custom `font-size: 11px` |

**Label pattern** (used widely for metric labels, account labels):
```css
font-size: 0.7rem;
font-weight: 500;
text-transform: uppercase;
letter-spacing: 0.08em;
color: #6b7280;
```

---

### Spacing Scale

Defined in `:root` as CSS variables (also mapped to Tailwind's default scale):

| Token | Value | px |
|-------|-------|----|
| `--spacing-xs` | `0.25rem` | 4px |
| `--spacing-sm` | `0.5rem` | 8px |
| `--spacing-md` | `1rem` | 16px |
| `--spacing-lg` | `1.5rem` | 24px |
| `--spacing-xl` | `2rem` | 32px |
| `--spacing-2xl` | `3rem` | 48px |

**Common patterns observed**:
- Card padding: `p-6` (24px) — most cards
- Card padding compact: `p-4` (16px) — mobile transaction cards
- Form field vertical gap: `space-y-6` (24px)
- Section gap: `gap-6` (24px) on metric grids
- List item gap: `space-y-4` (16px) or `space-y-3` (12px)
- Page horizontal padding: `px-4 sm:px-6 lg:px-8`
- Page max-width: `max-w-7xl mx-auto` (80rem)
- Main content bottom padding (mobile): `pb-20` (for bottom nav clearance)

---

### Border Radius

Defined in `:root`:

| Token | Value | px | Tailwind |
|-------|-------|----|---------|
| `--radius-sm` | `0.375rem` | 6px | `rounded-md` |
| `--radius-md` | `0.5rem` | 8px | `rounded-lg` |
| `--radius-lg` | `0.75rem` | 12px | `rounded-xl` |
| `--radius-xl` | `1rem` | 16px | `rounded-2xl` |

**Common usage**:
| Component | Radius |
|-----------|--------|
| Standard cards (bank accounts, statement cards) | `12px` / `rounded-xl` |
| Dashboard metric cards | `rounded-2xl` (16px) |
| Balance/hero card | `rounded-3xl` (24px) |
| Buttons | `rounded-lg` (8px) |
| Badges / pills | `rounded-full` (9999px) |
| Form inputs | `rounded-lg` (8px) or `rounded-xl` (12px auth) |
| Icon containers (small) | `rounded-lg` (8px) |
| Mobile FAB | `rounded-full` (56–64px circle) |
| Mobile nav items | `rounded-2xl` (16px) |

---

### Shadow Scale

Defined in `:root`:

| Token | Value |
|-------|-------|
| `--shadow-sm` | `0 1px 2px 0 rgb(0 0 0 / 0.05)` |
| `--shadow-md` | `0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)` |
| `--shadow-lg` | `0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)` |
| `--shadow-xl` | `0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)` |

**Component shadow philosophy**:
- Standard cards: **no shadow** (`box-shadow: none !important`) — flat design, border-only
- Dashboard metric cards (desktop): heavy shadow (`shadow-xl` with `hover:shadow-2xl`)
- Mobile cards: `shadow-sm` or `shadow-md`
- Mobile FAB: `0 8px 20px rgba(56,189,248,0.3), 0 4px 12px rgba(0,0,0,0.1)`
- Mobile bottom nav: `0 -8px 32px rgba(0,0,0,0.12), 0 -2px 8px rgba(59,130,246,0.08)`

> **Note**: There are two shadow "personalities" in the web app. The flat CSS files in `components/` show no-shadow cards (the intentional live design). The `application.tailwind.css` has an older elevated design with heavy shadows. The flat/no-shadow is the current production style — confirmed by `box-shadow: none !important` overrides.

---

### Icons

**Library**: [Lucide](https://lucide.dev/icons) — outline variant exclusively
**Helper**: `app/helpers/icons_helper.rb` — `icon_svg(name)` and `icon(name, library: "lucide", variant: "outline")`
**Size classes**: `w-5 h-5` default; `w-6 h-6` navigation; `w-4 h-4` action buttons; `w-12 h-12` metric icons

#### Navigation Icons (confirmed in `application.html.erb`)
| Route | Icon Name |
|-------|-----------|
| Dashboard | `layout-dashboard` |
| Bank Accounts | `credit-card` |
| Categories | `folder` |
| Transactions | `receipt` |
| Statement Files | `file-text` |
| New Transaction (FAB) | `plus` |
| Sign Out | `log-out` |

#### Future/Disabled Navigation Icons
| Route | Icon Name |
|-------|-----------|
| Goals | `target` |
| Savings | `piggy-bank` |
| Debts | `wallet` |

#### Full Category Icon Library (100+ icons in `IconsHelper::ICONS_LIBRARY`)

**Home & Living**: `house`, `sofa`, `lamp-desk`, `bed`, `armchair`, `refrigerator`, `microwave`, `washing-machine`

**Shopping**: `shopping-cart`, `shopping-bag`, `shopping-basket`, `gift`, `package`

**Food & Dining**: `pizza`, `utensils`, `utensils-crossed`, `chef-hat`, `cake`, `egg`, `salad`, `sandwich`, `soup`

**Beverages**: `coffee`, `milk`, `wine`, `beer`, `martini`

**Transportation**: `car`, `bus`, `train-front`, `plane`, `car-taxi-front`, `truck`, `bike`, `fuel`

**Finance**: `credit-card`, `wallet`, `coins`, `banknote`, `receipt`, `piggy-bank`, `landmark`, `chart-bar`, `briefcase`

**Entertainment**: `film`, `music`, `ticket`, `gamepad-2`, `tv`, `camera`

**Health**: `heart`, `pill`, `dumbbell`, `hospital`, `stethoscope`, `syringe`, `heart-pulse`

**Education**: `book`, `book-open`, `graduation-cap`, `library`, `pencil`

**Lifestyle**: `sparkles`, `star`, `scissors`, `smartphone`, `wifi`, `wrench`, `shirt`, `watch`, `glasses`

**Pets**: `dog`, `cat`, `bird`, `fish`

**Travel**: `globe`, `map`, `map-pin`, `compass`, `luggage`, `tree-palm`, `hotel`

**Utilities**: `droplet`, `droplets`, `flame`, `plug`

**Work**: `laptop`, `monitor`, `calculator`

**Security**: `shield`, `key`, `lock`

**Misc**: `repeat`, `arrow-left-right`, `square-parking`, `umbrella`, `tag`, `folder`, `circle-dot`, `zap`

**People**: `baby`, `users`, `heart-handshake`, `hand-heart`, `church`, `megaphone`, `scale`, `user-check`

**Documents**: `file-text`, `triangle-alert`, `award`

> **For mobile**: Import `lucide-react-native` (already in `/mobile-arch` architecture). The Lucide icon name from the API `icon` field maps 1:1 to the React Native component name (PascalCase: `"shopping-cart"` → `<ShoppingCart />`).

---

## Component Patterns

### Cards

**Standard card** (used everywhere):
```
background: #ffffff
border: 1px solid #e5e7eb  (gray-200)
border-radius: 12px  (rounded-xl)
padding: 1.5rem  (p-6)
box-shadow: none
transition: border-color 0.15s ease
hover: border-color → #d1d5db
```

**Metric card** (dashboard stats):
```
background: #ffffff
border-radius: 16px  (rounded-2xl)
padding: 1.25rem 1.5rem
box-shadow: heavy (0 20px 25px...)
hover: -translate-y-1 + heavier shadow
```

**Hero card** (dashboard balance):
```
background: #4f46e5  (indigo-600 solid)
border-radius: 16px
padding: 2rem
color: white throughout
```

### Badges / Pills

```
display: inline-flex
align-items: center
padding: 0.125rem 0.5rem  (py-0.5 px-2)
font-size: 0.7rem  (11px)
font-weight: 500-600
border-radius: 9999px  (rounded-full)
```

### Buttons

| Variant | Background | Text | Hover |
|---------|-----------|------|-------|
| Primary | `#4f46e5` (indigo-600) | white | `#4338ca` (indigo-700) |
| Secondary | `#ffffff` | `#374151` (gray-700) | `#f9fafb` bg + `#9ca3af` border |
| Danger | `#dc2626` (red-600) | white | `#b91c1c` (red-700) |
| Disabled | `#d1d5db` (gray-300) | `#6b7280` (gray-500) | — |

**Button shape**: `rounded-lg` (8px), `px-4 py-2` default, `px-6 py-3` large
**Form submit button**: full-width, `py-3`

### Form Inputs

```
padding: 0.75rem 1rem
border: 1px solid #d1d5db
border-radius: 0.5rem  (8px)
focus: border-color #3b82f6 + box-shadow 0 0 0 2px rgba(59,130,246,0.25)
transition: border-color 0.15s ease, box-shadow 0.15s ease
```

**Auth form inputs** (on dark card):
```
background: #1e293b (slate-800)
border: 1px solid #475569 (slate-600)
border-radius: 0.75rem  (12px)
color: white
placeholder: slate-400
focus: ring-2 ring-blue-500
```

### Modals (Mobile bottom sheets)

```
.mobile-transaction-modal-content:
  position: fixed; bottom: 0; left: 0; right: 0
  height: 90vh
  border-radius: top corners implied
  transform: translateY(100%) → translateY(0)
  transition: 200ms cubic-bezier(0.25, 0.46, 0.45, 0.94)
  backdrop: blur(8px) rgba(255,255,255,0.1)

.mobile-category-modal-content:
  max-width: 28rem
  max-height: 90vh
  animation: slideUpModal 300ms ease-out
  backdrop: blur(8px) rgba(0,0,0,0.5)
```

### Status Indicators

```css
.status-success: bg-green-100 text-green-800  (--color-success-100 / 700)
.status-warning: bg-yellow-100 text-yellow-800  (--color-warning-100 / 700)
.status-danger:  bg-red-100 text-red-800  (--color-danger-100 / 700)
.status-info:    bg-sky-100 text-sky-800  (--color-primary-100 / 700)
```

---

## Navigation Patterns

### Desktop Sidebar
- Width: `md:w-56` (224px), fixed, left side
- Background: `bg-white`, right border `border-slate-200`
- Logo at top, nav links in middle, user section at bottom
- Nav item: `text-slate-600`, active: `bg-blue-50 text-blue-700 border-r-2 border-blue-700`
- Nav icon: `text-slate-400`, active: `text-blue-500`
- Content area: `md:ml-56` offset

### Mobile Bottom Navigation (Web)
- Position: `fixed; bottom: 0`; height: `60px` + safe area
- Background: `rgba(255,255,255,0.95)` with `backdrop-filter: blur(20px)`
- Border: `1px solid rgba(59,130,246,0.1)` (subtle blue tint)
- Shadow: `0 -8px 32px rgba(0,0,0,0.12)` (upward)
- Active item: blue-600 color + subtle blue bg + `border: 1px solid rgba(59,130,246,0.2)` + top indicator pill
- Inactive item: `text-slate-500`
- Labels: 11px font-medium

**Tab order** (web mobile nav — 4 tabs + FAB):
```
[Dashboard] [Transactions] [+ FAB] [Statement Files] [Bank Accounts]
```

> **Note for mobile app**: UX_DIRECTION.md specifies 5 tabs: `[Home] [Txns] [+FAB] [Accounts] [Profile]`. Statement Files is replaced by Profile tab. This is the correct mobile nav structure — the web nav is a web constraint (no profile tab on web since it's in the sidebar user section).

### FAB Button (Web)
- Size: `64px` circle (`.mobile-nav-fab-button: w-16 h-16`)
- Background: `from-sky-400 to-blue-500` gradient (web uses sky/blue)
- Elevation: `margin-top: -38px` (floats above nav bar)
- Border: `4px solid white` (halo effect)
- Icon: `plus` (Lucide), `w-7 h-7`

> **Note for mobile**: UX_DIRECTION.md specifies FAB in indigo-600 (`#4f46e5`). The web uses sky/blue gradient. Mobile can use indigo for brand consistency.

### Mobile Slide-up Menu (Web hamburger on small screens)
- Panel: `w-80` (320px), full height, `bg-white`, `shadow-2xl`
- Slide from left: `transform -translate-x-full` → `translate-x-0`
- Transition: `duration-300 ease-in-out`

---

## Animation / Transitions

### Page Transitions (View Transition API — web only)
```css
/* Mobile: native-like slide */
slide-out-left 300ms ease-out (forward nav outgoing)
slide-in-right 300ms ease-out (forward nav incoming)
slide-out-right 300ms ease-out (back nav outgoing)
slide-in-left 300ms ease-out (back nav incoming)

/* Desktop: fade */
fade-out / fade-in, 200ms, cubic-bezier(0.4, 0.0, 0.2, 1)
```

### Component Transitions
```css
Default hover transition:  0.15s ease
Card border transitions:   0.15s ease
Button color transitions:  0.2s (duration-200)
Nav item transition:       0.3s ease-out
Modal slide-up:            300ms cubic-bezier(0.25, 0.46, 0.45, 0.94)
Mobile transaction modal:  200ms cubic-bezier(0.25, 0.46, 0.45, 0.94)
Chevron rotate:            0.2s ease
Skeleton shimmer:          animate-pulse (2s cubic-bezier)
Savings bar fill:          width 0.4s ease
Toast notification:        300ms ease-out (translateX + scale)
```

### Custom Keyframe Animations
```css
fadeInUp:     opacity 0→1 + translateY(20px→0), 0.6s ease-out
slideInRight: opacity 0→1 + translateX(20px→0), 0.6s ease-out
slideUpModal: translateY(100%→0), used for category modal
```

### Loading States
```css
.loading-skeleton:       animate-pulse bg-slate-200 rounded
.loading-skeleton-text:  h-4 bg-slate-200 rounded
.loading-skeleton-chart: h-64 bg-slate-200 rounded-xl
```

---

## i18n Approach

### Key Structure
Format: `[section].[feature].[element]`

**Examples observed**:
```yaml
navigation.dashboard
navigation.bank_accounts
navigation.transactions
navigation.statement_files
navigation.categories
navigation.goals
navigation.savings
navigation.debts

dashboard.title
dashboard.subtitle
dashboard.index.chart_render_error

transactions.concept
transactions.edit
transactions.delete_transaction
transactions.inline_edit.concept_hint
transactions.view_statement_file

session.sign_out

transaction_types.income
transaction_types.expense
transaction_types.transfer_in
transaction_types.transfer_out

form_actions.save
form_actions.cancel

api.transactions.destroyed
api.categories.destroyed

month_picker.previous_month
month_picker.next_month
month_picker.jump_to_current_month

spending_trends.title
account_balances.title
account_balances.no_accounts
bank_statements.unknown

mobile.dashboard.title
quick_actions.upload_statement
statement_files.upload_pro_only
```

### Key Alignment Advice for Mobile

1. **Reuse existing keys where semantically identical** — `navigation.*`, `transaction_types.*`, `form_actions.*` should be identical in mobile i18next config.

2. **`mobile.*` namespace exists** — The web already has `mobile.dashboard.title`. Mobile can use its own `mobile.*` namespace for mobile-only strings (push notifications, biometrics, etc.) without polluting web keys.

3. **API error codes** — Mobile displays errors from SCREAMING_SNAKE_CASE codes (e.g., `INVALID_CREDENTIALS`, `DASHBOARD_LOAD_FAILED`). Keep a separate `errors.*` namespace in mobile i18next, not mixed with web keys.

4. **Currency formatting** — Web uses Rails `number_with_precision` + `number_with_currency`. Mobile should use `Intl.NumberFormat` with `style: 'currency'` and the account's currency code from the API.

5. **Date formatting** — Web uses `format_local_time(date, format: 'short_date')`. Mobile should use `date-fns` with the user's locale (inferred from device or API `locale` field on user settings).

6. **Locale support** — Web has `en.yml` and `es.yml`. Mobile must have both `en` and `es` in i18next from day one.

---

## Recommendations for Mobile

### Align Exactly
- **Brand primary color**: indigo-600 (`#4f46e5`) — matches web hero card, CTA buttons exactly
- **Neutral palette**: Slate (`#0f172a` through `#f8fafc`) — same tokens
- **Income color**: `#059669` (emerald-600) — same as web
- **Expense color**: `#dc2626` (red-600) — same as web
- **Font family**: Inter (weight 300, 400, 500, 600, 700) — exact match
- **Border radius**: 12px cards, 16px larger containers, 8px buttons, 9999px pills — exact match
- **Icon library**: Lucide outline — exact match; use `lucide-react-native`
- **Account type colors**: Debit (blue-100/blue-800), Credit (violet-100/violet-800), Cash (emerald-100/emerald-800) — exact match

### Diverge Intentionally (Mobile-Native Patterns)
- **Navigation**: Web has sidebar (desktop) + 4-tab bottom nav. Mobile has 5-tab bottom nav with Profile tab — Profile replaces the sidebar user section. This is the right call.
- **FAB color**: Web uses sky-400→blue-500 gradient. Mobile should use indigo-600 (UX_DIRECTION.md) for stronger brand consistency.
- **Cards**: Web mixes flat and elevated card styles. Mobile should use flat cards (no shadow, border-only) consistently — this matches the CSS component files (the elevated shadows are a legacy layer).
- **Typography sizes**: Web uses `rem`-based scale for browser zoom. Mobile uses `pt` scale for native. Map: web `text-sm` (14px) → mobile `body-md` (15pt), web `text-base` (16px) → mobile `body-lg` (16pt).
- **Touch targets**: Web has no minimum target enforcement. Mobile must enforce 44pt minimum on all interactive elements.
- **Haptics**: Web has no haptics. Mobile adds haptic feedback per UX_DIRECTION.md haptic map.
- **Dark mode**: Web has no dark mode. Mobile plans for dark mode in Phase 5+ — use semantic tokens from day one.
- **Transitions**: Web uses CSS View Transition API (browser-native). Mobile uses React Navigation spring animations — same principles, native implementation.

### Watch Out For
1. **Dual shadow personality**: The `components/*.css` files show the intentional flat/no-shadow design. The `application.tailwind.css` has elevated shadow definitions. Trust the component CSS files — they override the base in production.
2. **`nav-link-active` vs `sidebar-nav-item.active`**: Web nav active state is `bg-blue-50 text-blue-700` (blue, not indigo). Mobile uses indigo-600 for active states — this is an intentional divergence from the web sidebar.
3. **FAB uses sky-500 on web, not indigo**: The web FAB is `from-sky-400 to-blue-500`. This appears to be a legacy web decision. Mobile should align to indigo-600 per UX_DIRECTION.md.
4. **`gray-*` vs `slate-*` inconsistency**: The web CSS mixes Tailwind's `gray` and `slate` families (both close to neutral gray). Mobile should standardize on `slate` throughout — consistent with `--color-neutral-*` tokens and UX_DIRECTION.md.

---

## Shared Brand Assets

- **Logo**: `app/assets/images/` (rendered via `shared/logo` partial, `h-8 w-auto` desktop, `h-6 w-auto` mobile header)
- **Favicon**: `/icon.svg` (SVG favicon)
- **Avatar**: Gravatar via `current_user.avatar_url` (user model method)
- **Beta badge**: Present in web logo (check `shared/logo` partial)

---

## Summary Token Reference (Mobile Quick-Start)

```typescript
// colors.ts — paste into mobile theme
export const colors = {
  brand: {
    primary:   '#4f46e5',  // indigo-600 — CTAs, FAB, active states
    primaryHov:'#4338ca',  // indigo-700 — hover/pressed
    primaryLt: '#e0e7ff',  // indigo-100 — backgrounds behind primary
  },
  income:  '#059669',  // emerald-600
  expense: '#dc2626',  // red-600
  warning: '#d97706',  // amber-600
  transfer:'#7c3aed',  // violet-600
  bg: {
    screen:  '#f8fafc',  // slate-50
    card:    '#ffffff',
    surface2:'#f1f5f9',  // slate-100
  },
  border: {
    default: '#e5e7eb',  // gray-200
    slate:   '#e2e8f0',  // slate-200
    focus:   '#6366f1',  // indigo-500
  },
  text: {
    primary:   '#0f172a',  // slate-900
    secondary: '#475569',  // slate-600
    muted:     '#94a3b8',  // slate-400
    inverse:   '#ffffff',
  },
  account: {
    debit:  { bg: '#dbeafe', text: '#1e40af' },
    credit: { bg: '#ede9fe', text: '#5b21b6' },
    cash:   { bg: '#d1fae5', text: '#065f46' },
  },
  status: {
    success: { bg: '#d1fae5', text: '#065f46' },
    error:   { bg: '#fee2e2', text: '#991b1b' },
    warning: { bg: '#fef3c7', text: '#92400e' },
    info:    { bg: '#dbeafe', text: '#1e40af' },
  },
} as const;

export const radius = {
  sm:   6,   // buttons, inputs
  md:   8,   // buttons, chips
  lg:   12,  // cards
  xl:   16,  // large cards
  xxl:  24,  // hero card
  full: 9999,
} as const;

export const spacing = {
  xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48,
} as const;

export const font = {
  family: 'Inter',
  weights: { light:300, regular:400, medium:500, semibold:600, bold:700 },
} as const;
```
