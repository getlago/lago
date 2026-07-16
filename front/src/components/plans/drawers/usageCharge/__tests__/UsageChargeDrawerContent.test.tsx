import { act, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import type { VirtualFilterListProps } from '~/components/designSystem/VirtualList/VirtualFilterList'
import { ChargeModelEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import { UsageChargeDrawerContent as OriginalUsageChargeDrawerContent } from '../UsageChargeDrawerContent'

// Cast to strip the injected `form` prop that withForm adds to the type
const UsageChargeDrawerContent = OriginalUsageChargeDrawerContent as unknown as React.FC<{
  isCreateMode: boolean
  isEdition?: boolean
  disabled?: boolean
  isInSubscriptionForm?: boolean
  showCode?: boolean
  existingChargeCodes?: (string | null | undefined)[]
  amountCurrency?: string
  editIndex: number
  initialCharge?: unknown
  alreadyUsedChargeAlertMessage?: string
  currency: string
  interval: string
}>

// Mutable billable-metric query payload, swapped per-test (the `mock` prefix
// lets the jest.mock factory below close over it).
let mockBillableMetricsData: unknown = null

// Captures the `listeners` passed to each AppField by field name so tests can
// drive the billable-metric combobox onChange without a real form.
let capturedAppFieldListeners: Record<string, { onChange?: (arg: { value: unknown }) => void }> = {}

// --- Test ID constants ---

const CHARGE_MODEL_SELECTOR_TEST_ID = 'charge-model-selector'
const CHARGE_WRAPPER_SWITCH_TEST_ID = 'charge-wrapper-switch'
const PLAN_BILLING_PERIOD_INFO_SECTION_TEST_ID = 'plan-billing-period-info-section'
const CHARGE_PAY_IN_ADVANCE_OPTION_TEST_ID = 'charge-pay-in-advance-option'
const TAXES_SELECTOR_SECTION_TEST_ID = 'taxes-selector-section'
const BM_PICKER_COMBOBOX_TEST_ID = 'bm-picker-combobox'

// --- Mocks ---

const mockFormReset = jest.fn()
const mockSetFieldValue = jest.fn()
const mockGetFieldValue = jest.fn()

const mockDefaultFormValues = {
  billableMetricId: '',
  billableMetric: {
    id: '',
    name: '',
    code: '',
    aggregationType: 'count_agg',
    recurring: false,
  },
  chargeModel: ChargeModelEnum.Standard,
  invoiceDisplayName: '',
  invoiceable: true,
  minAmountCents: '',
  payInAdvance: false,
  prorated: false,
  properties: { amount: '', packageSize: '' },
  filters: [] as {
    values: string[]
    properties: Record<string, string>
    invoiceDisplayName: string
  }[],
  regroupPaidFees: null,
  taxes: [] as { id: string; code: string; name: string; rate: number }[],
}

const mockEditFormValues = {
  billableMetricId: 'bm-1',
  billableMetric: {
    id: 'bm-1',
    name: 'API Calls',
    code: 'api_calls',
    aggregationType: 'count_agg',
    recurring: false,
  },
  chargeModel: ChargeModelEnum.Standard,
  invoiceDisplayName: '',
  invoiceable: true,
  minAmountCents: '',
  payInAdvance: false,
  prorated: false,
  properties: { amount: '10', packageSize: '' },
  filters: [] as {
    values: string[]
    properties: Record<string, string>
    invoiceDisplayName: string
  }[],
  regroupPaidFees: null,
  taxes: [] as { id: string; code: string; name: string; rate: number }[],
}

const mockEditFormValuesWithFilters = {
  ...mockEditFormValues,
  billableMetric: {
    ...mockEditFormValues.billableMetric,
    filters: [{ id: 'f1', key: 'region', values: ['us', 'eu'] }],
  },
  filters: [
    {
      values: ['{"region":"us"}'],
      properties: { amount: '5', packageSize: '' },
      invoiceDisplayName: '',
    },
  ],
}

let mockCurrentFormValues = mockDefaultFormValues

const mockCreateStore = (values: Record<string, unknown>) => ({
  subscribe: jest.fn((cb: () => void) => {
    cb()
    return () => {}
  }),
  listeners: new Set(),
  state: { values },
})

const mockForm = {
  reset: mockFormReset,
  setFieldValue: mockSetFieldValue,
  getFieldValue: mockGetFieldValue,
  store: mockCreateStore(mockDefaultFormValues),
  state: { values: mockDefaultFormValues },
  AppField: ({
    children,
    name,
    listeners,
  }: {
    children: (field: unknown) => React.ReactNode
    name: string
    listeners?: { onChange?: (arg: { value: unknown }) => void }
  }) => {
    capturedAppFieldListeners[name] = listeners ?? {}

    const mockFieldApi = {
      state: { meta: { errors: [] } },
      TextInputField: (props: Record<string, unknown>) => (
        <input
          data-test={`field-${name}`}
          placeholder={props.placeholder as string}
          aria-label={props.label as string}
        />
      ),
      ComboBoxField: (props: Record<string, unknown>) => (
        <div data-test={BM_PICKER_COMBOBOX_TEST_ID} data-placeholder={props.placeholder as string}>
          combobox
        </div>
      ),
      SwitchField: (props: Record<string, unknown>) => (
        <input type="checkbox" data-test={`field-${name}`} aria-label={props.label as string} />
      ),
    }

    return <div data-field-name={name}>{children(mockFieldApi)}</div>
  },
}

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((_store: unknown, selector: (state: unknown) => unknown) =>
    selector({ values: mockCurrentFormValues }),
  ),
  revalidateLogic: jest.fn(() => ({})),
}))

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(() => mockForm),
  withForm: jest.fn((mockOpts: Record<string, unknown>) => {
    const mockRenderFn = mockOpts.render as (mockArgs: Record<string, unknown>) => any

    return (mockProps: Record<string, unknown>) => mockRenderFn({ ...mockProps, form: mockForm })
  }),
  withFieldGroup: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => `translated_${key}`,
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))

