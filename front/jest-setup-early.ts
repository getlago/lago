/**
 * Early Jest Setup - Runs before any test imports
 *
 * This file configures console suppression BEFORE any libraries are imported,
 * so we can intercept warnings from libraries that cache console references.
 */

/**
 * Patterns to suppress in test console output.
 * Each pattern is an array of strings that must ALL be present in the message.
 */
const SUPPRESSED_PATTERNS: string[][] = [
  // Apollo Client 4.0 deprecation warnings (printf-style format)
  ['MockedProvider', 'addTypename', 'deprecated'],
  ['InMemoryCache', 'addTypename', 'deprecated'],
  ['useLazyQuery', 'variables', 'deprecated'],
  ['cache.diff', 'canonizeResults', 'deprecated'],
  ['ApolloLink', 'onError', 'deprecated'],

  // Apollo Client 4.0 deprecation warnings (URL-encoded format)
  // These show as "An error occurred! For more details, see the full error text at https://go.apollo.dev/c/err#..."
  ['go.apollo.dev/c/err'],

  // Apollo MockLink warnings - these indicate missing mocks in tests
  // but the full stack trace is too verbose for CI logs
  ['No more mocked responses for the query'],

  // Apollo refetchQueries warnings in test environment
  ['Unknown query named', 'refetchQueries'],

  // Apollo cache warnings about missing fields in mock data
  ['Missing field', 'while writing result'],

  // Apollo cache merge warnings (test environment artifact)
  ['Cache data may be lost when replacing'],

  // React Router v7 future flag warnings
  ['React Router Future Flag Warning', 'v7_startTransition'],
  ['React Router Future Flag Warning', 'v7_relativeSplatPath'],

  // GraphQL fragment duplicate warnings (test environment artifact)
  ['Warning: fragment with name', 'already exists'],

  // React act() warnings - often false positives in async tests
  ['not wrapped in act'],

  // React testing environment warnings
  ['testing environment is not configured to support act'],

  // React ref warnings on mocked components
  ['Function components cannot be given refs'],
]

/**
 * Check if console args should be suppressed based on known noise patterns.
 *
 * Note: Console messages may come as printf-style format strings with multiple args,
 * e.g., console.warn("[%s]: `%s` is deprecated", "InMemoryCache", "addTypename")
 * So we need to check ALL arguments, not just the first one.
 */
function shouldSuppressWarning(args: unknown[]): boolean {
  const fullMessage = args.map(String).join(' ')
  return SUPPRESSED_PATTERNS.some((pattern) => pattern.every((term) => fullMessage.includes(term)))
}

// Store original methods before any library can cache them
const originalWarn = console.warn.bind(console)
const originalError = console.error.bind(console)

// Replace console methods
console.warn = (...args: unknown[]) => {
  if (shouldSuppressWarning(args)) return
  originalWarn(...args)
}

console.error = (...args: unknown[]) => {
  if (shouldSuppressWarning(args)) return
  originalError(...args)
}
