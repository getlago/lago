# Lago Frontend

## Package Manager & Workspace

- The project uses pnpm workspaces with packages in `packages/*`:
  - `packages/configs/` — shared ESLint, TypeScript, Tailwind configs
  - `packages/design-system/` — shared UI components and icons
- After changes to workspace packages, run `pnpm install` to trigger postinstall scripts

## Project Stack

- **Frontend**: React 18 + TypeScript + Vite
- **UI**: Material UI + TailwindCSS + Custom Design System (MUI-based)
- **State**: Apollo Client (GraphQL) with reactive variables
- **Forms**: Tanstack form + zod validation
- **Routing**: React Router DOM + TanStack Router (newer routes)
- **Testing**: Jest + Cypress + Testing Library
- **Code Generation**: GraphQL Code Generator for type-safe queries
- **Linting**: ESLint + Prettier with custom configs from `lago-configs`
- Avoid suggesting build scripts — the project runs in development mode

## Key Commands

- `pnpm dev` — start development server
- `pnpm code:style` — command executed by the pre-push hook, better to run it after all modifications are done
- `pnpm test` — run Jest tests
- `pnpm test:coverage` — Jest tests with coverage
- `pnpm test:e2e` — run Cypress tests
- `pnpm lint:fix` — fix code style issues
- `pnpm codegen` — generate GraphQL types (**run after any GraphQL changes**)
- `pnpm translations:add <count>` — add new translation keys

## Development Guidelines

- TypeScript strict mode with path aliases (`~/*` maps to `src/*`)
- Use existing design system components from `packages/design-system/`
- Use hooks and utilities in `src/hooks/`
- GraphQL queries/mutations for API calls (generated types in `src/generated/`)
- **After any GraphQL schema/query/fragment changes, run `pnpm codegen`**
- Store translations in `translations/base.json` — **never manually create translation keys**, use `pnpm translations:add <number>`
- Apollo Client reactive variables for global state (`src/core/apolloClient/reactiveVars/`)
- Follow serialization patterns in `src/core/serializers/`

## Code Quality

- TypeScript strict mode with proper typing
- ESLint rules from `lago-configs` package
- Consistent naming: camelCase for variables, PascalCase for components
- Use existing design system components before creating new ones
- In tests, import and reuse the real exported types/interfaces (e.g. `MainHeaderTab`) instead of redeclaring a partial copy of a production type just for assertions — a local stub drifts from the source and hides type errors
- Always use direct MUI imports, never barrel imports:
  ```typescript
  // Correct
  import Button from '@mui/material/Button'
  // Wrong — triggers full MUI bundle parsing
  import { Button } from '@mui/material'
  ```
- Never import `useNavigate`, `Link`, `useLocation`, or `useMatch` from `react-router-dom`.
  Import them from `~/core/router` — the slug-aware wrappers auto-prepend
  `/${organizationSlug}` to navigation targets and expose `strippedPathname`
  on the location object. Instead of `useMatch`, use `matchPath` (from
  `react-router-dom`) with `strippedPathname` from the slug-aware
  `useLocation` — this is the established pattern throughout the codebase.
  Enforced by the custom `lago/no-direct-rrd-nav-import` ESLint rule.
  Other `react-router-dom` exports (`useParams`, `matchPath`, `generatePath`,
  `Outlet`, etc.) are unrestricted.
  ```typescript
  // Correct — slug-aware wrappers
  import { useNavigate, Link, useLocation } from '~/core/router'
  // Correct — route matching with strippedPathname
  import { matchPath } from 'react-router-dom'
  const { strippedPathname } = useLocation()
  const match = matchPath(SOME_ROUTE, strippedPathname)
  // Wrong — useMatch uses raw pathname (includes slug), never matches
  import { useMatch } from 'react-router-dom'
  ```

## Organization slug architecture

All authenticated app routes are nested under `/:organizationSlug/...`. The
URL slug is the **source of truth for the current organization in this tab**.
Multiple tabs can run on different orgs simultaneously; the legacy
`localStorage`-based current-org state is now a transitional bridge and must
not drive UI decisions.

### Mental model

Two complementary primitives:

