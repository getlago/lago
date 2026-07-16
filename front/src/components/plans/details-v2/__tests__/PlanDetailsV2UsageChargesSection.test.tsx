import { MockedProvider } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef, ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'

import { buildUsageChargeFixture, planDetailsV2Fixture } from './fixtures'

import {
  PlanDetailsV2UsageChargesSection,
  PlanDetailsV2UsageChargesSectionRef,
} from '../PlanDetailsV2UsageChargesSection'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/usageCharge/UsageChargeDrawer', () => {
  const { forwardRef, useImperativeHandle } = jest.requireActual('react')

  const UsageChargeDrawer = forwardRef((_props: unknown, ref: unknown) => {
    useImperativeHandle(ref, () => ({ openDrawer: mockOpenDrawer, closeDrawer: mockCloseDrawer }))
    return null
  })

  return { __esModule: true, UsageChargeDrawer }
})

const mockHandleSaveCharge = jest.fn()
const mockHandleDeleteCharge = jest.fn()

const chargeMutations = {
  handleSaveCharge: mockHandleSaveCharge,
  handleDeleteCharge: mockHandleDeleteCharge,
}

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

// jsdom has no layout, so stub the virtualizer to yield every row. The plain
// (<= threshold) branch ignores it, so the existing tests are unaffected.
const mockScrollToIndex = jest.fn()

jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 98,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, index) => ({ index, start: index * 98, key: index })),
    measureElement: () => {},
    scrollToIndex: mockScrollToIndex,
  }),
}))

// Lazy wrapper so the factory doesn't touch the const before it initializes.
const mockOpenAccordionThenScrollTo = jest.fn()

jest.mock('~/core/utils/domUtils', () => ({
  ...jest.requireActual('~/core/utils/domUtils'),
  openAccordionThenScrollTo: (...args: unknown[]) => mockOpenAccordionThenScrollTo(...args),
}))

const Wrapper = ({ children }: { children: ReactNode }) => (
  <MockedProvider mocks={[]} addTypename={false}>
    <NiceModal.Provider>{children}</NiceModal.Provider>
  </MockedProvider>
)

