import { screen } from '@testing-library/react'

import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { BillingTimeEnum, PlanInterval } from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionFormType } from '../buildSubscriptionDefaultValues'
import { SubscriptionInformationFormSection } from '../SubscriptionInformationFormSection'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/forms/formContext', () => ({
  useFieldContext: jest.fn(),
}))

const mockSetFieldValue = jest.fn()

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
  useStore: (
    store: { state: { values: Record<string, unknown> } },
    selector: (state: { values: Record<string, unknown> }) => unknown,
  ) => selector(store.state),
}))

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: jest.fn(),
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
        return <RenderComponent {...defaultProps} {...receivedProps} />
      }

      WithFormWrapper.displayName = 'WithFormWrapper'

      return WithFormWrapper
    },
  ),
}))

const createMockForm = (values: Record<string, unknown> = {}) => ({
  setFieldValue: mockSetFieldValue,
  store: {
    state: {
      values: { billingTime: BillingTimeEnum.Calendar, subscriptionAt: '', ...values },
    },
  },
  AppField: ({
    children,
    name,
  }: {
    children: (field: Record<string, React.FC<Record<string, unknown>>>) => React.ReactNode
    name: string
  }) => {
    const FieldComponent: React.FC<Record<string, unknown>> = (fieldProps) => (
      <input
        name={name}
        disabled={fieldProps.disabled as boolean | undefined}
        placeholder={fieldProps.placeholder as string | undefined}
        aria-label={fieldProps.label as string | undefined}
      />
    )

    return (
      <>
        {children({
          TextInputField: FieldComponent,
          DatePickerField: FieldComponent,
          ButtonSelectorField: FieldComponent,
        })}
      </>
    )
  },
  Subscribe: ({
    children,
    selector,
  }: {
    children: (value: unknown) => React.ReactNode
    selector: (state: {
      fieldMeta: Record<string, { errors?: unknown[] }>
      values: Record<string, unknown>
    }) => unknown
  }) => {
    const value = selector({
      fieldMeta: {},
      values: {
        billingTime: BillingTimeEnum.Calendar,
        subscriptionAt: '',
        endingAt: '',
        ...values,
      },
    })

    return <>{children(value)}</>
  },
})

const renderSection = (
  overrides: Partial<{
    formType: SubscriptionFormType
    shouldDisplaySubscriptionExternalId: boolean
    shouldDisplaySubscriptionName: boolean
    selectedPlanInterval: PlanInterval
  }> = {},
) =>
  render(
    <SubscriptionInformationFormSection
      // @ts-expect-error — mock form shape
      form={createMockForm()}
      formType={overrides.formType ?? FORM_TYPE_ENUM.creation}
      subscription={undefined}
      customerTimezone={undefined}
      shouldDisplaySubscriptionExternalId={overrides.shouldDisplaySubscriptionExternalId ?? false}
      setShouldDisplaySubscriptionExternalId={jest.fn()}
      shouldDisplaySubscriptionName={overrides.shouldDisplaySubscriptionName ?? false}
      setShouldDisplaySubscriptionName={jest.fn()}
      selectedPlanInterval={overrides.selectedPlanInterval}
    />,
  )

describe('SubscriptionInformationFormSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN show-flags are off', () => {
    it('THEN should render the show external-id and show name buttons', () => {
      renderSection()

      expect(screen.getByTestId('show-external-id')).toBeInTheDocument()
      expect(screen.getByTestId('show-name')).toBeInTheDocument()
    })
  })

  describe('GIVEN externalId display is enabled', () => {
    it('THEN should render the externalId field and hide its add button', () => {
      renderSection({ shouldDisplaySubscriptionExternalId: true })

      expect(screen.queryByTestId('show-external-id')).not.toBeInTheDocument()
      expect(screen.getByTestId('create-subscription-form-wrapper')).toBeInTheDocument()
    })
  })

  describe('GIVEN formType is upgradeDowngrade', () => {
    it('THEN should hide the show buttons section but keep the form wrapper', () => {
      renderSection({ formType: FORM_TYPE_ENUM.upgradeDowngrade })

      expect(screen.getByTestId('create-subscription-form-wrapper')).toBeInTheDocument()
      expect(screen.queryByText('text_62ea7cd44cd4b14bb9ac1db7')).not.toBeInTheDocument()
    })
  })
})
