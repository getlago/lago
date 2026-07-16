import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef, ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'

import { buildFixedChargeFixture, planDetailsV2Fixture } from './fixtures'

import {
  PlanDetailsV2FixedChargesSection,
  PlanDetailsV2FixedChargesSectionRef,
} from '../PlanDetailsV2FixedChargesSection'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/fixedCharge/FixedChargeDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const FixedChargeDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: mockOpenDrawer, closeDrawer: mockCloseDrawer }))
    return null
  })

  return { __esModule: true, FixedChargeDrawer }
})

const mockHandleSaveCharge = jest.fn()
const mockHandleDeleteCharge = jest.fn()

const mockHasPermissions = jest.fn((perms?: string[]) => {
  if (!perms) return true
  return !perms.includes('none')
})

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: mockHasPermissions }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))

// Editing in subscription mode is premium-gated (useSubscriptionPremiumGate):
// a non-premium user gets the upsell modal instead of the edit drawer, so the
// override-pre-fill assertions need a premium user.
jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

const Wrapper = ({ children }: { children: ReactNode }) => (
  <MockedProvider mocks={[]} addTypename={false}>
    <NiceModal.Provider>{children}</NiceModal.Provider>
  </MockedProvider>
)

describe('PlanDetailsV2FixedChargesSection', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockCloseDrawer.mockClear()
    mockHandleSaveCharge.mockClear()
    mockHandleDeleteCharge.mockClear()
    mockHasPermissions.mockReset().mockReturnValue(true)
  })

  it('renders the empty-state helper when plan has no fixed charges', () => {
    render(
      <PlanDetailsV2FixedChargesSection
        plan={planDetailsV2Fixture}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    // Section header
    expect(screen.getByText('text_1779289915866aj39dyv1wps')).toBeInTheDocument()
    // Empty state
    expect(screen.getByText('text_1779477955768bq18jsqhaom')).toBeInTheDocument()
  })

  it('renders an accordion per fixed charge with name + code', () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [
        buildFixedChargeFixture({ id: 'fc_1' }),
        buildFixedChargeFixture({
          id: 'fc_2',
          addOn: { __typename: 'AddOn', id: 'a2', name: 'Migration', code: 'migration' },
        }),
      ],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    expect(screen.getByText('Onboarding')).toBeInTheDocument()
    expect(screen.getByText('Migration')).toBeInTheDocument()
    expect(screen.queryByText('text_1779477955768bq18jsqhaom')).not.toBeInTheDocument()
  })

  it('opens drawer with no args when Add CTA is clicked', async () => {
    render(
      <PlanDetailsV2FixedChargesSection
        plan={planDetailsV2Fixture}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByText('text_176072970726882uau5y69f1'))

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledWith())
  })

  it('opens drawer with current values when Edit is clicked on a charge', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_1' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [chargeArg, indexArg] = mockOpenDrawer.mock.calls[0]

    expect(chargeArg.id).toBe('fc_1')
    expect(indexArg).toBe(0)
  })

  it('passes the already-used alert when the same add-on backs >1 fixed charge', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [
        buildFixedChargeFixture({ id: 'fc_1' }),
        buildFixedChargeFixture({ id: 'fc_2' }),
      ],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click((await screen.findAllByRole('button', { name: /actions/i }))[0])
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [, , options] = mockOpenDrawer.mock.calls[0]

    expect(options?.alreadyUsedChargeAlertMessage).toBe('text_1760729707268h378x60alri')
  })

  it('does NOT pass the already-used alert when the add-on is unique', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_1' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [, , options] = mockOpenDrawer.mock.calls[0]

    expect(options?.alreadyUsedChargeAlertMessage).toBeUndefined()
  })

  it('calls handleDeleteCharge when Delete is clicked', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_to_delete' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63ea0f84f400488553caa786' }),
    )

    expect(mockHandleDeleteCharge).toHaveBeenCalledWith('fc_to_delete')
  })

  it('warns before deleting a fixed charge when the plan has subscriptions', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      subscriptionsCount: 3,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_used' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63ea0f84f400488553caa786' }),
    )

    // The warning dialog defers the delete until the user confirms.
    expect(mockHandleDeleteCharge).not.toHaveBeenCalled()

    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63cfe20ad6c1a53c5352a474' }),
    )
    await waitFor(() => expect(mockHandleDeleteCharge).toHaveBeenCalledWith('fc_used'))
  })

  // Drift test: lock in the Add CTA in plan mode so a future refactor can't drop it.
  it('keeps Add CTA visible when isInSubscriptionForm is false', () => {
    render(
      <PlanDetailsV2FixedChargesSection
        plan={planDetailsV2Fixture}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    expect(screen.getByText('text_176072970726882uau5y69f1')).toBeInTheDocument()
  })

  it('hides the Add CTA when isInSubscriptionForm is true', () => {
    render(
      <PlanDetailsV2FixedChargesSection
        plan={planDetailsV2Fixture}
        isInSubscriptionForm
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    expect(screen.queryByText('text_176072970726882uau5y69f1')).not.toBeInTheDocument()
  })

  it('shows Edit but hides Add + Delete when isInSubscriptionForm is true', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_sub' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        isInSubscriptionForm
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    // Actions menu renders because Edit is visible (canUpdate=true via subscriptionsUpdate)
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    // Edit IS present
    expect(screen.getByText('text_63e51ef4985f0ebd75c212fc')).toBeInTheDocument()
    // Delete is NOT present (canDelete=false in sub mode)
    expect(screen.queryByText('text_63ea0f84f400488553caa786')).not.toBeInTheDocument()
    // Add CTA is NOT present (canCreate=false in sub mode — already covered by the
    // 'hides the Add CTA when isInSubscriptionForm is true' test above)
  })

  it('hides Delete when plansDelete permission is missing', async () => {
    mockHasPermissions.mockImplementation(
      ((perms: string[]) => !perms.includes('plansDelete')) as any,
    )
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_no_perm' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    expect(screen.queryByText('text_63ea0f84f400488553caa786')).not.toBeInTheDocument()
  })

  it('hides Edit when plansUpdate permission is missing', async () => {
    mockHasPermissions.mockImplementation(
      ((perms: string[]) => !perms.includes('plansUpdate')) as any,
    )
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_no_update' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    expect(screen.queryByText('text_63e51ef4985f0ebd75c212fc')).not.toBeInTheDocument()
  })

  // Drift test: the subscription override map should take precedence over the
  // plan-level units when displaying a row and when pre-filling the edit drawer.
  it('uses subscriptionFixedChargeUnitsById to override displayed units', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_override', units: '5' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        isInSubscriptionForm
        subscriptionFixedChargeUnitsById={{ fc_override: '42' }}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [chargeArg] = mockOpenDrawer.mock.calls[0]
    // Drawer pre-fills with the override, not the plan default.

    expect(chargeArg.units).toBe('42')
  })

  // Reproduction: the VISIBLE units (FixedChargeInfo), not just the drawer
  // pre-fill, must reflect the per-subscription override.
  it('displays the override units in the accordion body, not the plan default', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_vis', units: '777' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        isInSubscriptionForm
        subscriptionFixedChargeUnitsById={{ fc_vis: '222' }}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    // Expand the accordion so its body (FixedChargeInfo) is visible.
    await userEvent.click(await screen.findByText('Onboarding'))

    expect(await screen.findByText('222')).toBeInTheDocument()
    expect(screen.queryByText('777')).not.toBeInTheDocument()
  })

  // Drift test: when no override is present for a charge, the plan-level value
  // remains visible. Guards against accidental nullish display in sub mode.
  it('falls back to plan units when no override is present', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      fixedCharges: [buildFixedChargeFixture({ id: 'fc_plain', units: '7' })],
    }

    render(
      <PlanDetailsV2FixedChargesSection
        plan={plan}
        isInSubscriptionForm
        subscriptionFixedChargeUnitsById={{}}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )

    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [chargeArg] = mockOpenDrawer.mock.calls[0]

    expect(chargeArg.units).toBe('7')
  })

  it('exposes openCreate via ref', async () => {
    const ref = createRef<PlanDetailsV2FixedChargesSectionRef>()

    render(
      <PlanDetailsV2FixedChargesSection
        ref={ref}
        plan={planDetailsV2Fixture}
        fixedChargeMutations={{
          handleSaveCharge: mockHandleSaveCharge,
          handleDeleteCharge: mockHandleDeleteCharge,
        }}
      />,
      { wrapper: Wrapper },
    )

    ref.current?.openCreate()
    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
  })
})
