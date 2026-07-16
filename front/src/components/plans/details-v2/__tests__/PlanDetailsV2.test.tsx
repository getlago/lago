import { MockedProvider } from '@apollo/client/testing'
import { screen, waitFor } from '@testing-library/react'

import { GetPlanForDetailsV2Document } from '~/generated/graphql'
import { render } from '~/test-utils'

import { PLAN_DETAILS_V2_FIXTURE_ID, planDetailsV2Fixture } from './fixtures'

import { PlanDetailsV2 } from '../PlanDetailsV2'

// Mock the drawer hook (not a component): the section calls usePlanSettingsDrawer
// which pulls in the NiceModal drawer stack (drawerStack.ts uses import.meta and
// crashes Jest), so stub it to a no-op openDrawer.
jest.mock('~/components/plans/drawers/planSettings/usePlanSettingsDrawer', () => ({
  usePlanSettingsDrawer: () => ({ openDrawer: jest.fn() }),
}))

jest.mock('~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const SubscriptionFeeDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: jest.fn(), closeDrawer: jest.fn() }))
    return null
  })

  return { __esModule: true, SubscriptionFeeDrawer }
})

jest.mock('~/components/plans/drawers/fixedCharge/FixedChargeDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const FixedChargeDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: jest.fn(), closeDrawer: jest.fn() }))
    return null
  })

  return { __esModule: true, FixedChargeDrawer }
})

jest.mock('~/components/plans/drawers/usageCharge/UsageChargeDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const UsageChargeDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: jest.fn(), closeDrawer: jest.fn() }))
    return null
  })

  return { __esModule: true, UsageChargeDrawer }
})

jest.mock('~/components/plans/details-v2/accordions/MinimumCommitmentAccordion', () => {
  const React = jest.requireActual('react')

  return {
    __esModule: true,
    MinimumCommitmentAccordion: () => React.createElement('section', { id: 'minimum-commitment' }),
  }
})

jest.mock('~/components/plans/details-v2/accordions/ProgressiveBillingAccordion', () => {
  const React = jest.requireActual('react')

  return {
    __esModule: true,
    ProgressiveBillingAccordion: () =>
      React.createElement('section', { id: 'progressive-billing' }),
  }
})

jest.mock('~/components/plans/details-v2/accordions/EntitlementAccordion', () => {
  const React = jest.requireActual('react')

  return {
    __esModule: true,
    EntitlementAccordion: () => React.createElement('section', { id: 'entitlements' }),
  }
})

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const planMock = {
  request: {
    query: GetPlanForDetailsV2Document,
    variables: { planId: PLAN_DETAILS_V2_FIXTURE_ID },
  },
  result: { data: { plan: planDetailsV2Fixture } },
}

describe('PlanDetailsV2', () => {
  it('renders the sidebar and every plan section anchor once the query resolves', async () => {
    render(
      <MockedProvider mocks={[planMock]} addTypename={false}>
        <PlanDetailsV2 planId={PLAN_DETAILS_V2_FIXTURE_ID} />
      </MockedProvider>,
    )

    await waitFor(() =>
      expect(screen.getByRole('navigation', { name: /plan sections/i })).toBeInTheDocument(),
    )

    for (const id of [
      'plan-settings',
      'subscription-fee',
      'fixed-charges',
      'usage-charges',
      'minimum-commitment',
      'progressive-billing',
      'entitlements',
    ]) {
      expect(document.getElementById(id)).not.toBeNull()
    }
  })

  it('hides the sub-flow sections when isInSubscriptionForm=true', async () => {
    render(
      <MockedProvider mocks={[planMock]} addTypename={false}>
        <PlanDetailsV2 planId={PLAN_DETAILS_V2_FIXTURE_ID} isInSubscriptionForm />
      </MockedProvider>,
    )

    await waitFor(() =>
      expect(screen.getByRole('navigation', { name: /plan sections/i })).toBeInTheDocument(),
    )

    expect(document.getElementById('progressive-billing')).toBeNull()
    expect(document.getElementById('entitlements')).toBeNull()
    expect(document.getElementById('minimum-commitment')).not.toBeNull()
  })

  it('does not render the sidebar while the query is loading', () => {
    render(
      <MockedProvider mocks={[planMock]} addTypename={false}>
        <PlanDetailsV2 planId={PLAN_DETAILS_V2_FIXTURE_ID} />
      </MockedProvider>,
    )

    expect(screen.queryByRole('navigation', { name: /plan sections/i })).not.toBeInTheDocument()
  })
})
