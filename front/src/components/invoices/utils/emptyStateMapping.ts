import {
  isDraftUrlParams,
  isOutstandingUrlParams,
  isPaymentDisputeLostUrlParams,
  isPaymentOverdueUrlParams,
  isSucceededUrlParams,
  isVoidedUrlParams,
} from '~/components/designSystem/Filters'
import { GenericPlaceholderProps } from '~/components/designSystem/GenericPlaceholder'
import { INVOICE_LIST_FILTER_PREFIX } from '~/core/constants/filters'
import { INVOICE_SETTINGS_ROUTE } from '~/core/router'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

const URL_PARAMS_TYPE = {
  succeeded: 'succeeded',
  draft: 'draft',
  outstanding: 'outstanding',
  voided: 'voided',
  paymentDisputeLost: 'paymentDisputeLost',
  paymentOverdue: 'paymentOverdue',
  default: 'default',
} as const

type UrlParamsType = (typeof URL_PARAMS_TYPE)[keyof typeof URL_PARAMS_TYPE]

type TranslationConfig = readonly [string, Record<string, string>?]

type TranslationMap = Partial<Record<UrlParamsType, TranslationConfig>> & {
  default: TranslationConfig
}

type TranslationKeysType = {
  withSearchTerm: {
    titles: TranslationMap
    subtitle: TranslationConfig
  }
  withoutSearchTerm: {
    titles: TranslationMap
    subtitle: TranslationMap
  }
}

const TRANSLATION_KEYS: TranslationKeysType = {
  withSearchTerm: {
    titles: {
      succeeded: ['text_63c67d2913c20b8d7d05c44c'],
      draft: ['text_63c67d2913c20b8d7d05c442'],
      outstanding: ['text_63c67d8796db41749ada51ca'],
      voided: ['text_65269cd46e7ec037a6823fd8'],
      default: ['text_63c67d2913c20b8d7d05c43e'],
    },
    subtitle: ['text_66ab48ea4ed9cd01084c60b8'],
  },
  withoutSearchTerm: {
    titles: {
      succeeded: ['text_63b578e959c1366df5d14559'],
      draft: ['text_63b578e959c1366df5d1455b'],
      outstanding: ['text_63b578e959c1366df5d1456e'],
      voided: ['text_65269cd46e7ec037a6823fd6'],
      paymentDisputeLost: ['text_66141e30699a0631f0b2ec7f'],
      paymentOverdue: ['text_666c5b12fea4aa1e1b26bf70'],
      default: ['text_63b578e959c1366df5d14569'],
    },
    subtitle: {
      succeeded: ['text_63b578e959c1366df5d1455f'],
      draft: ['text_63b578e959c1366df5d14566', { link: INVOICE_SETTINGS_ROUTE }],
      outstanding: ['text_63b578e959c1366df5d14570'],
      voided: ['text_65269cd46e7ec037a6823fda'],
      paymentDisputeLost: ['text_66141e30699a0631f0b2ec87'],
      paymentOverdue: ['text_666c5b12fea4aa1e1b26bf73', { link: INVOICE_SETTINGS_ROUTE }],
      default: ['text_63b578e959c1366df5d1456d'],
    },
  },
} as const

/**
 * Method to determine the URL params type from the URL search params.
 *
 * @param searchParams - The URL search params to get the URL params type from.
 * @returns The URL params type, based on URL_PARAMS_TYPE
 */
const getUrlParamsType = (searchParams: URLSearchParams): UrlParamsType => {
  if (isSucceededUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX })) {
    return URL_PARAMS_TYPE.succeeded
  }
  if (isDraftUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX })) {
    return URL_PARAMS_TYPE.draft
  }
  if (isOutstandingUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX })) {
    return URL_PARAMS_TYPE.outstanding
  }
  if (isVoidedUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX })) {
    return URL_PARAMS_TYPE.voided
  }
  if (isPaymentDisputeLostUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX })) {
    return URL_PARAMS_TYPE.paymentDisputeLost
  }
  if (isPaymentOverdueUrlParams({ searchParams, prefix: INVOICE_LIST_FILTER_PREFIX })) {
    return URL_PARAMS_TYPE.paymentOverdue
  }

  return URL_PARAMS_TYPE.default
}

/**
 * Factory function to get empty state configuration based on URL params and search term
 *
 * @param urlParams - The URL search params to get the URL params type from.
 * @param hasSearchTerm - Whether user is searching (affects which empty state to show)
 * @param translate - Translation function from useInternationalization hook
 * @returns Partial GenericPlaceholderProps with translated title and subtitle
 */
export const getEmptyStateConfig = ({
  hasSearchTerm,
  searchParams,
  translate,
}: {
  hasSearchTerm: boolean
  searchParams: URLSearchParams
  translate: TranslateFunc
}): Pick<GenericPlaceholderProps, 'title' | 'subtitle'> => {
  const urlParamsType = getUrlParamsType(searchParams)

  if (hasSearchTerm) {
    const titleConfig =
      TRANSLATION_KEYS.withSearchTerm.titles[urlParamsType] ||
      TRANSLATION_KEYS.withSearchTerm.titles.default
    const [titleKey, titleVariables = {}] = titleConfig

    const subtitleConfig = TRANSLATION_KEYS.withSearchTerm.subtitle
    const [subtitleKey, subtitleVariables = {}] = subtitleConfig

    return {
      title: translate(titleKey, titleVariables),
      subtitle: translate(subtitleKey, subtitleVariables),
    }
  }

  const [titleKey, titleVariables = {}] =
    TRANSLATION_KEYS.withoutSearchTerm.titles[urlParamsType] ||
    TRANSLATION_KEYS.withoutSearchTerm.titles.default

  const [subtitleKey, subtitleVariables = {}] =
    TRANSLATION_KEYS.withoutSearchTerm.subtitle[urlParamsType] ||
    TRANSLATION_KEYS.withoutSearchTerm.subtitle.default

  return {
    title: translate(titleKey, titleVariables),
    subtitle: translate(subtitleKey, subtitleVariables),
  }
}
