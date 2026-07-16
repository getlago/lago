import { render } from '@testing-library/react'

import { PrivilegeValueTypeEnum } from '~/generated/graphql'
import { useFieldContext } from '~/hooks/forms/formContext'
import { useAppForm } from '~/hooks/forms/useAppform'

import { type FeatureEntitlementFormValues } from '../constants'
import { FeatureEntitlementDrawerContent } from '../FeatureEntitlementDrawerContent'

// --- Mocks ---

// --- Mocks ---

const mockTranslate = jest.fn((key: string) => `translated_${key}`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: mockTranslate,
  }),
}))

jest.mock('~/generated/graphql', () => {
  const actual = jest.requireActual('~/generated/graphql')

  return {
    ...actual,
    useGetFeatureDetailsForFeatureEntitlementPrivilegeSectionQuery: jest.fn(() => ({
      data: null,
      loading: false,
    })),
    useGetFeaturesListForPlanSectionLazyQuery: jest.fn(() => [jest.fn(), { data: null }]),
  }
})

// Mock TanStack form infrastructure
const mockHandleSubmit = jest.fn()
const mockReset = jest.fn()
const mockHandleChange = jest.fn()
const mockHandleBlur = jest.fn()
const mockSetFieldValue = jest.fn()
const mockRemoveFieldValue = jest.fn()

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: jest.fn(),
}))

jest.mock('@tanstack/react-form', () => ({
  useStore: jest.fn((store, selector) => {
    if (typeof store?.getState === 'function') {
      return selector(store.getState())
    }
    return false
  }),
  revalidateLogic: jest.fn(() => ({})),
}))

// Captures props passed to PrivilegeValueCell via the mocked form infrastructure
let mockAppFieldChildren: Map<
  string,
  { children: (field: unknown) => React.ReactNode; name: string }
>

// Store for overriding form values per test
let mockFormValuesOverride: Record<string, unknown> | null = null

jest.mock('~/hooks/forms/useAppform', () => ({
  withForm: ({
    render: Render,
  }: {
    defaultValues: Record<string, unknown>
    props: Record<string, unknown>
    render: React.FC<{ form: unknown; [key: string]: unknown }>
  }) => {
    return (props: { form: unknown; [key: string]: unknown }) => <Render {...props} />
  },
  useAppForm: jest.fn(
    ({
      onSubmit,
      defaultValues,
    }: {
      onSubmit?: (args: { value: Record<string, unknown> }) => void
      defaultValues: Record<string, unknown>
    }) => {
      const currentValues = mockFormValuesOverride ?? defaultValues

      const store = {
        subscribe: jest.fn(() => jest.fn()),
        getState: jest.fn(() => ({ isDirty: false, values: currentValues })),
      }

      return {
        store,
        state: { values: currentValues },
        reset: mockReset,
        setFieldValue: mockSetFieldValue,
        removeFieldValue: mockRemoveFieldValue,
        handleSubmit: () => {
          mockHandleSubmit()
          onSubmit?.({ value: currentValues })
        },
        AppField: ({
          children,
          name,
        }: {
          children: (field: ReturnType<typeof createFieldCtx>) => React.ReactNode
          name: string
        }) => {
          mockAppFieldChildren.set(name, { children: children as never, name })

          const fieldCtx = createFieldCtx(name, currentValues[name] ?? '')

          return <>{children(fieldCtx)}</>
        },
        Subscribe: ({
          children,
          selector,
        }: {
          children: (value: unknown) => React.ReactNode
          selector: (state: { canSubmit: boolean; values: Record<string, unknown> }) => unknown
        }) => {
          const value = selector({ canSubmit: true, values: currentValues })

          return <>{children(value)}</>
        },
      }
    },
  ),
}))

// Mock Tooltip to expose its props for assertions
jest.mock('~/components/designSystem/Tooltip', () => ({
  Tooltip: ({
    children,
    title,
    disableHoverListener,
    placement,
  }: {
    children: React.ReactNode
    title?: string
    disableHoverListener?: boolean
    placement?: string
  }) => (
    <div
      data-test="mocked-tooltip"
      data-tooltip-title={title || ''}
      data-tooltip-disabled={String(!!disableHoverListener)}
      data-tooltip-placement={placement || ''}
    >
      {children}
    </div>
  ),
}))

