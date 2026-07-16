import { render } from '@testing-library/react'
import { createRef } from 'react'

import {
  MinimumCommitmentDrawer,
  MinimumCommitmentDrawerRef,
  MinimumCommitmentFormValues,
} from '../MinimumCommitmentDrawer'

// --- Capture callbacks ---

let capturedOnSubmit:
  ((args: { value: Record<string, unknown> }) => void | Promise<void>) | undefined
let capturedDefaultValues: Record<string, unknown> | undefined

// --- Mocks ---

const mockDrawerClose = jest.fn()
const mockFormDrawerOpen = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: jest.fn(),
    close: mockDrawerClose,
  }),
  useFormDrawer: () => ({
    open: mockFormDrawerOpen,
    close: mockDrawerClose,
  }),
}))

jest.mock('~/components/drawers/const', () => ({
  DRAWER_TRANSITION_DURATION: 0,
}))

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (currency: string) => currency,
  intlFormatNumber: jest.fn(),
}))

jest.mock('~/components/taxes/TaxesSelectorSection', () => ({
  TaxesSelectorSection: () => <div data-test="taxes-selector-section" />,
}))

jest.mock('~/components/plans/drawers/common/PlanBillingPeriodInfoSection', () => ({
  PlanBillingPeriodInfoSection: () => <div data-test="plan-billing-period-info-section" />,
}))

jest.mock('~/contexts/PlanFormContext', () => {
  const { CurrencyEnum: CE, PlanInterval: PI } = jest.requireActual('~/generated/graphql')

  return {
    PlanFormProvider: ({ children }: { children: React.ReactNode }) => <>{children}</>,
    usePlanFormContext: () => ({
      currency: CE.Usd,
      interval: PI.Monthly,
    }),
  }
})

// Mock TanStack form infrastructure
const mockHandleSubmit = jest.fn()
const mockReset = jest.fn()
const mockSetFieldValue = jest.fn()

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
    getFieldValue: jest.fn(),
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
      selector: (state: { canSubmit: boolean; values: Record<string, unknown> }) => unknown
    }) => {
      const value = selector({ canSubmit: true, values: defaultValues })

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
      onSubmit?: (args: { value: Record<string, unknown> }) => void | Promise<void>
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

describe('MinimumCommitmentDrawer', () => {
  const mockOnSave = jest.fn()
  let drawerRef: React.RefObject<MinimumCommitmentDrawerRef>

  const defaultFormValues: MinimumCommitmentFormValues = {
    amountCents: '500',
    invoiceDisplayName: 'Test Commitment',
    taxes: [],
  }

  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = undefined
    capturedDefaultValues = undefined
    drawerRef = createRef<MinimumCommitmentDrawerRef>()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the drawer is rendered', () => {
    describe('WHEN it is initially closed', () => {
      it('THEN should expose ref methods', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(drawerRef.current).toBeDefined()
        expect(drawerRef.current?.openDrawer).toBeDefined()
        expect(drawerRef.current?.closeDrawer).toBeDefined()
      })
    })
  })

  describe('GIVEN the drawer ref is exposed', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should expose openDrawer and closeDrawer as functions', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(typeof drawerRef.current?.openDrawer).toBe('function')
        expect(typeof drawerRef.current?.closeDrawer).toBe('function')
      })
    })

    describe('WHEN openDrawer is called with values (edit mode)', () => {
      it('THEN should reset the form with keepDefaultValues true', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockReset).toHaveBeenCalledWith(
          { ...defaultFormValues, taxes: [] },
          { keepDefaultValues: true },
        )
      })
    })

    describe('WHEN openDrawer is called without values (add mode)', () => {
      it('THEN should reset the form with DEFAULT_VALUES', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer()

        expect(mockReset).toHaveBeenCalledWith(
          expect.objectContaining({
            amountCents: '',
            taxes: [],
          }),
          { keepDefaultValues: true },
        )
      })
    })

    // Guards the migration to the shared form drawer + form.SubmitButton: the
    // drawer must keep owning its own close (close on success, stay open on a
    // failed mutation) by opting out of the form drawer's auto-close.
    describe('WHEN the form drawer is wired', () => {
      it('THEN passes a form id, a submit handler and keeps its own close ownership', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockFormDrawerOpen).toHaveBeenCalledTimes(1)

        const openArgs = mockFormDrawerOpen.mock.calls[0][0]

        expect(openArgs.form?.id).toBe('minimum-commitment-drawer-form')
        expect(typeof openArgs.form?.submit).toBe('function')
        expect(openArgs.closeOnSubmitSuccess).toBe(false)
        expect(openArgs.mainAction).toBeDefined()
      })
    })
  })

  describe('GIVEN the form default values', () => {
    describe('WHEN the form is initialized', () => {
      it('THEN amountCents defaults to empty string', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues).toBeDefined()
        expect(capturedDefaultValues?.amountCents).toBe('')
      })

      it('THEN taxes defaults to empty array', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.taxes).toEqual([])
      })
    })
  })

  describe('GIVEN the onSubmit handler', () => {
    describe('WHEN values are submitted', () => {
      it('THEN should call onSave with correct values', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            amountCents: '500',
            invoiceDisplayName: 'Test Commitment',
            taxes: [],
          }),
        )
      })
    })

    describe('WHEN invoiceDisplayName is empty string', () => {
      it('THEN should normalize to undefined', () => {
        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues, invoiceDisplayName: '' } })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ invoiceDisplayName: undefined }),
        )
      })
    })

    describe('WHEN onSave resolves to false (cascade cancelled)', () => {
      it('THEN should NOT close the drawer', async () => {
        const abortingOnSave = jest.fn().mockResolvedValue(false)

        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={abortingOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(abortingOnSave).toHaveBeenCalled()
        expect(mockDrawerClose).not.toHaveBeenCalled()
      })
    })

    describe('WHEN onSave resolves to true', () => {
      it('THEN should close the drawer', async () => {
        const confirmingOnSave = jest.fn().mockResolvedValue(true)

        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={confirmingOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })

    describe('WHEN onSave returns void (sync)', () => {
      it('THEN should close the drawer', async () => {
        const voidOnSave = jest.fn().mockReturnValue(undefined)

        render(<MinimumCommitmentDrawer ref={drawerRef} onSave={voidOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })
  })
})