jest.mock('~/hooks/plans/useCustomPricingUnits', () => ({
  useCustomPricingUnits: () => ({ hasAnyPricingUnitConfigured: false }),
}))

jest.mock('~/hooks/plans/useChargeForm', () => ({
  useChargeForm: () => ({
    getUsageChargeModelComboboxData: jest.fn(() => []),
    getIsPayInAdvanceOptionDisabledForUsageCharge: jest.fn(() => false),
    getIsProRatedOptionDisabledForUsageCharge: jest.fn(() => false),
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  envGlobalVar: () => ({ sentryDsn: '', apiUrl: '', appVersion: '' }),
  initializeTranslations: jest.fn(),
}))

jest.mock('~/core/apolloClient/reactiveVars/currentOrganizationVar', () => {
  const { makeVar } = jest.requireActual('@apollo/client')

  return { currentOrganizationVar: makeVar(null) }
})

jest.mock('~/core/serializers/getPropertyShape', () => ({
  __esModule: true,
  default: () => ({ amount: '', packageSize: '' }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (c: string) => c,
  intlFormatNumber: jest.fn(),
}))

jest.mock('~/formValidation/chargePropertiesSchema', () => ({
  validateChargeProperties: jest.fn(),
}))

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useGetBillableMetricsLazyQuery: jest.fn(() => [jest.fn(), { data: mockBillableMetricsData }]),
    useGetMeteredBillableMetricsLazyQuery: jest.fn(() => [jest.fn(), { data: null }]),
    useGetRecurringBillableMetricsLazyQuery: jest.fn(() => [jest.fn(), { data: null }]),
  }
})

// withFieldGroup is mocked away (see useAppform mock), so the real ChargeCodeField
// renders nothing — stub it to assert mounting + the disabled wiring instead.
jest.mock('~/components/plans/drawers/common/ChargeCodeField', () => ({
  __esModule: true,
  default: (props: { disabled?: boolean }) => (
    <div data-test="charge-code-field" data-disabled={String(!!props.disabled)} />
  ),
}))

const mockDrawerOpen = jest.fn()
const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: mockDrawerOpen,
    close: mockDrawerClose,
  }),
}))

