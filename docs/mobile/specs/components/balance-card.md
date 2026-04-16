# BalanceCard Component

## Usage
Hero card on the Dashboard screen. Displays total balance with income/expense breakdown for the selected month. The most prominent visual element in the app.

## Props
```typescript
interface BalanceCardProps {
  totalBalance: number;           // Sum of all account balances
  totalIncome: number;            // Monthly income total
  totalExpenses: number;          // Monthly expense total
  netIncome: number;              // income - expenses
  currency: string;               // e.g. 'MXN', 'USD'
  selectedMonth: string;          // e.g. 'April 2026'
  isLoading?: boolean;
}
```

## Visual Anatomy

```
┌──────────────────────────────────────┐
│  Total Balance        April 2026     │  ← label row, white/70%
│                                      │
│  $12,450.00                          │  ← display-xl, white, tabular-nums
│                                      │
│  ──────────────────────────────────  │  ← 1pt divider, white/20%
│                                      │
│  ↑ $3,200.00        ↓ $1,850.00     │  ← income / expense
│  Income             Expenses         │  ← captions, white/70%
└──────────────────────────────────────┘
```

- **Width**: Full screen minus 32pt (16pt padding each side)
- **Height**: 160pt
- **Border-radius**: 20pt
- **Background**: Linear gradient, left to right — `#3b82f6` → `#4f46e5`
- **Padding**: 20pt all sides
- **Shadow**: `0 8px 24px rgba(79, 70, 229, 0.3)` — colored shadow matching gradient end

## Content Detail

**Label row** (top):
- "Total Balance" (caption, white, opacity 0.75, left)
- Month name (caption, white, opacity 0.75, right)

**Balance** (center):
- Formatted with `Intl.NumberFormat` using user locale + currency
- Font: Inter 700 Bold, 32pt
- Color: white
- `fontVariant: ['tabular-nums']` for stable width

**Divider**: 1pt line, white 20% opacity, full width, 16pt vertical margin

**Bottom row** (two columns):
- Left column: income
  - ↑ arrow (emerald-300, 16pt) + formatted amount (heading-md, white)
  - "Income" label (caption, white 70%)
- Right column: expenses
  - ↓ arrow (rose-300, 16pt) + formatted amount (heading-md, white)
  - "Expenses" label (caption, white 70%)

## Variants

### Default (populated)
As described above.

### Loading (skeleton)
- Same card shape and gradient
- Replace text with white shimmer bars (opacity 0.3 → 0.5 animated)
- Balance bar: 160pt wide × 40pt tall shimmer
- Bottom row: two 100pt × 16pt shimmer bars

### Negative balance
- Balance displayed as-is (negative with minus sign)
- No special color change — the gradient stays, the amount goes red would be confusing on dark bg
- Optionally: a subtle downward indicator ↓ before the amount

## Behavior
- Not tappable — purely informational in MVP
- Phase 4+: tapping could navigate to a detailed financial summary screen

## Accessibility
- `accessibilityLabel`: "Total balance: [amount]. Income this month: [amount]. Expenses this month: [amount]."
- Container: `accessibilityRole="summary"` or just wrapping with a descriptive label
- Loading state: `accessibilityLabel="Loading balance"`
