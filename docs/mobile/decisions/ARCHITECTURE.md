# Mobile Architecture Decisions

> Owned by `/mobile-arch`. Completed: 2026-04-16 (Phase 1)

---

## Framework Decision: React Native with Expo SDK 52

### Verdict: React Native + Expo

**Rationale**:

| Criteria | Hotwire Native | React Native/Expo | Flutter | KMP |
|----------|---------------|-------------------|---------|-----|
| Solo Rails dev ramp-up | ✅ Fastest | ✅ Good (JS/TS familiar) | ⚠️ Dart curve | ❌ Kotlin foreign |
| Fintech UX quality | ❌ Webview limited | ✅ Native quality | ✅ Best animations | N/A |
| Charting | ❌ Chart.js in webview | ✅ Skia-based, 60fps | ✅ Excellent | N/A |
| Haptics | ⚠️ Limited | ✅ Full native | ✅ Full native | N/A |
| Offline support | ❌ Poor | ✅ TanStack Query | ✅ Good | N/A |
| Ecosystem / tooling | ⚠️ Small | ✅ Largest | ✅ Growing | ⚠️ Complex |
| Build simplicity | ✅ Easy | ✅ Expo EAS | ⚠️ Complex | ❌ Very complex |
| OTA updates | ❌ No | ✅ Expo Updates | ❌ No | ❌ No |
| API compatibility | ✅ Same auth | ✅ Perfect fit | ✅ Perfect fit | ✅ Perfect fit |

**Why not Hotwire Native**: The existing web app already has a mobile-optimized Hotwire frontend (bottom nav, stimulus controllers, responsive layouts). Wrapping it in a native shell gives webview charts, limited haptics, and no real offline support. For a daily-use fintech app, users expect native-quality feel. The API already exists — there's no reason to reuse web views when a proper mobile client can be built against it.

**Why React Native over Flutter**: JavaScript/TypeScript is adjacent to a Rails developer's web skills. The `API_DEVELOPMENT.md` already mentions "React Native" explicitly in the i18n example code (`const errorMessages = { en: {...}, es: {...} }`). Expo's managed workflow eliminates most native build complexity. The CORS note from the BE audit (Expo Go web preview sends `Origin` headers) confirms Expo is the intended target.

---

## Project Structure

### Location
```
/Users/nived/vittio/
  bank_statements_app/     # Rails app (existing)
  vittio-mobile/           # React Native app (new)
    docs/                  # Symlink or reference to shared docs
```

### Full Project Layout
```
vittio-mobile/
  app/                          # Expo Router (file-based routing)
    _layout.tsx                 # Root layout — auth guard, providers
    (auth)/                     # Auth group (no tab bar)
      _layout.tsx
      login.tsx
      signup.tsx
      forgot-password.tsx
      confirm-email.tsx
    (app)/                      # Protected group (requires auth)
      _layout.tsx               # Tab bar layout
      index.tsx                 # Dashboard (home tab)
      transactions/
        index.tsx               # Transactions list
        new.tsx                 # Create transaction
        [id].tsx                # Transaction detail / edit
      accounts/
        index.tsx               # Bank accounts list
        new.tsx                 # Add bank account
        [id].tsx                # Account detail
      settings/
        index.tsx               # Settings / Profile
  src/
    api/                        # API layer
      client.ts                 # Axios instance + interceptors
      auth.ts                   # Auth endpoints
      dashboard.ts              # Dashboard endpoints
      transactions.ts           # Transaction endpoints
      bank-accounts.ts          # Bank account endpoints
      categories.ts             # Category endpoints
      user.ts                   # User endpoints
      banks.ts                  # Banks list endpoint
    hooks/                      # TanStack Query hooks
      useAuth.ts
      useDashboard.ts
      useTransactions.ts
      useBankAccounts.ts
      useCategories.ts
    store/                      # Zustand stores
      authStore.ts              # Auth state (tokens, user, isLoggedIn)
      uiStore.ts                # UI state (locale, theme)
    components/
      ui/                       # Base components (Button, Input, Card, etc.)
      charts/                   # Chart components (SpendingChart, CategoryChart)
      transactions/             # Transaction-specific components
      dashboard/                # Dashboard-specific components
    i18n/
      en.ts                     # English strings
      es.ts                     # Spanish strings
      index.ts                  # i18next setup
    utils/
      currency.ts               # Currency formatting
      date.ts                   # Date formatting
      errors.ts                 # Error code → localized message map
    constants/
      colors.ts                 # Design tokens
      typography.ts
  assets/
    fonts/
    images/
  app.json                      # Expo config
  eas.json                      # EAS Build config
  tsconfig.json
  package.json
```

---

## Technology Stack

