# Make Tests Skill

**Target:** `<PR_NUMBER | BRANCH_NAME>`

> **Important:** If no argument was provided above (empty or missing), use the AskUserQuestion tool to ask the user what they want to create tests for. They can provide:
>
> - A PR number (format: `#123` or `123`)
> - A branch name (local or remote, e.g., `feature/my-feature` or `origin/feature/my-feature`)

## Input Detection

Determine the input type in this order:

### Step 1: Check if PR Number (Remote)

If the argument is numeric or starts with `#` followed by numbers (e.g., `#123`, `123`):

- Remove the `#` prefix if present
- Verify the PR exists: `gh pr view <PR_NUMBER> --json number`
- If valid, use PR mode

### Step 2: Check if Branch Name (Local)

If the argument is not a PR number:

- Check if the branch exists locally: `git branch --list <BRANCH_NAME>`
- If found, use local branch mode

### Step 3: Check if Branch Name (Remote)

If the branch doesn't exist locally:

- Fetch remote refs: `git fetch origin`
- Check if branch exists on remote: `git branch -r --list origin/<BRANCH_NAME>`
- If found, use remote branch mode

### Step 4: Fallback - Current Branch

If no valid input is detected or the branch doesn't exist:

- Use the current branch: `git branch --show-current`
- Confirm with user before proceeding

This skill creates comprehensive tests for code changes in a GitHub Pull Request or a git branch, following the established patterns and conventions in this codebase.

## Overview

This skill will:

1. Analyze the PR or branch to identify changed/added files (compared to `main`)
2. **Critically evaluate** which parts of the new code actually need tests
3. Create tests following BDD approach (GIVEN/WHEN/THEN)
4. Target ~80% coverage **on new code only** (not the entire codebase)
5. Reuse existing factories/mocks and refactor shared ones

## Critical Testing Philosophy

**Test by default, justify skips.** Every new or significantly modified file SHOULD get tests unless it falls into the Explicit Exclusions list below. The bias is toward testing — if in doubt, write the test.

### The 80% Target is a Minimum, Not a Ceiling

- **80% coverage on new code** is the **minimum target** for files with any logic
- Aim higher (90-100%) for hooks, utilities, and form components
- Only accept lower coverage when the untested code is genuinely trivial (pure presentational JSX with zero logic)

### Default: Test Everything

Every new file gets tests unless it matches an **Explicit Exclusion**. This includes:

- Components with ANY conditional rendering, state, or user interaction
- ALL custom hooks (no exceptions — if it has a contract, test it)
- ALL utility/helper functions
- ALL validation schemas
- ALL form components (test validation, submission, error states)
- Components with loading/error states
- Components that call mutations or queries

### How to Determine If a File Has Testable Logic

**A file has testable logic if it contains ANY of the following. Even ONE match = MUST test:**

- `useState`, `useEffect`, `useLayoutEffect`, `useMemo`, `useCallback`
- `useNavigate`, `useParams`, `useSearchParams` or any routing hook
- Any custom hook call (`use*`)
- GraphQL queries or mutations (`useQuery`, `useLazyQuery`, `useMutation`)
- Conditional rendering (`{condition && ...}`, ternary in JSX)
- Event handlers (`onClick`, `onChange`, `onSubmit`)
- `if`/`else`, `switch`, ternary operators in logic
- `.map()`, `.filter()`, `.reduce()` on data
- Toast notifications, clipboard operations, dialog/modal management
- Any callback passed to child components

**A file is "pure presentational" ONLY if it literally does nothing but return static JSX with props interpolation — no hooks, no conditions, no handlers, no state. This is extremely rare in practice.**

### Explicit Exclusions (The ONLY Valid Reasons to Skip)

You may skip tests ONLY for files that are:

- Pure TypeScript types/interfaces (`.d.ts`, type-only files)
- Auto-generated files (`generated/graphql.tsx`, codegen output)
- Translation/i18n files (`translations/*.json`)
- Pure CSS/SCSS files
- Barrel/index re-exports with no logic
- Static constants with no computation

**If a file does not match the above list, it MUST be tested.** When in doubt, test it.

### When Skipping a Test, Justify It

If you decide not to test a file, you MUST document WHY in the coverage map (Phase 2). Valid reasons:

- "Pure type definitions, no runtime behavior"
- "Barrel export, no logic"
- "Generated file"

Invalid reasons (do NOT use these to skip tests):

- "Simple component" — if it has ANY hook, state, or conditional rendering, it needs tests
- "Thin wrapper" — if it adds any logic, transforms data, or calls hooks, it needs tests
- "Only renders props" — if it has any conditional rendering or event handlers, it needs tests
- "Low complexity" — complexity is not the only reason to test; correctness is
- "Mostly presentational" — if it uses hooks, manages state, or has click handlers, it is NOT presentational
- "Page component" — page components orchestrate logic and ALWAYS need tests
- "Just renders a table/list" — if it has column configs, actions, or row handlers, it needs tests
- "Minor refactor" — if the file has testable logic, test it regardless of change size
- "Minor UI changes" — if the file has hooks, state, or handlers, it is NOT a minor UI change

---

## Prerequisites

Before starting, gather context by reading these reference files:

1. **Testing Best Practices**: `@.agents/docs/testing-practices.md`
2. **Code Quality Standards**: `@.agents/docs/code-quality.md`
3. **Existing Test Example**: `src/components/invoices/details/__tests__/InvoiceDetailsTable.integration.test.tsx`
4. **Test Utils**: `src/test-utils.tsx`

---

## Phase 1: Code Analysis

### Step 1.1: Detect Input Type and Fetch Changed Files

Execute the following logic to detect input type and fetch the diff:

