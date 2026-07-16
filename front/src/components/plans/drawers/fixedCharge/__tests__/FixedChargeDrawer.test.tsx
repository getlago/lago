import { render } from '@testing-library/react'
import { createRef } from 'react'

import { FORM_ERRORS_ENUM } from '~/core/constants/form'

import {
  FixedChargeDrawer,
  FixedChargeDrawerFormValues,
  FixedChargeDrawerRef,
} from '../FixedChargeDrawer'

// --- Capture callbacks ---

let capturedOnSubmit: ((args: { value: Record<string, unknown> }) => void) | undefined
let capturedDefaultValues: Record<string, unknown> | undefined

// --- Mocks ---

jest.mock('../FixedChargeDrawerContent', () => ({
  FixedChargeDrawerContent: () => <div data-test="fixed-charge-drawer-content" />,
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
  const { CurrencyEnum } = jest.requireActual('~/generated/graphql')

  return {
    PlanFormProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
    usePlanFormContext: () => ({
      currency: CurrencyEnum.Usd,
    }),
  }
})

jest.mock('~/core/apolloClient', () => ({
  useDuplicatePlanVar: () => ({ type: '' }),
  envGlobalVar: () => ({ sentryDsn: '', apiUrl: '', appVersion: '' }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (c: string) => c,
  intlFormatNumber: jest.fn(),
}))

jest.mock('~/core/serializers/getPropertyShape', () => ({
  __esModule: true,
  default: () => ({ amount: '', packageSize: '' }),
}))

jest.mock('~/formValidation/chargePropertiesSchema', () => ({
  validateChargeProperties: jest.fn(),
}))

jest.mock('~/hooks/plans/useChargeForm', () => ({
  useChargeForm: () => ({
    getFixedChargeModelComboboxData: jest.fn(() => []),
    getIsPayInAdvanceOptionDisabledForFixedCharge: jest.fn(() => false),
    getIsProRatedOptionDisabledForFixedCharge: jest.fn(() => false),
  }),
}))

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useGetAddOnsForFixedChargesSectionLazyQuery: jest.fn(() => [
      jest.fn(),
      { loading: false, data: null },
    ]),
  }
})

jest.mock('~/components/plans/drawers/common/PlanBillingPeriodInfoSection', () => ({
  PlanBillingPeriodInfoSection: () => <div data-test="plan-billing-period-info-section" />,
}))

jest.mock('~/components/plans/chargeAccordion/ChargeModelSelector', () => ({
  ChargeModelSelector: () => <div data-test="charge-model-selector" />,
}))

jest.mock('~/components/plans/chargeAccordion/ChargeWrapperSwitch', () => ({
  ChargeWrapperSwitch: () => <div data-test="charge-wrapper-switch" />,
}))

jest.mock('~/components/plans/chargeAccordion/options/ChargePayInAdvanceOption', () => ({
  ChargePayInAdvanceOption: () => <div data-test="charge-pay-in-advance-option" />,
}))

