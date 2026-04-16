# Dashboard Screen

## Purpose
Home screen. Gives the user an at-a-glance financial health summary for the selected month: total balance, income vs expenses, category breakdown, recent transactions, and account balances.

## Data Source
- `GET /api/v1/dashboard?month=YYYY-MM`
- Key fields used:
  - `data.summary`: total_balance, total_transactions, selected_month
  - `data.monthly_summary`: total_income, total_expenses, net_income
  - `data.monthly_stats`: average_transaction, largest_expense, daily_average
  - `data.bank_accounts`: id, name, account_type, balance, currency
  - `data.category_summary`: categories array (name, amount), has_data
  - `data.spending_trends`: array of { month, total_expenses, total_income, net_income }
  - `data.recent_transactions`: last 5-10 transactions
  - `data.available_months`: array of { value, label } for month picker

## Layout

```
┌─────────────────────────────┐
│  [safe area top]            │
│                             │
│  ← Month Picker [Jun 2026 ▾]│  ← Top bar: greeting + month selector
│                             │
│  ┌─────────────────────────┐│
│  │  gradient card          ││  ← Balance Hero Card (blue→indigo)
│  │                         ││
│  │  Total Balance          ││
│  │  $12,450.00             ││  ← display-xl, white
│  │                         ││
│  │  ↑ $3,200   ↓ $1,850   ││  ← Income / Expense mini stats
│  └─────────────────────────┘│
│                             │
│  ── Accounts ───────── All →│  ← Section header with "See all" link
│  ┌────────────────────────┐ │
│  │ [scrollable horizontal]│ │  ← Account chips (horizontal scroll)
│  └────────────────────────┘ │
│                             │
│  ── Spending by Category ── │
│  ┌─────────────────────────┐│
│  │   [Bar chart or donut]  ││  ← Category breakdown chart
│  │   Food     $450  ████   ││
│  │   Transport $280  ███   ││
│  │   Shopping  $200  ██    ││
│  └─────────────────────────┘│
│                             │
│  ── Monthly Trend ───────── │
│  ┌─────────────────────────┐│
│  │  [Sparkline/bar chart]  ││  ← 6-month spending trend
│  └─────────────────────────┘│
│                             │
│  ── Recent Transactions ─── │
│  │ See all →               │
│  [transaction row]          │  ← Up to 5 recent transactions
│  [transaction row]          │
│  [transaction row]          │
│  [transaction row]          │
│  [transaction row]          │
│                             │
│  [safe area bottom]         │
└─────────────────────────────┘
```

## Components

### Top Bar
- Left: Greeting text "Good morning, Nived" (body-md, slate-600) or just month context
- Center/Right: Month picker button showing "Jun 2026 ▾" (heading-md, slate-900)
- Month picker opens a bottom sheet with scrollable month list from `available_months`

### Balance Hero Card
- Full-width minus 16pt horizontal padding
- 160pt height
- Gradient: blue-500 → indigo-600 (left to right)
- Border-radius: 20pt
- Content:
  - "Total Balance" label (caption, white/70% opacity)
  - Balance amount (display-xl, white, tabular nums)
  - Bottom row: two mini stats side by side
    - ↑ income: emerald-300 arrow + white amount
    - ↓ expenses: rose-300 arrow + white amount

### Account Chips (Horizontal Scroll)
- Height: 80pt per chip, min-width: 160pt
- Horizontally scrollable, 8pt gap between chips
- Each chip: white card, 12pt radius, border slate-200
  - Chip content: account type color dot + account name (body-sm) + balance (heading-md)
  - Account type color: sky (debit), violet (credit), emerald (cash)
- "See all" ghost link → navigates to Accounts tab

### Category Breakdown (Horizontal Bar Chart)
- Uses `victory-native` `VictoryBar` (horizontal)
- Up to 5 categories shown; 6th+ grouped as "Other"
- Each bar: category name (body-sm, left) + amount (caption, right) + filled bar (category color or indigo)
- "No data yet" empty state if `has_data === false`
- Chart is NOT interactive in MVP (tap to drill down is Phase 4+)

### Monthly Trend (Sparkline)
- 6-month bar chart from `spending_trends`
- Two series: income (emerald) and expenses (rose)
- X-axis: short month labels (Jan, Feb, ...)
- Selected month highlighted with indigo border
- Height: 120pt

### Recent Transactions
- Section header: "Recent Transactions" (heading-md) + "See all →" (ghost link, indigo)
- "See all" → navigates to Transactions tab
- Up to 5 transactions using `TransactionRow` component
- Each row: tappable → navigates to Transaction Detail

## States

- **Loading**: 
  - Balance hero: shimmer rectangle (160pt)
  - Account chips: 2 shimmer chips
  - Chart section: shimmer rectangle (150pt)
  - Trend: shimmer rectangle (120pt)
  - Recent transactions: 5 shimmer rows
  
- **Empty (new user, no data)**:
  - Balance hero: shows $0.00
  - Accounts section: "Add your first bank account" CTA card
  - Charts: "No transactions yet" empty state with wallet illustration
  - Recent transactions: empty state with "Import a statement or add transactions manually" + two CTA buttons

- **Error**:
  - Full-page error state: icon + "Couldn't load dashboard" + "Try again" button
  - Retry calls `GET /api/v1/dashboard` again

- **Populated**: Normal state as described in layout

## Interactions

- **Pull-to-refresh**: Refetches `GET /api/v1/dashboard` for current month
  - Haptic: light impact on trigger
  
- **Month picker tap**: Opens bottom sheet with month list
  - Selecting a month: re-fetches dashboard with new `?month=` param
  - Previous months up to 12 months back
  
- **Account chip tap**: Navigates to bank account detail
  
- **"See all" accounts**: Switches to Accounts tab
  
- **Recent transaction tap**: Pushes Transaction Detail on Transactions stack

## Animations

- **Initial load**: Staggered card entrance — each section fades in with 50ms stagger (balance first, then accounts, then charts, then transactions)
- **Month change**: Content fades out (150ms), new content fades in after data loads
- **Chart bars**: Animate from 0 height on first render (staggered 30ms per bar)
- **Balance number**: Count-up animation from 0 to actual value (600ms, ease-out) on first load only

## Accessibility

- Balance card: `accessibilityLabel="Total balance: twelve thousand four hundred fifty pesos"`
- Month picker: `accessibilityRole="button"`, announces selected month
- Charts: Each bar has `accessibilityLabel` with category name and amount
- "See all" links: include context — `accessibilityLabel="See all transactions"` / `"See all accounts"`