```bash
# Store the input argument
INPUT="$ARGUMENTS"

# Step 1: Check if PR Number
if [[ "$INPUT" =~ ^#?[0-9]+$ ]]; then
  PR_NUMBER="${INPUT#\#}"  # Remove # prefix if present

  # Verify PR exists
  if gh pr view "$PR_NUMBER" --json number &>/dev/null; then
    echo "Detected: PR #$PR_NUMBER"
    # Fetch PR info and diff
    gh pr view "$PR_NUMBER" --json files,additions,deletions,body,title
    gh pr diff "$PR_NUMBER"
    exit 0
  fi
fi

# Step 2: Check if Local Branch
if git branch --list "$INPUT" | grep -q "$INPUT"; then
  echo "Detected: Local branch '$INPUT'"
  git diff main..."$INPUT" --name-only
  git diff main..."$INPUT"
  exit 0
fi

# Step 3: Check if Remote Branch
git fetch origin &>/dev/null
REMOTE_BRANCH="${INPUT#origin/}"  # Remove origin/ prefix if present
if git branch -r --list "origin/$REMOTE_BRANCH" | grep -q "origin/$REMOTE_BRANCH"; then
  echo "Detected: Remote branch 'origin/$REMOTE_BRANCH'"
  git diff main...origin/"$REMOTE_BRANCH" --name-only
  git diff main...origin/"$REMOTE_BRANCH"
  exit 0
fi

# Step 4: Fallback to current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Input '$INPUT' not found. Using current branch: '$CURRENT_BRANCH'"
git diff main...HEAD --name-only
git diff main...HEAD
```

#### Summary of Commands per Input Type

| Input Type     | Example              | Diff Command                         |
| -------------- | -------------------- | ------------------------------------ |
| PR Number      | `#123`, `123`        | `gh pr diff 123`                     |
| Local Branch   | `feature/my-feature` | `git diff main...feature/my-feature` |
| Remote Branch  | `origin/feature/x`   | `git diff main...origin/feature/x`   |
| Current Branch | (fallback)           | `git diff main...HEAD`               |

### Step 1.2: Identify Files Requiring Tests

Analyze the changed files and categorize them. **Default bias: TEST.**

**Files that ALWAYS get tests (no exceptions):**

- Components (`.tsx` files in `src/components/`, `src/pages/`)
- Hooks (`.ts` files in `src/hooks/`)
- Utilities (`.ts` files in `src/core/utils/`, `src/utils/`)
- Validation schemas
- Business logic modules
- Form components

**Files that may be skipped (Explicit Exclusions only):**

- Pure type definitions (`.d.ts`, type-only files)
- Auto-generated files (`generated/graphql.tsx`, codegen output)
- Translation files (`translations/*.json`)
- Style files (`.css`, `.scss`)
- Barrel/index re-exports with no logic
- Static constants with no computation

**Every file that is NOT in the exclusion list above MUST be tested.** When in doubt, test it.

### Step 1.3: Assess Test Scope

For each file requiring tests, briefly assess the scope:

1. **Complexity**: Conditional logic, loops, state management → more test cases
2. **Business criticality**: Payments, invoices, sensitive operations → higher coverage target
3. **User interaction**: Form submissions, button clicks, navigation → test interactions
4. **Edge cases**: Null checks, error handling, boundary conditions → test edge cases

This assessment determines HOW MANY tests to write, not WHETHER to test.

### Step 1.4: Check for Implicit Coverage and Related Files

Before creating tests, verify that ALL new files in the PR are accounted for:

**1. Supporting Files (schemas, configs, types)**

- Check if these are already tested implicitly through component tests
- If a component test exercises the supporting file's behavior, separate tests may not be needed
- Only create separate tests if the file has complex logic not covered elsewhere

**2. Custom Hooks**

- Hooks should be tested for their **core contract**: what they return and what side effects they trigger
- Focus on: callbacks return expected values, correct parameters passed to external dependencies
- Don't skip hook tests just because the hook is "simple" - if it has a contract, test it

**3. New Patterns Introduced by the PR**

- Identify if the PR introduces new approaches or replaces old patterns
- Focus tests specifically on the NEW behavior, not on unchanged existing logic
- If a PR changes HOW something is done (e.g., navigation, state management), test that the new approach works correctly

---

## Phase 1.5: Complete PR File Table (MANDATORY)

**CRITICAL:** Before proceeding to test planning and before asking for user approval, you MUST generate a complete table listing **EVERY SINGLE FILE** changed in the PR or branch. No files may be omitted or grouped. If the PR has 50 files changed, the table MUST have exactly 50 rows.

### Step 1.5.1: Gather File Stats

For each file in the PR/branch diff, collect:

- **File path**: Full relative path
- **Additions/Deletions**: Lines added (+) and removed (-)
- **Status**: `NEW` (added), `Modified` (changed), `DELETED` (removed), `Renamed`
- **Test?**: Whether this file will have tests written for it (`✅ YES` or `⏭️ NO`)
- **Skip Reason**: If `⏭️ NO`, provide a short reason (e.g., "Type definitions", "Generated file", "Pure presentational", "Config file", "Translation file", "Barrel export", "Simple prop pass-through", "Tested implicitly via ComponentName", "Deleted file", "Snapshot update")

### Step 1.5.2: Generate the Table

Use the following exact format. Every file MUST appear as its own row:

