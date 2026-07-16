import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'

import { planDetailsV2Fixture } from './fixtures'

import { PlanDetailsV2PlanSettingsSection } from '../PlanDetailsV2PlanSettingsSection'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

const mockOpenDrawer = jest.fn()

// Mock the drawer hook: the section's only job is to wire the Edit action to it.
// The drawer's own behaviour is covered in usePlanSettingsDrawer.test.
jest.mock('~/components/plans/drawers/planSettings/usePlanSettingsDrawer', () => ({
  usePlanSettingsDrawer: () => ({ openDrawer: mockOpenDrawer }),
}))

jest.mock('../SubscriptionFeeAccordion', () => ({
  __esModule: true,
  SubscriptionFeeAccordion: () => null,
}))

const mockHasPermissions = jest.fn((perms?: string[]) => {
  if (!perms) return true
  return !perms.includes('none')
})

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

let mockIsPremium = true

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: mockIsPremium }),
}))

const mockOpenPremiumDialog = jest.fn()

jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => ({ open: mockOpenPremiumDialog, close: jest.fn() }),
}))

const Wrapper = ({ children }: { children: ReactNode }) => (
  <MockedProvider mocks={[]} addTypename={false}>
    <NiceModal.Provider>{children}</NiceModal.Provider>
  </MockedProvider>
)

describe('PlanDetailsV2PlanSettingsSection', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockOpenPremiumDialog.mockClear()
    mockHasPermissions.mockReset().mockReturnValue(true)
    mockIsPremium = true
  })

  it('renders the section header and accordion summary', () => {
    render(<PlanDetailsV2PlanSettingsSection plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    expect(screen.getAllByText('text_642d5eb2783a2ad10d67031a').length).toBeGreaterThan(0)
  })

  it('opens the drawer when Edit is clicked in plan mode', async () => {
    render(<PlanDetailsV2PlanSettingsSection plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
  })

  // Drift test (memory/feedback_drift_test_pattern.md): lock in the Edit
  // action present in plan mode so a future refactor can't silently drop it.
  it('should keep the Edit action wired when isInSubscriptionForm is undefined or false', async () => {
    render(<PlanDetailsV2PlanSettingsSection plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))

    expect(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    ).toBeInTheDocument()
  })

  it('shows the Plan settings Edit action in subscription context (routes through plan override)', async () => {
    // Sub mode now surfaces Edit: the editable settings (description + taxes) are
    // saved via updateSubscription(planOverrides) inside PlanSettingsDrawer, so the
    // action is gated only by canUpdate — subscriptionId no longer hides it.
    render(
      <PlanDetailsV2PlanSettingsSection
        plan={planDetailsV2Fixture}
        isInSubscriptionForm
        subscriptionId="sub_1"
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
  })

  // Drift test: sub plan-override editing is premium-gated. A freemium user's
  // Edit click opens the upsell modal instead of the drawer.
  it('opens the premium upsell instead of the drawer in subscription context for freemium users', async () => {
    mockIsPremium = false

    render(
      <PlanDetailsV2PlanSettingsSection
        plan={planDetailsV2Fixture}
        isInSubscriptionForm
        subscriptionId="sub_1"
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenPremiumDialog).toHaveBeenCalledTimes(1))
    expect(mockOpenDrawer).not.toHaveBeenCalled()
  })

  it('hides the Edit action when plansUpdate permission is missing', () => {
    mockHasPermissions.mockImplementation(
      ((perms: string[]) => !perms.includes('plansUpdate')) as never,
    )
    render(<PlanDetailsV2PlanSettingsSection plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    expect(screen.queryByRole('button', { name: /actions/i })).not.toBeInTheDocument()
  })
})