jest.mock('~/components/drawers/const', () => ({
  DRAWER_TRANSITION_DURATION: 0,
}))

// Prop-capturing mocks for child components
let lastChargeModelSelectorProps: Record<string, unknown> = {}
let lastChargePayInAdvanceOptionProps: Record<string, unknown> = {}

const mockSelectorActions: jest.Mock<null, [{ actions: Array<{ icon: string }> }]> = jest.fn()

jest.mock('~/components/designSystem/Selector', () => ({
  ...jest.requireActual('~/components/designSystem/Selector'),
  SelectorActions: (props: { actions: Array<{ icon: string }> }) => mockSelectorActions(props),
}))

jest.mock('~/components/plans/chargeAccordion/ChargeModelSelector', () => ({
  ChargeModelSelector: (props: Record<string, unknown>) => {
    lastChargeModelSelectorProps = props
    return <div data-test={CHARGE_MODEL_SELECTOR_TEST_ID} />
  },
}))

jest.mock('~/components/plans/chargeAccordion/ChargeWrapperSwitch', () => ({
  ChargeWrapperSwitch: () => <div data-test={CHARGE_WRAPPER_SWITCH_TEST_ID} />,
}))

jest.mock('~/components/plans/chargeAccordion/CustomPricingUnitSelector', () => ({
  CustomPricingUnitSelector: () => <div data-test="custom-pricing-unit-selector" />,
}))

jest.mock('~/components/plans/drawers/common/PlanBillingPeriodInfoSection', () => ({
  PlanBillingPeriodInfoSection: () => <div data-test={PLAN_BILLING_PERIOD_INFO_SECTION_TEST_ID} />,
}))

jest.mock('~/components/plans/chargeAccordion/options/ChargePayInAdvanceOption', () => ({
  ChargePayInAdvanceOption: (props: Record<string, unknown>) => {
    lastChargePayInAdvanceOptionProps = props
    return <div data-test={CHARGE_PAY_IN_ADVANCE_OPTION_TEST_ID} />
  },
}))

jest.mock('~/components/plans/chargeAccordion/options/ChargeInvoicingStrategyOption', () => ({
  ChargeInvoicingStrategyOption: () => <div data-test="charge-invoicing-strategy-option" />,
}))

const mockSpendingMinimumOptionSection: jest.Mock<null, [{ disabled?: boolean }]> = jest.fn()

jest.mock('~/components/plans/chargeAccordion/SpendingMinimumOptionSection', () => ({
  SpendingMinimumOptionSection: (props: { disabled?: boolean }) => {
    mockSpendingMinimumOptionSection(props)
    return <div data-test="spending-minimum-option-section" />
  },
}))

jest.mock('~/components/taxes/TaxesSelectorSection', () => ({
  TaxesSelectorSection: () => <div data-test={TAXES_SELECTOR_SECTION_TEST_ID} />,
}))

jest.mock('~/components/plans/chargeAccordion/ChargeFilter', () => ({
  ChargeFilter: () => <div data-test="charge-filter" />,
  buildChargeFilterAddFilterButtonId: jest.fn(() => 'filter-btn-id'),
}))

jest.mock('~/components/plans/drawers/usageCharge/ChargeFilterDrawerContent', () => ({
  ChargeFilterDrawerContent: () => <div data-test="charge-filter-drawer-content" />,
  chargeFilterDrawerSchema: {},
}))

