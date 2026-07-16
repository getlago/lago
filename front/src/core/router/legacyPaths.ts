/**
 * Set of all first-level path segments from authenticated routes.
 *
 * Used by OrganizationLayout to distinguish legacy bookmarks (e.g. /customers)
 * from genuinely unknown org slugs (e.g. /typo-org). The backend RESERVED_SLUGS
 * list guarantees no org can ever have one of these as a slug, making the check
 * deterministic.
 *
 * TRANSITIONAL — to be removed once slug adoption is complete.
 *
 */
export const LEGACY_APP_PATH_SEGMENTS = new Set([
  'analytics',
  'analytics-v2',
  'forecasts',
  'customers',
  'customer',
  'plans',
  'plan',
  'billable-metrics',
  'billable-metric',
  'coupons',
  'coupon',
  'add-ons',
  'add-on',
  'invoices',
  'invoice',
  'payments',
  'payment',
  'credit-notes',
  'subscriptions',
  'features',
  'feature',
  'settings',
  'create',
  'update',
  'duplicate',
  'api-keys',
  'webhook',
])
