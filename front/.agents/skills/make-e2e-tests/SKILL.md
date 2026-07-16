---
name: make-e2e-tests
description: Create Cypress e2e tests for a specific feature. Accepts a feature name, PR number, or branch name. Navigates the codebase, adds data-test attributes if missing, writes happy-path tests following project conventions, and validates them with Cypress.
user-invocable: true
argument-hint: '<feature | PR_NUMBER | BRANCH_NAME>'
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion, Agent
---

# Make E2E Tests Skill

**Target:** `$ARGUMENTS`

> **Important:** If no argument was provided above (empty or missing), use the AskUserQuestion tool to ask the user what they want to create E2E tests for. They can provide:
>
> - A feature name (e.g., `customer creation form`, `coupon create and edit flow`)
> - A PR number (format: `#123` or `123`)
> - A branch name (local or remote, e.g., `feature/my-feature` or `origin/feature/my-feature`)

---

## Philosophy: Happy Path Only

**E2E tests cover ONLY the macro happy paths** — the core user journeys that prove the feature works end-to-end. Deep coverage (edge cases, error states, complex validations) belongs in unit and integration tests.

**What E2E tests should cover:**
- Create a resource via form -> verify success
- Edit a resource -> verify changes persisted
- Navigate through key UI flows (list -> detail -> action)
- Apply filters / interact with key UI controls

**What E2E tests should NOT cover:**
- Validation error states (test in unit tests)
- API error handling (test in integration tests)
- Complex cross-resource flows (too fragile)
- Edge cases and boundary conditions
- Delete flows (destructive, hard to make idempotent)

**Key principles:**
- Each test should be **short** (5-10 actions max)
- Prefer **few robust tests** over many fragile ones
- Tests should be **independent** where possible, but can share setup via `before()` hooks
- Never test implementation details — only visible user outcomes
- **Zero tests is a valid outcome.** If the change only affects internal logic, refactors code, fixes styling, or has no meaningful user-facing flow that warrants E2E coverage, report that no E2E tests are needed and explain why. Not every change deserves an E2E test.

---

## Phase 1: Input Detection & Feature Analysis

### Step 1.1: Detect Input Type

Determine what the user provided:

**If PR number** (numeric or starts with `#`):
```bash
PR_NUMBER="${INPUT#\#}"
gh pr view "$PR_NUMBER" --json files,additions,deletions,body,title
gh pr diff "$PR_NUMBER"
```

**If branch name:**
```bash
# Check local branch first
git branch --list "$INPUT"
# Then remote
git fetch origin && git branch -r --list "origin/$INPUT"
# Get diff against main
git diff main..."$INPUT" --name-only
git diff main..."$INPUT"
```

**If feature name** (not a PR or branch):
- Validate scope (see Step 1.2)
- Search the codebase to locate the feature's implementation

**Fallback:** If input doesn't match any of the above, use the current branch:
```bash
git diff main...HEAD --name-only
```

### Step 1.2: Validate Feature Scope

If the input is a feature name, evaluate whether it's specific enough.

**Too broad (ask the user to narrow down):**
- "wallet" — which page? which flow?
- "customers" — creation? editing? listing? details?
- "billing" — invoices? subscriptions? plans?
- "settings" — which settings section?

**Good scope (proceed):**
- "wallet details page"
- "customer creation form"
- "coupon create and edit flow"
- "plan creation with charges"

If too broad, use the AskUserQuestion tool to ask the user to narrow it down.

### Step 1.3: Understand the Feature

Whether from a PR diff or a feature name, determine:

1. **What feature is involved** — Read changed files, PR description, or search the codebase
2. **Which pages/routes are affected** — Check `src/core/router/` for route paths, `src/pages/` for page components
3. **What user flows exist** — Create, Read, Update operations
4. **What UI components are involved** — Forms, dialogs, tables, lists

Focus on **user-facing behavior**, not implementation details.

### Step 1.4: Read Component Source Code

For each page/component involved, read the source to extract:

1. **All `data-test` attributes** — These are your selectors
2. **All `input[name="..."]` fields** — These are your form field selectors
3. **Navigation paths** — Where `navigate()` or `<Link>` goes
4. **Existing TestIds files** — Check if the component has a `*TestIds.ts` or `*dataTestConstants.ts` file

```bash
# Find data-test attributes in components
grep -n 'data-test' src/pages/TargetPage.tsx
# Find existing TestIds files
find src -name "*TestIds*" -o -name "*testIds*" -o -name "*dataTestConstants*"
```

