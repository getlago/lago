import { renderHook } from '@testing-library/react'
import { generatePath } from 'react-router-dom'

import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE } from '~/core/router'
import { StatusTypeEnum } from '~/generated/graphql'

import { useRedirectIncompleteSubscription } from '../useRedirectIncompleteSubscription'

const mockNavigate = jest.fn()

jest.mock('~/core/router', () => ({
  ...jest.requireActual('~/core/router'),
  useNavigate: () => mockNavigate,
}))

const CUSTOMER_ID = 'cust-1'
const SUBSCRIPTION_ID = 'sub-1'

describe('useRedirectIncompleteSubscription', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN an incomplete subscription with a customer and subscription id', () => {
    describe('WHEN the hook runs', () => {
      it('THEN should redirect to the subscription overview, replacing history', () => {
        renderHook(() =>
          useRedirectIncompleteSubscription({
            customerId: CUSTOMER_ID,
            subscriptionId: SUBSCRIPTION_ID,
            subscriptionStatus: StatusTypeEnum.Incomplete,
          }),
        )

        const expectedPath = generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
          customerId: CUSTOMER_ID,
          subscriptionId: SUBSCRIPTION_ID,
          tab: CustomerSubscriptionDetailsTabsOptionsEnum.overview,
        })

        expect(mockNavigate).toHaveBeenCalledTimes(1)
        expect(mockNavigate).toHaveBeenCalledWith(expectedPath, { replace: true })
      })
    })
  })

  describe('GIVEN the redirect conditions are not met', () => {
    it.each([
      [
        'the status is not incomplete',
        {
          customerId: CUSTOMER_ID,
          subscriptionId: SUBSCRIPTION_ID,
          subscriptionStatus: StatusTypeEnum.Active,
        },
      ],
      [
        'the customer id is missing',
        {
          customerId: undefined,
          subscriptionId: SUBSCRIPTION_ID,
          subscriptionStatus: StatusTypeEnum.Incomplete,
        },
      ],
      [
        'the subscription id is missing',
        {
          customerId: CUSTOMER_ID,
          subscriptionId: null,
          subscriptionStatus: StatusTypeEnum.Incomplete,
        },
      ],
      [
        'the status is missing',
        {
          customerId: CUSTOMER_ID,
          subscriptionId: SUBSCRIPTION_ID,
          subscriptionStatus: null,
        },
      ],
    ])('THEN should not redirect when %s', (_, args) => {
      renderHook(() => useRedirectIncompleteSubscription(args))

      expect(mockNavigate).not.toHaveBeenCalled()
    })
  })

  describe('GIVEN a subscription that becomes incomplete after mount', () => {
    describe('WHEN the status updates to incomplete', () => {
      it('THEN should redirect once the conditions are met', () => {
        const { rerender } = renderHook((props) => useRedirectIncompleteSubscription(props), {
          initialProps: {
            customerId: CUSTOMER_ID,
            subscriptionId: SUBSCRIPTION_ID,
            subscriptionStatus: StatusTypeEnum.Pending,
          },
        })

        expect(mockNavigate).not.toHaveBeenCalled()

        rerender({
          customerId: CUSTOMER_ID,
          subscriptionId: SUBSCRIPTION_ID,
          subscriptionStatus: StatusTypeEnum.Incomplete,
        })

        expect(mockNavigate).toHaveBeenCalledTimes(1)
      })
    })
  })
})
