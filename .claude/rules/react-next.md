---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/next.config.*"
  - "**/proxy.ts"
  - "**/middleware.ts"
  - "**/app/**/page.*"
  - "**/app/**/layout.*"
  - "**/app/**/route.*"
---

# React and Next.js

Check the versions in `package.json`. The notes below are for React 19 and Next.js 16 with the App Router; follow the repo when it is older.

## React
- Function components and hooks only. Keep components small and pure; derive values during render instead of storing them in state.
- Effects are for synchronizing with things outside React. Do not use `useEffect` to compute state from props.
- When the React Compiler is enabled, do not add `useMemo` and `useCallback` by hand unless measurement says so.
- Lists have stable keys from the data, never array indexes for lists that change.
- Accessibility: semantic elements, labels, keyboard support. Never `dangerouslySetInnerHTML` with user data.

## Next.js (App Router)
- Server Components by default. Add `'use client'` only for state, effects, event handlers or browser APIs, as low in the tree as possible.
- `params`, `searchParams`, `cookies()` and `headers()` are async: `await` them.
- Server Actions and route handlers are public endpoints: validate input, check authentication and authorization in every one.
- Caching in Next.js 16 is opt in with Cache Components (`cacheComponents: true` and the `"use cache"` directive). `revalidateTag(tag, profile)` takes a cacheLife profile; `updateTag` gives read your writes in Server Actions.
- Request interception lives in `proxy.ts` (formerly `middleware.ts`, now deprecated).
- Secrets only in server code and server environment variables; anything prefixed `NEXT_PUBLIC_` is visible to everyone.
- Use `next/image` with `images.remotePatterns`, and `next/font`.
- Turbopack is the default bundler; `next lint` is gone, so run ESLint directly.
