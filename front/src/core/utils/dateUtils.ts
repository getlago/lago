import { DateTime } from 'luxon'

/**
 * Converts a date string to the end of day in ISO format
 * @param dateString - The input date string in ISO format
 * @returns The date string converted to end of day in ISO format, or empty string if input is falsy
 */
export const endOfDayIso = (dateString: string | null | undefined): string => {
  if (!dateString) return ''

  return DateTime.fromISO(dateString).endOf('day').toISO() || ''
}
