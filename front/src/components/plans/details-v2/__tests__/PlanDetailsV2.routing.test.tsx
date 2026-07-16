import { MockedProvider } from '@apollo/client/testing'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { GetPlanForDetailsV2Document } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  buildUsageChargeFixture,
  PLAN_DETAILS_V2_FIXTURE_ID,
  planDetailsV2Fixture,
} from './fixtures'

import { PlanDetailsV2 } from '../PlanDetailsV2'

// Spy the section's imperative scrollToCharge so we can assert which sidebar ids
// route to it vs the generic openAccordionThenScrollTo.
const mockScrollToCharge = jest.fn()

jest.mock('../PlanDetailsV2UsageChargesSection', () => {
  const { forwardRef, useImperativeHandle, createElement } = jest.requireActual('react')

  const PlanDetailsV2UsageChargesSection = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openCreate: jest.fn(), scrollToCharge: mockScrollToCharge }))
    return createElement('section', { id: 'usage-charges' })
  })

  return { __esModule: true, PlanDetailsV2UsageChargesSection }
})

// Lazy wrapper so the factory doesn't touch the const before it initializes.
const mockOpenAccordionThenScrollTo = jest.fn()

jest.mock('~/core/utils/domUtils', () => ({
  ...jest.requireActual('~/core/utils/domUtils'),
  openAccordionThenScrollTo: (...args: unknown[]) => mockOpenAccordionThenScrollTo(...args),
}))

// Sibling sections pull drawers/accordions that crash Jest (import.meta) - stub them.
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

const accordionStub = (id: string) => () => {
  const { createElement } = jest.requireActual('react')

  return createElement('section', { id })
}

jest.mock('~/components/plans/details-v2/accordions/MinimumCommitmentAccordion', () => ({
  __esModule: true,
  MinimumCommitmentAccordion: accordionStub('minimum-commitment'),
}))

jest.mock('~/components/plans/details-v2/accordions/ProgressiveBillingAccordion', () => ({
  __esModule: true,
  ProgressiveBillingAccordion: accordionStub('progressive-billing'),
}))

jest.mock('~/components/plans/details-v2/accordions/EntitlementAccordion', () => ({
  __esModule: true,
  EntitlementAccordion: accordionStub('entitlements'),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => {
      const map: Record<string, string> = {
        text_1779289915866etwoweh1syv: 'Subscription fee',
        text_1779289915866ngi8sv5t9lg: 'Usage-based charges',
      }

      return map[key] ?? key
    },
  }),
}))

const planMock = {
  request: {
    query: GetPlanForDetailsV2Document,
    variables: { planId: PLAN_DETAILS_V2_FIXTURE_ID },
  },
  result: {
    data: {
      plan: {
        ...planDetailsV2Fixture,
        charges: [buildUsageChargeFixture({ id: 'uc-1', invoiceDisplayName: 'My Usage Charge' })],
      },
    },
  },
}

const renderDetails = () =>
  render(
    <MockedProvider mocks={[planMock]} addTypename={false}>
      <PlanDetailsV2 planId={PLAN_DETAILS_V2_FIXTURE_ID} />
    </MockedProvider>,
  )

describe('PlanDetailsV2 sidebar navigation routing', () => {
  beforeEach(() => {
    mockScrollToCharge.mockClear()
    mockOpenAccordionThenScrollTo.mockClear()
  })

  it('routes a usage-charge id to the section scrollToCharge (not the generic anchor jump)', async () => {
    renderDetails()

    await waitFor(() =>
      expect(screen.getByRole('navigation', { name: /plan sections/i })).toBeInTheDocument(),
    )

    // Expand the usage-charges folder, then click the charge child.
    await userEvent.click(screen.getByTestId('sidebar-toggle-usage-charges'))
    await userEvent.click(screen.getByRole('button', { name: 'My Usage Charge' }))

    expect(mockScrollToCharge).toHaveBeenCalledWith('uc-1')
    expect(mockOpenAccordionThenScrollTo).not.toHaveBeenCalled()
  })

  it('routes a non-charge section id to the generic openAccordionThenScrollTo', async () => {
    renderDetails()

    await waitFor(() =>
      expect(screen.getByRole('navigation', { name: /plan sections/i })).toBeInTheDocument(),
    )

    await userEvent.click(screen.getByRole('button', { name: 'Subscription fee' }))

    // 1-charge fixture is below the virtualization threshold, so the jump stays smooth.
    expect(mockOpenAccordionThenScrollTo).toHaveBeenCalledWith('subscription-fee', 'smooth')
    expect(mockScrollToCharge).not.toHaveBeenCalled()
  })
})
