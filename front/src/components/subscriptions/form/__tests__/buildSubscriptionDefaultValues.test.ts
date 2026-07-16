import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { ActivationRuleFormTypeEnum } from '~/core/constants/subscriptionActivationRules'
import { ActivationRuleTypeEnum, BillingTimeEnum } from '~/generated/graphql'

import {
  buildSubscriptionDefaultValues,
  SubscriptionDefaultsSource,
} from '../buildSubscriptionDefaultValues'

const CURRENT_DATE = '2026-05-20T00:00:00.000Z'

const baseSubscription = {
  id: 'sub-1',
  name: 'My subscription',
  externalId: 'ext-1',
  subscriptionAt: '2026-01-01T00:00:00.000Z',
  endingAt: '2026-12-31T00:00:00.000Z',
  billingTime: BillingTimeEnum.Anniversary,
  plan: { id: 'plan-1' },
  paymentMethodType: null,
  paymentMethod: null,
  selectedInvoiceCustomSections: [],
  skipInvoiceCustomSections: false,
} as unknown as SubscriptionDefaultsSource

describe('buildSubscriptionDefaultValues', () => {
  describe('GIVEN no subscription (creation flow)', () => {
    it('THEN should return empty defaults with the provided currentDate', () => {
      const result = buildSubscriptionDefaultValues(
        undefined,
        FORM_TYPE_ENUM.creation,
        CURRENT_DATE,
      )

      expect(result).toEqual({
        planId: '',
        name: '',
        externalId: '',
        subscriptionAt: CURRENT_DATE,
        endingAt: undefined,
        billingTime: BillingTimeEnum.Calendar,
        paymentMethod: { paymentMethodType: undefined, paymentMethodId: undefined },
        invoiceCustomSection: { invoiceCustomSections: [], skipInvoiceCustomSections: false },
        consolidateInvoice: true,
        activationRuleType: ActivationRuleFormTypeEnum.Immediately,
        activationRuleTimeoutHours: '24',
      })
    })
  })

  describe('GIVEN a subscription with formType=edition', () => {
    it('THEN should hydrate planId, name, externalId, dates and billingTime from the subscription', () => {
      const result = buildSubscriptionDefaultValues(
        baseSubscription,
        FORM_TYPE_ENUM.edition,
        CURRENT_DATE,
      )

      expect(result).toMatchObject({
        planId: 'plan-1',
        name: 'My subscription',
        externalId: 'ext-1',
        subscriptionAt: '2026-01-01T00:00:00.000Z',
        endingAt: '2026-12-31T00:00:00.000Z',
        billingTime: BillingTimeEnum.Anniversary,
      })
    })
  })

  describe('GIVEN formType=upgradeDowngrade', () => {
    it('THEN should clear planId and name even when present on the subscription', () => {
      const result = buildSubscriptionDefaultValues(
        baseSubscription,
        FORM_TYPE_ENUM.upgradeDowngrade,
        CURRENT_DATE,
      )

      expect(result.planId).toBe('')
      expect(result.name).toBe('')
    })

    it('THEN should preserve other fields (externalId, dates, billingTime)', () => {
      const result = buildSubscriptionDefaultValues(
        baseSubscription,
        FORM_TYPE_ENUM.upgradeDowngrade,
        CURRENT_DATE,
      )

      expect(result.externalId).toBe('ext-1')
      expect(result.subscriptionAt).toBe('2026-01-01T00:00:00.000Z')
      expect(result.endingAt).toBe('2026-12-31T00:00:00.000Z')
      expect(result.billingTime).toBe(BillingTimeEnum.Anniversary)
    })
  })

  describe('GIVEN a subscription missing subscriptionAt', () => {
    it('THEN should fall back to the provided currentDate', () => {
      const subscription = {
        ...baseSubscription,
        subscriptionAt: undefined,
      } as unknown as SubscriptionDefaultsSource
      const result = buildSubscriptionDefaultValues(
        subscription,
        FORM_TYPE_ENUM.edition,
        CURRENT_DATE,
      )

      expect(result.subscriptionAt).toBe(CURRENT_DATE)
    })
  })

  describe('GIVEN a subscription with payment method + custom invoice sections', () => {
    it('THEN should map paymentMethod and invoiceCustomSection correctly', () => {
      const subscription = {
        ...baseSubscription,
        paymentMethodType: 'card',
        paymentMethod: { id: 'pm-1' },
        selectedInvoiceCustomSections: [{ id: 'section-1' }],
        skipInvoiceCustomSections: true,
      } as unknown as SubscriptionDefaultsSource
      const result = buildSubscriptionDefaultValues(
        subscription,
        FORM_TYPE_ENUM.edition,
        CURRENT_DATE,
      )

      expect(result.paymentMethod).toEqual({ paymentMethodType: 'card', paymentMethodId: 'pm-1' })
      expect(result.invoiceCustomSection).toEqual({
        invoiceCustomSections: [{ id: 'section-1' }],
        skipInvoiceCustomSections: true,
      })
    })
  })

  describe('GIVEN activation rule hydration', () => {
    describe('WHEN the subscription has no activation rules', () => {
      it('THEN should default to immediate activation with the default timeout', () => {
        const result = buildSubscriptionDefaultValues(
          baseSubscription,
          FORM_TYPE_ENUM.edition,
          CURRENT_DATE,
        )

        expect(result.activationRuleType).toBe(ActivationRuleFormTypeEnum.Immediately)
        expect(result.activationRuleTimeoutHours).toBe('24')
      })
    })

    describe('WHEN the subscription has a payment activation rule with a timeout', () => {
      it('THEN should hydrate on-payment activation with the timeout as a string', () => {
        const subscription = {
          ...baseSubscription,
          activationRules: [{ type: ActivationRuleTypeEnum.Payment, timeoutHours: 72 }],
        } as unknown as SubscriptionDefaultsSource

        const result = buildSubscriptionDefaultValues(
          subscription,
          FORM_TYPE_ENUM.edition,
          CURRENT_DATE,
        )

        expect(result.activationRuleType).toBe(ActivationRuleFormTypeEnum.OnPayment)
        expect(result.activationRuleTimeoutHours).toBe('72')
      })
    })

    describe('WHEN the payment activation rule has a null timeout', () => {
      it('THEN should hydrate on-payment activation with an empty timeout', () => {
        const subscription = {
          ...baseSubscription,
          activationRules: [{ type: ActivationRuleTypeEnum.Payment, timeoutHours: null }],
        } as unknown as SubscriptionDefaultsSource

        const result = buildSubscriptionDefaultValues(
          subscription,
          FORM_TYPE_ENUM.edition,
          CURRENT_DATE,
        )

        expect(result.activationRuleType).toBe(ActivationRuleFormTypeEnum.OnPayment)
        expect(result.activationRuleTimeoutHours).toBe('')
      })
    })
  })
})