describe('PlanDetailsV2UsageChargesSection', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockCloseDrawer.mockClear()
    mockHandleSaveCharge.mockClear()
    mockHandleDeleteCharge.mockClear()
    mockHasPermissions.mockReset().mockReturnValue(true)
    mockScrollToIndex.mockClear()
    mockOpenAccordionThenScrollTo.mockClear()
  })

  it('renders the empty-state helper when plan has no usage charges', () => {
    render(
      <PlanDetailsV2UsageChargesSection
        plan={planDetailsV2Fixture}
        chargeMutations={chargeMutations}
      />,
      { wrapper: Wrapper },
    )
    expect(screen.getByText('text_1779289915866ngi8sv5t9lg')).toBeInTheDocument()
    expect(screen.getByText('text_17797360854699edp5yofy8h')).toBeInTheDocument()
  })

  it('renders an accordion per usage charge with billable metric name + code', () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [
        buildUsageChargeFixture({ id: 'ch_1' }),
        buildUsageChargeFixture({
          id: 'ch_2',
          billableMetric: {
            __typename: 'BillableMetric',
            id: 'bm_2',
            name: 'Storage',
            code: 'storage',
            aggregationType: 'sum_agg',
            recurring: false,
            filters: [],
          } as never,
        }),
      ],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })

    expect(screen.getByText('API calls')).toBeInTheDocument()
    expect(screen.getByText('Storage')).toBeInTheDocument()
    expect(screen.queryByText('text_17797360854699edp5yofy8h')).not.toBeInTheDocument()
  })

  it('renders presentation group keys in the usage charge details', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [
        buildUsageChargeFixture({
          id: 'ch_with_presentation_group_keys',
          properties: {
            __typename: 'Properties',
            amount: '10',
            presentationGroupKeys: [
              {
                __typename: 'PresentationGroupKey',
                value: 'account_manager',
                options: {
                  __typename: 'PresentationGroupKeyOptions',
                  displayInInvoice: true,
                },
              },
            ],
          } as never,
        }),
      ],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByText('API calls'))

    expect(screen.getByText('text_17774502138912d3etwcacpe')).toBeInTheDocument()
    expect(screen.getByText('text_1777456950225zgyccgcm3x4')).toBeInTheDocument()
    expect(screen.getByText('account_manager')).toBeInTheDocument()
  })

  it('opens drawer with no args when Add CTA is clicked', async () => {
    render(
      <PlanDetailsV2UsageChargesSection
        plan={planDetailsV2Fixture}
        chargeMutations={chargeMutations}
      />,
      { wrapper: Wrapper },
    )
    await userEvent.click(await screen.findByText('text_1772133285142oouequiz2t2'))
    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledWith())
  })

  it('opens drawer with current values when Edit is clicked on a charge', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [buildUsageChargeFixture({ id: 'ch_1' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )
    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [chargeArg, indexArg] = mockOpenDrawer.mock.calls[0]

    expect(chargeArg.id).toBe('ch_1')
    expect(indexArg).toBe(0)
  })

  it('passes the already-used alert when the same billable metric backs >1 charge', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [buildUsageChargeFixture({ id: 'ch_1' }), buildUsageChargeFixture({ id: 'ch_2' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click((await screen.findAllByRole('button', { name: /actions/i }))[0])
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    )
    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
    const [, , options] = mockOpenDrawer.mock.calls[0]

    expect(options?.alreadyUsedChargeAlertMessage).toBe('text_6435895831d323008a47911f')
  })

  it('does NOT pass the already-used alert when the billable metric is unique', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [buildUsageChargeFixture({ id: 'ch_1' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
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
      charges: [buildUsageChargeFixture({ id: 'ch_to_delete' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63ea0f84f400488553caa786' }),
    )
    expect(mockHandleDeleteCharge).toHaveBeenCalledWith('ch_to_delete')
  })

  it('warns before deleting a charge when the plan has subscriptions', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      subscriptionsCount: 3,
      charges: [buildUsageChargeFixture({ id: 'ch_used' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63ea0f84f400488553caa786' }),
    )

    // The warning dialog defers the delete until the user confirms.
    expect(mockHandleDeleteCharge).not.toHaveBeenCalled()

    await userEvent.click(
      await screen.findByRole('button', { name: 'text_63cfe20ad6c1a53c5352a474' }),
    )
    await waitFor(() => expect(mockHandleDeleteCharge).toHaveBeenCalledWith('ch_used'))
  })

  // Drift test: lock in the Add CTA in plan mode so a future refactor can't drop it.
  it('keeps Add CTA visible when isInSubscriptionForm is false', () => {
    render(
      <PlanDetailsV2UsageChargesSection
        plan={planDetailsV2Fixture}
        chargeMutations={chargeMutations}
      />,
      { wrapper: Wrapper },
    )
    expect(screen.getByText('text_1772133285142oouequiz2t2')).toBeInTheDocument()
  })

  // Drift test: lock in that sub mode hides the Add CTA.
  it('hides the Add CTA when isInSubscriptionForm is true', () => {
    render(
      <PlanDetailsV2UsageChargesSection
        plan={planDetailsV2Fixture}
        isInSubscriptionForm
        chargeMutations={chargeMutations}
      />,
      {
        wrapper: Wrapper,
      },
    )
    expect(screen.queryByText('text_1772133285142oouequiz2t2')).not.toBeInTheDocument()
  })

  // Drift test: lock in that sub mode shows Edit but hides Delete (canUpdate=true, canDelete=false).
  it('shows Edit but hides Add + Delete when isInSubscriptionForm is true', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [buildUsageChargeFixture({ id: 'ch_sub' })],
    }

    render(
      <PlanDetailsV2UsageChargesSection
        plan={plan}
        isInSubscriptionForm
        chargeMutations={chargeMutations}
      />,
      {
        wrapper: Wrapper,
      },
    )
    // Actions menu renders because Edit is visible (canUpdate=true via subscriptionsUpdate)
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    // Edit IS present
    expect(screen.getByText('text_63e51ef4985f0ebd75c212fc')).toBeInTheDocument()
    // Delete is NOT present (canDelete=false in sub mode)
    expect(screen.queryByText('text_63ea0f84f400488553caa786')).not.toBeInTheDocument()
  })

  it('hides Delete when plansDelete permission is missing', async () => {
    mockHasPermissions.mockImplementation(
      ((perms: string[]) => !perms.includes('plansDelete')) as never,
    )
    const plan = {
      ...planDetailsV2Fixture,
      charges: [buildUsageChargeFixture({ id: 'ch_no_perm' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    expect(screen.queryByText('text_63ea0f84f400488553caa786')).not.toBeInTheDocument()
  })

  it('hides Edit when plansUpdate permission is missing', async () => {
    mockHasPermissions.mockImplementation(
      ((perms: string[]) => !perms.includes('plansUpdate')) as never,
    )
    const plan = {
      ...planDetailsV2Fixture,
      charges: [buildUsageChargeFixture({ id: 'ch_no_update' })],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByRole('button', { name: /actions/i }))
    expect(screen.queryByText('text_63e51ef4985f0ebd75c212fc')).not.toBeInTheDocument()
  })

  // Drift test: filters render as read-only — no actions menu appears next to a filter row.
  it('does not render an actions menu on filter accordions in the section body', async () => {
    const plan = {
      ...planDetailsV2Fixture,
      charges: [
        buildUsageChargeFixture({
          id: 'ch_with_filters',
          filters: [
            {
              __typename: 'ChargeFilter',
              id: 'flt_1',
              invoiceDisplayName: 'EU',
              values: ['{"region":"eu"}'] as never,
              properties: { amount: '15' } as never,
            } as never,
          ],
        }),
      ],
    }

    render(<PlanDetailsV2UsageChargesSection plan={plan} chargeMutations={chargeMutations} />, {
      wrapper: Wrapper,
    })
    await userEvent.click(await screen.findByText('API calls'))
    expect(screen.getAllByRole('button', { name: /actions/i })).toHaveLength(1)
  })

  it('exposes openCreate via ref', async () => {
    const ref = createRef<PlanDetailsV2UsageChargesSectionRef>()

    render(
      <PlanDetailsV2UsageChargesSection
        ref={ref}
        plan={planDetailsV2Fixture}
        chargeMutations={chargeMutations}
      />,
      {
        wrapper: Wrapper,
      },
    )
    ref.current?.openCreate()
    await waitFor(() => expect(mockOpenDrawer).toHaveBeenCalledTimes(1))
  })

  describe('charge-list virtualization', () => {
    const buildCharges = (count: number) =>
      Array.from({ length: count }, (_, i) => buildUsageChargeFixture({ id: `ch_${i}` }))

    const planWith = (count: number) => ({ ...planDetailsV2Fixture, charges: buildCharges(count) })

    it('renders the charge list through the virtualized path above the threshold', () => {
      const { container } = render(
        <PlanDetailsV2UsageChargesSection plan={planWith(51)} chargeMutations={chargeMutations} />,
        { wrapper: Wrapper },
      )

      // Virtualized rows carry data-index inside the positioned spacer.
      expect(container.querySelector('[data-index="0"]')).not.toBeNull()
    })

    it('renders the charge list as a plain list at or below the threshold', () => {
      const { container } = render(
        <PlanDetailsV2UsageChargesSection plan={planWith(3)} chargeMutations={chargeMutations} />,
        { wrapper: Wrapper },
      )

      expect(container.querySelector('[data-index]')).toBeNull()
    })

    it('drops the off-screen content-visibility on cards only when virtualized', () => {
      const virtualized = render(
        <PlanDetailsV2UsageChargesSection plan={planWith(51)} chargeMutations={chargeMutations} />,
        { wrapper: Wrapper },
      )

      expect(virtualized.container.querySelector('[class*="content-visibility"]')).toBeNull()

      const plain = render(
        <PlanDetailsV2UsageChargesSection plan={planWith(3)} chargeMutations={chargeMutations} />,
        { wrapper: Wrapper },
      )

      expect(plain.container.querySelector('[class*="content-visibility"]')).not.toBeNull()
    })

    it('scrollToCharge drives the virtualizer to the charge index when virtualized', () => {
      const ref = createRef<PlanDetailsV2UsageChargesSectionRef>()

      render(
        <PlanDetailsV2UsageChargesSection
          ref={ref}
          plan={planWith(51)}
          chargeMutations={chargeMutations}
        />,
        { wrapper: Wrapper },
      )

      ref.current?.scrollToCharge('ch_5')

      expect(mockScrollToIndex).toHaveBeenCalledWith(5, { align: 'start' })
    })

    it('scrollToCharge falls back to openAccordionThenScrollTo when not virtualized', () => {
      const ref = createRef<PlanDetailsV2UsageChargesSectionRef>()

      render(
        <PlanDetailsV2UsageChargesSection
          ref={ref}
          plan={planWith(3)}
          chargeMutations={chargeMutations}
        />,
        { wrapper: Wrapper },
      )

      ref.current?.scrollToCharge('ch_1')

      expect(mockOpenAccordionThenScrollTo).toHaveBeenCalledWith('ch_1')
      expect(mockScrollToIndex).not.toHaveBeenCalled()
    })
  })
})
