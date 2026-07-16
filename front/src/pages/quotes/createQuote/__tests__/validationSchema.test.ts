import { CurrencyEnum, OrderTypeEnum } from '~/generated/graphql'

import { createQuoteSchema } from '../validationSchema'

describe('createQuoteSchema', () => {
  it('validates a valid one_off quote', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.OneOff,
      subscriptionId: '',
    })

    expect(result.success).toBe(true)
  })

  it('validates a valid subscription_creation quote', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.SubscriptionCreation,
      subscriptionId: '',
    })

    expect(result.success).toBe(true)
  })

  it('validates a valid subscription_amendment quote with subscriptionId', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.SubscriptionAmendment,
      subscriptionId: 'sub-456',
    })

    expect(result.success).toBe(true)
  })

  it('fails when customerId is empty', () => {
    const result = createQuoteSchema.safeParse({
      customerId: '',
      orderType: OrderTypeEnum.OneOff,
      subscriptionId: '',
    })

    expect(result.success).toBe(false)
    if (!result.success) {
      expect(result.error.issues[0].path).toContain('customerId')
    }
  })

  it('fails when subscription_amendment has no subscriptionId', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.SubscriptionAmendment,
      subscriptionId: '',
    })

    expect(result.success).toBe(false)
    if (!result.success) {
      const paths = result.error.issues.map((i) => i.path).flat()

      expect(paths).toContain('subscriptionId')
    }
  })

  it('does not require subscriptionId for one_off', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.OneOff,
      subscriptionId: '',
    })

    expect(result.success).toBe(true)
  })

  it('does not require subscriptionId for subscription_creation', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.SubscriptionCreation,
      subscriptionId: '',
    })

    expect(result.success).toBe(true)
  })

  it('validates with owners array', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.OneOff,
      subscriptionId: '',
      owners: [{ value: 'user-1' }, { value: 'user-2' }],
    })

    expect(result.success).toBe(true)
  })

  it('validates without owners (optional field)', () => {
    const result = createQuoteSchema.safeParse({
      customerId: 'customer-123',
      orderType: OrderTypeEnum.OneOff,
      subscriptionId: '',
    })

    expect(result.success).toBe(true)
  })

  describe('GIVEN the currency field', () => {
    describe('WHEN a valid CurrencyEnum value is provided', () => {
      it('THEN should pass validation', () => {
        const result = createQuoteSchema.safeParse({
          customerId: 'customer-123',
          orderType: OrderTypeEnum.OneOff,
          subscriptionId: '',
          currency: CurrencyEnum.Usd,
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN currency is omitted', () => {
      it('THEN should pass validation (optional field)', () => {
        const result = createQuoteSchema.safeParse({
          customerId: 'customer-123',
          orderType: OrderTypeEnum.OneOff,
          subscriptionId: '',
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN currency is undefined', () => {
      it('THEN should pass validation', () => {
        const result = createQuoteSchema.safeParse({
          customerId: 'customer-123',
          orderType: OrderTypeEnum.OneOff,
          subscriptionId: '',
          currency: undefined,
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN an invalid currency value is provided', () => {
      it('THEN should fail validation', () => {
        const result = createQuoteSchema.safeParse({
          customerId: 'customer-123',
          orderType: OrderTypeEnum.OneOff,
          subscriptionId: '',
          currency: 'INVALID_CURRENCY',
        })

        expect(result.success).toBe(false)
      })
    })
  })
})