```
Complete File List — PR #<PR_NUMBER> (or Branch: <BRANCH_NAME>)
  ┌─────┬────────────────────────────────────────────────────────────────┬───────────┬──────────┬───────┬─────────────────────────────────┐
  │  #  │ File                                                           │    +/-    │  Status  │ Test? │ Skip Reason                     │
  ├─────┼────────────────────────────────────────────────────────────────┼───────────┼──────────┼───────┼─────────────────────────────────┤
  │ 1   │ src/components/example/Component.tsx                           │ +122/-0   │ NEW      │ ✅ YES │                                 │
  ├─────┼────────────────────────────────────────────────────────────────┼───────────┼──────────┼───────┼─────────────────────────────────┤
  │ 2   │ src/components/example/types.ts                                │ +15/-0    │ NEW      │ ⏭️ NO │ Type definitions                │
  ├─────┼────────────────────────────────────────────────────────────────┼───────────┼──────────┼───────┼─────────────────────────────────┤
  │ 3   │ src/generated/graphql.tsx                                      │ +267/-190 │ Modified │ ⏭️ NO │ Generated file                  │
  ├─────┼────────────────────────────────────────────────────────────────┼───────────┼──────────┼───────┼─────────────────────────────────┤
  │ 4   │ translations/base.json                                         │ +17/-4    │ Modified │ ⏭️ NO │ Translation file                │
  └─────┴────────────────────────────────────────────────────────────────┴───────────┴──────────┴───────┴─────────────────────────────────┘
```

### Rules for the Table

1. **EVERY file changed in the PR must appear** - no exceptions, no grouping, no summarizing
2. Files should be listed in the same order as they appear in the PR diff
3. The `#` column is a sequential counter starting from 1
4. The `+/-` column shows additions and deletions (e.g., `+122/-0`, `+8/-12`, `+0/-64`)
5. The `Status` column uses: `NEW` for added files, `Modified` for changed files, `DELETED` for removed files, `Renamed` for renamed files
6. The `Test?` column uses: `✅ YES` for files that will have tests, `⏭️ NO` for files that won't
7. The `Skip Reason` column is empty for files marked `✅ YES`, and provides a concise reason for files marked `⏭️ NO`
8. After the table, show a summary: `Total: X files | Will test: Y files | Skipped: Z files`

### Step 1.5.3: Wait for User Approval

After displaying the table, ask the user to confirm:

- Whether the file analysis is correct
- Whether they agree with the test/skip decisions
- Whether they want to add or remove files from the test list

**Do NOT proceed to Phase 2 until the user approves the table.**

---

## Phase 2: Test Planning

### Step 2.1: Coverage Map (MANDATORY)

**Before writing any test, you MUST create a coverage map that accounts for EVERY new or significantly changed file in the PR.**

The coverage map must list ALL added or modified files (NOT deleted files) with their test status.

**Rules for classifying files — apply the "Testable Logic Checklist" from the Philosophy section:**

- Open each file and scan for: `useState`, `useEffect`, `useMemo`, `useCallback`, `useNavigate`, `useParams`, `useSearchParams`, custom hooks (`use*`), GraphQL queries/mutations, conditional rendering, event handlers, `.map()/.filter()/.reduce()`, toast/clipboard/dialog operations
- **If the file contains even ONE item from the checklist → Status = ✅ WILL TEST**
- **Only files matching the Explicit Exclusions list → Status = ⏭️ SKIP**

**For MODIFIED files (not just new files):**

- A modified file with 20+ lines of additions that contains testable logic MUST be tested
- "Minor refactor" or "props change" is NOT a valid skip reason if the file has testable logic
- If the modified file has NO existing test file, this is an opportunity to add coverage — mark as ✅ WILL TEST
- If the modified file already HAS a test file, mark as ✅ WILL TEST (update existing tests)

```markdown
| #   | File                                | Type      | Lines Added | Test File                                | Status       | Skip Reason           |
| --- | ----------------------------------- | --------- | ----------- | ---------------------------------------- | ------------ | --------------------- |
| 1   | `src/pages/WebhookForm.tsx`         | Page      | 327         | `__tests__/WebhookForm.test.tsx`         | ✅ WILL TEST | —                     |
| 2   | `src/hooks/useWebhookEventTypes.ts` | Hook      | 211         | `__tests__/useWebhookEventTypes.test.ts` | ✅ WILL TEST | —                     |
| 3   | `src/hooks/useDeleteWebhook.ts`     | Hook      | 50          | `__tests__/useDeleteWebhook.test.ts`     | ✅ WILL TEST | —                     |
| 4   | `src/types/webhook.ts`              | Types     | 15          | —                                        | ⏭️ SKIP      | Pure type definitions |
| 5   | `src/generated/graphql.tsx`         | Generated | 267         | —                                        | ⏭️ SKIP      | Generated file        |
```

**Rules for the coverage map:**

1. **Every file** with >20 lines of additions MUST appear in the map
2. Files marked ✅ WILL TEST must get a test file — no exceptions
3. Files marked ⏭️ SKIP must have a valid skip reason from the Explicit Exclusions list
4. **Hooks ALWAYS get tested** — no skip allowed
5. **Utility files ALWAYS get tested** — no skip allowed
6. **Page/form components ALWAYS get tested** — no skip allowed
7. **Components with ANY hook call, state, or event handler ALWAYS get tested** — no skip allowed
8. If the map shows more than 30% of files being skipped, reconsider — you are likely being too conservative
9. "Thin wrapper" is NEVER a valid skip reason — if it has props transformation, hook calls, or any logic, test it
10. "Minor refactor" or "minor UI changes" is NEVER a valid skip reason — if the file has testable logic, test it

### Step 2.2: User Checkpoint (MANDATORY — STOP HERE)

**⛔ STOP: Before writing any test, you MUST present the coverage map to the user and ask for confirmation.**

Present the table from Step 2.1 to the user and ask:

> "Here is the coverage map for this PR. I will create test files for all ✅ items and skip ⏭️ items for the reasons listed. Do you want me to proceed, or would you like to adjust any decisions?"