| Concern | Library | Version | Rationale |
|---------|---------|---------|-----------|
| Framework | React Native + Expo | SDK 52 | Managed workflow, OTA updates |
| Language | TypeScript | 5.x (strict) | Type safety, IDE support |
| Navigation | Expo Router | v4 | File-based routing, deep linking |
| Server state | TanStack Query | v5 | Caching, pagination, background refresh |
| Client state | Zustand | v5 | Auth state, UI state (no Redux boilerplate) |
| HTTP client | Axios | v1 | Interceptors for token refresh |
| Token storage | expo-secure-store | latest | Keychain (iOS) / Keystore (Android) |
| Charts | victory-native | v40+ | Skia-based, 60fps on New Architecture |
| i18n | i18next + react-i18next | v23/v15 | Industry standard, matches API error code pattern |
| Forms | react-hook-form + zod | latest | Validation schema, minimal re-renders |
| Icons | @expo/vector-icons (Lucide) | latest | Matches web app Lucide icons |
| Date handling | date-fns | v3 | Lightweight, tree-shakeable |
| Currency | Intl.NumberFormat | native | Browser/RN built-in, no extra dependency |

---

## Authentication Architecture

### Token Storage
```typescript
// src/utils/tokenStorage.ts
import * as SecureStore from 'expo-secure-store';

const KEYS = {
  ACCESS_TOKEN: 'vittio_access_token',
  REFRESH_TOKEN: 'vittio_refresh_token',
  USER: 'vittio_user',
} as const;

export const tokenStorage = {
  getAccessToken: () => SecureStore.getItemAsync(KEYS.ACCESS_TOKEN),
  getRefreshToken: () => SecureStore.getItemAsync(KEYS.REFRESH_TOKEN),
  setTokens: async (access: string, refresh: string) => {
    await SecureStore.setItemAsync(KEYS.ACCESS_TOKEN, access);
    await SecureStore.setItemAsync(KEYS.REFRESH_TOKEN, refresh);
  },
  clearAll: async () => {
    await SecureStore.deleteItemAsync(KEYS.ACCESS_TOKEN);
    await SecureStore.deleteItemAsync(KEYS.REFRESH_TOKEN);
    await SecureStore.deleteItemAsync(KEYS.USER);
  },
};
```

### Auth Interceptor (Axios)
```typescript
// src/api/client.ts
import axios from 'axios';
import { tokenStorage } from '../utils/tokenStorage';
import { useAuthStore } from '../store/authStore';

let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string) => void;
  reject: (error: Error) => void;
}> = [];

const processQueue = (error: Error | null, token: string | null) => {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) reject(error);
    else resolve(token!);
  });
  failedQueue = [];
};

export const apiClient = axios.create({
  baseURL: process.env.EXPO_PUBLIC_API_URL, // 'http://localhost:3000/api/v1'
  headers: { 'Content-Type': 'application/json' },
});

// Attach access token to every request
apiClient.interceptors.request.use(async (config) => {
  const token = await tokenStorage.getAccessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Handle 401 — refresh token then retry
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // Queue this request until refresh completes
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`;
          return apiClient(originalRequest);
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshToken = await tokenStorage.getRefreshToken();
        const response = await axios.post(
          `${process.env.EXPO_PUBLIC_API_URL}/refresh`,
          { refresh_token: refreshToken }
        );
        const { access_token, refresh_token } = response.data.data;
        await tokenStorage.setTokens(access_token, refresh_token);
        processQueue(null, access_token);
        originalRequest.headers.Authorization = `Bearer ${access_token}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError as Error, null);
        // Refresh failed — log out
        await tokenStorage.clearAll();
        useAuthStore.getState().logout();
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);
```

### Auth Store (Zustand)
```typescript
// src/store/authStore.ts
import { create } from 'zustand';

interface User {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  confirmed: boolean;
  avatar_url: string | null;
  subscription_status: string;
  trial_ends_at: string | null;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  setUser: (user: User) => void;
  logout: () => void;
  setLoading: (loading: boolean) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isAuthenticated: false,
  isLoading: true,
  setUser: (user) => set({ user, isAuthenticated: true, isLoading: false }),
  logout: () => set({ user: null, isAuthenticated: false, isLoading: false }),
  setLoading: (isLoading) => set({ isLoading }),
}));
```

---

## Navigation Structure

```
Root Layout (_layout.tsx)
├── Auth Guard (redirect to login if no token)
│
├── (auth)/ — Stack navigator
│   ├── login
│   ├── signup
│   ├── forgot-password
│   └── confirm-email
│
└── (app)/ — Tab navigator
    ├── Tab 1: Home (Dashboard)    — icon: home
    ├── Tab 2: Transactions         — icon: list
    ├── Tab 3: [FAB placeholder]    — center fab for quick add
    ├── Tab 4: Accounts             — icon: bank
    └── Tab 5: Settings             — icon: user
```

The center FAB (floating action button) mirrors the web app's mobile bottom nav pattern and opens a quick-add transaction modal.

---

## State Management Strategy

### Server State (TanStack Query)
All API data goes through TanStack Query. Key cache keys:

```typescript
export const queryKeys = {
  dashboard: (month: string) => ['dashboard', month] as const,
  transactions: {
    list: (filters: TransactionFilters) => ['transactions', 'list', filters] as const,
    detail: (id: number) => ['transactions', 'detail', id] as const,
    summary: (filters: TransactionFilters) => ['transactions', 'summary', filters] as const,
  },
  bankAccounts: {
    list: () => ['bank-accounts'] as const,
    detail: (id: number) => ['bank-accounts', 'detail', id] as const,
  },
  categories: () => ['categories'] as const,
  user: () => ['user'] as const,
  banks: () => ['banks'] as const,
} as const;
```