### Step 1.5: Check Existing E2E Tests

Look in `cypress/e2e/` for any tests already covering this feature. Understand what's covered and what's missing.

---

## Phase 2: Test Plan (MANDATORY STOP)

### Step 2.1: Identify Happy Path Flows

From the analysis, identify **only the core user journeys** worth E2E testing:

| Flow Type | Include in E2E? | Notes |
|---|---|---|
| **Create resource** | Yes | Fill form with valid data -> submit -> verify |
| **Edit resource** | Yes | Navigate to existing -> modify -> submit -> verify |
| **Key UI interactions** | Yes | Filters, tabs, navigation — but keep minimal |
| **Navigation** | Only if new routes | Verify route access, not deep navigation |
| **Delete flows** | No | Too destructive, test in integration tests |
| **Validation errors** | No | Test in unit tests |
| **Error states** | No | Test in integration tests |
| **Cross-page flows** | No | Too fragile for E2E |
| **Edge cases** | No | Test in unit/integration tests |

### Step 2.2: Determine File Location

| Feature Area | Folder | Example |
|---|---|---|
| Authentication | `cypress/e2e/00-auth/` | `t40-password-reset.cy.ts` |
| Core resources (CRUD) | `cypress/e2e/10-resources/` | `t80-webhook-create-edit.cy.ts` |
| Cross-resource flows | `cypress/e2e/` (root) | `t40-assign-plan-to-customer.cy.ts` |

Check existing files in the target folder to determine the next number. Use increments of 10 (`t10`, `t20`, `t30`, ...).

### Step 2.3: Present Test Plan & Ask for Confirmation

**You MUST present a test plan and wait for user confirmation before writing any code.**

Keep to **2-4 test cases max** — only the essential happy paths:

```
E2E Test Plan

Source: PR #<NUMBER> "<PR TITLE>"  (or Feature: <feature-name>, or Branch: <branch-name>)

Summary of Changes Analyzed:
  - <Brief description of what the feature implements>
  - <Key pages/components affected>

Target File: cypress/e2e/<folder>/t<NN>-<feature-name>.cy.ts

Prerequisites:
  - [List any resources that must exist, e.g., "logged-in user", "existing plan"]

Test Cases (happy paths only):
  1. should be able to create a <resource>
     Flow: login -> navigate -> fill form -> submit -> verify success
     Selectors needed: [list key data-test / input selectors]

  2. should be able to edit the <resource>
     Flow: login -> navigate to resource -> click edit -> modify -> submit -> verify
     Selectors needed: [list key data-test / input selectors]

Components Needing New data-test Attributes:
  - [List components that need new data-test attributes, or "None - all selectors already exist"]

Excluded from E2E (covered elsewhere):
  - [List what was intentionally left out, e.g., "validation errors (unit tests)", "delete flow (destructive)"]
```

Ask the user:

> "Here is the E2E test plan. Do you want me to proceed with implementation, or would you like to adjust anything?"

**Do NOT proceed to Phase 3 until the user explicitly confirms.**

---

## Phase 3: Implementation

### Step 3.1: Add Missing data-test Attributes

If components lack `data-test` attributes for key interactive elements, add them now.

**CRITICAL:** Data-test constants MUST live in a **standalone `.ts` file** (no React imports, no JSX, only plain string exports). Cypress cannot import React components — it can only import plain JS/TS modules.

**Where to put the constants file:**
```
src/components/<feature>/utils/dataTestConstants.ts   <- preferred location
src/pages/<feature>/featureTestIds.ts                 <- alternative
```

**Existing examples to follow:**
```typescript
// src/components/customers/utils/dataTestConstants.ts
export const CREATE_CUSTOMER_DATA_TEST = 'create-customer'
export const SUBMIT_CUSTOMER_DATA_TEST = 'submit-customer'
```

```typescript
// src/pages/auth/signUpTestIds.ts
export const SIGNUP_SUBMIT_BUTTON_TEST_ID = 'signup-submit-button'
```

**Naming conventions:**
- Constants: `SCREAMING_SNAKE_CASE` ending with `_DATA_TEST` or `_TEST_ID`
- Values: `kebab-case` matching the feature/element name
- Group constants by component with a `// ComponentName` comment