**Do NOT proceed to Phase 3 until the user confirms.** The user may:

- Ask you to test a file you planned to skip
- Ask you to skip a file you planned to test
- Ask you to adjust the scope

### Step 2.3: Code Review Per File

For each file marked ✅ WILL TEST, briefly identify key test scenarios:

```markdown
### File: `src/path/to/Component.tsx`

**Key scenarios to test:**

- Default rendering with required props
- Conditional rendering paths (lines X-Y)
- User interactions (form submit, button clicks)
- Error/loading states
- Edge cases (empty data, invalid input)
```

Keep this brief — the goal is to plan, not to over-analyze. If a file has logic, test it.

### Step 2.4: Search for Existing Mocks and Factories

Before creating new mocks, search for existing ones:

```bash
# Search for existing factories
find src -name "*factory*" -o -name "*Factory*" | head -20

# Search for existing mocks
find src -name "*mock*" -o -name "*Mock*" | head -20

# Search for shared test utilities
ls -la src/__mocks__/ 2>/dev/null || echo "No shared mocks folder"
```

---

## Phase 3: Implementation

### Step 3.1: Add data-test Constants to Components

**CRITICAL:** Before writing tests, add `data-test` constants to the component being tested.

**In the component file:**

```typescript
// Export data-test constants at the top of the component file (after imports)
export const COMPONENT_NAME_TEST_ID = 'component-name'
export const COMPONENT_NAME_TITLE_TEST_ID = 'component-name-title'
export const COMPONENT_NAME_SUBMIT_BUTTON_TEST_ID = 'component-name-submit-button'
export const COMPONENT_NAME_ERROR_MESSAGE_TEST_ID = 'component-name-error-message'
// Add more as needed for testable elements

export const ComponentName = ({ ... }) => {
  return (
    <div data-test={COMPONENT_NAME_TEST_ID}>
      <Typography data-test={COMPONENT_NAME_TITLE_TEST_ID}>
        {translate('...')}
      </Typography>
      {/* For form.SubmitButton use dataTest (camelCase) */}
      <form.SubmitButton dataTest={COMPONENT_NAME_SUBMIT_BUTTON_TEST_ID}>
        Submit
      </form.SubmitButton>
    </div>
  )
}
```

**Naming convention:**

- Use SCREAMING_SNAKE_CASE for constant names
- Use kebab-case for the actual data-test value
- Pattern: `{COMPONENT_NAME}_{ELEMENT_DESCRIPTION}_TEST_ID`

**NEVER wrap elements in extra `<div>` just to add a `data-test` attribute:**

Adding a wrapper `<div>` (even without styles) can break the UI due to cascading CSS, flexbox/grid layout inheritance, or fragment-based rendering assumptions.

```typescript
// ❌ WRONG - Do NOT wrap fragments or elements in a <div> just for data-test
// Original code:
<>
  <Skeleton variant="text" className="w-60" textVariant="headline" />
  <Skeleton variant="text" className="w-40" textVariant="body" />
</>

// ❌ NEVER do this:
<div data-test={COMPONENT_LOADING_TEST_ID}>
  <Skeleton variant="text" className="w-60" textVariant="headline" />
  <Skeleton variant="text" className="w-40" textVariant="body" />
</div>
```

**Rule:** Only add `data-test` to elements that **already exist** in the JSX. If an element cannot accept `data-test` natively (e.g., React fragments `<>`, third-party components without `data-test` prop support), **do not test that element** rather than wrapping it in a `<div>`. Skipping a test is always preferable to altering the component's DOM structure.

### Step 3.2: Create Test File

Create test file at: `src/path/to/__tests__/ComponentName.test.tsx`

**Test file structure:**

```typescript
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  COMPONENT_NAME_TEST_ID,
  COMPONENT_NAME_TITLE_TEST_ID,
  COMPONENT_NAME_SUBMIT_BUTTON_TEST_ID,
  ComponentName,
} from '../ComponentName'
import { render } from '~/test-utils'

// Mock dependencies
jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

describe('ComponentName', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should display the main container', () => {
        render(<ComponentName />)

        expect(screen.getByTestId(COMPONENT_NAME_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the title', () => {
        render(<ComponentName />)

        expect(screen.getByTestId(COMPONENT_NAME_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN user interacts with the form', () => {
      it('THEN should enable submit button after valid input', async () => {
        const user = userEvent.setup()
        render(<ComponentName />)

        const input = screen.getByTestId(COMPONENT_NAME_INPUT_TEST_ID)
        await user.type(input, 'valid value')

        const submitButton = screen.getByTestId(COMPONENT_NAME_SUBMIT_BUTTON_TEST_ID)
        expect(submitButton).not.toBeDisabled()
      })
    })
  })

  describe('GIVEN the component receives props', () => {
    describe('WHEN isLoading is true', () => {
      it('THEN should display loading state', () => {
        render(<ComponentName isLoading={true} />)

        expect(screen.getByTestId(COMPONENT_LOADING_SKELETON_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
```

### Step 3.3: BDD Test Structure Rules

**MANDATORY:** All test descriptions MUST follow this pattern:

1. **describe** blocks use `GIVEN` or `WHEN` (always UPPERCASE)
2. **it** blocks use `THEN` (always UPPERCASE)
3. The rest of the description is lowercase

**Pattern:**

```typescript
describe('GIVEN [precondition]', () => {
  describe('WHEN [action or state]', () => {
    it('THEN should [expected outcome]', () => {
      // test implementation
    })
  })
})
```

**Examples:**

