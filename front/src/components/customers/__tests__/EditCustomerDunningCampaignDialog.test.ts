import { CurrencyEnum, EditCustomerDunningCampaignFragment } from '~/generated/graphql'

import { BehaviorType, getInitialBehavior } from '../EditCustomerDunningCampaignDialog'

describe('getInitialBehavior', () => {
  describe('WHEN customer has appliedDunningCampaign with id', () => {
    it('THEN returns NEW_CAMPAIGN', () => {
      const customer: EditCustomerDunningCampaignFragment = {
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-1',
        currency: CurrencyEnum.Usd,
        appliedDunningCampaign: {
          __typename: 'DunningCampaign',
          id: 'campaign-1',
        },
        excludeFromDunningCampaign: false,
      }

      const result = getInitialBehavior(customer)

      expect(result).toBe(BehaviorType.NEW_CAMPAIGN)
    })
  })

  describe('WHEN customer has excludeFromDunningCampaign set to true', () => {
    it('THEN returns DEACTIVATE', () => {
      const customer: EditCustomerDunningCampaignFragment = {
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-1',
        currency: CurrencyEnum.Usd,
        appliedDunningCampaign: null,
        excludeFromDunningCampaign: true,
      }

      const result = getInitialBehavior(customer)

      expect(result).toBe(BehaviorType.DEACTIVATE)
    })
  })

  describe('WHEN customer has no appliedDunningCampaign and excludeFromDunningCampaign is false', () => {
    it('THEN returns FALLBACK', () => {
      const customer: EditCustomerDunningCampaignFragment = {
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-1',
        currency: CurrencyEnum.Usd,
        appliedDunningCampaign: null,
        excludeFromDunningCampaign: false,
      }

      const result = getInitialBehavior(customer)

      expect(result).toBe(BehaviorType.FALLBACK)
    })
  })

  describe('WHEN customer has appliedDunningCampaign but id is null', () => {
    it('THEN returns DEACTIVATE if excludeFromDunningCampaign is true', () => {
      const customer: EditCustomerDunningCampaignFragment = {
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-1',
        currency: CurrencyEnum.Usd,
        appliedDunningCampaign: {
          __typename: 'DunningCampaign',
          id: '',
        },
        excludeFromDunningCampaign: true,
      }

      const result = getInitialBehavior(customer)

      expect(result).toBe(BehaviorType.DEACTIVATE)
    })

    it('THEN returns FALLBACK if excludeFromDunningCampaign is false', () => {
      const customer: EditCustomerDunningCampaignFragment = {
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-1',
        currency: CurrencyEnum.Usd,
        appliedDunningCampaign: {
          __typename: 'DunningCampaign',
          id: '',
        },
        excludeFromDunningCampaign: false,
      }

      const result = getInitialBehavior(customer)

      expect(result).toBe(BehaviorType.FALLBACK)
    })
  })
})
