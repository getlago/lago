import { screen } from '@testing-library/react'

import {
  BillingTimeEnum,
  FeatureFlagEnum,
  NextSubscriptionTypeEnum,
  StatusTypeEnum,
  SubscriptionForSubscriptionInformationsFragment,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionDowngradeAlert, SubscriptionInformations } from '../SubscriptionInformations'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, params?: Record<string, string>) => {
      if (params) {
        return Object.entries(params).reduce(
          (acc, [k, v]) => acc.replace(`{{${k}}}`, String(v)),
          key,
        )
      }
      return key
    },
  }),
}))

const mockHasFeatureFlag = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasFeatureFlag: mockHasFeatureFlag,
    intlFormatDateTimeOrgaTZ: () => ({ date: '2025-01-01' }),
  }),
}))

jest.mock('~/components/billingEntity/BillingEntityLabel', () => ({
  BillingEntityLabel: () => <span data-test="billing-entity-label">billing-entity-label</span>,
}))

const baseSubscription: SubscriptionForSubscriptionInformationsFragment = {
  id: 'sub-1',
  externalId: 'ext-sub-1',
  status: StatusTypeEnum.Active,
  subscriptionAt: '2024-01-15T00:00:00Z',
  endingAt: null,
  terminatedAt: null,
  billingTime: BillingTimeEnum.Calendar,
  downgradePlanDate: null,
  nextSubscriptionAt: null,
  nextSubscriptionType: null,
  billingEntityId: 'entity-1',
  activationRules: [],
  nextPlan: null,
  previousPlan: null,
  previousSubscription: null,
  customer: {
    id: 'customer-1',
    name: 'Test Customer',
    displayName: 'Test Customer Display',
    externalId: 'ext-customer-1',
    deletedAt: null,
    billingEntity: {
      id: 'entity-1',
      code: 'default',
      name: 'Default Entity',
    },
  },
  plan: {
    id: 'plan-1',
    name: 'Basic Plan',
    parent: null,
  },
}

describe('SubscriptionInformations', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasFeatureFlag.mockReturnValue(false)
  })

  describe('GIVEN MultiEntityBilling feature flag is enabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN shows the billing entity row', () => {
        mockHasFeatureFlag.mockImplementation(
          (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiEntityBilling,
        )

        render(<SubscriptionInformations subscription={baseSubscription} />)

        expect(screen.getByTestId('billing-entity-label')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN MultiEntityBilling feature flag is disabled', () => {
    describe('WHEN the component renders', () => {
      it('THEN hides the billing entity row', () => {
        mockHasFeatureFlag.mockReturnValue(false)

        render(<SubscriptionInformations subscription={baseSubscription} />)

        expect(screen.queryByTestId('billing-entity-label')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a customer that is deleted', () => {
    describe('WHEN the component renders', () => {
      it('THEN shows the customer name with deleted suffix', () => {
        const deletedCustomerSubscription: SubscriptionForSubscriptionInformationsFragment = {
          ...baseSubscription,
          customer: {
            ...(baseSubscription.customer as SubscriptionForSubscriptionInformationsFragment['customer']),
            deletedAt: '2024-06-01T00:00:00Z',
          },
        }

        render(<SubscriptionInformations subscription={deletedCustomerSubscription} />)

        // The deleted suffix is a translation key: text_1764874328964clrgkmh7i9h
        expect(
          screen.getByText('Test Customer Display text_1764874328964clrgkmh7i9h'),
        ).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a customer that is not deleted', () => {
    describe('WHEN the component renders', () => {
      it('THEN shows the customer name without deleted suffix', () => {
        render(<SubscriptionInformations subscription={baseSubscription} />)

        expect(screen.getByText('Test Customer Display')).toBeInTheDocument()
        expect(
          screen.queryByText('Test Customer Display text_1764874328964clrgkmh7i9h'),
        ).not.toBeInTheDocument()
      })
    })
  })
})

describe('SubscriptionDowngradeAlert', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN a subscription with a downgrade next plan', () => {
    describe('WHEN the component renders', () => {
      it('THEN shows the downgrade alert', () => {
        const downgradeSubscription: SubscriptionForSubscriptionInformationsFragment = {
          ...baseSubscription,
          nextPlan: { id: 'plan-2', name: 'Downgrade Plan' },
          nextSubscriptionType: NextSubscriptionTypeEnum.Downgrade,
          downgradePlanDate: '2025-02-01T00:00:00Z',
        }

        const { container } = render(
          <SubscriptionDowngradeAlert subscription={downgradeSubscription} />,
        )

        expect(container.querySelector('[data-test="alert-type-info"]')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a subscription with no downgrade', () => {
    describe('WHEN the component renders', () => {
      it('THEN does not show the downgrade alert', () => {
        const { container } = render(<SubscriptionDowngradeAlert subscription={baseSubscription} />)

        expect(container.innerHTML).toBe('')
      })
    })
  })
})