```typescript
// Correct
describe('GIVEN the user is logged in', () => {
  describe('WHEN clicking the logout button', () => {
    it('THEN should redirect to login page', () => { ... })
    it('THEN should clear the session', () => { ... })
  })
})

// Incorrect - don't do this
describe('Given the user is logged in', () => { ... })  // Wrong case
describe('When clicking the logout button', () => { ... })  // Wrong case
it('Then should redirect', () => { ... })  // Wrong case
it('should redirect', () => { ... })  // Missing THEN
```

### Step 3.4: Using it.each for Similar Tests

**IMPORTANT:** When you have multiple tests that follow the same pattern but with different inputs/outputs, use `it.each` to reduce code duplication and improve maintainability.

**When to use `it.each`:**

- Testing multiple elements are rendered (e.g., form fields, buttons)
- Testing multiple inputs produce expected outputs
- Testing the same behavior with different props/states
- Testing multiple validation cases

**Pattern for checking multiple elements are displayed:**

```typescript
describe('WHEN the component renders', () => {
  it.each([
    ['name input field', COMPONENT_NAME_INPUT_TEST_ID],
    ['email input field', COMPONENT_EMAIL_INPUT_TEST_ID],
    ['cancel button', COMPONENT_CANCEL_BUTTON_TEST_ID],
    ['submit button', COMPONENT_SUBMIT_BUTTON_TEST_ID],
  ])('THEN should display the %s', (_, testId) => {
    render(<ComponentName />)

    expect(screen.getByTestId(testId)).toBeInTheDocument()
  })
})
```

**Pattern for checking default values:**

```typescript
describe('WHEN form fields are empty', () => {
  it.each([
    ['name', COMPONENT_NAME_INPUT_TEST_ID],
    ['email', COMPONENT_EMAIL_INPUT_TEST_ID],
    ['phone', COMPONENT_PHONE_INPUT_TEST_ID],
  ])('THEN should have empty %s input by default', (_, testId) => {
    render(<ComponentName />)

    const container = screen.getByTestId(testId)
    const input = container.querySelector('input')

    expect(input).toHaveValue('')
  })
})
```

**Pattern for testing multiple validation cases:**

```typescript
describe('WHEN user enters invalid data', () => {
  it.each([
    ['empty email', '', 'Email is required'],
    ['invalid email format', 'invalid', 'Invalid email format'],
    ['email too long', 'a'.repeat(256) + '@test.com', 'Email too long'],
  ])('THEN should show error for %s', async (_, inputValue, expectedError) => {
    const user = userEvent.setup()
    render(<ComponentName />)

    const input = screen.getByTestId(COMPONENT_EMAIL_INPUT_TEST_ID)
    await user.type(input, inputValue)
    await user.tab() // trigger blur validation

    expect(screen.getByText(expectedError)).toBeInTheDocument()
  })
})
```

**Pattern with object parameters for complex cases:**

```typescript
describe('WHEN displaying different states', () => {
  it.each([
    { status: 'pending', expectedColor: 'yellow', expectedText: 'In Progress' },
    { status: 'completed', expectedColor: 'green', expectedText: 'Done' },
    { status: 'failed', expectedColor: 'red', expectedText: 'Error' },
  ])('THEN should display $status state correctly', ({ status, expectedColor, expectedText }) => {
    render(<StatusBadge status={status} />)

    const badge = screen.getByTestId(STATUS_BADGE_TEST_ID)
    expect(badge).toHaveClass(expectedColor)
    expect(badge).toHaveTextContent(expectedText)
  })
})
```

**When NOT to use `it.each`:**

- When tests have significantly different setup or assertions
- When the test logic is complex and would be harder to read in a table
- When you only have 1-2 similar tests (not worth the abstraction)
- When debugging would be harder due to the abstraction

### Step 3.5: Selector Rules - CRITICAL: NEVER USE TRANSLATION KEYS

## ⛔ ABSOLUTE RULE: NEVER USE TRANSLATION KEYS IN TESTS ⛔

**This is the most important rule for test selectors. NEVER, under ANY circumstances, use translation keys to find or verify elements.**

### What NOT to do (FORBIDDEN):

```typescript
// ❌ WRONG - NEVER DO THIS
expect(screen.getByText('text_17440321235444hcxi31f8j6')).toBeInTheDocument()
expect(screen.getByText(translate('some_key'))).toBeInTheDocument()
expect(screen.queryByText('text_6271200984178801ba8bdeb2')).toBeInTheDocument()
expect(screen.getAllByText('text_64d23a81a7d807f8aa570509').length).toBeGreaterThan(0)

// ❌ WRONG - Even in waitFor
await waitFor(() => {
  expect(screen.getByText('text_6271200984178801ba8bdf7f')).toBeInTheDocument()
})

// ❌ WRONG - Even for error messages
expect(screen.getByText('text_6271200984178801ba8bdf58')).toBeInTheDocument()
```

### What TO do (CORRECT):

```typescript
// ✅ CORRECT - Always use data-test IDs
expect(screen.getByTestId(COMPONENT_NAME_TITLE_TEST_ID)).toBeInTheDocument()
expect(screen.getByTestId(COMPONENT_ERROR_MESSAGE_TEST_ID)).toBeInTheDocument()

// ✅ CORRECT - For checking element existence
expect(screen.getByTestId(COMPONENT_SUBMIT_BUTTON_TEST_ID)).toBeInTheDocument()

// ✅ CORRECT - For checking element is NOT present
expect(screen.queryByTestId(COMPONENT_ERROR_TEST_ID)).not.toBeInTheDocument()

// ✅ CORRECT - In waitFor
await waitFor(() => {
  expect(screen.getByTestId(COMPONENT_SUCCESS_MESSAGE_TEST_ID)).toBeInTheDocument()
})
```

### Why this rule exists:

