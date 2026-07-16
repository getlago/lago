import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { PlanInterval } from '~/generated/graphql'

import { planDetailsV2Fixture } from './fixtures'

import { SubscriptionFeeAccordion } from '../SubscriptionFeeAccordion'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const SubscriptionFeeDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: mockOpenDrawer, closeDrawer: mockCloseDrawer }))
    return null
  })

  return { __esModule: true, SubscriptionFeeDrawer }
})

const mockSetFieldValue = jest.fn()
const mockSubmit = jest.fn()

jest.mock('~/hooks/plans/useUpdatePlanWithCascade', () => ({
  useUpdatePlanWithCascade: () => ({
    form: { setFieldValue: mockSetFieldValue },
    submit: mockSubmit,
  }),
}))

const mockHasPermissions = jest.fn((perms?: string[]) => {
  if (!perms) return true
  return !perms.includes('none')
})

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const Wrapper = ({ children }: { children: ReactNode }) => (
  <MockedProvider mocks={[]} addTypename={false}>
    <NiceModal.Provider>{children}</NiceModal.Provider>
  </MockedProvider>
)

describe('SubscriptionFeeAccordion', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockCloseDrawer.mockClear()
    mockSetFieldValue.mockClear()
    mockSubmit.mockClear()
    mockHasPermissions.mockReset().mockReturnValue(true)
  })

  it('renders the section anchor with the subscription-fee id', () => {
    const { container } = render(<SubscriptionFeeAccordion plan={planDetailsV2Fixture} />, {
      wrapper: Wrapper,
    })

    expect(container.querySelector('#subscription-fee')).not.toBeNull()
  })

  it('falls back to the default title when plan has no invoiceDisplayName', () => {
    render(<SubscriptionFeeAccordion plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    expect(screen.getByText('text_642d5eb2783a2ad10d670336')).toBeInTheDocument()
  })

  it('uses plan.invoiceDisplayName as the title when present', () => {
    const plan = { ...planDetailsV2Fixture, invoiceDisplayName: 'Pro plan fee' }

    render(<SubscriptionFeeAccordion plan={plan} />, { wrapper: Wrapper })

    expect(screen.getByText('Pro plan fee')).toBeInTheDocument()
  })

  it('renders the interval badge resolved from plan.interval', () => {
    const plan = { ...planDetailsV2Fixture, interval: PlanInterval.Yearly }

    render(<SubscriptionFeeAccordion plan={plan} />, { wrapper: Wrapper })

    // Yearly interval translation key — surfaced inside the Chip badge via
    // getIntervalTranslationKey[PlanInterval.Yearly] in src/core/constants/form.ts.
    expect(screen.getByText('text_624453d52e945301380e49ac')).toBeInTheDocument()
  })

  it('does not render the interval badge when plan.interval is null', () => {
    const plan = { ...planDetailsV2Fixture, interval: null as never }

    render(<SubscriptionFeeAccordion plan={plan} />, { wrapper: Wrapper })

    // No interval keys should leak through when interval is missing.
    expect(screen.queryByText('text_624453d52e945301380e49ac')).not.toBeInTheDocument()
    expect(screen.queryByText('text_624453d52e945301380e49aa')).not.toBeInTheDocument()
  })

  it('opens drawer with current plan values when Edit is clicked', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      amountCents: '2500',
      payInAdvance: true,
      trialPeriod: 7,
      invoiceDisplayName: 'Pro plan fee',
    }

    render(<SubscriptionFeeAccordion plan={plan} />, { wrapper: Wrapper })

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    expect(mockOpenDrawer).toHaveBeenCalledWith({
      // Deserialized for the input: 2500 cents → 25 (USD). The drawer edits
      // display units and re-serializes on save.
      amountCents: '25',
      payInAdvance: true,
      trialPeriod: 7,
      invoiceDisplayName: 'Pro plan fee',
    })
  })

  it('passes empty amountCents string when plan.amountCents is null', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      amountCents: null as never,
    }

    render(<SubscriptionFeeAccordion plan={plan} />, { wrapper: Wrapper })

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    expect(mockOpenDrawer.mock.calls[0][0].amountCents).toBe('')
  })

  // Drift test: lock in the Edit action in plan mode so a future refactor can't drop it.
  it('keeps the Edit action visible when isInSubscriptionForm is false', () => {
    render(<SubscriptionFeeAccordion plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    expect(screen.getByRole('button', { name: /actions/i })).toBeInTheDocument()
  })

  // Drift test: lock in that sub mode shows the Edit action (canUpdate=true via subscriptionsUpdate).
  it('shows the Edit action when isInSubscriptionForm is true', () => {
    render(<SubscriptionFeeAccordion plan={planDetailsV2Fixture} isInSubscriptionForm />, {
      wrapper: Wrapper,
    })

    expect(screen.getByRole('button', { name: /actions/i })).toBeInTheDocument()
  })

  it('hides the Edit action when plansUpdate permission is missing', () => {
    mockHasPermissions.mockImplementation(
      ((perms: string[]) => !perms.includes('plansUpdate')) as never,
    )
    render(<SubscriptionFeeAccordion plan={planDetailsV2Fixture} />, { wrapper: Wrapper })

    expect(screen.queryByRole('button', { name: /actions/i })).not.toBeInTheDocument()
  })
})
