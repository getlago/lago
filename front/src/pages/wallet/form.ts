import { DateTime } from 'luxon'
import { array, number, object, string } from 'yup'

import { dateErrorCodes } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { metadataSchema } from '~/formValidation/metadataSchema'
import {
  CurrencyEnum,
  RecurringTransactionMethodEnum,
  RecurringTransactionTriggerEnum,
} from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

export const walletFormErrorCodes = {
  targetOngoingBalanceShouldBeGreaterThanThreshold:
    'targetOngoingBalanceShouldBeGreaterThanThreshold',
  thresholdShouldBeLessThanTargetOngoingBalance: 'thresholdShouldBeLessThanTargetOngoingBalance',
} as const

enum TopUpAmountError {
  BelowMin = 'top-up-below-min',
  AboveMax = 'top-up-above-max',
  NotBetween = 'top-up-not-between',
}

export const topUpAmountError = ({
  rateAmount,
  paidCredits,
  paidTopUpMinAmountCents,
  paidTopUpMaxAmountCents,
  currency,
  translate,
  skip,
}: {
  rateAmount?: string
  paidCredits?: string
  paidTopUpMinAmountCents?: string
  paidTopUpMaxAmountCents?: string
  currency?: CurrencyEnum
  translate?: TranslateFunc
  skip?: boolean
}):
  | {
      error: TopUpAmountError
      label: string
    }
  | null
  | undefined => {
  if (skip) return
  if (!rateAmount || typeof paidCredits === 'undefined' || paidCredits === '') return
  if (Number(paidCredits) === 0) return

  const paidCreditsAmount = Number(rateAmount) * Number(paidCredits)
  const minCredits = Number(paidTopUpMinAmountCents) / Number(rateAmount)
  const maxCredits = Number(paidTopUpMaxAmountCents) / Number(rateAmount)
  const minAmount = intlFormatNumber(Number(paidTopUpMinAmountCents), {
    currency,
  })
  const maxAmount = intlFormatNumber(Number(paidTopUpMaxAmountCents), {
    currency,
  })
  const hasMin = typeof paidTopUpMinAmountCents !== 'undefined' && paidTopUpMinAmountCents !== null
  const hasMax = typeof paidTopUpMaxAmountCents !== 'undefined' && paidTopUpMaxAmountCents !== null
  const isBelow = paidCreditsAmount < Number(paidTopUpMinAmountCents)
  const isAbove = paidCreditsAmount > Number(paidTopUpMaxAmountCents)

  if (hasMin && hasMax && (isBelow || isAbove)) {
    return {
      error: TopUpAmountError.NotBetween,
      label: translate
        ? translate('text_1758285686647a868tiok58q', {
            minCredits,
            maxCredits,
            minAmount,
            maxAmount,
          })
        : '',
    }
  }

  if (hasMin && isBelow) {
    return {
      error: TopUpAmountError.BelowMin,
      label: translate
        ? translate('text_1758285686647tnf634qa99c', {
            minCredits,
            minAmount,
          })
        : '',
    }
  }

  if (hasMax && isAbove) {
    return {
      error: TopUpAmountError.AboveMax,
      label: translate
        ? translate('text_175828568664787kip4pzn8l', {
            maxCredits,
            maxAmount,
          })
        : '',
    }
  }

  return null
}