Config:
- `staleTime`: 5 minutes for most data, 30 seconds for dashboard
- `gcTime`: 10 minutes
- `retry`: 2 retries on failure
- `refetchOnWindowFocus`: true
- `networkMode`: 'offlineFirst' (serve stale cache when offline)

### Client State (Zustand)
Only three stores:
- `authStore` — user, tokens, isAuthenticated
- `uiStore` — locale (en/es), selected month on dashboard
- `toastStore` — temporary toast notifications

---

## i18n Architecture

```typescript
// src/i18n/en.ts
export const en = {
  errors: {
    INVALID_CREDENTIALS: 'Invalid email or password',
    EMAIL_NOT_CONFIRMED: 'Please confirm your email address',
    TOKEN_EXPIRED: 'Your session has expired. Please log in again.',
    VALIDATION_ERROR: 'Please check the form for errors',
    SUBSCRIPTION_REQUIRED: 'A subscription is required for this feature',
    RATE_LIMIT_EXCEEDED: 'Too many requests. Please wait a moment.',
    DASHBOARD_LOAD_FAILED: 'Failed to load dashboard data',
    TRANSACTIONS_LOAD_FAILED: 'Failed to load transactions',
    // ... all SCREAMING_SNAKE_CASE codes from API
  },
  auth: {
    login: { title: 'Welcome back', emailLabel: 'Email', ... },
    signup: { title: 'Create account', ... },
  },
  dashboard: { title: 'Dashboard', totalBalance: 'Total Balance', ... },
  transactions: { title: 'Transactions', empty: 'No transactions yet', ... },
  // ...
};

// src/utils/errors.ts
export const getErrorMessage = (code: string, fallback: string, locale: string): string => {
  const messages = locale === 'es' ? es.errors : en.errors;
  return messages[code as keyof typeof messages] || fallback;
};
```

---

## Offline Strategy (MVP)

**Goal**: Graceful degradation — show cached data, clearly indicate offline state.

1. TanStack Query serves stale cache while offline (`networkMode: 'offlineFirst'`)
2. `useNetInfo()` from `@react-native-community/netinfo` detects offline state
3. Show a subtle offline banner when no network
4. Mutation operations (create/update/delete) show an error toast when offline
5. No optimistic updates in MVP — too complex for initial release
6. **Phase 6+**: Consider React Query's `persistQueryClient` for full offline support

---

## Build & Deploy

### Development
```bash
# Start Expo dev server
npx expo start

# iOS simulator
npx expo start --ios

# Android emulator
npx expo start --android

# API: http://localhost:3000/api/v1 (dev)
# API: https://vitt.io/api/v1 (prod)
```

### Environment Configuration
```bash
# vittio-mobile/.env.local
EXPO_PUBLIC_API_URL=http://localhost:3000/api/v1

# vittio-mobile/.env.production
EXPO_PUBLIC_API_URL=https://vitt.io/api/v1
```

### EAS Build Config (eas.json)
```json
{
  "cli": { "version": ">= 10.0.0" },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal",
      "ios": { "simulator": true }
    },
    "production": {
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {
      "ios": { "appleId": "...", "ascAppId": "..." },
      "android": { "serviceAccountKeyPath": "..." }
    }
  }
}
```

### Release Process
1. `eas build --platform all --profile production` — build both platforms
2. `eas submit --platform all` — submit to App Store + Google Play
3. **OTA updates** via `expo-updates` for JS-only changes (no store review)

---

## Answer to `/be-dev` Bank Picker Question

**Decision**: Yes, create `GET /api/v1/banks` in Phase 2.

The `Bank` model has: `id`, `code`, `name`, `logo_url`, `active`, `supported_type`. Mobile bank account creation should present a searchable, logo-enhanced bank picker. A free-text field would be user-hostile and bypass the bank validation logic.

**Implementation for be-dev**:
- No auth required (public endpoint — banks don't contain user data)
- Response: `{ data: { banks: [{ id, code, name, logo_url, supported_type }] } }`
- Filter: only `active: true` banks
- Optional `?account_type=debit|credit` filter to show compatible banks only

---

## Phase 3 Scaffold Checklist

When Phase 2 (API Hardening) is complete, Phase 3 will:
- [ ] `npx create-expo-app vittio-mobile --template tabs` or blank template
- [ ] Configure TypeScript strict mode
- [ ] Install all dependencies from stack table above
- [ ] Set up Expo Router with auth/app groups
- [ ] Set up Axios client with auth interceptor
- [ ] Set up TanStack Query provider
- [ ] Set up Zustand auth store
- [ ] Set up i18next with en + es
- [ ] Set up expo-secure-store token management
- [ ] Implement login, signup, forgot-password screens
- [ ] Implement token refresh flow (end-to-end test)
- [ ] Implement logout
- [ ] Verify auth works against `http://localhost:3000/api/v1`
