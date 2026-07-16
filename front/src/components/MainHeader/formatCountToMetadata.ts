import { TranslateFunc } from '~/hooks/core/useInternationalization'

/**
 * Formats a totalCount into a metadata string (e.g. "42 results").
 * Returns `undefined` if count is absent.
 */
export const formatCountToMetadata = (
  count: number | undefined | null,
  translate: TranslateFunc,
): string | undefined => {
  if (count === undefined || count === null) return undefined

  return translate('text_17740184000000_total_results', { count }, count)
}
