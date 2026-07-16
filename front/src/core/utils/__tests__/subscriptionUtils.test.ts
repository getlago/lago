import { DateTime, Settings } from 'luxon'

import {
  ActivationRuleStatusEnum,
  ActivationRuleTypeEnum,
  CancellationReasonEnum,
  StatusTypeEnum,
} from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'

import {
  getPaymentActivationRule,
  getTimeoutDisplayValue,
  shouldShowTimeoutField,
} from '../subscriptionUtils'

const translate = ((key: string, variables?: Record<string, unknown>) => {
  if (key === 'text_1779882021466cfug4osir5m') return `In ${variables?.hours} hours`
  if (key === 'text_17798820214660s59bjuztra') return 'No timeout defined'
  if (key === 'text_1779882021466x423uayjorq') return 'Expired'
  if (key === 'text_1779882021466f56z1ymyt09') return 'In less than 1 hour'

  return key
}) as TranslateFunc

describe('subscriptionUtils', () => {
  beforeAll(() => {
    Settings.now = () => new Date('2026-04-10T12:00:00.000Z').valueOf()
  })

  afterAll(() => {
    Settings.now = () => Date.now()
  })

  it('returns the payment activation rule', () => {
    const paymentRule = {
      type: ActivationRuleTypeEnum.Payment,
      timeoutHours: 48,
      status: ActivationRuleStatusEnum.Pending,
      expiresAt: '2026-04-12T12:00:00.000Z',
    }

    expect(getPaymentActivationRule({ activationRules: [paymentRule] })).toBe(paymentRule)
  })

  it('shows timeout information for active payment-gated subscriptions', () => {
    expect(
      shouldShowTimeoutField({
        status: StatusTypeEnum.Active,
        activationRules: [
          {
            type: ActivationRuleTypeEnum.Payment,
            timeoutHours: 48,
            status: ActivationRuleStatusEnum.Satisfied,
            expiresAt: '2026-04-12T12:00:00.000Z',
          },
        ],
      }),
    ).toBe(true)
  })

  it('formats disabled timeouts as no timeout defined', () => {
    expect(
      getTimeoutDisplayValue(
        {
          status: StatusTypeEnum.Incomplete,
          activationRules: [
            {
              type: ActivationRuleTypeEnum.Payment,
              timeoutHours: 0,
              status: ActivationRuleStatusEnum.Pending,
              expiresAt: null,
            },
          ],
        },
        translate,
      ),
    ).toBe('No timeout defined')
  })

  it('formats an expired rule as expired even when the timeout is 0', () => {
    expect(
      getTimeoutDisplayValue(
        {
          status: StatusTypeEnum.Canceled,
          cancellationReason: CancellationReasonEnum.Timeout,
          activationRules: [
            {
              type: ActivationRuleTypeEnum.Payment,
              timeoutHours: 0,
              status: ActivationRuleStatusEnum.Expired,
              expiresAt: null,
            },
          ],
        },
        translate,
      ),
    ).toBe('Expired')
  })

  it('formats future expiration as a rounded-up hour count', () => {
    expect(
      getTimeoutDisplayValue(
        {
          status: StatusTypeEnum.Incomplete,
          activationRules: [
            {
              type: ActivationRuleTypeEnum.Payment,
              timeoutHours: 48,
              status: ActivationRuleStatusEnum.Pending,
              expiresAt: DateTime.now().plus({ hours: 2, minutes: 5 }).toISO(),
            },
          ],
        },
        translate,
      ),
    ).toBe('In 3 hours')
  })

  it('formats timeout cancellation as expired', () => {
    expect(
      getTimeoutDisplayValue(
        {
          status: StatusTypeEnum.Canceled,
          cancellationReason: CancellationReasonEnum.Timeout,
          activationRules: [
            {
              type: ActivationRuleTypeEnum.Payment,
              timeoutHours: 48,
              status: ActivationRuleStatusEnum.Expired,
              expiresAt: '2026-04-10T11:00:00.000Z',
            },
          ],
        },
        translate,
      ),
    ).toBe('Expired')
  })
})
