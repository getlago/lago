/* eslint-disable import/order -- prettier's sort-imports groups node builtins with externals, conflicting with import/order's builtin-first grouping */
import fs from 'fs'
import { DocumentNode, FieldNode, OperationDefinitionNode, parse, SelectionNode } from 'graphql'
import path from 'path'

import { queryFieldPolicies } from '../cache'

const SRC_DIR = path.resolve(__dirname, '../../..')

const IGNORED_DIRECTORIES = new Set(['generated', '__tests__', '__mocks__', 'node_modules'])

// Paginated root fields that are intentionally NOT registered in cache.ts because no
// call site paginates them via fetchMore (verified by hand). If a list built on one of
// these starts using fetchMore/InfiniteScroll, remove it from here and add a field
// policy in cache.ts instead.
const FIELDS_WITHOUT_FETCH_MORE = new Set([
  // XeroIntegrationMapItemDrawer combobox searchQuery, always a fresh page-1 lazy query
  'integrationItems',
])

const listSourceFiles = (directory: string): string[] => {
  const entries = fs.readdirSync(directory, { withFileTypes: true })

  return entries.flatMap((entry) => {
    const fullPath = path.join(directory, entry.name)

    if (entry.isDirectory()) {
      return IGNORED_DIRECTORIES.has(entry.name) ? [] : listSourceFiles(fullPath)
    }

    const isSourceFile = /\.(ts|tsx)$/.test(entry.name) && !/\.test\.(ts|tsx)$/.test(entry.name)

    return isSourceFile ? [fullPath] : []
  })
}

type ScanResult = {
  // root query field name -> source files (relative to src/) defining a query on it
  paginatedFields: Map<string, string[]>
  parseFailures: string[]
}

// Every root query field with a paginated `{ collection, metadata }` shape needs a merge
// field policy in cache.ts. Without one, a fetchMore page-2 result is stored under a
// page-specific storeFieldName and the watched query never re-renders with the appended
// rows: infinite scroll silently stops. The repo convention is that NO fetchMore call
// site passes updateQuery, so the field policy is the only merge path. This already
// drifted three times (dunningCampaigns, quotes, orderForms shipped without a policy),
// hence this scan covers ALL gql documents instead of trusting call-site mapping:
// queries and their fetchMore calls can live in different files (apiLogs pattern), and
// the paginated shape can hide behind a fragment spread (creditNotes pattern).
const scanPaginatedQueryFields = (): ScanResult => {
  const documents: { file: string; document: DocumentNode }[] = []
  const parseFailures: string[] = []

  for (const filePath of listSourceFiles(SRC_DIR)) {
    const source = fs.readFileSync(filePath, 'utf8')
    const relativePath = path.relative(SRC_DIR, filePath)

    for (const [, template] of source.matchAll(/gql`([\s\S]*?)`/g)) {
      // Drop `${...}` interpolations (fragment documents) so the template parses standalone
      try {
        documents.push({
          file: relativePath,
          document: parse(template.replace(/\$\{[^}]*\}/g, '')),
        })
      } catch {
        parseFailures.push(relativePath)
      }
    }
  }

  // Fragments are resolved by name across the whole codebase, mirroring what codegen does
  const fragmentSelections = new Map<string, readonly SelectionNode[]>()

  for (const { document } of documents) {
    for (const definition of document.definitions) {
      if (definition.kind === 'FragmentDefinition') {
        fragmentSelections.set(definition.name.value, definition.selectionSet.selections)
      }
    }
  }

  const topLevelFieldNames = (
    selections: readonly SelectionNode[] | undefined,
    visitedFragments = new Set<string>(),
  ): string[] => {
    return (selections || []).flatMap((selection) => {
      if (selection.kind === 'Field') return [selection.name.value]

      if (selection.kind === 'FragmentSpread' && !visitedFragments.has(selection.name.value)) {
        visitedFragments.add(selection.name.value)

        return topLevelFieldNames(fragmentSelections.get(selection.name.value), visitedFragments)
      }

      if (selection.kind === 'InlineFragment') {
        return topLevelFieldNames(selection.selectionSet.selections, visitedFragments)
      }

      return []
    })
  }

  const paginatedFields = new Map<string, string[]>()

  for (const { file, document } of documents) {
    const queryOperations = document.definitions.filter(
      (definition): definition is OperationDefinitionNode =>
        definition.kind === 'OperationDefinition' && definition.operation === 'query',
    )

    for (const operation of queryOperations) {
      const rootFields = operation.selectionSet.selections.filter(
        (selection): selection is FieldNode => selection.kind === 'Field',
      )

      for (const rootField of rootFields) {
        const subFieldNames = topLevelFieldNames(rootField.selectionSet?.selections)

        if (subFieldNames.includes('collection') && subFieldNames.includes('metadata')) {
          const files = paginatedFields.get(rootField.name.value) || []

          paginatedFields.set(rootField.name.value, [...files, file])
        }
      }
    }
  }

  return { paginatedFields, parseFailures }
}

describe('cache typePolicies', () => {
  const { paginatedFields, parseFailures } = scanPaginatedQueryFields()

  it('parses every gql template in src (scanner sanity check)', () => {
    expect(parseFailures).toEqual([])
  })

  it('finds the known paginated queries, including fragment-spread and cross-file shapes (scanner sanity check)', () => {
    const found = Array.from(paginatedFields.keys())

    for (const knownField of [
      'plans',
      'invoices',
      'dunningCampaigns',
      'quotes',
      'orderForms',
      // paginated shape behind a fragment spread (...CreditNotesForTable)
      'creditNotes',
      // query defined in ApiLogs.tsx, fetchMore called from ApiLogsTable.tsx
      'apiLogs',
    ]) {
      expect(found).toContain(knownField)
    }
  })

  it('every paginated root query field has a merge field policy in cache.ts', () => {
    const missingPolicies = Array.from(paginatedFields.entries())
      .filter(([fieldName]) => !FIELDS_WITHOUT_FETCH_MORE.has(fieldName))
      .filter(([fieldName]) => !queryFieldPolicies[fieldName]?.merge)
      .map(([fieldName, files]) => `${fieldName} (queried in ${files.join(', ')})`)
      .sort((a, b) => a.localeCompare(b))

    // A missing entry means infinite scroll on that list silently stops after page 1.
    // Fix: add `<fieldName>: createPaginatedFieldPolicy()` to cache.ts. Only if the
    // field is provably never paginated via fetchMore, add it to
    // FIELDS_WITHOUT_FETCH_MORE above with a justification comment.
    expect(missingPolicies).toEqual([])
  })

  it('allowlisted fields are still queried somewhere (stale allowlist check)', () => {
    for (const fieldName of FIELDS_WITHOUT_FETCH_MORE) {
      expect(Array.from(paginatedFields.keys())).toContain(fieldName)
    }
  })
})
