/**
 * Parses a comma-separated filter value string into an array of { value } objects
 * for use with MultipleComboBox components.
 */
export const parseMultiFilterValue = (value?: string): { value: string }[] =>
  (value || '')
    .split(',')
    .filter((v) => !!v)
    .map((v) => ({ value: v }))

/**
 * Formats an array of { value } objects back into a comma-separated string
 * for filter state storage.
 */
export const formatMultiFilterValue = (items: { value: string }[]): string =>
  items.map((v) => v.value).join(',')