1. **URL slug** (`useParams().organizationSlug`) — the **per-tab source of
   truth** for "which org is the user viewing here". Set by the user (typing,
   clicking the org switcher, following a link). Independent across tabs.
2. **`currentOrganizationVar`** (Apollo `makeVar<string | null>`) — a
   **per-tab in-memory centralized cache** of the org id, derived from the
   URL slug + `currentUser.memberships`. Populated by `OrganizationLayout`'s
   `useEffect` on every authenticated render. Read synchronously by the
   Apollo auth link to inject the `x-lago-organization` HTTP header.

The var is a **denormalized read of the URL** — not a competing source of
truth. Feature components that need the slug or org reference for UI or
identifier construction must derive directly from `useParams()` +
memberships; reading the var is reserved for a small, audited set of
infrastructure call sites (the Apollo auth link, `OrganizationLayout`'s
switch detection, the post-login org-recovery in `cacheUtils.onLogIn`, and
the slug-first-with-var-fallback membership resolution in `useCurrentUser`).
See **Consistency rule** below for the canonical list and the rationale per
caller.

### Consistency rule — which API to use, by caller

| Caller                                                                                                            | Source to read                          | API                                                                                                                                                        |
| ----------------------------------------------------------------------------------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| React component **inside** `/:organizationSlug/...` routes                                                        | URL + memberships                       | `useParams().organizationSlug` then `currentUser.memberships.find(m => m.organization.slug === slug)` (or `useCurrentUser().currentMembership` shortcut)   |
| React component **outside** Routes (`AiAgent`, `UserIdentifier`, anything sibling to `RouteWrapper` in `App.tsx`) | URL + memberships                       | `window.location.pathname.split('/')[1]` then `currentUser.memberships.find(...)` — `useParams` returns `{}` here because there's no matched-route context |
| Non-React code that needs synchronous access (Apollo auth link only)                                              | Var                                     | `getCurrentOrganizationId()`                                                                                                                               |
| `OrganizationLayout` itself, for org-switch detection                                                             | Var (compared against derived `org.id`) | `useReactiveVar(currentOrganizationVar)` — this is the single sync point that bridges URL → var                                                            |

