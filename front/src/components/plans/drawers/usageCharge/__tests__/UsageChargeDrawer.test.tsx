import { render } from '@testing-library/react'
import { createRef } from 'react'

import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { validateChargeProperties } from '~/formValidation/chargePropertiesSchema'

import { UsageChargeDrawerFormValues } from '../constants'
import {
  UsageChargeDrawer,
  UsageChargeDrawerRef,
  usageChargeDrawerSchema,
} from '../UsageChargeDrawer'

// --- Capture callbacks ---

let capturedOnSubmit: ((args: { value: Record<string, unknown> }) => void) | undefined
let capturedDefaultValues: Record<string, unknown> | undefined

// --- Mocks ---

jest.mock('../UsageChargeDrawerContent', () => ({
  UsageChargeDrawerContent: () => <div data-test="usage-charge-drawer-content" />,
}))

const mockFormDrawerOpen = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: jest.fn(),
    close: jest.fn(),
  }),
  useFormDrawer: () => ({
    open: mockFormDrawerOpen,
    close: jest.fn(),
  }),
}))

jest.mock('~/components/drawers/const', () => ({
  DRAWER_TRANSITION_DURATION: 0,
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => `translated_${key}`,
  }),
}))

jest.mock('~/contexts/PlanFormContext', () => {
  const { CurrencyEnum, PlanInterval: mockedPlanInterval } =
    jest.requireActual('~/generated/graphql')

  return {
    PlanFormProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
    usePlanFormContext: () => ({
      currency: CurrencyEnum.Usd,
      interval: mockedPlanInterval.Monthly,
    }),
  }
})

jest.mock('~/core/apolloClient', () => ({
  useDuplicatePlanVar: () => ({ type: '' }),
  envGlobalVar: () => ({ sentryDsn: '', apiUrl: '', appVersion: '' }),
}))

jest.mock('~/core/serializers/getPropertyShape', () => ({
  __esModule: true,
  default: () => ({ amount: '', packageSize: '' }),
}))

jest.mock('~/formValidation/chargePropertiesSchema', () => ({
  validateChargeProperties: jest.fn(),
}))

// Mock TanStack form infrastructure
const mockHandleSubmit = jest.fn()
const mockReset = jest.fn()
const mockSetFieldValue = jest.fn()
const mockGetFieldValue = jest.fn()

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
}))

const createMockForm = (defaultValues: Record<string, unknown>) => {
  const store = {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({ isDirty: false, values: defaultValues })),
  }

  return {
    store,
    useStore: jest.fn(() => defaultValues),
    state: { values: defaultValues },
    reset: mockReset,
    handleSubmit: mockHandleSubmit,
    setFieldValue: mockSetFieldValue,
    getFieldValue: mockGetFieldValue,
    AppField: ({
      children,
      name,
    }: {
      children: (field: unknown) => React.ReactNode
      name: string
      listeners?: unknown
    }) => {
      return <div data-field-name={name}>{children({ name })}</div>
    },
    AppForm: ({ children }: { children: React.ReactNode }) => <>{children}</>,
    SubmitButton: ({ children }: { children: React.ReactNode }) => (
      <button type="submit">{children}</button>
    ),
    Subscribe: ({
      children,
      selector,
    }: {
      children: (value: unknown) => React.ReactNode
      selector: (state: { canSubmit: boolean }) => unknown
    }) => {
      const value = selector({ canSubmit: true })

      return <>{children(value)}</>
    },
  }
}

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(
    ({
      onSubmit,
      defaultValues,
    }: {
      onSubmit?: (args: { value: Record<string, unknown> }) => void
      defaultValues: Record<string, unknown>
    }) => {
      capturedOnSubmit = onSubmit
      capturedDefaultValues = defaultValues

      const form = createMockForm(defaultValues)

      return {
        ...form,
        handleSubmit: () => {
          mockHandleSubmit()
          onSubmit?.({ value: defaultValues })
        },
      }
    },
  ),
}))

