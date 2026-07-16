import { render } from '@testing-library/react'
import { createRef } from 'react'

import { useFieldContext } from '~/hooks/forms/formContext'

import { ProgressiveBillingFormValues } from '../constants'
import { ProgressiveBillingDrawer, ProgressiveBillingDrawerRef } from '../ProgressiveBillingDrawer'

// --- Mocks ---

let capturedOnSubmit:
  ((args: { value: Record<string, unknown> }) => void | Promise<void>) | undefined
let capturedDefaultValues: Record<string, unknown> | undefined
let capturedDrawerOpenProps:
  | {
      onClose?: () => void
      shouldPromptOnClose?: () => boolean
      children?: React.ReactNode
      actions?: React.ReactNode
    }
  | undefined

const mockDrawerOpen = jest.fn((props) => {
  capturedDrawerOpenProps = props
})
const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: mockDrawerOpen,
    close: mockDrawerClose,
  }),
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
const mockHandleChange = jest.fn()
const mockHandleBlur = jest.fn()
const mockSetFieldValue = jest.fn()

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: jest.fn(),
}))

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
}))

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

      const store = {
        subscribe: jest.fn(() => jest.fn()),
        getState: jest.fn(() => ({ isDirty: false })),
      }

      return {
        store,
        state: { values: defaultValues, isDirty: false },
        reset: mockReset,
        setFieldValue: mockSetFieldValue,
        handleSubmit: () => {
          mockHandleSubmit()
          onSubmit?.({ value: defaultValues })
        },
        AppField: ({
          children,
          name,
        }: {
          children: (field: ReturnType<typeof createFieldCtx>) => React.ReactNode
          name: string
        }) => {
          const fieldCtx = createFieldCtx(name, defaultValues[name] ?? '')

          return <>{children(fieldCtx)}</>
        },
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
    },
  ),
  withForm: jest.fn(
    ({
      render: RenderComponent,
      props: defaultProps,
    }: {
      render: React.FC<Record<string, unknown>>
      defaultValues: Record<string, unknown>
      props: Record<string, unknown>
    }) => {
      const WithFormWrapper = (receivedProps: Record<string, unknown>) => {
        return <RenderComponent {...defaultProps} {...receivedProps} form={receivedProps.form} />
      }

      WithFormWrapper.displayName = 'WithFormWrapper'

      return WithFormWrapper
    },
  ),
}))

const MockFieldComponent = (props: Record<string, unknown>) => {
  return <input name={props.name as string} disabled={props.disabled as boolean | undefined} />
}

const createFieldCtx = (name: string, value: unknown) => ({
  name,
  state: { value },
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({
      meta: { errors: [], errorMap: {} },
      values: { [name]: value },
    })),
  },
  handleChange: mockHandleChange,
  handleBlur: mockHandleBlur,
  AmountInputField: (props: Record<string, unknown>) => (
    <MockFieldComponent {...props} name={name} />
  ),
  TextInputField: (props: Record<string, unknown>) => <MockFieldComponent {...props} name={name} />,
})

const mockedUseFieldContext = useFieldContext as jest.Mock

