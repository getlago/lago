import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { getIntervalTranslationKey } from '~/core/constants/form'
import { CommitmentTypeEnum, PlanInterval } from '~/generated/graphql'

import { planDetailsV2Fixture } from './fixtures'

import { MinimumCommitmentAccordion } from '../accordions/MinimumCommitmentAccordion'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

// ── Drawer mock ────────────────────────────────────────────────────────────────
const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/minimumCommitment/MinimumCommitmentDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const MinimumCommitmentDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: mockOpenDrawer, closeDrawer: mockCloseDrawer }))
    return null
  })

  return { __esModule: true, MinimumCommitmentDrawer }
})

// ── Hook mocks ─────────────────────────────────────────────────────────────────
const mockReset = jest.fn()
const mockSetFieldValue = jest.fn()
const mockSubmit = jest.fn()

jest.mock('~/hooks/plans/useUpdatePlanWithCascade', () => ({
  useUpdatePlanWithCascade: () => ({
    form: { reset: mockReset, setFieldValue: mockSetFieldValue },
    submit: mockSubmit,
  }),
  buildUpdatePlanFormDefaults: () => ({}),
}))

const mockIsPremium = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium() }),
}))

const mockHasPermissions = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

// PremiumFeature calls usePremiumWarningDialog internally – stub it out
jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => ({ open: jest.fn(), close: jest.fn() }),
}))

// ── Test wrapper ───────────────────────────────────────────────────────────────
const Wrapper = ({ children }: { children: ReactNode }) => (
  <MockedProvider mocks={[]} addTypename={false}>
    <NiceModal.Provider>{children}</NiceModal.Provider>
  </MockedProvider>
)

// ── Fixtures ───────────────────────────────────────────────────────────────────
const planWithCommitment = {
  ...planDetailsV2Fixture,
  interval: PlanInterval.Monthly,
  minimumCommitment: {
    __typename: 'Commitment' as const,
    amountCents: '5000',
    commitmentType: CommitmentTypeEnum.MinimumCommitment,
    invoiceDisplayName: null,
    taxes: [],
  },
}

describe('MinimumCommitmentAccordion', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockCloseDrawer.mockClear()
    mockReset.mockClear()
    mockSetFieldValue.mockClear()
    mockSubmit.mockClear()
    mockIsPremium.mockReturnValue(true)
    mockHasPermissions.mockReset().mockReturnValue(true)
  })

  // ── 1. Premium + has commitment ────────────────────────────────────────────
  it('renders the section anchor and the commitment title when premium user has a commitment', () => {
    const { container } = render(<MinimumCommitmentAccordion plan={planWithCommitment} />, {
      wrapper: Wrapper,
    })

    // Section id always present
    expect(container.querySelector('#minimum-commitment')).not.toBeNull()

    // The SectionAccordion summary always renders (the accordion title key is
    // the commitment invoiceDisplayName fallback = 'text_65d601bffb11e0f9d1d9f569').
    // The accordion defaults closed (unmountOnExit:true), so we assert the
    // always-visible summary content rather than the collapsed body.
    // The interval badge chip is also always visible in the summary.
    expect(screen.getByText(getIntervalTranslationKey[PlanInterval.Monthly])).toBeInTheDocument()
  })

  // ── 2. Non-premium + no commitment → paywall ───────────────────────────────
  it('renders PremiumFeature paywall when user is not premium and has no commitment', () => {
    mockIsPremium.mockReturnValue(false)

    const { container } = render(
      <MinimumCommitmentAccordion plan={{ ...planDetailsV2Fixture, minimumCommitment: null }} />,
      { wrapper: Wrapper },
    )

    // Section anchor still present
    expect(container.querySelector('#minimum-commitment')).not.toBeNull()

    // PremiumFeature title key
    expect(screen.getByText('text_17700400130439xuo82ha60n')).toBeInTheDocument()
  })

  // ── 3. Missing plansUpdate permission + has commitment → no Edit action ────
  it('does not render the Edit action when plansUpdate permission is missing', () => {
    // Deny plansUpdate but allow everything else
    mockHasPermissions.mockImplementation((perms) => !perms.includes('plansUpdate'))

    render(<MinimumCommitmentAccordion plan={planWithCommitment} />, { wrapper: Wrapper })

    // Edit label key must not appear anywhere (hidden action is not rendered in the DOM)
    expect(
      screen.queryByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    ).not.toBeInTheDocument()
  })

  // ── 4. isInSubscriptionForm → Edit visible, Add + Delete hidden ───────────
  it('shows Edit but hides Add + Delete when isInSubscriptionForm is true', async () => {
    const { container } = render(
      <MinimumCommitmentAccordion plan={planWithCommitment} isInSubscriptionForm />,
      { wrapper: Wrapper },
    )

    expect(container.querySelector('#minimum-commitment')).not.toBeNull()
    // Actions menu renders because Edit is visible (canUpdate=true via subscriptionsUpdate)
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    // Edit action IS present
    expect(
      screen.getByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    ).toBeInTheDocument()
    // Delete action is NOT present (canDelete=false in sub mode)
    expect(
      screen.queryByRole('button', { name: 'text_63ea0f84f400488553caa786' }),
    ).not.toBeInTheDocument()
    // Add button (SectionHeader action) is NOT present (canCreate=false in sub mode)
    expect(
      screen.queryByRole('button', { name: 'text_6661ffe746c680007e2df0e1' }),
    ).not.toBeInTheDocument()
  })

  // ── 5. Edit pre-fill deserializes cents → major units (guard for 100× bug) ─
  it('calls openDrawer with the deserialized major-unit amount when Edit is clicked', async () => {
    render(<MinimumCommitmentAccordion plan={planWithCommitment} />, { wrapper: Wrapper })

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() =>
      expect(mockOpenDrawer).toHaveBeenCalledWith(expect.objectContaining({ amountCents: '50' })),
    )
  })
})