jest.mock('~/components/taxes/TaxesSelectorSection', () => ({
  TaxesSelectorSection: () => <div data-test="taxes-selector-section" />,
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

describe('FixedChargeDrawer', () => {
  const mockOnSave = jest.fn()
  let drawerRef: React.RefObject<FixedChargeDrawerRef>

  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = undefined
    capturedDefaultValues = undefined
    drawerRef = createRef<FixedChargeDrawerRef>()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the drawer is rendered', () => {
    describe('WHEN it mounts', () => {
      it('THEN should expose ref methods', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(drawerRef.current).toBeDefined()
        expect(typeof drawerRef.current?.openDrawer).toBe('function')
        expect(typeof drawerRef.current?.closeDrawer).toBe('function')
      })
    })
  })

  describe('GIVEN the form default values', () => {
    describe('WHEN the form is initialized', () => {
      it('THEN should have standard as the default charge model', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues).toBeDefined()
        expect(capturedDefaultValues?.chargeModel).toBe('standard')
      })

      it('THEN should have empty addOnId', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.addOnId).toBe('')
      })

      it('THEN should have empty units string', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.units).toBe('')
      })

      it('THEN should have payInAdvance as false', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.payInAdvance).toBe(false)
      })

      it('THEN should have prorated as false', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.prorated).toBe(false)
      })

      it('THEN should have empty taxes array', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.taxes).toEqual([])
      })
    })
  })

  describe('GIVEN openDrawer is called with a charge (edit mode)', () => {
    const mockCharge = {
      addOn: { id: 'addon-1', name: 'Setup Fee', code: 'setup_fee' },
      applyUnitsImmediately: true,
      chargeModel: 'graduated' as const,
      id: 'charge-1',
      invoiceDisplayName: 'Custom Name',
      payInAdvance: true,
      properties: { amount: '200' },
      prorated: true,
      taxes: [{ id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }],
      units: '10',
    }

    describe('WHEN the charge data is provided', () => {
      it('THEN should reset the form with the charge values', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(
          mockCharge as unknown as Parameters<FixedChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            addOnId: 'addon-1',
            chargeModel: 'graduated',
            id: 'charge-1',
            invoiceDisplayName: 'Custom Name',
            payInAdvance: true,
            prorated: true,
            units: '10',
          }),
          { keepDefaultValues: true },
        )
      })

      it('THEN should map the addOn correctly', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(
          mockCharge as unknown as Parameters<FixedChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            addOn: { id: 'addon-1', name: 'Setup Fee', code: 'setup_fee' },
          }),
          expect.anything(),
        )
      })

      it('THEN should include taxes', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(
          mockCharge as unknown as Parameters<FixedChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
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
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer()

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            addOnId: '',
            chargeModel: 'standard',
            payInAdvance: false,
            prorated: false,
            units: '',
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
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer()

        expect(mockFormDrawerOpen).toHaveBeenCalledTimes(1)

        const openArgs = mockFormDrawerOpen.mock.calls[0][0]

        expect(openArgs.form?.id).toBe('fixed-charge-drawer-form')
        expect(typeof openArgs.form?.submit).toBe('function')
        expect(openArgs.closeOnSubmitSuccess).toBe(false)
        expect(openArgs.mainAction).toBeDefined()
      })
    })
  })

  describe('GIVEN the onSubmit handler', () => {
    describe('WHEN the form is submitted with valid data', () => {
      it('THEN should call onSave with the form values', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        const formValues: FixedChargeDrawerFormValues = {
          addOnId: 'addon-1',
          addOn: { id: 'addon-1', name: 'Setup', code: 'setup' },
          applyUnitsImmediately: false,
          chargeModel: 'standard' as FixedChargeDrawerFormValues['chargeModel'],
          code: 'setup',
          invoiceDisplayName: 'Test',
          payInAdvance: false,
          properties: { amount: '100' },
          prorated: false,
          taxes: [],
          units: '5',
        }

        capturedOnSubmit?.({ value: formValues as unknown as Record<string, unknown> })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            chargeModel: 'standard',
            code: 'setup',
            payInAdvance: false,
            units: '5',
          }),
          -1,
        )
      })
    })

    describe('WHEN onSave reports a duplicate code', () => {
      it('THEN surfaces the error under the Code field (and keeps the drawer open)', async () => {
        mockOnSave.mockResolvedValueOnce(FORM_ERRORS_ENUM.existingCode)
        const setFieldMeta = jest.fn()

        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} showCode />)

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
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({
          value: {
            ...capturedDefaultValues,
            addOn: { id: '', name: '', code: '' },
            invoiceDisplayName: '',
          },
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ invoiceDisplayName: undefined }),
          -1,
        )
      })
    })
  })

  describe('GIVEN openDrawer with missing optional fields', () => {
    describe('WHEN optional charge fields are undefined', () => {
      it('THEN should use default fallback values', () => {
        render(<FixedChargeDrawer ref={drawerRef} onSave={mockOnSave} />)

        const minimalCharge = {
          addOn: { id: 'addon-1', name: 'Fee', code: 'fee' },
          chargeModel: 'standard' as const,
        }

        drawerRef.current?.openDrawer(
          minimalCharge as unknown as Parameters<FixedChargeDrawerRef['openDrawer']>[0],
          0,
        )

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            applyUnitsImmediately: false,
            invoiceDisplayName: '',
            payInAdvance: false,
            prorated: false,
            taxes: [],
            units: '',
          }),
          { keepDefaultValues: true },
        )
      })
    })
  })
})
