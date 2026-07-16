import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { AggregationTypeEnum, ChargeModelEnum } from '~/generated/graphql'
import { render } from '~/test-utils'
import { createMockPlanForm } from '~/test-utils/createMockPlanForm'

import { LocalUsageChargeInput, PlanFormInput } from '../types'
import { USAGE_CHARGES_ADD_BUTTON_TEST_ID, UsageChargesSection } from '../UsageChargesSection'

// --- Mocks ---

const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/usageCharge/UsageChargeDrawer', () => {
  const React = jest.requireActual('react')

  const MockedDrawer = React.forwardRef((_props: unknown, ref: unknown) => {
    React.useImperativeHandle(ref, () => ({
      openDrawer: mockOpenDrawer,
      closeDrawer: mockCloseDrawer,
    }))

    return React.createElement('div', { 'data-test': 'usage-charge-drawer-mock' })
  })

  MockedDrawer.displayName = 'UsageChargeDrawer'

  return { UsageChargeDrawer: MockedDrawer }
})

jest.mock('~/components/plans/RemoveChargeWarningDialog', () => {
  const React = jest.requireActual('react')

  const MockedDialog = React.forwardRef((_props: unknown, ref: unknown) => {
    React.useImperativeHandle(ref, () => ({
      openDialog: jest.fn(),
      closeDialog: jest.fn(),
    }))

    return React.createElement('div', { 'data-test': 'remove-charge-warning-dialog-mock' })
  })

  MockedDialog.displayName = 'RemoveChargeWarningDialog'

  return { RemoveChargeWarningDialog: MockedDialog, RemoveChargeWarningDialogRef: {} }
})

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => `translated_${key}`,
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  useDuplicatePlanVar: () => ({ type: '' }),
  envGlobalVar: () => ({ sentryDsn: '', apiUrl: '', appVersion: '' }),
  initializeTranslations: jest.fn(),
}))

jest.mock('~/core/apolloClient/reactiveVars/duplicatePlanVar', () => ({
  useDuplicatePlanVar: () => ({ type: '' }),
}))

// jsdom has no layout; stub the virtualizer to yield every row so the virtualized
// branch is exercised. The plain (<= threshold) branch ignores it.
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 76,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, index) => ({ index, start: index * 76, key: index })),
    measureElement: () => {},
  }),
}))

class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}

beforeAll(() => {
  global.ResizeObserver = ResizeObserverMock
})

// --- Helpers ---

const createMockCharge = (overrides: Partial<LocalUsageChargeInput> = {}): LocalUsageChargeInput =>
  ({
    id: 'charge-1',
    chargeModel: ChargeModelEnum.Standard,
    invoiceDisplayName: 'Test Charge',
    payInAdvance: false,
    prorated: false,
    properties: { amount: '10' },
    billableMetric: {
      id: 'bm-1',
      name: 'API Calls',
      code: 'api_calls',
      aggregationType: AggregationTypeEnum.CountAgg,
      recurring: false,
      filters: [],
    },
    taxes: [],
    ...overrides,
  }) as unknown as LocalUsageChargeInput

const createForm = (overrides: Partial<PlanFormInput> = {}) => createMockPlanForm(overrides)

// --- Tests ---