**Rules:**
1. **NEVER wrap elements in extra `<div>` just for data-test** — this breaks CSS/layout
2. Only add `data-test` to elements that already exist in the JSX
3. Never use translation keys as test IDs

**Import in component:**
```typescript
import { FEATURE_SUBMIT_DATA_TEST } from '~/components/feature/utils/dataTestConstants'

<Button data-test={FEATURE_SUBMIT_DATA_TEST} />
```

**Import in E2E test:**
```typescript
import { FEATURE_SUBMIT_DATA_TEST } from '~/components/feature/utils/dataTestConstants'

cy.get(`[data-test="${FEATURE_SUBMIT_DATA_TEST}"]`).click({ force: true })
```

### Step 3.2: Add Reusable Constants (if needed)

If the test needs shared constants, add them to `cypress/support/reusableConstants.ts`. Only add if the value is used across multiple test files.

### Step 3.3: Write the E2E Test File

#### File Structure Template

```typescript
// Imports
import { SOME_TEST_ID } from '~/components/path/to/testIds'
import { customerName } from '../../support/reusableConstants'

// Test-scoped unique data (outside describe, shared across tests in file)
const randomId = Math.round(Math.random() * 10000)
const resourceName = `Resource ${randomId}`
const resourceCode = `resource_${randomId}`

describe('Feature Name', () => {
  beforeEach(() => {
    cy.login()
  })

  it('should be able to create a <resource>', () => {
    cy.visit('/resource/create')

    // Fill only required fields
    cy.get('input[name="name"]').type(resourceName)
    cy.get('input[name="code"]').should('have.value', resourceCode)

    // Submit and verify
    cy.get('[data-test="submit"]').click({ force: true })
    cy.url().should('not.include', '/create')
    cy.contains(resourceName).should('exist')
  })

  it('should be able to edit the <resource>', () => {
    cy.visit('/resources')
    cy.get(`[data-test="${resourceName}"]`).click({ force: true })

    // Open edit
    cy.get('[data-test="resource-actions"]').click({ force: true })
    cy.get('[data-test="resource-edit"]').click({ force: true })

    // Modify a field
    cy.get('input[name="name"]').clear().type('Updated Name')

    // Submit and verify
    cy.get('[data-test="submit"]').click({ force: true })
    cy.contains('Updated Name').should('exist')
  })
})
```

**Important:** Keep each test to **5-10 Cypress actions max**. If a test is getting long, it's testing too much.

### Step 3.4: Selector Priority

1. **data-test attributes (preferred):**
   ```typescript
   cy.get('[data-test="create-button"]').click({ force: true })
   cy.get(`[data-test="${IMPORTED_TEST_ID}"]`).click({ force: true })
   ```

2. **Input name attributes (for form fields):**
   ```typescript
   cy.get('input[name="email"]').type('test@example.com')
   cy.get('textarea[name="description"]').type('Some text')
   ```

3. **Role attributes (for semantic elements):**
   ```typescript
   cy.get('[role="dialog"]').should('exist')
   cy.get('button[role="tab"]').contains('Settings').click()
   ```

4. **Scoped queries with `.within()`:**
   ```typescript
   cy.get('[data-test="charge-accordion-2"]').within(() => {
     cy.get('input[name="chargeModel"]').should('have.value', 'Value')
   })
   ```

### Step 3.5: Common Patterns

**Combobox/dropdown selection:**
```typescript
cy.get('input[name="fieldName"]').click()
cy.get('[data-option-index="0"]').click()
```

**Dialog interactions:**
```typescript
cy.get('[role="dialog"]').should('exist')
cy.get('[data-test="submit-dialog"]').click({ force: true })
cy.get('[role="dialog"]').should('not.exist')
```

**URL assertions:**
```typescript
cy.url().should('include', '/customers')
cy.url().should('be.equal', Cypress.config().baseUrl + '/')
```

**Scroll into view:**
```typescript
cy.get('input[name="field"]').scrollIntoView({ offset: { top: -100, left: 0 }, duration: 0 })
```

### Step 3.6: Timing and Waits

- **Never use `cy.wait(ms)`** — rely on Cypress implicit waits
- Use timeout for slow elements: `cy.get('[data-test="el"]', { timeout: 10000 }).should('be.visible')`
- Use assertions as implicit waits: `cy.url().should('include', '/path')`

### Step 3.7: Custom Commands Available

- `cy.login(email?, password?)` — logs in (defaults to test user from reusableConstants)
- `cy.logout()` — logs out current user
- `cy.signup({ organizationName, email, password })` — signs up a new user