describe('UsageChargeDrawer', () => {
  const mockOnSave = jest.fn()
  let drawerRef: React.RefObject<UsageChargeDrawerRef>

  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = undefined
    capturedDefaultValues = undefined
    drawerRef = createRef<UsageChargeDrawerRef>()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the drawer is rendered', () => {
    describe('WHEN it mounts', () => {
      it('THEN should expose ref methods', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(drawerRef.current).toBeDefined()
        expect(typeof drawerRef.current?.openDrawer).toBe('function')
        expect(typeof drawerRef.current?.closeDrawer).toBe('function')
      })
    })
  })

  describe('GIVEN the form default values', () => {
    describe('WHEN the form is initialized', () => {
      it('THEN should have standard as the default charge model', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues).toBeDefined()
        expect(capturedDefaultValues?.chargeModel).toBe('standard')
      })

      it('THEN should have empty billableMetricId', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.billableMetricId).toBe('')
      })

      it('THEN should have invoiceable as true by default', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.invoiceable).toBe(true)
      })

      it('THEN should have payInAdvance as false', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.payInAdvance).toBe(false)
      })

      it('THEN should have empty filters array', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.filters).toEqual([])
      })

      it('THEN should have regroupPaidFees as null', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.regroupPaidFees).toBeNull()
      })

      it('THEN should have empty taxes array', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.taxes).toEqual([])
      })
    })
  })

  describe('GIVEN openDrawer is called with a charge (edit mode)', () => {
    const mockBillableMetric = {
      id: 'bm-1',
      name: 'API Calls',
      code: 'api_calls',
      aggregationType: 'count_agg',
      recurring: false,
    }

    const mockCharge = {
      billableMetric: mockBillableMetric,
      chargeModel: 'percentage' as const,
      id: 'charge-1',
      invoiceDisplayName: 'API Usage',
      invoiceable: false,
      minAmountCents: '500',
      payInAdvance: true,
      prorated: true,
      properties: { rate: '2.5' },
      filters: [{ values: ['val1'], properties: { rate: '3' }, invoiceDisplayName: '' }],
      regroupPaidFees: 'invoice',
      taxes: [{ id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }],
    }

    describe('WHEN the charge data is provided', () => {
      it('THEN should reset the form with the charge values', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(
          mockCharge as unknown as Parameters<UsageChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            billableMetricId: 'bm-1',
            chargeModel: 'percentage',
            id: 'charge-1',
            invoiceDisplayName: 'API Usage',
            invoiceable: false,
            minAmountCents: '500',
            payInAdvance: true,
            prorated: true,
            regroupPaidFees: 'invoice',
          }),
          { keepDefaultValues: true },
        )
      })

      it('THEN should map the billableMetric correctly', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(
          mockCharge as unknown as Parameters<UsageChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            billableMetric: mockBillableMetric,
          }),
          expect.anything(),
        )
      })

      it('THEN should include filters and taxes', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(
          mockCharge as unknown as Parameters<UsageChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            filters: mockCharge.filters,
            taxes: [{ id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }],
          }),
          expect.anything(),
        )
      })
    })
  })

  describe('GIVEN openDrawer is called without a charge (create mode)', () => {
    describe('WHEN no charge data is provided', () => {
      it('THEN should reset the form with default values', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer()

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            billableMetricId: '',
            chargeModel: 'standard',
            invoiceable: true,
            payInAdvance: false,
            prorated: false,
            filters: [],
            regroupPaidFees: null,
            taxes: [],
          }),
          { keepDefaultValues: true },
        )
      })
    })
  })

  // Guards the migration to the shared form drawer + form.SubmitButton: the
  // drawer must keep owning its own close (close on success, stay open on a
  // failed mutation) by opting out of the form drawer's auto-close.
  describe('GIVEN the drawer is opened', () => {
    describe('WHEN the form drawer is wired', () => {
      it('THEN passes a form id, a submit handler and keeps its own close ownership', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer()

        expect(mockFormDrawerOpen).toHaveBeenCalledTimes(1)

        const openArgs = mockFormDrawerOpen.mock.calls[0][0]

        expect(openArgs.form?.id).toBe('usage-charge-drawer-form')
        expect(typeof openArgs.form?.submit).toBe('function')
        expect(openArgs.closeOnSubmitSuccess).toBe(false)
        expect(openArgs.mainAction).toBeDefined()
      })
    })
  })

  describe('GIVEN the onSubmit handler', () => {
    describe('WHEN the form is submitted with valid data', () => {
      it('THEN should call onSave with the form values', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        const formValues: UsageChargeDrawerFormValues = {
          billableMetricId: 'bm-1',
          billableMetric: {
            id: 'bm-1',
            name: 'Calls',
            code: 'calls',
            aggregationType:
              'count_agg' as UsageChargeDrawerFormValues['billableMetric']['aggregationType'],
            recurring: false,
          },
          chargeModel: 'standard' as UsageChargeDrawerFormValues['chargeModel'],
          code: 'calls',
          invoiceDisplayName: 'Test',
          invoiceable: true,
          minAmountCents: '100',
          payInAdvance: false,
          prorated: false,
          properties: { amount: '10' },
          filters: [],
          regroupPaidFees: null,
          taxes: [],
        }

        capturedOnSubmit?.({ value: formValues as unknown as Record<string, unknown> })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            chargeModel: 'standard',
            code: 'calls',
            invoiceable: true,
            payInAdvance: false,
          }),
          -1,
        )
      })
    })

    describe('WHEN onSave reports a duplicate code', () => {
      it('THEN surfaces the error under the Code field (and keeps the drawer open)', async () => {
        mockOnSave.mockResolvedValueOnce(FORM_ERRORS_ENUM.existingCode)
        const setFieldMeta = jest.fn()

        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} showCode />)

        const submit = capturedOnSubmit as unknown as (args: {
          value: Record<string, unknown>
          formApi: { setFieldMeta: jest.Mock }
        }) => Promise<void>

        await submit({
          value: { ...capturedDefaultValues, code: 'dup_code' },
          formApi: { setFieldMeta },
        })

        expect(setFieldMeta).toHaveBeenCalledWith('code', expect.any(Function))
      })
    })

    describe('WHEN invoiceDisplayName is empty string', () => {
      it('THEN should normalize to undefined', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({
          value: {
            ...capturedDefaultValues,
            billableMetric: {
              id: '',
              name: '',
              code: '',
              aggregationType: 'count_agg',
              recurring: false,
            },
            invoiceDisplayName: '',
          },
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ invoiceDisplayName: undefined }),
          -1,
        )
      })
    })

    describe('WHEN minAmountCents is empty string', () => {
      it('THEN should normalize to undefined', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({
          value: {
            ...capturedDefaultValues,
            billableMetric: {
              id: '',
              name: '',
              code: '',
              aggregationType: 'count_agg',
              recurring: false,
            },
            minAmountCents: '',
          },
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ minAmountCents: undefined }),
          -1,
        )
      })
    })

    describe('WHEN regroupPaidFees is empty string', () => {
      it('THEN should normalize to undefined', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({
          value: {
            ...capturedDefaultValues,
            billableMetric: {
              id: '',
              name: '',
              code: '',
              aggregationType: 'count_agg',
              recurring: false,
            },
            regroupPaidFees: '',
          },
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ regroupPaidFees: undefined }),
          -1,
        )
      })
    })
  })

  describe('GIVEN the schema validation', () => {
    const baseData = {
      billableMetricId: 'bm-1',
      billableMetric: {
        id: 'bm-1',
        name: 'API Calls',
        code: 'api_calls',
        aggregationType: 'count_agg',
        recurring: false,
      },
      chargeModel: 'standard',
      code: 'api_calls',
      invoiceDisplayName: '',
      invoiceable: true,
      minAmountCents: '',
      payInAdvance: false,
      prorated: false,
      properties: { amount: '' },
      regroupPaidFees: null,
      taxes: [],
    }

    const mockedValidateChargeProperties = validateChargeProperties as jest.Mock

    describe('WHEN no filters are present', () => {
      it('THEN should call validateChargeProperties for main properties', () => {
        usageChargeDrawerSchema.safeParse({ ...baseData, filters: [] })

        expect(mockedValidateChargeProperties).toHaveBeenCalledWith(
          'standard',
          { amount: '' },
          expect.anything(),
          ['properties'],
        )
      })
    })

    describe('WHEN filters are present', () => {
      it('THEN should still call validateChargeProperties for main properties', () => {
        usageChargeDrawerSchema.safeParse({
          ...baseData,
          filters: [{ values: ['val1'], properties: { amount: '5' }, invoiceDisplayName: '' }],
        })

        expect(mockedValidateChargeProperties).toHaveBeenCalledWith(
          'standard',
          { amount: '' },
          expect.anything(),
          ['properties'],
        )
      })
    })
  })

  describe('GIVEN openDrawer with missing optional fields', () => {
    describe('WHEN optional charge fields are undefined', () => {
      it('THEN should use default fallback values', () => {
        render(<UsageChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        const minimalCharge = {
          billableMetric: {
            id: 'bm-1',
            name: 'Metric',
            code: 'metric',
            aggregationType: 'count_agg',
            recurring: false,
          },
          chargeModel: 'standard' as const,
        }

        drawerRef.current?.openDrawer(
          minimalCharge as unknown as Parameters<UsageChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            invoiceDisplayName: '',
            invoiceable: true,
            minAmountCents: '',
            payInAdvance: false,
            prorated: false,
            filters: [],
            regroupPaidFees: null,
            taxes: [],
          }),
          { keepDefaultValues: true },
        )
      })
    })
  })
})