jest.mock('~/contexts/ChargeFilterDrawerContext', () => ({
  ChargeFilterDrawerProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))

jest.mock('~/components/plans/utils', () => ({
  mapChargeIntervalCopy: jest.fn(() => ({})),
}))

// --- Tests ---

describe('UsageChargeDrawerContent', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockCurrentFormValues = mockDefaultFormValues
    mockForm.store = mockCreateStore(mockDefaultFormValues)
    mockForm.state = { values: mockDefaultFormValues }
    mockBillableMetricsData = null
    capturedAppFieldListeners = {}
    lastChargeModelSelectorProps = {}
    lastChargePayInAdvanceOptionProps = {}
    mockSelectorActions.mockClear()
    mockSpendingMinimumOptionSection.mockClear()
  })

  describe('GIVEN create mode with no billable metric selected', () => {
    describe('WHEN it renders', () => {
      it('THEN should render the billable metric picker combobox', () => {
        mockCurrentFormValues = mockDefaultFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode
            editIndex={-1}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId(BM_PICKER_COMBOBOX_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should NOT render the charge model selector', () => {
        mockCurrentFormValues = mockDefaultFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode
            editIndex={-1}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.queryByTestId(CHARGE_MODEL_SELECTOR_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN edit mode with a billable metric selected', () => {
    describe('WHEN it renders', () => {
      it('THEN should render the charge model selector', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId(CHARGE_MODEL_SELECTOR_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the charge wrapper switch', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId(CHARGE_WRAPPER_SWITCH_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should NOT render the billable metric picker combobox', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.queryByTestId(BM_PICKER_COMBOBOX_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a billable metric with filters', () => {
    describe('WHEN filters are present on the charge', () => {
      it('THEN should render filter selectors', () => {
        mockCurrentFormValues = mockEditFormValuesWithFilters

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId('filter-charge-selector-0')).toBeInTheDocument()
      })
    })

    describe('WHEN a filter selector is clicked', () => {
      it('THEN should reset the filter form before opening the drawer', async () => {
        mockCurrentFormValues = mockEditFormValuesWithFilters

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        await userEvent.click(screen.getByTestId('filter-charge-selector-0'))

        // The form must be reset with the filter's data BEFORE the drawer opens
        // to avoid a race condition with charge model hooks that initialize defaults
        expect(mockFormReset).toHaveBeenCalledWith(
          expect.objectContaining({
            chargeModel: mockEditFormValuesWithFilters.chargeModel,
            properties: mockEditFormValuesWithFilters.filters[0].properties,
            values: mockEditFormValuesWithFilters.filters[0].values,
          }),
        )

        // The drawer should open after the reset
        expect(mockDrawerOpen).toHaveBeenCalled()

        // Reset must happen before open
        const resetOrder = mockFormReset.mock.invocationCallOrder[0]
        const openOrder = mockDrawerOpen.mock.invocationCallOrder[0]

        expect(resetOrder).toBeLessThan(openOrder)
      })
    })
  })

  describe('GIVEN the invoicing section renders', () => {
    describe('WHEN the component is in edit mode', () => {
      it('THEN should render PlanBillingPeriodInfoSection', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId(PLAN_BILLING_PERIOD_INFO_SECTION_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render ChargePayInAdvanceOption', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId(CHARGE_PAY_IN_ADVANCE_OPTION_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render TaxesSelectorSection', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

        expect(screen.getByTestId(TAXES_SELECTOR_SECTION_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a plan with subscriptions and an EXISTING usage charge', () => {
    const existingChargeFormValues = {
      ...mockEditFormValues,
      id: 'charge-1', // Has an id = existing charge persisted on backend
    }

    beforeEach(() => {
      mockCurrentFormValues = existingChargeFormValues
      mockForm.store = mockCreateStore(existingChargeFormValues)
      mockForm.state = { values: existingChargeFormValues }
    })

    describe('WHEN disabled=true (plan has subscriptions)', () => {
      const renderExistingChargeOnSubscribedPlan = () =>
        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            isEdition
            disabled
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

      it('THEN ChargeModelSelector should be disabled', () => {
        renderExistingChargeOnSubscribedPlan()

        expect(lastChargeModelSelectorProps.disabled).toBe(true)
      })

      it('THEN ChargePayInAdvanceOption should be disabled', () => {
        renderExistingChargeOnSubscribedPlan()

        expect(lastChargePayInAdvanceOptionProps.disabled).toBe(true)
      })

      it('THEN the charge code field should be disabled', () => {
        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            isEdition
            disabled
            editIndex={0}
            currency="USD"
            interval="monthly"
            showCode
          />,
        )

        expect(screen.getByTestId('charge-code-field')).toHaveAttribute('data-disabled', 'true')
      })
    })
  })

  describe('GIVEN a plan with subscriptions and a NEW usage charge (no id)', () => {
    const newChargeFormValues = {
      ...mockEditFormValues,
      id: undefined, // No id = new charge not yet persisted
    }

    beforeEach(() => {
      mockCurrentFormValues = newChargeFormValues
      mockForm.store = mockCreateStore(newChargeFormValues)
      mockForm.state = { values: newChargeFormValues }
    })

    describe('WHEN disabled=true (plan has subscriptions) but charge has no id', () => {
      const renderNewChargeOnSubscribedPlan = () =>
        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            isEdition
            disabled
            editIndex={0}
            currency="USD"
            interval="monthly"
          />,
        )

      it('THEN ChargeModelSelector should NOT be disabled (new charge)', () => {
        renderNewChargeOnSubscribedPlan()

        expect(lastChargeModelSelectorProps.disabled).toBe(false)
      })

      it('THEN ChargePayInAdvanceOption should NOT be disabled', () => {
        renderNewChargeOnSubscribedPlan()

        expect(lastChargePayInAdvanceOptionProps.disabled).toBe(false)
      })

      it('THEN the charge code field should NOT be disabled (new charge)', () => {
        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            isEdition
            disabled
            editIndex={0}
            currency="USD"
            interval="monthly"
            showCode
          />,
        )

        expect(screen.getByTestId('charge-code-field')).toHaveAttribute('data-disabled', 'false')
      })
    })
  })

  describe('GIVEN isInSubscriptionForm={true} (sub plan override mode)', () => {
    const renderInSubscriptionForm = (values = mockEditFormValuesWithFilters) => {
      mockCurrentFormValues = values

      return render(
        <UsageChargeDrawerContent
          isCreateMode={false}
          editIndex={0}
          currency="USD"
          interval="monthly"
          isInSubscriptionForm
        />,
      )
    }

    it('THEN ChargeModelSelector should receive isInSubscriptionForm prop', () => {
      renderInSubscriptionForm()

      expect(lastChargeModelSelectorProps.isInSubscriptionForm).toBe(true)
    })

    it('THEN ChargePayInAdvanceOption should be disabled', () => {
      renderInSubscriptionForm()

      expect(lastChargePayInAdvanceOptionProps.disabled).toBe(true)
    })

    it('THEN the "Add filter" button should remain visible (filters belong to the charge, not the plan)', () => {
      renderInSubscriptionForm()

      expect(screen.getByTestId('add-charge-filter')).toBeInTheDocument()
    })

    it('THEN the filter row trash AND pen hover-actions should remain wired (filters are charge-scoped)', () => {
      renderInSubscriptionForm()

      // First filter row's SelectorActions must receive both trash and pen actions
      // regardless of isInSubscriptionForm — filters live INSIDE a charge and follow
      // charge-scoped semantics, not plan-scoped add/delete rules.
      const filterRowActions = mockSelectorActions.mock.calls[0]?.[0]?.actions

      expect(filterRowActions).toBeDefined()
      expect(filterRowActions.map((action) => action.icon)).toEqual(['trash', 'pen'])
    })

    it('THEN SpendingMinimumOptionSection should remain editable (min spending is a value override)', () => {
      renderInSubscriptionForm()

      // Min spending is a value-override knob like amountCents/units, not a structural
      // billing config like payInAdvance/prorated. It must NOT be gated on isInSubscriptionForm.
      expect(mockSpendingMinimumOptionSection).toHaveBeenCalled()
      const lastCall = mockSpendingMinimumOptionSection.mock.calls.at(-1)?.[0]

      expect(lastCall?.disabled).toBeFalsy()
    })
  })

  describe('GIVEN showCode (v2 edition/details UI)', () => {
    describe('WHEN a billable metric is already selected', () => {
      it('THEN renders the editable charge code field', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
            showCode
          />,
        )

        expect(screen.getByTestId('charge-code-field')).toBeInTheDocument()
      })

      it('THEN disables the code field in subscription-form mode', () => {
        mockCurrentFormValues = mockEditFormValues

        render(
          <UsageChargeDrawerContent
            isCreateMode={false}
            editIndex={0}
            currency="USD"
            interval="monthly"
            isInSubscriptionForm
            showCode
          />,
        )

        expect(screen.getByTestId('charge-code-field')).toHaveAttribute('data-disabled', 'true')
      })
    })

    describe('WHEN selecting a billable metric on the create picker screen', () => {
      beforeEach(() => {
        mockCurrentFormValues = mockDefaultFormValues
        mockBillableMetricsData = {
          billableMetrics: {
            collection: [
              {
                id: 'bm-9',
                name: 'API Calls',
                code: 'api_calls',
                aggregationType: 'count_agg',
                recurring: false,
                filters: [],
              },
            ],
          },
        }
      })

      it('THEN stores the metric and seeds a unique charge code from its code', () => {
        render(
          <UsageChargeDrawerContent
            isCreateMode
            editIndex={-1}
            currency="USD"
            interval="monthly"
            showCode
            existingChargeCodes={['api_calls']}
          />,
        )

        act(() => {
          capturedAppFieldListeners.billableMetricId?.onChange?.({ value: 'bm-9' })
        })

        expect(mockSetFieldValue).toHaveBeenCalledWith(
          'billableMetric',
          expect.objectContaining({ id: 'bm-9', code: 'api_calls' }),
        )
        // `api_calls` is already taken, so the seeded code gets a numeric suffix.
        expect(mockSetFieldValue).toHaveBeenCalledWith('code', 'api_calls_2')
      })

      it('THEN does NOT seed a code when showCode is false', () => {
        render(
          <UsageChargeDrawerContent
            isCreateMode
            editIndex={-1}
            currency="USD"
            interval="monthly"
            existingChargeCodes={['api_calls']}
          />,
        )

        act(() => {
          capturedAppFieldListeners.billableMetricId?.onChange?.({ value: 'bm-9' })
        })

        expect(mockSetFieldValue).not.toHaveBeenCalledWith('code', expect.anything())
      })
    })
  })
})

// Stays in lockstep with the real component: if renderItem's signature changes,
// this breaks at compile time instead of silently drifting.
type CapturedVirtualListProps = Pick<VirtualFilterListProps<unknown>, 'items' | 'renderItem'>

const capturedVirtualList: { props?: CapturedVirtualListProps } = {}

jest.mock('~/components/designSystem/VirtualList/VirtualFilterList', () => ({
  VIRTUALIZATION_THRESHOLD: 50,
  VirtualFilterList: (props: CapturedVirtualListProps) => (
    <>
      {props.items.map((item, index) => {
        capturedVirtualList.props = props

        return <div key={index}>{props.renderItem(item, index)}</div>
      })}
    </>
  ),
}))

const mockFormValuesWithThreeFilters = {
  ...mockEditFormValues,
  billableMetric: {
    ...mockEditFormValues.billableMetric,
    filters: [{ id: 'f1', key: 'region', values: ['us', 'eu', 'ap'] }],
  },
  filters: [
    {
      values: ['{"region":"us"}'],
      properties: { amount: '5', packageSize: '' },
      invoiceDisplayName: '',
    },
    {
      values: ['{"region":"eu"}'],
      properties: { amount: '8', packageSize: '' },
      invoiceDisplayName: '',
    },
    {
      values: ['{"region":"ap"}'],
      properties: { amount: '12', packageSize: '' },
      invoiceDisplayName: '',
    },
  ],
}

describe('VirtualFilterList drift test', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedVirtualList.props = undefined
    mockCurrentFormValues = mockFormValuesWithThreeFilters
    mockForm.store = mockCreateStore(mockFormValuesWithThreeFilters)
    mockForm.state = { values: mockFormValuesWithThreeFilters }
  })

  it('renders the filter selectors through VirtualFilterList', () => {
    render(
      <UsageChargeDrawerContent
        isCreateMode={false}
        editIndex={0}
        currency="USD"
        interval="monthly"
      />,
    )

    expect(capturedVirtualList.props?.items).toHaveLength(3)
  })
})
