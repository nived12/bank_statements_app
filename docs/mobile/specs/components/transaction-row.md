# TransactionRow Component

## Usage
Used in: Transactions List screen, Dashboard recent transactions, Bank Account detail. The primary way transactions are displayed throughout the app.

## Props
```typescript
interface TransactionRowProps {
  id: number;
  description: string;
  amount: number;               // Raw float (positive = income, negative = expense by convention in UI)
  transaction_type: 'income' | 'fixed_expense' | 'variable_expense' | 'transfer_out' | 'transfer_in';
  source: 'manual' | 'statement_file';
  date: string;                 // ISO 8601
  merchant?: string | null;
  category?: {
    id: number;
    name: string;
    icon: string;               // Lucide icon name
  } | null;
  bank_account: {
    name: string;
    account_type: 'debit' | 'credit' | 'cash';
  };
  is_transfer: boolean;
  onPress: () => void;          // Navigate to detail
  showAccountName?: boolean;    // Default: false. Show on dashboard, hide on account detail
  enableSwipeActions?: boolean; // Default: true. Disable in dashboard recent list
}
```

## Visual Anatomy

```
┌─────────────────────────────────────────────────┐
│  [●]   Merchant/Description         +$1,200.00  │  72pt height (min)
│  [icon] Date • Account name         Transaction  │
└─────────────────────────────────────────────────┘
```

**Left**: Category icon circle (40×40pt)
- Background: category-specific color (or slate-100 if no category)
- Icon: Lucide icon in white, 20pt
- If no category: question-mark icon, slate-400 on slate-100

**Center** (flex: 1, truncate overflow):
- Line 1: `merchant || description` (body-md, slate-900, truncated to 1 line)
- Line 2: Formatted date (caption, slate-500) + `•` separator + account name (if `showAccountName`)

**Right** (fixed width, right-aligned):
- Line 1: Formatted amount (heading-md, tabular-nums)
  - Income / transfer_in: emerald-500, with `+` prefix
  - Expense / transfer_out: rose-500, no prefix (negative implied)
  - Transfer: violet-500
- Line 2: Transaction type badge (caption, colored pill) — optional, only when useful context

**Full row**: `onPress` navigates to transaction detail

## Category Color Map
```typescript
const categoryColors: Record<string, string> = {
  food: '#f97316',         // orange-500
  transport: '#3b82f6',    // blue-500
  shopping: '#ec4899',     // pink-500
  entertainment: '#8b5cf6', // violet-500
  health: '#10b981',       // emerald-500
  education: '#06b6d4',    // cyan-500
  home: '#84cc16',         // lime-500
  finance: '#4f46e5',      // indigo-600
  income: '#10b981',       // emerald-500
  transfer: '#8b5cf6',     // violet-500
  default: '#94a3b8',      // slate-400
};
```
Map the category icon name to a color. Fall back to `default` if icon not in map.

## Variants

### Default (Transactions List)
- 72pt height
- Swipe actions enabled
- Account name shown in subtitle

### Dashboard (Recent Transactions)
- Same visual but NO swipe actions
- Account name shown
- Tapping navigates to Transactions tab → Transaction Detail

### Account Detail (within account context)
- Hide account name in subtitle (redundant)
- Swipe actions enabled

## Swipe Actions

**Left swipe (destructive) — only for `source === 'manual'`**:
```
[  🗑  Delete  ]
red background, white icon + text
```
- Width: 80pt
- Reveal threshold: 80pt
- Full reveal triggers delete (with haptic: heavy)
- Confirmation: ActionSheet "Delete this transaction?" → Confirm/Cancel

**Right swipe (non-destructive)**:
```
[ 🏷  Categorize ]
indigo background, white icon + text
```
- Width: 80pt
- Opens category picker bottom sheet on full reveal

## Behavior

- Long press → context menu: Edit / Delete (manual only) / Copy amount / Share
- Loading/deleting state: Row fades to 50% opacity + ActivityIndicator
- Deleted: Row collapses with height animation (72 → 0, 250ms spring)

## Accessibility
- `accessibilityRole="button"`
- `accessibilityLabel`: "[merchant], [amount], [transaction type], [date]"
  - Example: "Netflix, minus two hundred fifty pesos, expense, April 15th"
- Amount `accessibilityLabel` spells out sign: "plus" / "minus" prefix
- Swipe actions have `accessibilityLabel` on the action buttons