describe('UsageChargesSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN there are no charges', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render the add usage charge button', () => {
        const form = createForm()

        render(<UsageChargesSection form={form} isEdition={false} />)

        expect(screen.getByTestId(USAGE_CHARGES_ADD_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the mocked drawer', () => {
        const form = createForm()

        render(<UsageChargesSection form={form} isEdition={false} />)

        expect(screen.getByTestId('usage-charge-drawer-mock')).toBeInTheDocument()
      })
    })

    describe('WHEN isInSubscriptionForm is true', () => {
      it('THEN should return null', () => {
        const form = createForm()

        const { container } = render(
          <UsageChargesSection form={form} isEdition={false} isInSubscriptionForm />,
        )

        expect(screen.queryByTestId(USAGE_CHARGES_ADD_BUTTON_TEST_ID)).not.toBeInTheDocument()
        // The component returns null when no charges and isInSubscriptionForm
        expect(container.querySelector('section')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN there are charges', () => {
    const charge = createMockCharge()

    describe('WHEN the component renders with metered charges', () => {
      it('THEN should render charge selectors', () => {
        const form = createForm({ charges: [charge] })

        render(<UsageChargesSection form={form} isEdition={false} />)

        expect(screen.getByTestId('usage-charge-selector-0')).toBeInTheDocument()
      })

      it('THEN should render both metered and recurring charges', () => {
        const meteredCharge = createMockCharge()
        const recurringCharge = createMockCharge({
          id: 'charge-2',
          billableMetric: {
            id: 'bm-2',
            name: 'Storage',
            code: 'storage',
            aggregationType: AggregationTypeEnum.CountAgg,
            recurring: true,
            filters: [],
          },
        })
        const form = createForm({ charges: [meteredCharge, recurringCharge] })

        render(<UsageChargesSection form={form} isEdition={false} />)

        expect(screen.getByTestId('usage-charge-selector-0')).toBeInTheDocument()
        expect(screen.getByTestId('usage-charge-selector-1')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the add button is visible', () => {
    describe('WHEN the user clicks the add usage charge button', () => {
      it('THEN should open the drawer', async () => {
        const user = userEvent.setup()
        const form = createForm()

        render(<UsageChargesSection form={form} isEdition={false} />)

        await user.click(screen.getByTestId(USAGE_CHARGES_ADD_BUTTON_TEST_ID))

        expect(mockOpenDrawer).toHaveBeenCalledTimes(1)
        expect(mockOpenDrawer).toHaveBeenCalledWith()
      })
    })
  })

  describe('GIVEN a charge exists and is not in a subscription', () => {
    describe('WHEN the user clicks on a charge selector', () => {
      it('THEN should open the drawer with the charge data', async () => {
        const user = userEvent.setup()
        const charge = createMockCharge()
        const form = createForm({ charges: [charge] })

        render(<UsageChargesSection form={form} isEdition={false} />)

        await user.click(screen.getByTestId('usage-charge-selector-0'))

        expect(mockOpenDrawer).toHaveBeenCalledTimes(1)
        expect(mockOpenDrawer).toHaveBeenCalledWith(charge, 0, {
          alreadyUsedChargeAlertMessage: undefined,
          initialCharge: undefined,
          isUsedInSubscription: false,
        })
      })
    })
  })

  describe('GIVEN the charge list crosses the virtualization threshold', () => {
    const buildCharges = (count: number) =>
      Array.from({ length: count }, (_, i) =>
        createMockCharge({
          id: `charge-${i}`,
          billableMetric: {
            id: `bm-${i}`,
            name: `Metric ${i}`,
            code: `metric_${i}`,
            aggregationType: AggregationTypeEnum.CountAgg,
            recurring: false,
            filters: [],
          },
        } as Partial<LocalUsageChargeInput>),
      )

    describe('WHEN there are more charges than the threshold', () => {
      it('THEN should render the charge list through the virtualized path', () => {
        const form = createForm({ charges: buildCharges(51) })

        const { container } = render(<UsageChargesSection form={form} isEdition={false} />)

        // Virtualized rows carry data-index inside the positioned spacer.
        expect(container.querySelector('[data-index="0"]')).not.toBeNull()
      })
    })

    describe('WHEN there are at or below the threshold', () => {
      it('THEN should render the charge list as a plain list (no virtual rows)', () => {
        const form = createForm({ charges: buildCharges(3) })

        const { container } = render(<UsageChargesSection form={form} isEdition={false} />)

        expect(container.querySelector('[data-index]')).toBeNull()
        expect(screen.getByTestId('usage-charge-selector-0')).toBeInTheDocument()
      })
    })
  })
})
