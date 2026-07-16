/**
 * Stable `popperGroupName` values for the design-system Popper's single-open
 * coordination: poppers sharing a value are mutually exclusive (opening one
 * closes the others). Centralized so the strings can't drift via a misspell.
 */
export const POPPER_GROUP_NAME = {
  sectionAccordionActions: 'section-accordion-actions',
  subscriptionEntitlementActions: 'subscription-entitlement-actions',
} as const
