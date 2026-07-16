import {
  AvailableFiltersEnum,
  filterDataInlineSeparator,
} from '~/components/designSystem/Filters/types'
import { CurrencyEnum, FeatureFlagEnum } from '~/generated/graphql'

import { useBillingEntitiesOptions } from './useBillingEntitiesOptions'
import { useOrganizationInfos } from './useOrganizationInfos'

type CustomerFilterKind = 'currency' | 'entity'

type UseCustomerFilterDefaultsArgs = {
  /**
   * Currency to seed the default. Optional: when omitted, falls back to the
   * organization's default currency, then to `USD` as a safety net.
   * Only used when `withDefaults` is true.
   */
  customerCurrency?: CurrencyEnum
  filtersNamePrefix: string
  /**
   * Which filters this view wants to expose. Each kind is independently
   * subject to its own feature flag and resolution state — if either gates it
   * out, that kind is silently dropped from the returned `availableFilters`.
   */
  include: CustomerFilterKind[]
  /**
   * When true, seeds `staticFilters` so that the `<Filters.Provider>`
   * pre-populates the URL with default values on mount (e.g. customer
   * currency, default billing entity). Use for views where filters are
   * mandatory (analytics). Defaults to `false` — filters start empty.
   */
  withDefaults?: boolean
}

export type CustomerFilterProviderProps = {
  filtersNamePrefix: string
  availableFilters: AvailableFiltersEnum[]
  staticFilters?: Partial<Record<AvailableFiltersEnum, string>>
}

/**
 * Shared defaults for the currency + entity filter pair used across the
 * customer detail views (usage analytics, credit notes, payments, etc.).
 *
 * Each view stays inline with the project convention (mount its own
 * `<Filters.Provider>` in JSX) but reuses this hook to derive a ready-to-
 * spread props bundle — feature-flag gating, default value formatting, and
 * static URL population are all encapsulated here.
 *
 * Returns `null` when no filter would render (e.g. all flags off) so the
 * caller can skip the whole `<Filters.Provider>` block with a single check.
 *
 * @example
 *   const filtersProps = useCustomerFilterDefaults({
 *     customerCurrency,
 *     filtersNamePrefix: CUSTOMER_ANALYTICS_FILTER_PREFIX,
 *     include: ['currency', 'entity'],
 *   })
 *
 *   {filtersProps && (
 *     <Filters.Provider {...filtersProps}>
 *       <Filters.Component />
 *     </Filters.Provider>
 *   )}
 */
export const useCustomerFilterDefaults = ({
  customerCurrency,
  filtersNamePrefix,
  include,
  withDefaults = false,
}: UseCustomerFilterDefaultsArgs): CustomerFilterProviderProps | null => {
  const { organization, hasFeatureFlag } = useOrganizationInfos()
  const { options } = useBillingEntitiesOptions()
  const defaultBillingEntity = options.find((option) => option.isDefault) ?? options[0]

  const wantCurrency = include.includes('currency') && hasFeatureFlag(FeatureFlagEnum.MultiCurrency)
  const wantEntity =
    include.includes('entity') &&
    hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling) &&
    !!defaultBillingEntity

  const availableFilters: AvailableFiltersEnum[] = []

  if (wantCurrency) {
    availableFilters.push(AvailableFiltersEnum.currency)
  }

  if (wantEntity) {
    availableFilters.push(AvailableFiltersEnum.billingEntityId)
  }

  if (availableFilters.length === 0) return null

  if (!withDefaults) {
    return { filtersNamePrefix, availableFilters }
  }

  const resolvedCurrency = customerCurrency || organization?.defaultCurrency || CurrencyEnum.Usd
  const staticFilters: Partial<Record<AvailableFiltersEnum, string>> = {}

  if (wantCurrency) {
    staticFilters[AvailableFiltersEnum.currency] = resolvedCurrency
  }

  if (wantEntity && defaultBillingEntity) {
    staticFilters[AvailableFiltersEnum.billingEntityId] =
      `${defaultBillingEntity.id}${filterDataInlineSeparator}${defaultBillingEntity.name || defaultBillingEntity.value}`
  }

  return { filtersNamePrefix, availableFilters, staticFilters }
}