**Do not** read `currentOrganizationVar` from feature components for UI or identifier construction. That is a known bug pattern (logo flashing wrong org cross-tab, webhook URLs baking the wrong UUID, slug page showing the other tab's value, etc.). The fix in every case is migrating off the var and onto `useParams` + memberships.

Legitimate var reads in the codebase (audit anchor, keep this short). Two permitted purposes only: (a) constructing the `x-lago-organization` auth header, (b) gating org-scoped queries so they don't fire header-less, (c) bridging URL → var inside `OrganizationLayout`. UI/identifier construction is never permitted.

- `src/core/apolloClient/authHeaders.ts` and `src/core/apolloClient/init.ts` — auth-header construction (the canonical reason the var exists).
- `src/layouts/OrganizationLayout.tsx` — switch detection on the `currentOrgId !== org.id` mismatch (the single sync point that writes the var from the URL slug).
- `src/components/UserIdentifier.tsx` — query-gates the `UserIdentifier` query (org-scoped `organization` field) on `!!currentOrganizationId` so it doesn't fire on slug-less surfaces (e.g. `/`).
- `src/hooks/useOrganizationInfos.ts` — query-gates `getOrganizationInfos` (org-scoped) on `!!currentOrganizationId` for the same reason.
- `src/hooks/useCurrentUser.ts` — slug-first resolution of `currentMembership` with var as a fallback for routes outside `/:organizationSlug` (login, customer portal). The fallback exists so callers in those non-org routes still get a membership; if a future audit shows nobody consumes `currentMembership` from those contexts, the fallback can be dropped.

Anything else reading the var in a feature component is a regression — fix it.

### Source-of-truth hierarchy

| Concern                                   | Source                                        | Notes                                                                                                                                               |
| ----------------------------------------- | --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Which org is the user viewing in this tab | URL slug (`useParams().organizationSlug`)     | Resolves to a `Membership` via `currentUser.memberships`                                                                                            |
| Auth                                      | `LAGO_USER_AUTH_TOKEN_KEY` in LS              | Unchanged                                                                                                                                           |
| Apollo `x-lago-organization` header       | `currentOrganizationVar` (in-memory, per-tab) | Centralized synchronous cache of the slug-derived org id. `OrganizationLayout` keeps it in sync with the URL slug. Never read directly to drive UI. |
| Browser-survival of OAuth round-trip      | `REDIRECT_AFTER_LOGIN_LS_KEY`                 | Read & cleared exclusively by `Home.tsx`                                                                                                            |

### `useCurrentUser` vs `useOrganizationInfos`

- **`useCurrentUser().currentMembership.organization`** — slug-driven. Use whenever the value lands in a **persistent identifier**: a URL the user copies (e.g. provider webhook), an LS key, a mutation argument, a filename. The hook resolves the membership by matching `useParams().organizationSlug` against the user's memberships.
- **`useOrganizationInfos().organization`** — query-driven. Use for **org-scoped behavior** that is not in the lighter membership fragment: `timezone`, `defaultCurrency`, `featureFlags`, `premiumIntegrations`, `authenticatedMethod`. The hook self-gates: when the cached `Query.organization.slug` doesn't match the URL slug it returns `loading: true, organization: undefined` (skeleton), so consumers can't render another tab's data.

  ```typescript
  // Persistent identifier (URL, LS key, mutation arg) → currentMembership
  const { currentMembership } = useCurrentUser()
  const orgId = currentMembership?.organization.id || ''
  const webhookUrl = `${apiUrl}/webhooks/foo/${orgId}`

  // Behavior config (timezone, feature flags, premium addons) → useOrganizationInfos
  const { hasFeatureFlag, timezone } = useOrganizationInfos()
  ```

### Why the distinction exists

Apollo cache is persisted to IndexedDB and shared cross-tab. Root-field
queries (`Query.organization`) are not partitioned by org-id header in their
cache key, so `cache-first` reads can briefly return another tab's org
payload on initial paint. Membership data is user-scoped and consistent
across tabs, so a slug→membership lookup always resolves to the right org
for the current tab regardless of cache state.

### Navigating to a different org

Use `navigate(`/${targetSlug}/...`, { skipSlugPrepend: true })` plus
`switchCurrentOrganization(client, targetOrgId)` (or rely on
`OrganizationLayout`'s effect to detect the slug change and resync the var
and Apollo cache automatically).

## Cypress e2e tests

- Authenticated navigation goes through `cy.visitApp(path)`, not `cy.visit(path)`.
  `cy.visitApp` prepends `/${orgSlug}` captured by `cy.login()` / `cy.signup()`
  so spec files write paths as they would look without the slug (e.g.
  `cy.visitApp('/customers')` lands on `/${slug}/customers`).
  ```typescript
  // Correct — authenticated
  cy.login().visitApp('/customers')
  cy.visitApp('/settings/taxes')
  // Correct — public paths pass through unchanged
  cy.visit('/login')
  cy.visit('/sign-up')
  ```
- For strict URL assertions use the slug-tolerant regex pattern instead of
  `be.equal(baseUrl + '/path')`:
  ```typescript
  // Correct
  cy.url().should('match', /\/[^/]+\/create\/plans$/)
  // Wrong — `baseUrl + '/create/plans'` is never the full URL anymore
  cy.url().should('be.equal', Cypress.config().baseUrl + '/create/plans')
  ```
- `cy.url().should('include', '/path')` continues to work — `/acme/customers`
  still includes `/customers` — so existing `include` assertions need no changes.
- Keep `cy.visit()` with slug-less paths only when the test is intentionally
  probing legacy-URL behavior (e.g. testing the auth-guard redirect from a
  slug-less path to `/login`). Always add an inline comment explaining why.

## Detailed Guidelines (read on demand)

When working on these areas, read the relevant file first:

- **TypeScript conventions**: `@.agents/docs/typescript-conventions.md`
- **Folder architecture**: `@.agents/docs/folder-architecture.md`
- **Library documentation**: `@.agents/docs/documentation.md`
- **GraphQL fragments & type safety**: `@.agents/docs/graphql-fragments.md`
- **Testing best practices**: `@.agents/docs/testing-practices.md`
