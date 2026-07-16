import { render } from '@testing-library/react'
import { createRef } from 'react'

import {
  SubscriptionFeeDrawer,
  SubscriptionFeeDrawerRef,
  SubscriptionFeeFormValues,
} from '../SubscriptionFeeDrawer'

// --- Capture callbacks ---

let capturedOnSubmit: ((args: { value: Record<string, unknown> }) => void) | undefined
let capturedDefaultValues: Record<string, unknown> | undefined

// --- Mocks ---

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

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
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

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (currency: string) => currency,
  intlFormatNumber: jest.fn(),
}))

jest.mock('~/components/plans/drawers/common/PlanBillingPeriodInfoSection', () => ({
  PlanBillingPeriodInfoSection: () => <div data-test="plan-billing-period-info-section" />,
}))

// Mock TanStack form infrastructure
const mockHandleSubmit = jest.fn()
const mockReset = jest.fn()

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
    setFieldValue: jest.fn(),
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

describe('SubscriptionFeeDrawer', () => {
  const mockOnSave = jest.fn()
  let drawerRef: React.RefObject<SubscriptionFeeDrawerRef>

  const defaultFormValues: SubscriptionFeeFormValues = {
    amountCents: '100',
    payInAdvance: false,
    trialPeriod: 30,
    invoiceDisplayName: 'Test Fee',
  }

  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = undefined
    capturedDefaultValues = undefined
    drawerRef = createRef<SubscriptionFeeDrawerRef>()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the drawer is rendered', () => {
    describe('WHEN it is initially closed', () => {
      it('THEN should expose ref methods', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(drawerRef.current).toBeDefined()
        expect(drawerRef.current?.openDrawer).toBeDefined()
        expect(drawerRef.current?.closeDrawer).toBeDefined()
      })
    })
  })

  describe('GIVEN the drawer ref is exposed', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should expose openDrawer and closeDrawer as functions', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(typeof drawerRef.current?.openDrawer).toBe('function')
        expect(typeof drawerRef.current?.closeDrawer).toBe('function')
      })
    })

    describe('WHEN openDrawer is called with values', () => {
      it('THEN should reset the form with keepDefaultValues true', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockReset).toHaveBeenCalledWith(defaultFormValues, { keepDefaultValues: true })
      })
    })

    // Guards the migration to the shared form drawer + form.SubmitButton: the
    // drawer must keep owning its own close (close on success, stay open on a
    // failed mutation) by opting out of the form drawer's auto-close.
    describe('WHEN the form drawer is wired', () => {
      it('THEN passes a form id, a submit handler and keeps its own close ownership', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockFormDrawerOpen).toHaveBeenCalledTimes(1)

        const openArgs = mockFormDrawerOpen.mock.calls[0][0]

        expect(openArgs.form?.id).toBe('subscription-fee-drawer-form')
        expect(typeof openArgs.form?.submit).toBe('function')
        expect(openArgs.closeOnSubmitSuccess).toBe(false)
        expect(openArgs.mainAction).toBeDefined()
      })
    })
  })

  describe('GIVEN the form values type', () => {
    describe('WHEN SubscriptionFeeFormValues is constructed', () => {
      it('THEN should contain all required fields', () => {
        const values: SubscriptionFeeFormValues = {
          amountCents: '50',
          payInAdvance: true,
          trialPeriod: 14,
          invoiceDisplayName: 'Custom Name',
        }

        expect(values.amountCents).toBe('50')
        expect(values.payInAdvance).toBe(true)
        expect(values.trialPeriod).toBe(14)
        expect(values.invoiceDisplayName).toBe('Custom Name')
      })
    })
  })

  describe('GIVEN the form default values', () => {
    describe('WHEN the form is initialized', () => {
      it('THEN trialPeriod defaults to 0 as a number', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues).toBeDefined()
        expect(capturedDefaultValues?.trialPeriod).toBe(0)
        expect(typeof capturedDefaultValues?.trialPeriod).toBe('number')
      })

      it('THEN trialPeriod is not undefined or an empty string', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.trialPeriod).not.toBeUndefined()
        expect(capturedDefaultValues?.trialPeriod).not.toBe('')
      })
    })
  })

  describe('GIVEN the onSubmit handler', () => {
    describe('WHEN trialPeriod is a valid number', () => {
      it('THEN should preserve the number value', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues, trialPeriod: 30 } })

        expect(mockOnSave).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 30 }))
      })
    })

    describe('WHEN trialPeriod is 0', () => {
      it('THEN should preserve 0 as the value', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues, trialPeriod: 0 } })

        expect(mockOnSave).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 0 }))
      })
    })

    describe('WHEN trialPeriod is NaN', () => {
      it('THEN should normalize to 0', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues, trialPeriod: NaN } })

        expect(mockOnSave).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 0 }))
      })
    })

    describe('WHEN trialPeriod is undefined', () => {
      it('THEN should normalize to 0', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues, trialPeriod: undefined } })

        expect(mockOnSave).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 0 }))
      })
    })

    describe('WHEN invoiceDisplayName is empty string', () => {
      it('THEN should normalize to undefined', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues, invoiceDisplayName: '' } })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({ invoiceDisplayName: undefined }),
        )
      })
    })
  })

  describe('GIVEN the openDrawer normalization', () => {
    describe('WHEN called with a defined trialPeriod', () => {
      it('THEN should pass the value as-is to form.reset', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer({ ...defaultFormValues, trialPeriod: 14 })

        expect(mockReset).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 14 }), {
          keepDefaultValues: true,
        })
      })
    })

    describe('WHEN called with trialPeriod as 0', () => {
      it('THEN should preserve 0', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer({ ...defaultFormValues, trialPeriod: 0 })

        expect(mockReset).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 0 }), {
          keepDefaultValues: true,
        })
      })
    })

    describe('WHEN called with trialPeriod as undefined (cast)', () => {
      it('THEN should normalize to 0 via nullish coalescing', () => {
        render(<SubscriptionFeeDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer({
          ...defaultFormValues,
          trialPeriod: undefined as unknown as number,
        })

        expect(mockReset).toHaveBeenCalledWith(expect.objectContaining({ trialPeriod: 0 }), {
          keepDefaultValues: true,
        })
      })
    })
  })
})