1. **Translation keys are implementation details** - They can change without changing functionality
2. **Translation keys are not human-readable** - `text_6271200984178801ba8bdeb2` tells you nothing about what's being tested
3. **Translation keys make tests brittle** - Any translation file change breaks tests
4. **data-test IDs are semantic** - `WEBHOOK_FORM_ERROR_MESSAGE_TEST_ID` clearly describes the element
5. **data-test IDs are stable** - They only change when the component structure changes intentionally

### If you need to verify text content:

```typescript
// ✅ CORRECT - Get element by test ID, then check it exists
const errorMessage = screen.getByTestId(COMPONENT_ERROR_MESSAGE_TEST_ID)
expect(errorMessage).toBeInTheDocument()

// ✅ CORRECT - If you MUST check text content, use toHaveTextContent with the actual translated string
// But prefer checking for element existence via data-test ID
```

### For form inputs, use the data-test container:

```typescript
// ✅ CORRECT - Find input within data-test container, use type assertion (NOT non-null assertion)
const inputContainer = screen.getByTestId(COMPONENT_NAME_INPUT_TEST_ID)
const input = inputContainer.querySelector('input') as HTMLInputElement
await user.type(input, 'test value')

// ❌ WRONG - Don't use non-null assertion
// const input = inputContainer.querySelector('input')
// await user.type(input, 'test value')  // ESLint error if using non-null assertion
```

### Type Assertions for DOM Elements:

Always use `as HTMLInputElement` (or appropriate HTML type) instead of non-null assertion:

```typescript
// ✅ CORRECT - Use type assertion
const input = container.querySelector('input') as HTMLInputElement
const button = container.querySelector('button') as HTMLButtonElement
const select = container.querySelector('select') as HTMLSelectElement

// ❌ WRONG - Non-null assertion causes ESLint errors
// const input = container.querySelector('input') with non-null assertion
// await user.type(input, 'value')  // Fails: typescript-eslint/no-non-null-assertion
```

### Step 3.6: Reuse and Refactor Mocks

**Step 3.6.1: Check for existing mocks**

Before creating new mocks, search the codebase:

```typescript
// Search in existing test files for similar mocks
grep -r "mockInvoice" src/**/__tests__/*.tsx
grep -r "createMock" src/**/__tests__/*.tsx
```

**Step 3.6.2: Refactor shared mocks**

If you find the same mock used in multiple test files, move it to a shared location:

1. Create shared mock files in `src/__mocks__/` or `src/test-utils/mocks/`
2. Export factory functions for creating mock objects
3. Update existing tests to import from the shared location

**Shared mock pattern:**

```typescript
// src/__mocks__/invoiceMocks.ts
import { CurrencyEnum, InvoiceStatusTypeEnum } from '~/generated/graphql'

export const createMockInvoice = (overrides = {}) => ({
  id: 'invoice-1',
  status: InvoiceStatusTypeEnum.Finalized,
  currency: CurrencyEnum.Usd,
  totalAmountCents: 10000,
  ...overrides,
})

export const createMockCustomer = (overrides = {}) => ({
  id: 'customer-1',
  name: 'Test Customer',
  ...overrides,
})
```

**Usage in tests:**

```typescript
import { createMockCustomer, createMockInvoice } from '~/mocks/invoiceMocks'

const mockInvoice = createMockInvoice({ status: InvoiceStatusTypeEnum.Draft })
```

---

## Phase 4: Coverage Analysis (Critical Evaluation)

### Step 4.1: Run Tests with Coverage on New Files Only

```bash
# Run coverage ONLY on the new/changed files from the PR
pnpm test:coverage -- --collectCoverageFrom='src/path/to/new-file.tsx' src/path/to/__tests__/new-file.test.tsx
```

### Step 4.2: Analyze Uncovered Code Critically

When reviewing coverage results, for each uncovered line/branch ask:

1. **Is this code worth testing?**
   - If it's error handling for an edge case that could break production → YES, add test
   - If it's a simple return statement or trivial else branch → NO, leave it

2. **What would a test for this code look like?**
   - If the test would be meaningful and catch real bugs → Write it
   - If the test would just be `expect(component).toBeInTheDocument()` with no real assertion → Skip it

3. **Would adding this test improve confidence in the code?**
   - If yes → Write it
   - If the test would just be testing implementation details → Skip it

### Step 4.3: Coverage Targets (Minimums)

**Minimum: 80% on new code.** Aim higher for critical files:

| Scenario                         | Minimum Coverage | Target Coverage | Reason                                |
| -------------------------------- | ---------------- | --------------- | ------------------------------------- |
| Custom hooks                     | 85%              | 95-100%         | Core contracts, always testable       |
| Utility/helper functions         | 85%              | 95-100%         | Pure logic, easy to test              |
| Complex business logic           | 80%              | 90-100%         | High value, many edge cases           |
| Form with validation             | 80%              | 85-95%          | Test validation + submission + errors |
| Component with conditional logic | 75%              | 85-90%          | Test all branches and interactions    |
| Simple component with some logic | 65%              | 75-85%          | Test the logic paths                  |
| Mostly presentational component  | 50%              | 60-70%          | Test meaningful interactions only     |

### Step 4.4: Keep Test Files Clean

**IMPORTANT:** Do NOT add coverage note comments to test files. Test files should contain only tests, mocks, and necessary setup code.

```typescript
// DON'T DO THIS
/**
 * Coverage Note: This test file achieves ~65% coverage...
 * Uncovered code includes: ...
 */
```

The coverage targets in Step 4.3 are guidelines. If coverage is lower because the untested code is trivial, that's fine - no documentation needed.

### Step 4.5: Run All Tests

