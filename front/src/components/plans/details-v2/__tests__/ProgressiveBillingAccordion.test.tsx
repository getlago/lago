import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { CurrencyEnum, PlanInterval, PremiumIntegrationTypeEnum } from '~/generated/graphql'

import { planDetailsV2Fixture } from './fixtures'

import { ProgressiveBillingAccordion } from '../accordions/ProgressiveBillingAccordion'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

// ── Drawer mock ────────────────────────────────────────────────────────────────
const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/progressiveBilling/ProgressiveBillingDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const ProgressiveBillingDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: mockOpenDrawer, closeDrawer: mockCloseDrawer }))
    return null
  })

  return { __esModule: true, ProgressiveBillingDrawer }
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

const mockPremiumIntegrations = jest
  .fn()
  .mockReturnValue([PremiumIntegrationTypeEnum.ProgressiveBilling])

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { premiumIntegrations: mockPremiumIntegrations() },
  }),
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
const planWithThresholds = {
  ...planDetailsV2Fixture,
  interval: PlanInterval.Monthly,
  amountCurrency: CurrencyEnum.Usd,
  usageThresholds: [
    {
      __typename: 'UsageThreshold' as const,
      id: 'ut_1',
      amountCents: '10000',
      recurring: false,
      thresholdDisplayName: null,
    },
    {
      __typename: 'UsageThreshold' as const,
      id: 'ut_2',
      amountCents: '20000',
      recurring: false,
      thresholdDisplayName: null,
    },
  ],
}

describe('ProgressiveBillingAccordion', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockCloseDrawer.mockClear()
    mockReset.mockClear()
    mockSetFieldValue.mockClear()
    mockSubmit.mockClear()
    mockPremiumIntegrations.mockReturnValue([PremiumIntegrationTypeEnum.ProgressiveBilling])
    mockHasPermissions.mockReset().mockReturnValue(true)
  })

  // ── 1. Has integration + has thresholds → read accordion ──────────────────
  it('renders the section anchor and the accordion summary when org has the integration and thresholds', () => {
    const { container } = render(<ProgressiveBillingAccordion plan={planWithThresholds} />, {
      wrapper: Wrapper,
    })

    // Section id always present
    expect(container.querySelector('#progressive-billing')).not.toBeNull()

    // Both SectionHeader and SectionAccordion render the same title key —
    // use getAllByText and assert at least one instance is present.
    expect(screen.getAllByText('text_1724179887722baucvj7bvc1').length).toBeGreaterThan(0)

    // The subtitle (threshold count) is unique in the collapsed summary
    expect(screen.getByText('text_1773950414511euzjefq877r')).toBeInTheDocument()
  })

  // ── 2. No integration + no thresholds → paywall ────────────────────────────
  it('renders PremiumFeature paywall when org lacks the integration and has no thresholds', () => {
    mockPremiumIntegrations.mockReturnValue([])

    const { container } = render(
      <ProgressiveBillingAccordion plan={{ ...planDetailsV2Fixture, usageThresholds: [] }} />,
      { wrapper: Wrapper },
    )

    // Section anchor still present
    expect(container.querySelector('#progressive-billing')).not.toBeNull()

    // PremiumFeature title key
    expect(screen.getByText('text_1724345142892pcnx5m2k3r2')).toBeInTheDocument()
  })

  // ── 3. Missing plansUpdate permission + thresholds → no Edit action ────────
  it('does not render the Edit action when plansUpdate permission is missing', () => {
    // Deny plansUpdate but allow everything else
    mockHasPermissions.mockImplementation((perms) => !perms.includes('plansUpdate'))

    render(<ProgressiveBillingAccordion plan={planWithThresholds} />, { wrapper: Wrapper })

    // Edit label key must not appear as a button (hidden action is not rendered in the DOM)
    expect(
      screen.queryByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    ).not.toBeInTheDocument()
  })

  // ── 4. Edit pre-fill deserializes cents → major units (guard for 100× bug) ─
  it('calls openDrawer with the deserialized major-unit amounts when Edit is clicked', async () => {
    render(<ProgressiveBillingAccordion plan={planWithThresholds} />, { wrapper: Wrapper })

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => {
      expect(mockOpenDrawer).toHaveBeenCalledTimes(1)
      const [arg] = mockOpenDrawer.mock.calls[0]

      expect(arg.nonRecurringUsageThresholds[0].amountCents).toBe('100')
    })
  })
})
