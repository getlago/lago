import { LocalPrivilegeInput } from '~/components/plans/types'

export interface FeatureEntitlementFormValues {
  featureId: string
  featureName: string
  featureCode: string
  privileges: LocalPrivilegeInput[]
}

export const DEFAULT_VALUES: FeatureEntitlementFormValues = {
  featureId: '',
  featureName: '',
  featureCode: '',
  privileges: [],
}