export const walletFormSchema = () => {
  return object().shape({
    name: string(),
    appliesTo: object()
      .shape({
        feeTypes: array().of(string()).nullable(),
      })
      .nullable(),
    expirationAt: string()
      .test({
        test: function (value, { path }) {
          // Value can be undefined
          if (!value) {
            return true
          }

          // Make sure value has correct format
          if (!DateTime.fromISO(value).isValid) {
            return this.createError({
              path,
              message: dateErrorCodes.wrongFormat,
            })
          }

          const endingAt = DateTime.fromISO(value)

          // Make sure endingAt is in the future
          if (DateTime.now().diff(endingAt, 'days').days >= 0) {
            return this.createError({
              path,
              message: dateErrorCodes.shouldBeInFuture,
            })
          }

          return true
        },
      })
      .nullable(),
    paidCredits: string().test({
      test: function (paidCredits) {
        const {
          paidTopUpMinAmountCents,
          paidTopUpMaxAmountCents,
          rateAmount,
          currency,
          ignorePaidTopUpLimitsOnCreation,
        } = this?.parent || {}

        const error = topUpAmountError({
          skip: ignorePaidTopUpLimitsOnCreation,
          paidCredits,
          rateAmount,
          paidTopUpMinAmountCents,
          paidTopUpMaxAmountCents,
          currency,
        })

        if (error?.error) {
          return false
        }

        return true
      },
    }),
    rateAmount: string().required(''),
    paidTopUpMinAmountCents: string().test({
      test: function (paidTopUpMinAmountCents) {
        const { paidTopUpMaxAmountCents } = this?.parent || {}

        if (isNaN(Number(paidTopUpMinAmountCents)) || isNaN(Number(paidTopUpMaxAmountCents))) {
          return true
        }

        if (Number(paidTopUpMinAmountCents) <= Number(paidTopUpMaxAmountCents)) {
          return true
        }

        return false
      },
    }),
    paidTopUpMaxAmountCents: string().test({
      test: function (paidTopUpMaxAmountCents) {
        const { paidTopUpMinAmountCents } = this?.parent || {}

        if (isNaN(Number(paidTopUpMaxAmountCents)) || isNaN(Number(paidTopUpMinAmountCents))) {
          return true
        }

        if (Number(paidTopUpMaxAmountCents) >= Number(paidTopUpMinAmountCents)) {
          return true
        }

        return false
      },
    }),
    recurringTransactionRules: array()
      .of(
        object().shape({
          trigger: string().required(''),
          method: string().required(''),
          interval: string()
            .test({
              test: function (interval) {
                const { trigger } = this?.parent || {}

                if (!!trigger && trigger !== RecurringTransactionTriggerEnum.Interval) {
                  return true
                }

                return !!interval
              },
            })
            .nullable(),
          thresholdCredits: string()
            .test({
              test: function (thresholdCredits, { path }) {
                const { trigger, targetOngoingBalance, method } = this?.parent || {}

                if (!!trigger && trigger !== RecurringTransactionTriggerEnum.Threshold) {
                  return true
                }

                if (
                  !!thresholdCredits &&
                  method === RecurringTransactionMethodEnum.Target &&
                  !!targetOngoingBalance &&
                  Number(targetOngoingBalance) < Number(thresholdCredits)
                ) {
                  return this.createError({
                    path,
                    message: walletFormErrorCodes.thresholdShouldBeLessThanTargetOngoingBalance,
                  })
                }

                return !!thresholdCredits
              },
            })
            .nullable(),
          paidCredits: string().test({
            test: function (paidCredits) {
              const { paidTopUpMinAmountCents, paidTopUpMaxAmountCents, rateAmount, currency } =
                this?.options?.context || {}

              const {
                grantedCredits: ruleGrantedCredit,
                method,
                ignorePaidTopUpLimits,
              } = this?.parent || {}

              const error = topUpAmountError({
                skip: ignorePaidTopUpLimits,
                paidCredits,
                rateAmount,
                paidTopUpMinAmountCents,
                paidTopUpMaxAmountCents,
                currency,
              })

              if (error?.error) {
                return false
              }

              if (!!method && method !== RecurringTransactionMethodEnum.Fixed) {
                return true
              }

              return !isNaN(Number(paidCredits)) || !isNaN(Number(ruleGrantedCredit))
            },
          }),
          grantedCredits: string().test({
            test: function (grantedCredits) {
              const { paidCredits: rulePaidCredit, method } = this?.parent || {}

              if (!!method && method !== RecurringTransactionMethodEnum.Fixed) {
                return true
              }

              return !isNaN(Number(grantedCredits)) || !isNaN(Number(rulePaidCredit))
            },
          }),
          targetOngoingBalance: string()
            .nullable()
            .test({
              test: function (targetOngoingBalance, { path }) {
                const { method, thresholdCredits, trigger } = this?.parent || {}

                if (!!method && method !== RecurringTransactionMethodEnum.Target) {
                  return true
                }

                if (!targetOngoingBalance && method === RecurringTransactionMethodEnum.Target) {
                  return this.createError()
                }

                if (
                  !!thresholdCredits &&
                  trigger === RecurringTransactionTriggerEnum.Threshold &&
                  !!targetOngoingBalance &&
                  Number(targetOngoingBalance) < Number(thresholdCredits)
                ) {
                  return this.createError({
                    path,
                    message: walletFormErrorCodes.targetOngoingBalanceShouldBeGreaterThanThreshold,
                  })
                }

                return !isNaN(Number(targetOngoingBalance))
              },
            }),
          startedAt: string()
            .nullable()
            .test({
              test: function (startedAt, { path }) {
                const { trigger } = this?.parent || {}

                if (!!trigger && trigger !== RecurringTransactionTriggerEnum.Interval) {
                  return true
                }

                if (startedAt && !DateTime.fromISO(startedAt).isValid) {
                  return this.createError({
                    path,
                    message: dateErrorCodes.wrongFormat,
                  })
                }

                return true
              },
            }),
          expirationAt: string()
            .test({
              test: function (value, { path }) {
                // Value can be undefined
                if (!value) {
                  return true
                }

                // Make sure value has correct format
                if (!DateTime.fromISO(value).isValid) {
                  return this.createError({
                    path,
                    message: dateErrorCodes.wrongFormat,
                  })
                }

                const endingAt = DateTime.fromISO(value)

                // Make sure endingAt is in the future
                if (DateTime.now().diff(endingAt, 'days').days >= 0) {
                  return this.createError({
                    path,
                    message: dateErrorCodes.shouldBeInFuture,
                  })
                }

                return true
              },
            })
            .nullable(),
          transactionMetadata: metadataSchema({ metadataKey: 'transactionMetadata' }).nullable(),
        }),
      )
      .nullable(),
    priority: number().min(1).max(50),
  })
}
