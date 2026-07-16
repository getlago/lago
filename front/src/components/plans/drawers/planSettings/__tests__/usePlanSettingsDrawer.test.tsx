import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, render, renderHook, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { PlanDetailsV2Fragment, UpdatePlanDocument } from '~/generated/graphql'

import { planDetailsV2Fixture } from '../../../details-v2/__tests__/fixtures'
import { usePlanSettingsDrawer } from '../usePlanSettingsDrawer'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

type CapturedDrawerArgs = {
  title?: ReactNode
  children?: ReactNode
  mainAction?: ReactNode
  form?: { id: string; submit: () => void }
}

let lastDrawerArgs: CapturedDrawerArgs | null = null
const mockClose = jest.fn()
const mockUpdatePlanOverride = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useFormDrawer: () => ({
    open: jest.fn((args: CapturedDrawerArgs) => {
      lastDrawerArgs = args
    }),
    close: mockClose,
  }),
}))

jest.mock('~/hooks/plans/useUpdateSubscriptionPlanOverride', () => ({
  useUpdateSubscriptionPlanOverride: () => ({
    updatePlanOverride: (...args: unknown[]) => mockUpdatePlanOverride(...args),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const updateMockFactory = (cascadeUpdates: boolean | undefined): MockedResponse => ({
  request: { query: UpdatePlanDocument },
  variableMatcher: (vars) => {
    const input = vars?.input

    if (!input || input.id !== planDetailsV2Fixture.id || input.name !== 'Pro Renamed') {
      return false
    }
    if (cascadeUpdates === undefined) {
      return input.cascadeUpdates === undefined
    }
    return input.cascadeUpdates === cascadeUpdates
  },
  result: {
    data: { updatePlan: { ...planDetailsV2Fixture, name: 'Pro Renamed' } },
  },
})

// Renders the hook inside the Apollo + NiceModal context the real form needs,
// opens the drawer, and exposes the captured open() args via lastDrawerArgs.
const openDrawer = (
  plan: PlanDetailsV2Fragment = planDetailsV2Fixture,
  { subscriptionId, mocks = [] }: { subscriptionId?: string; mocks?: MockedResponse[] } = {},
) => {
  const { result } = renderHook(() => usePlanSettingsDrawer(plan, subscriptionId), {
    wrapper: ({ children }: { children: ReactNode }) => (
      <MockedProvider mocks={mocks} addTypename={false}>
        <NiceModal.Provider>{children}</NiceModal.Provider>
      </MockedProvider>
    ),
  })

  act(() => result.current.openDrawer())
}

const renderDrawerBody = () => {
  if (!lastDrawerArgs?.children) {
    throw new Error('Drawer was not opened')
  }
  return render(
    <MockedProvider mocks={[]} addTypename={false}>
      <NiceModal.Provider>{lastDrawerArgs.children}</NiceModal.Provider>
    </MockedProvider>,
  )
}

describe('usePlanSettingsDrawer', () => {
  beforeEach(() => {
    lastDrawerArgs = null
    mockClose.mockClear()
    mockUpdatePlanOverride.mockReset()
    mockUpdatePlanOverride.mockResolvedValue(true)
  })

  afterEach(() => {
    cleanup()
  })

  it('opens with current plan values pre-filled', async () => {
    openDrawer()

    expect(lastDrawerArgs?.title).toBe('text_642d5eb2783a2ad10d67031a')

    renderDrawerBody()

    await waitFor(() => {
      expect(screen.getByDisplayValue('Pro')).toBeInTheDocument()
    })
    expect(screen.getByDisplayValue('pro')).toBeInTheDocument()
  })

  it('submits updatePlan without opening the cascade dialog when no overrides exist', async () => {
    openDrawer(planDetailsV2Fixture, { mocks: [updateMockFactory(undefined)] })

    renderDrawerBody()

    await waitFor(() => screen.getByDisplayValue('Pro'))

    const nameInput = screen.getByDisplayValue('Pro') as HTMLInputElement

    await userEvent.clear(nameInput)
    await userEvent.type(nameInput, 'Pro Renamed')

    await act(async () => {
      lastDrawerArgs?.form?.submit()
    })

    await waitFor(() => {
      expect(screen.queryByText('text_1729604107534r3hsj7i64gp')).not.toBeInTheDocument()
    })
  })

  it('renders the save action', () => {
    openDrawer()

    // The mainAction render-prop renders the save button.
    render(
      <MockedProvider mocks={[]} addTypename={false}>
        <NiceModal.Provider>{lastDrawerArgs?.mainAction}</NiceModal.Provider>
      </MockedProvider>,
    )

    // testIdAttribute defaults to data-testid here, so assert on the label text.
    expect(screen.getByText('text_17295436903260tlyb1gp1i7')).toBeInTheDocument()
  })

  describe('GIVEN a subscriptionId (sub plan-override mode)', () => {
    // A plan carrying a description + tax so the override payload exercises both
    // the description normalization and the taxCodes mapper.
    const subPlan = {
      ...planDetailsV2Fixture,
      description: 'Pro description',
      taxes: [{ __typename: 'Tax' as const, id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }],
    }

    it('routes the edit through updateSubscription(planOverrides) instead of updatePlan', async () => {
      openDrawer(subPlan, { subscriptionId: 'sub-1' })

      renderDrawerBody()

      await waitFor(() => screen.getByDisplayValue('Pro'))

      await act(async () => {
        lastDrawerArgs?.form?.submit()
      })

      await waitFor(() => {
        expect(mockUpdatePlanOverride).toHaveBeenCalledWith({
          name: 'Pro',
          description: 'Pro description',
          taxCodes: ['vat'],
        })
      })
      // Drawer closes once the override resolves successfully.
      expect(mockClose).toHaveBeenCalled()
    })

    it('persists a renamed plan through the override payload', async () => {
      openDrawer(subPlan, { subscriptionId: 'sub-1' })

      renderDrawerBody()

      await waitFor(() => screen.getByDisplayValue('Pro'))

      const nameInput = screen.getByDisplayValue('Pro') as HTMLInputElement

      await userEvent.clear(nameInput)
      await userEvent.type(nameInput, 'Pro Renamed')

      await act(async () => {
        lastDrawerArgs?.form?.submit()
      })

      await waitFor(() => {
        expect(mockUpdatePlanOverride).toHaveBeenCalledWith({
          name: 'Pro Renamed',
          description: 'Pro description',
          taxCodes: ['vat'],
        })
      })
    })

    it('clears the description through the override payload (sends null, not undefined)', async () => {
      openDrawer(subPlan, { subscriptionId: 'sub-1' })

      renderDrawerBody()

      const descriptionInput = await screen.findByDisplayValue('Pro description')

      await userEvent.clear(descriptionInput)

      await act(async () => {
        lastDrawerArgs?.form?.submit()
      })

      await waitFor(() => {
        expect(mockUpdatePlanOverride).toHaveBeenCalledWith({
          name: 'Pro',
          description: null,
          taxCodes: ['vat'],
        })
      })
    })

    it('keeps the drawer open when the override does not succeed', async () => {
      mockUpdatePlanOverride.mockResolvedValueOnce(false)

      // Bare fixture (no description, no taxes) so the override payload also
      // exercises the empty-value normalization branches.
      openDrawer(planDetailsV2Fixture, { subscriptionId: 'sub-1' })

      renderDrawerBody()

      await waitFor(() => screen.getByDisplayValue('Pro'))

      await act(async () => {
        lastDrawerArgs?.form?.submit()
      })

      await waitFor(() => {
        expect(mockUpdatePlanOverride).toHaveBeenCalledWith({
          name: 'Pro',
          description: null,
          taxCodes: [],
        })
      })
      expect(mockClose).not.toHaveBeenCalled()
    })
  })

  describe('GIVEN a plan with subscriptions (plan-edit mode, no subscriptionId)', () => {
    it('locks the code field (ISO with the plan form)', async () => {
      openDrawer({ ...planDetailsV2Fixture, subscriptionsCount: 5 })

      renderDrawerBody()

      await waitFor(() => screen.getByDisplayValue('pro'))

      expect(screen.getByDisplayValue('pro')).toBeDisabled()
    })

    it('keeps the code field editable when the plan has no subscriptions', async () => {
      openDrawer({ ...planDetailsV2Fixture, subscriptionsCount: 0 })

      renderDrawerBody()

      await waitFor(() => screen.getByDisplayValue('pro'))

      expect(screen.getByDisplayValue('pro')).not.toBeDisabled()
    })
  })

  it('opens the cascade dialog when plan has overridden subs', async () => {
    openDrawer(
      { ...planDetailsV2Fixture, hasOverriddenPlans: true },
      {
        mocks: [updateMockFactory(true)],
      },
    )

    renderDrawerBody()

    await waitFor(() => screen.getByDisplayValue('Pro'))

    const nameInput = screen.getByDisplayValue('Pro') as HTMLInputElement

    await userEvent.clear(nameInput)
    await userEvent.type(nameInput, 'Pro Renamed')

    await act(async () => {
      lastDrawerArgs?.form?.submit()
    })

    await waitFor(() => {
      expect(screen.getByText('text_1729604107534r3hsj7i64gp')).toBeInTheDocument()
    })
  })
})
