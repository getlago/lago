import { DateTime } from 'luxon'

import { DateFormat, intlFormatDateTime } from '~/core/timezone'
import { BillingTimeEnum, PlanInterval } from '~/generated/graphql'

export type BillingTimeHelperKey =
  { key: string; variables?: Record<string, string | number> } | undefined

export const getBillingTimeHelperKey = (
  billingTime: BillingTimeEnum,
  subscriptionAt: string | undefined,
  selectedPlanInterval: PlanInterval | undefined,
): BillingTimeHelperKey => {
  if (!selectedPlanInterval) return undefined

  const currentDate = subscriptionAt
    ? DateTime.fromISO(subscriptionAt)
    : DateTime.now().setLocale('en-gb')
  const formattedCurrentDate = currentDate.toFormat('LL/dd/yyyy')
  const february29 = `02/29/${DateTime.now().year}`
  const currentDay = currentDate.get('day')

  switch (selectedPlanInterval) {
    case PlanInterval.Monthly:
      if (billingTime === BillingTimeEnum.Calendar) {
        return { key: 'text_62ea7cd44cd4b14bb9ac1d7e' }
      }

      if (currentDay <= 28) {
        return { key: 'text_62ea7cd44cd4b14bb9ac1d82', variables: { day: currentDay } }
      } else if (currentDay === 29) {
        return { key: 'text_62ea7cd44cd4b14bb9ac1d86' }
      } else if (currentDay === 30) {
        return { key: 'text_62ea7cd44cd4b14bb9ac1d8a' }
      }
      return { key: 'text_62ea7cd44cd4b14bb9ac1d8e' }

    case PlanInterval.Yearly:
      if (billingTime === BillingTimeEnum.Calendar) {
        return { key: 'text_62ea7cd44cd4b14bb9ac1d92' }
      }

      if (formattedCurrentDate === february29) {
        return { key: 'text_62ea7cd44cd4b14bb9ac1d9a' }
      }

      return {
        key: 'text_62ea7cd44cd4b14bb9ac1d96',
        variables: {
          date: intlFormatDateTime(currentDate.toISO() || '', {
            formatDate: DateFormat.DATE_MED_SHORT,
          }).date,
        },
      }

    case PlanInterval.Semiannual:
      return billingTime === BillingTimeEnum.Calendar
        ? { key: 'text_1757502242292q05inkc09vq' }
        : {
            key: 'text_1757504174992y39ailqcch0',
            variables: {
              date: intlFormatDateTime(currentDate.toISO() || '', {
                formatDate: DateFormat.DATE_MED_SHORT,
              }).date,
            },
          }

    case PlanInterval.Quarterly:
      if (billingTime === BillingTimeEnum.Calendar) {
        return { key: 'text_64d6357b00dea100ad1cba34' }
      }

      if (currentDay <= 28) {
        return { key: 'text_64d6357b00dea100ad1cba36', variables: { day: currentDay } }
      } else if (currentDay === 29) {
        return { key: 'text_64d63ec2f6bd3f41a6e353ac' }
      } else if (currentDay === 30) {
        return { key: 'text_64d63ec2f6bd3f41a6e353b0' }
      }
      return { key: 'text_64d63ec2f6bd3f41a6e353b4' }

    case PlanInterval.Weekly:
    default:
      return billingTime === BillingTimeEnum.Calendar
        ? { key: 'text_62ea7cd44cd4b14bb9ac1d9e' }
        : {
            key: 'text_62ea7cd44cd4b14bb9ac1da2',
            variables: { day: currentDate.weekdayLong ?? '' },
          }
  }
}
