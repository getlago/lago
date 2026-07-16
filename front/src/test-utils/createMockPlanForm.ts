import React from 'react'

import { PlanFormInput } from '~/components/plans/types'
import { CurrencyEnum, PlanInterval } from '~/generated/graphql'
import { PlanFormType } from '~/hooks/plans/usePlanForm'

const DEFAULT_PLAN_VALUES: PlanFormInput = {
  name: 'Test Plan',
  code: 'test-plan',
  description: '',
  interval: PlanInterval.Monthly,
  payInAdvance: false,
  amountCents: '100',
  amountCurrency: CurrencyEnum.Usd,
  trialPeriod: 0,
  taxes: [],
  billChargesMonthly: false,
  billFixedChargesMonthly: false,
  charges: [],
  fixedCharges: [],
  minimumCommitment: {},
  invoiceDisplayName: '',
  entitlements: [],
}

/**
 * Creates a mock TanStack form instance for testing plan form sections.
 * The mock provides a reactive store that useStore() can subscribe to.
 */
export const createMockPlanForm = (overrides: Partial<PlanFormInput> = {}): PlanFormType => {
  const values = { ...DEFAULT_PLAN_VALUES, ...overrides }
  let subscribers: (() => void)[] = []

  const state = {
    values,
    isDirty: false,
    canSubmit: true,
    isSubmitting: false,
    errors: [],
    errorMap: {},
    submissionAttempts: 0,
    isValid: true,
    isTouched: false,
    isPristine: true,
    isFieldsValid: true,
    isFieldsValidating: false,
    fieldMeta: {},
  }

  const store = {
    get: () => state,
    getState: () => state,
    subscribe: (cb: () => void) => {
      subscribers.push(cb)

      const unsubscribe = () => {
        subscribers = subscribers.filter((s) => s !== cb)
      }

      return { unsubscribe }
    },
    setState: (updater: (prev: typeof state) => typeof state) => {
      Object.assign(state, updater(state))
      subscribers.forEach((cb) => cb())
    },
  }

  return {
    store,
    state,
    setFieldValue: jest.fn((field: string, value: unknown) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ;(state.values as any)[field] = value
      subscribers.forEach((cb) => cb())
    }),
    setFieldMeta: jest.fn(),
    getFieldValue: jest.fn((field: string) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      return (state.values as any)[field]
    }),
    handleSubmit: jest.fn(),
    reset: jest.fn(),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    AppField: ({ children, name }: { children: (field: any) => React.ReactNode; name: string }) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const fieldValue = (state.values as any)[name]

      // Stub field components that render basic HTML for testing
      const stubFieldComponents = {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        TextInputField: (props: any) =>
          React.createElement('input', {
            type: 'text',
            value: fieldValue ?? '',
            placeholder: props.placeholder,
            'aria-label': name,
            onChange: () => {},
          }),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        SwitchField: (props: any) =>
          React.createElement('input', {
            type: 'checkbox',
            checked: !!fieldValue,
            'aria-label': name,
            name,
            onChange: () => {},
            ...(props.label ? { 'data-label': props.label } : {}),
          }),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ComboBoxField: (props: any) =>
          React.createElement('select', {
            value: fieldValue ?? '',
            'aria-label': props.label || name,
            onChange: () => {},
          }),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ButtonSelectorField: (props: any) =>
          React.createElement('div', { 'data-testid': `button-selector-${name}` }, props.label),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        AmountInputField: (props: any) =>
          React.createElement('input', {
            type: 'text',
            value: fieldValue ?? '',
            'aria-label': props.label || name,
            onChange: () => {},
          }),
        CheckboxField: () => React.createElement('input', { type: 'checkbox', 'aria-label': name }),
        RadioGroupField: () => React.createElement('div', { 'aria-label': name }),
        RadioField: () => React.createElement('input', { type: 'radio', 'aria-label': name }),
        DatePickerField: () => React.createElement('input', { type: 'date', 'aria-label': name }),
        MultipleComboBoxField: () => React.createElement('div', { 'aria-label': name }),
      }

      return children({
        state: { value: fieldValue },
        handleChange: jest.fn(),
        ...stubFieldComponents,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
      }) as any
    },
    Subscribe: ({
      children,
      selector,
    }: {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      children: (value: any) => React.ReactNode
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      selector: (state: any) => any
    }) => {
      return children(selector(state))
    },
  } as unknown as PlanFormType
}
