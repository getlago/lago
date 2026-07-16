import { CurrencyEnum } from '~/generated/graphql'

import { TPeriodScopeTranslationLookupValue } from './MonthSelectorDropdown'

export type TGraphProps = {
  currency: CurrencyEnum | undefined
  period: TPeriodScopeTranslationLookupValue
  demoMode?: boolean
  className?: string
  blur?: boolean
  forceLoading?: boolean
}
