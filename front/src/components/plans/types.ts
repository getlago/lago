import {
  AddOnForFixedChargesSectionFragment,
  AppliedPricingUnitInput,
  BillableMetricForPlanFragment,
  ChargeFilterInput,
  ChargeInput,
  CommitmentInput,
  CreatePlanInput,
  EntitlementInput,
  EntitlementPrivilegeInput,
  FixedChargeInput,
  PrivilegeValueTypeEnum,
  PropertiesInput,
  TaxForPlanAndChargesInPlanFormFragment,
  TaxForPlanSettingsSectionFragment,
  TaxForTaxesSelectorSectionFragment,
  UsageThresholdInput,
} from '~/generated/graphql'

type LocalCommitmentInput = Omit<CommitmentInput, 'taxCodes'> & {
  taxes?: TaxForPlanAndChargesInPlanFormFragment[] | null
}

export enum LocalPricingUnitType {
  Custom = 'custom',
  Fiat = 'fiat',
}

export type LocalPricingUnitInput = Omit<AppliedPricingUnitInput, 'conversionRate'> & {
  shortName: string
  type: LocalPricingUnitType
  conversionRate?: string
}

export type LocalChargeFilterInput = Omit<ChargeFilterInput, 'properties' | 'values'> & {
  properties: PropertiesInput
  values: string[] // This value should be defined using transformFilterObjectToString method
}

export type LocalFixedChargeInput = Omit<FixedChargeInput, 'addOnId'> & {
  id?: string
  code?: string | null
  // NOTE: used for display purpose, replaced by taxCodes[] on save
  taxes?: TaxForTaxesSelectorSectionFragment[] | null
  // NOTE: used for display purpose, replaced by addOnId on save
  addOn: AddOnForFixedChargesSectionFragment
}

export type LocalUsageChargeInput = Omit<
  ChargeInput,
  'billableMetricId' | 'filters' | 'properties' | 'appliedPricingUnit'
> & {
  appliedPricingUnit?: LocalPricingUnitInput
  billableMetric: BillableMetricForPlanFragment
  id?: string
  code?: string | null
  properties?: PropertiesInput
  filters?: LocalChargeFilterInput[]
  // NOTE: this is used for display purpose but will be replaced by taxCodes[] on save
  taxes?: TaxForTaxesSelectorSectionFragment[] | null
}

export type LocalUsageThresholdInput = UsageThresholdInput

export type LocalPrivilegeInput = EntitlementPrivilegeInput & {
  // NOTE: this is used for display purpose but will be removed on save
  id?: string
  privilegeName: string | null | undefined
  valueType: PrivilegeValueTypeEnum
  config?: {
    selectOptions?: string[] | null
  }
}

export type LocalEntitlementInput = Omit<EntitlementInput, 'privileges'> & {
  featureId?: string
  featureName: string
  featureCode: string
  privileges: LocalPrivilegeInput[]
}

export type PlanFormInput = Omit<
  CreatePlanInput,
  'clientMutationId' | 'charges' | 'usageThresholds' | 'entitlements' | 'fixedCharges'
> & {
  fixedCharges: LocalFixedChargeInput[]
  charges: LocalUsageChargeInput[]
  // NOTE: this is used for display purpose but will be replaced by taxCodes[] on save
  taxes?: TaxForPlanSettingsSectionFragment[]
  minimumCommitment?: LocalCommitmentInput
  // NOTE: this is used for display purpose but will be replaced by usageThresholds[] on save
  nonRecurringUsageThresholds?: LocalUsageThresholdInput[]
  recurringUsageThreshold?: LocalUsageThresholdInput
  cascadeUpdates?: boolean
  entitlements: LocalEntitlementInput[]
}
