import { DateTime } from 'luxon'
import { z } from 'zod'

import {
  BillableMetricsForCouponsFragment,
  CouponExpiration,
  CouponFrequency,
  CouponTypeEnum,
  CurrencyEnum,
  PlansForCouponsFragment,
} from '~/generated/graphql'

// Custom Zod types for complex objects
const planSchema = z.custom<PlansForCouponsFragment>()
const billableMetricSchema = z.custom<BillableMetricsForCouponsFragment>()

export const couponValidationSchema = z
  .object({
    name: z.string().min(1, 'text_1771342980565bx64zqq2mjs'),
    code: z.string().min(1, 'text_1771342994699klxu2paz7g9'),
    description: z.string().optional(),
    couponType: z.enum(CouponTypeEnum),
    amountCents: z.union([z.string(), z.number()]).optional(),
    amountCurrency: z.enum(CurrencyEnum),
    percentageRate: z.union([z.string(), z.number()]).optional(),
    frequency: z.enum(CouponFrequency),
    frequencyDuration: z.union([z.string(), z.number()]).optional(),
    reusable: z.boolean(),
    expiration: z.enum(CouponExpiration),
    expirationAt: z.string().optional(),
    hasPlanLimit: z.boolean(),
    limitPlansList: z.array(planSchema),
    hasBillableMetricLimit: z.boolean(),
    limitBillableMetricsList: z.array(billableMetricSchema),
  })
  // Validate amountCents when couponType is FixedAmount
  .refine(
    (data) => {
      if (data.couponType !== CouponTypeEnum.FixedAmount) {
        return true
      }

      if (data.amountCents === undefined || data.amountCents === '') {
        return false
      }

      const amount = Number(data.amountCents)

      if (isNaN(amount)) {
        return false
      }

      return amount >= 0.001
    },
    {
      message: 'text_632d68358f1fedc68eed3e91',
      path: ['amountCents'],
    },
  )
  // Validate percentageRate when couponType is Percentage
  .refine(
    (data) => {
      if (data.couponType !== CouponTypeEnum.Percentage) {
        return true
      }

      if (data.percentageRate === undefined || data.percentageRate === '') {
        return false
      }

      const rate = Number(data.percentageRate)

      if (isNaN(rate)) {
        return false
      }

      return rate >= 0.001
    },
    {
      message: 'text_633445d00315a713775f02a6',
      path: ['percentageRate'],
    },
  )
  // Validate frequencyDuration when frequency is Recurring
  .refine(
    (data) => {
      if (data.frequency !== CouponFrequency.Recurring) {
        return true
      }

      if (data.frequencyDuration === undefined || data.frequencyDuration === '') {
        return false
      }

      const duration = Number(data.frequencyDuration)

      if (isNaN(duration)) {
        return false
      }

      return duration >= 1
    },
    {
      message: 'text_63314cfeb607e57577d894c9',
      path: ['frequencyDuration'],
    },
  )
  // Validate expirationAt when expiration is TimeLimit
  .refine(
    (data) => {
      if (data.expiration !== CouponExpiration.TimeLimit) {
        return true
      }

      if (!data.expirationAt) {
        return false
      }

      const expirationDate = DateTime.fromISO(data.expirationAt)
      const minDate = DateTime.now().plus({ days: -1 })

      return expirationDate >= minDate
    },
    {
      message: 'text_632d68358f1fedc68eed3ef2',
      path: ['expirationAt'],
    },
  )
  // Validate limitPlansList when hasPlanLimit is true
  .refine((data) => !data.hasPlanLimit || data.limitPlansList.length > 0, {
    message: 'text_1771344249653qh6ka7v6ot2',
    path: ['limitPlansList'],
  })
  // Validate limitBillableMetricsList when hasBillableMetricLimit is true
  .refine((data) => !data.hasBillableMetricLimit || data.limitBillableMetricsList.length > 0, {
    message: 'text_1771344249653wx8dh32y28w',
    path: ['limitBillableMetricsList'],
  })

export type CouponFormValues = z.infer<typeof couponValidationSchema>

export const emptyCouponDefaultValues: CouponFormValues = {
  name: '',
  code: '',
  description: '',
  couponType: CouponTypeEnum.FixedAmount,
  amountCents: undefined,
  amountCurrency: CurrencyEnum.Usd,
  percentageRate: undefined,
  frequency: CouponFrequency.Once,
  frequencyDuration: undefined,
  reusable: true,
  expiration: CouponExpiration.NoExpiration,
  expirationAt: undefined,
  hasPlanLimit: false,
  limitPlansList: [],
  hasBillableMetricLimit: false,
  limitBillableMetricsList: [],
}