```bash
pnpm test src/path/to/__tests__/file.test.tsx
```

### Step 4.6: Run Code Style Check (MANDATORY)

**CRITICAL:** After all tests pass, you MUST run the code style check:

```bash
pnpm run code:style
```

**Rules:**

1. **Only fix ERRORs** — ignore warnings entirely
2. If there are ERRORs, fix them in the affected files (both test files and source files)
3. Re-run `pnpm run code:style` after fixing to confirm all ERRORs are resolved
4. Do NOT spend time fixing warnings — they are acceptable and should be left as-is

---

## Phase 5: Final Checklist

### Test Quality Checklist

- [ ] **Critical analysis performed** - Each test has a clear purpose (what bug would it catch?)
- [ ] Tests follow BDD structure (GIVEN/WHEN/THEN in UPPERCASE)
- [ ] **it.each used** where appropriate for similar tests
- [ ] **⛔ NO TRANSLATION KEYS USED AS SELECTORS** - All selectors use data-test IDs
- [ ] **⛔ NO TRANSLATION KEYS IN ASSERTIONS** - Use `expect.objectContaining()` for partial matching
- [ ] data-test constants are exported from the component
- [ ] Tests import data-test constants from the component
- [ ] **Type assertions used correctly** - Use type assertions (as HTMLInputElement) instead of non-null assertions
- [ ] Existing mocks/factories are reused
- [ ] Shared mocks are extracted to shared mock folder (src/\_\_mocks\_\_/) if used in multiple files
- [ ] **Coverage is appropriate** (80% target, but lower is OK if justified)
- [ ] **No trivial tests** - Every test verifies meaningful behavior
- [ ] **Snapshot tests considered** - Added where they provide value (not forced)
- [ ] Tests pass: `pnpm test <test-file>`
- [ ] **⚠️ Code style passes: `pnpm run code:style`** (MANDATORY - fix ERRORs only, ignore warnings)

### ⛔ MANDATORY: Translation Key Verification (Final Step)

**Before completing the task, you MUST verify that NO translation keys exist in the test files.**

Run this check on all test files created or modified:

```bash
# Search for translation key patterns in test files (text_ followed by alphanumeric characters)
grep -E "text_[a-zA-Z0-9]+" src/path/to/__tests__/*.test.tsx
```

**If ANY translation keys are found, you MUST remove them:**

1. Replace `title: 'text_xxx'` with `title: expect.any(String)` or remove entirely
2. Replace `description: 'text_xxx'` with `description: expect.any(String)` or remove entirely
3. Replace `actionText: 'text_xxx'` with `actionText: expect.any(String)` or remove entirely
4. Replace `message: 'text_xxx'` with removal (only keep `severity` for toasts)
5. Replace `screen.getByText('text_xxx')` with `screen.getByTestId(COMPONENT_TEST_ID)`

**This check is NON-NEGOTIABLE. Tests with translation keys will break when translations change.**

### Coverage Decision Guide

| New Code Type                       | Recommended Action                    | Minimum Coverage |
| ----------------------------------- | ------------------------------------- | ---------------- |
| Custom hooks                        | Full test coverage (contract + edges) | 85%              |
| Utility/helper functions            | Full test coverage (all paths)        | 85%              |
| Complex logic with branches         | Full test coverage                    | 80%              |
| Form handling + validation          | Test validation + submission + errors | 80%              |
| Component with conditional logic    | Test all branches and interactions    | 75%              |
| Simple component with some logic    | Test the logic paths                  | 65%              |
| Mostly presentational + minor logic | Test meaningful interactions          | 50%              |

**Files that get NO tests (Explicit Exclusions only):**

| Exclusion Type              | Example                          |
| --------------------------- | -------------------------------- |
| Pure type definitions       | `types.ts`, `*.d.ts`             |
| Auto-generated files        | `generated/graphql.tsx`          |
| Translation files           | `translations/base.json`         |
| Pure CSS/SCSS               | `styles.css`                     |
| Barrel/index re-exports     | `index.ts` with only exports     |
| Static constants (no logic) | `constants.ts` with plain values |

### Snapshot Tests (When Appropriate)

Use snapshot tests **where they add value**, but don't force them.

**Good candidates for snapshots:**

- Complex UI structures that should remain stable
- Components with multiple visual states (loading, error, success)
- Tables or lists with specific formatting
- Components where visual regression would be a bug

**NOT good for snapshots:**

- Simple components with 1-2 elements
- Components that change frequently (snapshots become noisy)
- Dynamic content (timestamps, IDs, random values)
- Components where the structure is obvious from the code

**Snapshot test pattern:**

```typescript
describe('GIVEN the component renders different states', () => {
  describe('WHEN in default state', () => {
    it('THEN should match snapshot', () => {
      const { container } = render(<Component />)

      expect(container).toMatchSnapshot()
    })
  })

  describe('WHEN in error state', () => {
    it('THEN should match snapshot', () => {
      const { container } = render(<Component error="Something failed" />)

      expect(container).toMatchSnapshot()
    })
  })
})
```

**Important:** If a component has dynamic content (dates, IDs), either:

- Mock the dynamic values before snapshot
- Skip snapshot for that component
- Use inline snapshots with specific assertions instead

### What NOT to Include in Tests

- ⛔ **Translation key values** (dynamic and can change) - use `expect.any(String)` instead
- Pure UI styling assertions (colors, fonts, spacing)
- Third-party library internals
- Basic JSX structure assertions (e.g., "component renders a div")

---

## Common Patterns

### Testing Loading States