// Mock ComboBox to expose its props
jest.mock('~/components/form', () => ({
  ComboBox: ({
    value,
    error,
    placeholder,
    onChange,
    variant,
    data,
    className,
    disableClearable,
  }: {
    value?: string
    error?: boolean
    placeholder?: string
    onChange?: (v: string) => void
    variant?: string
    data?: { label: string; value: string }[]
    className?: string
    disableClearable?: boolean
  }) => (
    <div
      data-test="mocked-combobox"
      data-value={value || ''}
      data-error={String(!!error)}
      data-placeholder={placeholder || ''}
      data-variant={variant || ''}
      data-option-count={String(data?.length ?? 0)}
      data-classname={className || ''}
      data-disable-clearable={String(!!disableClearable)}
    >
      {data?.map((item, i) => (
        <button
          key={i}
          data-test={`combobox-option-${i}`}
          data-option-value={item.value}
          onClick={() => onChange?.(item.value)}
        />
      ))}
      <button data-test="combobox-trigger" onClick={() => onChange?.(data?.[0]?.value ?? '')} />
    </div>
  ),
  ComboboxItem: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}))

// Mock TextInput to expose its props
jest.mock('~/components/form/TextInput/TextInput', () => ({
  TextInput: ({
    error,
    variant,
    placeholder,
    beforeChangeFormatter,
    value,
    onChange,
    name,
  }: {
    error?: boolean
    variant?: string
    placeholder?: string
    beforeChangeFormatter?: string[]
    value?: string
    onChange?: (value: string) => void
    name?: string
  }) => (
    <div
      data-test="mocked-text-input"
      data-error={String(!!error)}
      data-variant={variant || ''}
      data-placeholder={placeholder || ''}
      data-formatter={beforeChangeFormatter?.join(',') || ''}
      data-value={value || ''}
      data-name={name || ''}
    >
      <input
        data-test="text-input-field"
        value={value || ''}
        onChange={(e) => onChange?.(e.target.value)}
      />
    </div>
  ),
}))

jest.mock('~/components/designSystem/Table/ChargeTable', () => ({
  ChargeTable: ({
    data,
    columns,
    onDeleteRow,
  }: {
    data: Record<string, unknown>[]
    columns: {
      content: (row: Record<string, unknown>, index: number) => React.ReactNode
    }[]
    onDeleteRow?: (row: Record<string, unknown>, index: number) => void
  }) => (
    <div data-test="mocked-charge-table">
      {data.map((row, i) => (
        <div key={i} data-test={`charge-table-row-${i}`}>
          {columns.map((col, j) => (
            <div key={j} data-test={`charge-table-cell-${i}-${j}`}>
              {typeof col.content === 'function' ? col.content(row, i) : null}
            </div>
          ))}
          {onDeleteRow && (
            <button data-test={`delete-row-${i}`} onClick={() => onDeleteRow(row, i)} />
          )}
        </div>
      ))}
    </div>
  ),
}))

jest.mock('~/components/designSystem/Button', () => ({
  Button: ({
    children,
    onClick,
    variant,
    icon,
    startIcon,
    disabled,
    ...rest
  }: {
    children?: React.ReactNode
    onClick?: () => void
    variant?: string
    icon?: string
    startIcon?: string
    disabled?: boolean
    [key: string]: unknown
  }) => (
    <button
      data-test={rest['data-test'] as string}
      data-variant={variant || ''}
      data-icon={icon || ''}
      data-start-icon={startIcon || ''}
      disabled={disabled}
      onClick={onClick}
    >
      {children}
    </button>
  ),
}))

jest.mock('~/components/designSystem/Selector', () => ({
  Selector: ({ title, subtitle }: { icon?: string; title?: string; subtitle?: string }) => (
    <div data-test="mocked-selector" data-title={title} data-subtitle={subtitle} />
  ),
}))

jest.mock('~/core/utils/domUtils', () => ({
  scrollToAndClickElement: jest.fn(),
}))

const createFieldCtx = (name: string, value: unknown, errors: { message: string }[] = []) => ({
  name,
  state: { value },
  store: {
    subscribe: jest.fn(() => jest.fn()),
    getState: jest.fn(() => ({
      meta: { errors, errorMap: {} },
      values: { [name]: value },
    })),
  },
  handleChange: mockHandleChange,
  handleBlur: mockHandleBlur,
  ComboBoxField: (props: Record<string, unknown>) => <input name={name} {...props} />,
  TextInputField: (props: Record<string, unknown>) => <input name={name} {...props} />,
})

