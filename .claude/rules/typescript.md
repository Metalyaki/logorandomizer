---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/tsconfig*.json"
---

# TypeScript

- `strict` mode stays on. No `any`; use `unknown` and narrow it. No non null assertions (`!`) without a comment that explains why it is safe.
- Model states with discriminated unions and handle every case; end a `switch` over a union with an exhaustive `never` check.
- Prefer union string literals or `as const` objects over `enum`.
- Use `satisfies` to check object literals against a type without widening them. `readonly` for data that must not change.
- Validate data that crosses a boundary (HTTP responses, `localStorage`, query strings, environment variables) with the schema library the repo uses (Zod, Valibot or similar) instead of trusting a type assertion.
- `async` functions: always `await` or return promises; handle rejections. No floating promises.
- Imports: ES modules, no default exports in shared code unless the framework needs them (Next.js pages and layouts do).
- Keep types close to their use; shared API types live in one place and match the backend contract.