```typescript
describe('GIVEN the component is loading', () => {
  describe('WHEN data is being fetched', () => {
    it('THEN should display loading skeleton', () => {
      render(<Component isLoading={true} />)

      expect(screen.getByTestId(COMPONENT_LOADING_SKELETON_TEST_ID)).toBeInTheDocument()
    })

    it('THEN should not display content', () => {
      render(<Component isLoading={true} />)

      expect(screen.queryByTestId(COMPONENT_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })
  })
})
```

### Testing Error States

```typescript
describe('GIVEN an error occurred', () => {
  describe('WHEN the error is displayed', () => {
    it('THEN should show error message', () => {
      render(<Component error="Something went wrong" />)

      expect(screen.getByTestId(COMPONENT_ERROR_TEST_ID)).toBeInTheDocument()
    })
  })
})
```

### Testing Form Submissions

```typescript
describe('GIVEN the form is filled', () => {
  describe('WHEN user submits the form', () => {
    it('THEN should call the submit handler with form values', async () => {
      const onSubmit = jest.fn()
      const user = userEvent.setup()
      render(<FormComponent onSubmit={onSubmit} />)

      const nameInput = screen.getByTestId(FORM_NAME_INPUT_TEST_ID).querySelector('input') as HTMLInputElement
      await user.type(nameInput, 'Test Name')

      const submitButton = screen.getByTestId(FORM_SUBMIT_BUTTON_TEST_ID)
      await user.click(submitButton)

      await waitFor(() => {
        expect(onSubmit).toHaveBeenCalledWith(
          expect.objectContaining({ name: 'Test Name' })
        )
      })
    })
  })
})
```

### Testing Conditional Rendering

```typescript
describe('GIVEN the feature flag is enabled', () => {
  describe('WHEN component renders', () => {
    it('THEN should display the new feature', () => {
      render(<Component featureEnabled={true} />)

      expect(screen.getByTestId(COMPONENT_NEW_FEATURE_TEST_ID)).toBeInTheDocument()
    })
  })
})

describe('GIVEN the feature flag is disabled', () => {
  describe('WHEN component renders', () => {
    it('THEN should not display the new feature', () => {
      render(<Component featureEnabled={false} />)

      expect(screen.queryByTestId(COMPONENT_NEW_FEATURE_TEST_ID)).not.toBeInTheDocument()
    })
  })
})
```

### Testing with Timezone (for date components)

```typescript
import { Settings } from 'luxon'

describe('ComponentWithDates', () => {
  const originalDefaultZone = Settings.defaultZone

  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  // ... tests
})
```

### Testing GraphQL Mutations Success

```typescript
describe('GIVEN the mutation succeeds', () => {
  describe('WHEN user performs action', () => {
    it('THEN should show success toast', async () => {
      const user = userEvent.setup()

      render(<Component />, { mocks: successMocks })

      const actionButton = screen.getByTestId(COMPONENT_ACTION_BUTTON_TEST_ID)
      await user.click(actionButton)

      // ✅ CORRECT - Use expect.objectContaining to skip translation key verification
      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith(
          expect.objectContaining({ severity: 'success' })
        )
      })

      // ❌ WRONG - NEVER include translation keys in assertions
      // await waitFor(() => {
      //   expect(addToast).toHaveBeenCalledWith({
      //     message: 'text_6271200984178801ba8bdf7f', // ❌ NEVER DO THIS
      //     severity: 'success',
      //   })
      // })
    })
  })
})
```

### Testing Dialog/Modal Opens (CRITICAL: No Translation Keys)

When testing that a dialog or modal was opened with specific properties, **NEVER** include translation keys for `title`, `description`, or `actionText`. Instead, verify only non-translation properties like `colorVariant`, or use `expect.any(String)` if you need to verify the presence of text fields.

```typescript
describe('GIVEN user wants to delete an item', () => {
  describe('WHEN clicking the delete button', () => {
    it('THEN should open confirmation dialog with danger variant', async () => {
      const user = userEvent.setup()
      render(<Component />)

      const deleteButton = screen.getByTestId(COMPONENT_DELETE_BUTTON_TEST_ID)
      await user.click(deleteButton)

      // ✅ CORRECT - Only verify non-translation key properties
      expect(mockDialogOpen).toHaveBeenCalledWith(
        expect.objectContaining({
          colorVariant: 'danger',
        }),
      )

      // ✅ ALSO CORRECT - If you need to verify title/description exist, use expect.any(String)
      expect(mockDialogOpen).toHaveBeenCalledWith(
        expect.objectContaining({
          title: expect.any(String),
          description: expect.any(String),
          colorVariant: 'danger',
        }),
      )

      // ❌ WRONG - NEVER include translation keys in dialog assertions
      // expect(mockDialogOpen).toHaveBeenCalledWith(
      //   expect.objectContaining({
      //     title: 'text_6271200984178801ba8bdeb2',        // ❌ NEVER DO THIS
      //     description: 'text_6271200984178801ba8bded2',  // ❌ NEVER DO THIS
      //     actionText: 'text_6271200984178801ba8bdf0c',   // ❌ NEVER DO THIS
      //     colorVariant: 'danger',
      //   }),
      // )
    })
  })
})
```

---

## Usage

Invoke this skill with a PR number or branch name:

### Using PR Number

```
/make-tests #123
/make-tests 123
```

### Using Branch Name

```
/make-tests feature/my-new-feature
/make-tests origin/fix/bug-123
/make-tests chore/update-deps
```

### Examples

```
/make-tests #456                        # Analyze PR #456
/make-tests feature/add-webhook-form    # Analyze local branch
/make-tests origin/feature/new-dialog   # Analyze remote branch
```

The skill will analyze the PR or branch, identify files needing tests (compared to `main`), and create comprehensive tests following the BDD approach and project conventions.

**Remember: NEVER use translation keys in tests. Always use data-test IDs.**