### Step 3.8: Convention Checklist

Before finalizing, verify:

**Selectors:**
- [ ] `[data-test="..."]` for buttons, containers, actions
- [ ] `input[name="..."]` for input fields, `textarea[name="..."]` for textareas
- [ ] `input[name="..."]` to open dropdowns, `[data-option-index="N"]` to select
- [ ] `[role="dialog"]` for dialog existence checks
- [ ] Never use translation keys as selectors

**Interactions:**
- [ ] `.click({ force: true })` for buttons that may be overlapped
- [ ] `.type()` for text input (already has `delay: 0` from global override)
- [ ] `.clear().type()` when replacing existing values
- [ ] `.within(() => { })` for scoped interactions inside containers

**Assertions:**
- [ ] `cy.url().should('include', '/path')` for URL checks
- [ ] `.should('exist')` / `.should('not.exist')` for element presence
- [ ] `.should('have.value', 'expected')` for input values
- [ ] `.should('contain.text', 'text')` for text within elements

**Data:**
- [ ] Unique IDs via `Math.round(Math.random() * 10000)`
- [ ] Name pattern: `Resource ${randomId}`, code pattern: `resource_${randomId}`

**Structure:**
- [ ] `describe('Feature Name', () => { ... })` as top-level
- [ ] `beforeEach` with `cy.login()` and optional `.visit()`
- [ ] Tests follow logical flow: create -> verify -> edit -> verify

---

## Phase 4: Validation

### Step 4.1: Run Cypress

```bash
cd cypress && npx cypress run --spec "e2e/path/to/test-file.cy.ts"
```

**Important:** The app must be running. If tests fail because the app is not running, inform the user and ask them to start the dev server (`pnpm dev`) before retrying.

### Step 4.2: Fix Failures

If tests fail:
1. Read the error output carefully
2. Check if selectors match the actual DOM
3. Check for timing issues (add assertions as waits)
4. Check if test data conflicts with existing data
5. Fix and re-run until all tests pass

### Step 4.3: Present Summary

Show the user what was created/modified:

```
E2E Test Summary

Files Created:
  - cypress/e2e/<folder>/tNN-feature-name.cy.ts (N test cases)

Files Modified:
  - src/pages/feature/Component.tsx (added data-test attributes)
  - cypress/support/reusableConstants.ts (added constants) [if applicable]

Test Cases:
  1. should be able to create a resource
  2. should be able to edit the resource

To run:
  cd cypress && npx cypress run --spec "e2e/<folder>/tNN-feature-name.cy.ts"
```

---

## Reference: Selector Quick Guide

| Element | Selector Pattern | Example |
|---|---|---|
| Button/CTA | `[data-test="action-name"]` | `[data-test="create-plan"]` |
| Submit button | `[data-test="submit"]` | `[data-test="submit"]` |
| Text input | `input[name="fieldName"]` | `input[name="email"]` |
| Textarea | `textarea[name="fieldName"]` | `textarea[name="description"]` |
| Dropdown input | `input[name="fieldName"]` | `input[name="currency"]` |
| Dropdown option | `[data-option-index="N"]` | `[data-option-index="0"]` |
| Named option | `[data-test="option-value"]` | `[data-test="USD"]` |
| Dialog | `[role="dialog"]` | `[role="dialog"]` |
| Dialog confirm | `[data-test="warning-confirm"]` | `[data-test="warning-confirm"]` |
| Table row | `[data-test="table-name"] tr` | `[data-test="table-customers-list"] tr` |
| Error message | `[data-test="text-field-error"]` | `[data-test="text-field-error"]` |
| Alert | `[data-test="alert-type-danger"]` | `[data-test="alert-type-danger"]` |
| Tab | `[role="tab"]` + `.contains()` | `button[role="tab"]` |
| Checkbox | `[data-test="checkbox-name"]` | `[data-test="checkbox-hasPlanLimit"]` |
| Actions menu | `[data-test="*-actions"]` | `[data-test="coupon-details-actions"]` |
| Accordion | `[data-test="accordion-N"]` | `[data-test="charge-accordion-0"]` |
| Dynamic ID | `` `[data-test="${variable}"]` `` | `` `[data-test="${couponName}"]` `` |
| Prefix match | `[data-test^="prefix-"]` | `[data-test^="combobox-item-"]` |