describe('ProgressiveBillingDrawer', () => {
  const mockOnSave = jest.fn()
  let drawerRef: React.RefObject<ProgressiveBillingDrawerRef>

  const defaultFormValues: ProgressiveBillingFormValues = {
    nonRecurringUsageThresholds: [
      { amountCents: '100', thresholdDisplayName: 'First threshold', recurring: false },
      { amountCents: '500', thresholdDisplayName: 'Second threshold', recurring: false },
    ],
    recurringUsageThreshold: {
      amountCents: '50',
      thresholdDisplayName: 'Recurring',
      recurring: true,
    },
  }

  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = undefined
    capturedDefaultValues = undefined
    capturedDrawerOpenProps = undefined
    drawerRef = createRef<ProgressiveBillingDrawerRef>()
    mockedUseFieldContext.mockReturnValue(createFieldCtx('testField', ''))
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the drawer is rendered', () => {
    describe('WHEN it is initially closed', () => {
      it('THEN should expose ref methods', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(drawerRef.current).toBeDefined()
        expect(drawerRef.current?.openDrawer).toBeDefined()
        expect(drawerRef.current?.closeDrawer).toBeDefined()
      })

      it('THEN should return null (drawer rendered via NiceModal)', () => {
        const { container } = render(
          <ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />,
        )

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN the drawer ref is exposed', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should expose openDrawer and closeDrawer as functions', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(typeof drawerRef.current?.openDrawer).toBe('function')
        expect(typeof drawerRef.current?.closeDrawer).toBe('function')
      })
    })

    describe('WHEN openDrawer is called with values', () => {
      it('THEN should reset the form with keepDefaultValues true', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockReset).toHaveBeenCalledWith(defaultFormValues, { keepDefaultValues: true })
      })

      it('THEN should call useDrawer.open with correct props', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)

        expect(mockDrawerOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            title: expect.any(String),
            shouldPromptOnClose: expect.any(Function),
            onClose: expect.any(Function),
            children: expect.anything(),
            actions: expect.anything(),
          }),
        )
      })
    })

    describe('WHEN openDrawer is called without values', () => {
      it('THEN should reset the form with default values', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer()

        expect(mockReset).toHaveBeenCalledWith(
          {
            nonRecurringUsageThresholds: [{ amountCents: '', recurring: false }],
            recurringUsageThreshold: undefined,
          },
          { keepDefaultValues: true },
        )
      })
    })

    describe('WHEN closeDrawer is called', () => {
      it('THEN should call useDrawer.close', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.closeDrawer()

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the form default values', () => {
    describe('WHEN the form is initialized', () => {
      it('THEN nonRecurringUsageThresholds defaults to single empty threshold', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues).toBeDefined()
        expect(capturedDefaultValues?.nonRecurringUsageThresholds).toEqual([
          { amountCents: '', recurring: false },
        ])
      })

      it('THEN recurringUsageThreshold defaults to undefined', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        expect(capturedDefaultValues?.recurringUsageThreshold).toBeUndefined()
      })
    })
  })

  describe('GIVEN the onSubmit handler', () => {
    describe('WHEN values are submitted', () => {
      it('THEN should call onSave with correct values', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            nonRecurringUsageThresholds: defaultFormValues.nonRecurringUsageThresholds,
            recurringUsageThreshold: defaultFormValues.recurringUsageThreshold,
          }),
        )
      })
    })
  })

  describe('GIVEN the drawer close behavior', () => {
    describe('WHEN onClose is triggered via useDrawer props', () => {
      it('THEN should reset the form without arguments', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)
        capturedDrawerOpenProps?.onClose?.()

        expect(mockReset).toHaveBeenCalledWith()
      })
    })

    describe('WHEN shouldPromptOnClose is called', () => {
      it('THEN should return the form isDirty state', () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        drawerRef.current?.openDrawer(defaultFormValues)
        const result = capturedDrawerOpenProps?.shouldPromptOnClose?.()

        expect(typeof result).toBe('boolean')
      })
    })
  })

  describe('GIVEN the form submission flow', () => {
    describe('WHEN the form is submitted', () => {
      it('THEN should close the drawer after saving', async () => {
        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={mockOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockOnSave).toHaveBeenCalled()
        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })

    describe('WHEN onSave returns false (cascade dialog cancelled)', () => {
      it('THEN should NOT close the drawer', async () => {
        const abortingOnSave = jest.fn().mockResolvedValue(false)

        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={abortingOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(abortingOnSave).toHaveBeenCalled()
        expect(mockDrawerClose).not.toHaveBeenCalled()
      })
    })

    describe('WHEN onSave returns true', () => {
      it('THEN should close the drawer', async () => {
        const confirmingOnSave = jest.fn().mockResolvedValue(true)

        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={confirmingOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })

    describe('WHEN onSave returns void (sync)', () => {
      it('THEN should close the drawer', async () => {
        const voidOnSave = jest.fn().mockReturnValue(undefined)

        render(<ProgressiveBillingDrawer ref={drawerRef} onSave={voidOnSave} />)

        await capturedOnSubmit?.({ value: { ...defaultFormValues } })

        expect(mockDrawerClose).toHaveBeenCalled()
      })
    })
  })
})