const mockedUseFieldContext = useFieldContext as jest.Mock

describe('PrivilegesTable', () => {
  const defaultFormValues: FeatureEntitlementFormValues = {
    featureId: 'feature-1',
    featureName: 'Feature One',
    featureCode: 'feature_one',
    privileges: [],
  }

  const privilegeRow = {
    privilegeCode: 'priv-1',
    privilegeName: 'Privilege One',
    value: '',
    valueType: PrivilegeValueTypeEnum.String,
    config: undefined,
  }

  const renderContent = (overrides?: Partial<FeatureEntitlementFormValues>) => {
    if (overrides) {
      mockFormValuesOverride = { ...defaultFormValues, ...overrides }
    }

    const form = (useAppForm as jest.Mock)({
      defaultValues: defaultFormValues,
    })

    return render(<FeatureEntitlementDrawerContent form={form} existingFeatureCodes={[]} />)
  }

  beforeEach(() => {
    jest.clearAllMocks()
    mockAppFieldChildren = new Map()
    mockFormValuesOverride = null
    mockedUseFieldContext.mockReturnValue(createFieldCtx('testField', ''))
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  // --- Privilege table rendering ---

  describe('GIVEN the privilege table', () => {
    describe('WHEN privileges array has items', () => {
      it('THEN should render the ChargeTable', () => {
        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [privilegeRow],
        }

        const { container } = renderContent()

        expect(container.querySelector('[data-test="mocked-charge-table"]')).toBeTruthy()
      })
    })

    describe('WHEN privileges array is empty', () => {
      it('THEN should not render the ChargeTable', () => {
        mockFormValuesOverride = { ...defaultFormValues, privileges: [] }

        const { container } = renderContent()

        expect(container.querySelector('[data-test="mocked-charge-table"]')).toBeNull()
      })
    })

    describe('WHEN a privilege row is deleted', () => {
      it('THEN should call removeFieldValue with the correct index', () => {
        const secondPrivilege = {
          ...privilegeRow,
          privilegeCode: 'priv-2',
          privilegeName: 'Privilege Two',
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [privilegeRow, secondPrivilege],
        }

        const { container } = renderContent()

        const deleteBtn = container.querySelector('[data-test="delete-row-0"]') as HTMLButtonElement

        expect(deleteBtn).toBeTruthy()
        deleteBtn.click()

        expect(mockRemoveFieldValue).toHaveBeenCalledWith('privileges', 0)
      })

      it('THEN should remove the correct index when deleting a later row', () => {
        const secondPrivilege = {
          ...privilegeRow,
          privilegeCode: 'priv-2',
          privilegeName: 'Privilege Two',
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [privilegeRow, secondPrivilege],
        }

        const { container } = renderContent()

        const deleteBtn = container.querySelector('[data-test="delete-row-1"]') as HTMLButtonElement

        expect(deleteBtn).toBeTruthy()
        deleteBtn.click()

        expect(mockRemoveFieldValue).toHaveBeenCalledWith('privileges', 1)
      })
    })
  })

  // --- PrivilegeValueCell rendering per value type ---

  describe('GIVEN the PrivilegeValueCell component', () => {
    describe('WHEN the privilege valueType is String', () => {
      it('THEN should render a TextInput with error state and outlined variant', () => {
        const stringPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.String,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const textInput = container.querySelector('[data-test="mocked-text-input"]')

        expect(textInput).toBeTruthy()
        expect(textInput?.getAttribute('data-variant')).toBe('outlined')
      })

      it('THEN should render the string placeholder', () => {
        const stringPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.String,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const textInput = container.querySelector('[data-test="mocked-text-input"]')

        expect(textInput?.getAttribute('data-placeholder')).toBe(
          'translated_text_1753864223060d5jej59ti86',
        )
      })

      it('THEN should not apply beforeChangeFormatter', () => {
        const stringPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.String,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const textInput = container.querySelector('[data-test="mocked-text-input"]')

        expect(textInput?.getAttribute('data-formatter')).toBe('')
      })
    })

    describe('WHEN the privilege valueType is Integer', () => {
      it('THEN should render a TextInputField with int and positiveNumber formatters', () => {
        const intPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Integer,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [intPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const textInput = container.querySelector('[data-test="mocked-text-input"]')

        expect(textInput).toBeTruthy()
        expect(textInput?.getAttribute('data-formatter')).toBe('int,positiveNumber')
      })

      it('THEN should render the integer placeholder', () => {
        const intPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Integer,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [intPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const textInput = container.querySelector('[data-test="mocked-text-input"]')

        expect(textInput?.getAttribute('data-placeholder')).toBe(
          'translated_text_1753864223060bxskzw3877s',
        )
      })
    })

    describe('WHEN the privilege valueType is Select', () => {
      it('THEN should render a ComboBox with the select options', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          config: { selectOptions: ['option_a', 'option_b', 'option_c'] },
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBox = container.querySelector('[data-test="mocked-combobox"]')

        expect(comboBox).toBeTruthy()
        expect(comboBox?.getAttribute('data-variant')).toBe('outlined')
        expect(comboBox?.getAttribute('data-option-count')).toBe('3')
      })

      it('THEN should render the select placeholder', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          config: { selectOptions: ['opt1'] },
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBox = container.querySelector('[data-test="mocked-combobox"]')

        expect(comboBox?.getAttribute('data-placeholder')).toBe(
          'translated_text_66ab42d4ece7e6b7078993b1',
        )
      })

      it('THEN should display the current field value', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          value: 'option_a',
          config: { selectOptions: ['option_a', 'option_b'] },
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', 'option_a'))

        const { container } = renderContent()

        const comboBox = container.querySelector('[data-test="mocked-combobox"]')

        expect(comboBox?.getAttribute('data-value')).toBe('option_a')
      })

      it('THEN should handle missing config selectOptions gracefully', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          config: undefined,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBox = container.querySelector('[data-test="mocked-combobox"]')

        expect(comboBox).toBeTruthy()
        expect(comboBox?.getAttribute('data-option-count')).toBe('0')
      })
    })

    describe('WHEN the privilege valueType is Boolean', () => {
      it('THEN should render a ComboBox with true/false options', () => {
        const boolPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Boolean,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [boolPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBox = container.querySelector('[data-test="mocked-combobox"]')

        expect(comboBox).toBeTruthy()
        expect(comboBox?.getAttribute('data-option-count')).toBe('2')
      })

      it('THEN should render the boolean placeholder', () => {
        const boolPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Boolean,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [boolPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBox = container.querySelector('[data-test="mocked-combobox"]')

        expect(comboBox?.getAttribute('data-placeholder')).toBe(
          'translated_text_1753864223060ji5l38phiya',
        )
      })
    })
  })

  // --- Validation error tooltip ---

  describe('GIVEN the validation error tooltip', () => {
    describe('WHEN a String field has no validation errors', () => {
      it('THEN should render the tooltip with disableHoverListener true', () => {
        const stringPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.String,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', '', []))

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )

        expect(tooltip).toBeTruthy()
        expect(tooltip?.getAttribute('data-tooltip-disabled')).toBe('true')
        expect(tooltip?.getAttribute('data-tooltip-title')).toBe('')
      })
    })

    describe('WHEN a String field has a validation error', () => {
      it('THEN should render the tooltip with the translated error message', () => {
        const stringPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.String,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(
          createFieldCtx('privileges[0].value', '', [{ message: 'text_1771342994699klxu2paz7g8' }]),
        )

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )

        expect(tooltip).toBeTruthy()
        expect(tooltip?.getAttribute('data-tooltip-disabled')).toBe('false')
        expect(tooltip?.getAttribute('data-tooltip-title')).toBe(
          'translated_text_1771342994699klxu2paz7g8',
        )
      })
    })

    describe('WHEN a Select field has a validation error', () => {
      it('THEN should show the error tooltip and set error on ComboBox', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          config: { selectOptions: ['opt1'] },
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(
          createFieldCtx('privileges[0].value', '', [{ message: 'text_1771342994699klxu2paz7g8' }]),
        )

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )
        const comboBox = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-combobox"]',
        )

        expect(tooltip?.getAttribute('data-tooltip-disabled')).toBe('false')
        expect(comboBox?.getAttribute('data-error')).toBe('true')
      })
    })

    describe('WHEN a Boolean field has a validation error', () => {
      it('THEN should show the error tooltip and set error on ComboBox', () => {
        const boolPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Boolean,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [boolPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(
          createFieldCtx('privileges[0].value', '', [{ message: 'text_1771342994699klxu2paz7g8' }]),
        )

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )
        const comboBox = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-combobox"]',
        )

        expect(tooltip?.getAttribute('data-tooltip-disabled')).toBe('false')
        expect(comboBox?.getAttribute('data-error')).toBe('true')
      })
    })

    describe('WHEN a Select field has no validation errors', () => {
      it('THEN should disable the tooltip and not set error on ComboBox', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          config: { selectOptions: ['opt1'] },
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', '', []))

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )
        const comboBox = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-combobox"]',
        )

        expect(tooltip?.getAttribute('data-tooltip-disabled')).toBe('true')
        expect(comboBox?.getAttribute('data-error')).toBe('false')
      })
    })

    describe('WHEN the tooltip placement is set', () => {
      it('THEN should use top placement', () => {
        const stringPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.String,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )

        expect(tooltip?.getAttribute('data-tooltip-placement')).toBe('top')
      })
    })
  })

  // --- Multiple privileges ---

  describe('GIVEN multiple privileges with different value types', () => {
    describe('WHEN rendering a mix of String and Boolean privileges', () => {
      it('THEN should render the correct input type for each row', () => {
        const stringPrivilege = {
          ...privilegeRow,
          privilegeCode: 'priv-string',
          valueType: PrivilegeValueTypeEnum.String,
        }
        const boolPrivilege = {
          ...privilegeRow,
          privilegeCode: 'priv-bool',
          valueType: PrivilegeValueTypeEnum.Boolean,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [stringPrivilege, boolPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        // Row 0 should have TextInputField (String type)
        const row0Cell = container.querySelector('[data-test="charge-table-cell-0-1"]')

        expect(row0Cell?.querySelector('[data-test="mocked-text-input"]')).toBeTruthy()

        // Row 1 should have ComboBox (Boolean type)
        const row1Cell = container.querySelector('[data-test="charge-table-cell-1-1"]')

        expect(row1Cell?.querySelector('[data-test="mocked-combobox"]')).toBeTruthy()
      })
    })
  })

  // --- ComboBox onChange handlers in PrivilegeValueCell ---

  describe('GIVEN the ComboBox onChange handlers in PrivilegeValueCell', () => {
    describe('WHEN a Select ComboBox value is changed', () => {
      it('THEN should call field.handleChange with the new value', () => {
        const selectPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Select,
          config: { selectOptions: ['option_a', 'option_b'] },
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [selectPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBoxTrigger = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="combobox-trigger"]',
        ) as HTMLButtonElement

        expect(comboBoxTrigger).toBeTruthy()
        comboBoxTrigger.click()

        expect(mockHandleChange).toHaveBeenCalled()
      })
    })

    describe('WHEN a Boolean ComboBox value is changed', () => {
      it('THEN should call field.handleChange with the new value', () => {
        const boolPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Boolean,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [boolPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(createFieldCtx('privileges[0].value', ''))

        const { container } = renderContent()

        const comboBoxTrigger = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="combobox-trigger"]',
        ) as HTMLButtonElement

        expect(comboBoxTrigger).toBeTruthy()
        comboBoxTrigger.click()

        expect(mockHandleChange).toHaveBeenCalled()
      })
    })
  })

  // --- Integer field error handling ---

  describe('GIVEN the Integer field error handling', () => {
    describe('WHEN an Integer field has a validation error', () => {
      it('THEN should show the error tooltip on TextInputField', () => {
        const intPrivilege = {
          ...privilegeRow,
          valueType: PrivilegeValueTypeEnum.Integer,
        }

        mockFormValuesOverride = {
          ...defaultFormValues,
          privileges: [intPrivilege],
        }

        mockedUseFieldContext.mockReturnValue(
          createFieldCtx('privileges[0].value', '', [{ message: 'text_1771342994699klxu2paz7g8' }]),
        )

        const { container } = renderContent()

        const tooltip = container.querySelector(
          '[data-test="charge-table-cell-0-1"] [data-test="mocked-tooltip"]',
        )

        expect(tooltip?.getAttribute('data-tooltip-disabled')).toBe('false')
        expect(tooltip?.getAttribute('data-tooltip-title')).toBe(
          'translated_text_1771342994699klxu2paz7g8',
        )
      })
    })
  })
})
