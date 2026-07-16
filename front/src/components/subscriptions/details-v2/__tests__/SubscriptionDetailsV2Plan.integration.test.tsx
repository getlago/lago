import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import {
  GetPlanForDetailsV2Document,
  GetSubscriptionFixedChargeUnitsOverridesDocument,
  GetSubscriptionForDetailsV2PlanDocument,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  buildFixedChargeFixture,
  PLAN_DETAILS_V2_FIXTURE_ID,
  planDetailsV2Fixture,
} from '../../../plans/details-v2/__tests__/fixtures'
import { SubscriptionDetailsV2Plan } from '../SubscriptionDetailsV2Plan'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

// Drawers/accordions pull import.meta (drawerStack) which crashes Jest — stub them.
jest.mock('~/components/plans/drawers/planSettings/usePlanSettingsDrawer', () => ({
  usePlanSettingsDrawer: () => ({ openDrawer: jest.fn() }),
}))
const stubRefDrawer = () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  return forwardRef((_p: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: jest.fn(), closeDrawer: jest.fn() }))
    return null
  })
}

jest.mock('~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer', () => ({
  __esModule: true,
  SubscriptionFeeDrawer: stubRefDrawer(),
}))
jest.mock('~/components/plans/drawers/fixedCharge/FixedChargeDrawer', () => ({
  __esModule: true,
  FixedChargeDrawer: stubRefDrawer(),
}))
jest.mock('~/components/plans/drawers/usageCharge/UsageChargeDrawer', () => ({
  __esModule: true,
  UsageChargeDrawer: stubRefDrawer(),
}))
jest.mock('~/components/plans/details-v2/accordions/MinimumCommitmentAccordion', () => ({
  __esModule: true,
  MinimumCommitmentAccordion: () => null,
}))
jest.mock('~/components/plans/details-v2/accordions/ProgressiveBillingAccordion', () => ({
  __esModule: true,
  ProgressiveBillingAccordion: () => null,
}))
jest.mock('~/components/plans/details-v2/accordions/EntitlementAccordion', () => ({
  __esModule: true,
  EntitlementAccordion: () => null,
}))
jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))
jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))
jest.mock('~/components/premium/PremiumFeature', () => ({ __esModule: true, default: () => null }))

const SUB_ID = 'sub_int_1'
const FC_ID = 'fc_int_1'

const planWithCharge = {
  ...planDetailsV2Fixture,
  id: PLAN_DETAILS_V2_FIXTURE_ID,
  hasOverriddenPlans: true,
  subscriptionsCount: 9,
  fixedCharges: [
    buildFixedChargeFixture({
      id: FC_ID,
      units: '5',
      addOn: { __typename: 'AddOn', id: 'addon_int', name: 'JuiceTax', code: 'juicetax' },
    }),
  ],
}

const subscriptionPlanMock = {
  request: {
    query: GetSubscriptionForDetailsV2PlanDocument,
    variables: { subscriptionId: SUB_ID },
  },
  result: {
    data: { subscription: { id: SUB_ID, plan: { ...planWithCharge, parent: null } } },
  },
}

const overridesMock = {
  request: {
    query: GetSubscriptionFixedChargeUnitsOverridesDocument,
    variables: { subscriptionId: SUB_ID },
  },
  result: {
    data: {
      subscription: {
        __typename: 'Subscription',
        id: SUB_ID,
        fixedCharges: [{ __typename: 'FixedCharge', id: FC_ID, units: '999' }],
      },
    },
  },
}

const planMock = {
  request: {
    query: GetPlanForDetailsV2Document,
    variables: { planId: PLAN_DETAILS_V2_FIXTURE_ID },
  },
  result: { data: { plan: planWithCharge } },
}

describe('SubscriptionDetailsV2Plan (integration)', () => {
  // Wires the real PlanDetailsV2 → section → FixedChargeInfo so the override
  // map is threaded and applied end-to-end (the row reads override ?? plan).
  it('shows the per-subscription override units (999), not the plan default (5)', async () => {
    render(
      <MockedProvider mocks={[subscriptionPlanMock, overridesMock, planMock]} addTypename>
        <NiceModal.Provider>
          <SubscriptionDetailsV2Plan subscriptionId={SUB_ID} />
        </NiceModal.Provider>
      </MockedProvider>,
    )

    // Expand the fixed-charge accordion to reveal its body (FixedChargeInfo).
    await userEvent.click(await screen.findByText('JuiceTax'))

    expect(await screen.findByText('999')).toBeInTheDocument()
    expect(screen.queryByText('5')).not.toBeInTheDocument()
  })
})
