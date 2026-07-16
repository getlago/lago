export enum PlanDetailsV2SectionId {
  PlanSettings = 'plan-settings',
  SubscriptionFee = 'subscription-fee',
  FixedCharges = 'fixed-charges',
  UsageCharges = 'usage-charges',
  AdvancedSettings = 'advanced-settings',
  MinimumCommitment = 'minimum-commitment',
  ProgressiveBilling = 'progressive-billing',
  Entitlements = 'entitlements',
}

// Scroll-anchor id shared by the sidebar entitlement child item and its
// SectionAccordion on the right, so clicking the item resolves to its accordion.
export const getEntitlementSectionId = (code: string): string => `entitlement-${code}`
