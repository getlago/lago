import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  CHARGE_FILTER_DRAWER_CHARGE_MODEL_CHIP_TEST_ID,
  ChargeFilterDrawerContent as OriginalChargeFilterDrawerContent,
} from '../ChargeFilterDrawerContent'

// Cast to strip the injected `form` prop that withForm adds to the type
const ChargeFilterDrawerContent = OriginalChargeFilterDrawerContent as unknown as React.FC<{
  billableMetricFilters: { id: string; key: string; values: string[] }[]
  chargeIndex: number
  filterIndex: number
}>

// --- Mocks ---

const mockFormReset = jest.fn()
const mockSetFieldValue = jest.fn()

const mockDefaultFormValues = {
  chargeModel: 'standard',
  invoiceDisplayName: '',
  properties: {},
  values: [],
}

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
  store: mockCreateStore(mockDefaultFormValues),
  state: { values: mockDefaultFormValues },
  AppField: ({
    children,
    name,
  }: {
    children: (field: unknown) => React.ReactNode
    name: string
  }) => {
    const mockFieldApi = {
      state: { meta: { errors: [] } },
      TextInputField: (props: Record<string, unknown>) => (
        <input
          data-test={`field-${name}`}
          placeholder={props.placeholder as string}
          aria-label={props.label as string}
        />
      ),
    }

    return <div data-field-name={name}>{children(mockFieldApi)}</div>
  },
}

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((store: { state?: unknown }, selector: (state: unknown) => unknown) => {
    if (typeof store === 'object' && store !== null && 'state' in store) {
      return selector(store.state)
    }

    return undefined
  }),
}))

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(),
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

jest.mock('~/contexts/ChargeFilterDrawerContext', () => ({
  useChargeFilterDrawerContext: () => ({
    chargeModel: 'standard',
    chargeType: 'usage',
    currency: 'USD',
    chargePricingUnitShortName: undefined,
    isEdition: false,
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  envGlobalVar: () => ({ sentryDsn: '', apiUrl: '', appVersion: '' }),
  initializeTranslations: jest.fn(),
}))

jest.mock('~/core/constants/form', () => ({
  FORM_TYPE_ENUM: { creation: 'creation', edition: 'edition' },
  chargeModelLookupTranslation: {
    standard: 'standard_model_label',
    graduated: 'graduated_model_label',
    package: 'package_model_label',
    percentage: 'percentage_model_label',
    volume: 'volume_model_label',
    graduated_percentage: 'graduated_percentage_model_label',
    custom: 'custom_model_label',
  },
  ALL_FILTER_VALUES: '__ALL_FILTER_VALUES__',
  MUI_INPUT_BASE_ROOT_CLASSNAME: 'MuiInputBase-root',
  SEARCH_FILTER_FOR_CHARGE_CLASSNAME: 'searchFilterForChargeInput',
}))

jest.mock('~/formValidation/chargePropertiesSchema', () => ({
  validateChargeProperties: jest.fn(),
}))

jest.mock('~/components/plans/chargeAccordion/ChargeWrapperSwitch', () => ({
  ChargeWrapperSwitch: () => <div data-test="charge-wrapper-switch" />,
}))

jest.mock('~/components/plans/chargeAccordion/ChargeFilter', () => ({
  ChargeFilter: (props: { filter: { values: string[] } }) => (
    <div data-test="charge-filter-mock">
      {props.filter.values.length > 0 ? 'has-values' : 'no-values'}
    </div>
  ),
  buildChargeFilterAddFilterButtonId: (chargeIndex: number, filterIndex: number) =>
    `charge-${chargeIndex}-add-filter-${filterIndex}`,
  CHARGE_FILTER_VALUES_CONTAINER_TEST_ID: 'charge-filter-values-container',
}))

// --- Tests ---

describe('ChargeFilterDrawerContent', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component renders', () => {
    describe('WHEN the charge model chip is displayed', () => {
      it('THEN should render the charge model chip', () => {
        render(
          <ChargeFilterDrawerContent billableMetricFilters={[]} chargeIndex={0} filterIndex={0} />,
        )

        expect(
          screen.getByTestId(CHARGE_FILTER_DRAWER_CHARGE_MODEL_CHIP_TEST_ID),
        ).toBeInTheDocument()
      })
    })

    describe('WHEN the charge filter section is rendered', () => {
      it('THEN should render the ChargeFilter component', () => {
        render(
          <ChargeFilterDrawerContent billableMetricFilters={[]} chargeIndex={0} filterIndex={0} />,
        )

        expect(screen.getByTestId('charge-filter-mock')).toBeInTheDocument()
      })
    })

    describe('WHEN the charge wrapper switch section is rendered', () => {
      it('THEN should render the ChargeWrapperSwitch component', () => {
        render(
          <ChargeFilterDrawerContent billableMetricFilters={[]} chargeIndex={0} filterIndex={0} />,
        )

        expect(screen.getByTestId('charge-wrapper-switch')).toBeInTheDocument()
      })
    })

    describe('WHEN the invoice display name field is rendered', () => {
      it('THEN should render the text input for invoice display name', () => {
        render(
          <ChargeFilterDrawerContent billableMetricFilters={[]} chargeIndex={0} filterIndex={0} />,
        )

        const invoiceField = document.querySelector('[data-field-name="invoiceDisplayName"]')

        expect(invoiceField).toBeInTheDocument()
      })
    })
  })
})
