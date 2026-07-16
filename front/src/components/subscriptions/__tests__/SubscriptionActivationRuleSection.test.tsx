import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useEffect } from 'react'

import { useDisplayedPaymentMethod } from '~/components/paymentMethodSelection/useDisplayedPaymentMethod'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { ActivationRuleFormTypeEnum } from '~/core/constants/subscriptionActivationRules'
import { SubscriptionFormValues } from '~/formValidation/subscriptionFormSchema'
import { StatusTypeEnum } from '~/generated/graphql'
import { usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'
import { useAppForm } from '~/hooks/forms/useAppform'
import { render } from '~/test-utils'

import { buildSubscriptionDefaultValues } from '../form/buildSubscriptionDefaultValues'
import {
  SUBSCRIPTION_ACTIVATION_RULE_SECTION_TEST_ID,
  SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID,
  SubscriptionActivationRuleSection,
} from '../SubscriptionActivationRuleSection'

const IMMEDIATELY_RADIO_VALUE = ActivationRuleFormTypeEnum.Immediately
const ON_PAYMENT_RADIO_VALUE = ActivationRuleFormTypeEnum.OnPayment

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/customer/usePaymentMethodsList', () => ({
  usePaymentMethodsList: jest.fn(() => ({
    data: [],
    loading: false,
    error: false,
    refetch: jest.fn(),
  })),
}))

jest.mock('~/components/paymentMethodSelection/useDisplayedPaymentMethod', () => ({
  useDisplayedPaymentMethod: jest.fn(),
}))

const mockUseDisplayedPaymentMethod = jest.mocked(useDisplayedPaymentMethod)
const mockUsePaymentMethodsList = jest.mocked(usePaymentMethodsList)

type WrapperProps = {
  activationRuleType?: ActivationRuleFormTypeEnum
  customerExternalId?: string | null
  formType?: keyof typeof FORM_TYPE_ENUM
  subscriptionStatus?: StatusTypeEnum | null
  onActivationRuleTypeChange?: (value?: ActivationRuleFormTypeEnum) => void
}

const Wrapper = ({
  activationRuleType = ActivationRuleFormTypeEnum.Immediately,
  customerExternalId = 'cust-ext-1',
  formType = FORM_TYPE_ENUM.creation,
  subscriptionStatus,
  onActivationRuleTypeChange,
}: WrapperProps) => {
  const defaultValues: SubscriptionFormValues = {
    ...buildSubscriptionDefaultValues(undefined, FORM_TYPE_ENUM.creation, '2026-01-01'),
    activationRuleType,
  }

  const form = useAppForm({ defaultValues })

  useEffect(() => {
    if (!onActivationRuleTypeChange) return

    const subscription = form.store.subscribe(() => {
      onActivationRuleTypeChange(form.state.values.activationRuleType)
    })

    return () => subscription.unsubscribe()
  }, [form, onActivationRuleTypeChange])

  return (
    <form.AppForm>
      <SubscriptionActivationRuleSection
        form={form}
        customerExternalId={customerExternalId}
        formType={formType}
        subscriptionStatus={subscriptionStatus}
      />
    </form.AppForm>
  )
}

const getRadioInput = (value: string): HTMLInputElement =>
  screen
    .getByTestId(SUBSCRIPTION_ACTIVATION_RULE_SECTION_TEST_ID)
    .querySelector(`input[type="radio"][value="${value}"]`) as HTMLInputElement

describe('SubscriptionActivationRuleSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUsePaymentMethodsList.mockReturnValue({
      data: [],
      loading: false,
      error: undefined,
      refetch: jest.fn(),
    } as unknown as ReturnType<typeof usePaymentMethodsList>)
    mockUseDisplayedPaymentMethod.mockReturnValue({
      paymentMethod: null,
      isManual: false,
      isInherited: false,
    })
  })

  describe('GIVEN a customer with an automatic (non-manual) payment method', () => {
    describe('WHEN the section renders in creation mode', () => {
      it('THEN should display the activation rule section', () => {
        render(<Wrapper />)

        expect(screen.getByTestId(SUBSCRIPTION_ACTIVATION_RULE_SECTION_TEST_ID)).toBeInTheDocument()
      })

      it.each([
        ['immediately', IMMEDIATELY_RADIO_VALUE],
        ['on payment', ON_PAYMENT_RADIO_VALUE],
      ])('THEN should render the "%s" radio option enabled', (_, testId) => {
        render(<Wrapper />)

        expect(getRadioInput(testId)).not.toBeDisabled()
      })

      it('THEN should not display the timeout field while "immediately" is selected', () => {
        render(<Wrapper activationRuleType={ActivationRuleFormTypeEnum.Immediately} />)

        expect(
          screen.queryByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })

    describe('WHEN "activate on payment" is selected', () => {
      it('THEN should display the timeout field', () => {
        render(<Wrapper activationRuleType={ActivationRuleFormTypeEnum.OnPayment} />)

        expect(
          screen.getByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
        ).toBeInTheDocument()
      })
    })

    describe('WHEN the user selects "activate on payment"', () => {
      it('THEN should reveal the timeout field', async () => {
        const user = userEvent.setup()

        render(<Wrapper />)

        expect(
          screen.queryByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
        ).not.toBeInTheDocument()

        await user.click(getRadioInput(ON_PAYMENT_RADIO_VALUE))

        await waitFor(() => {
          expect(
            screen.getByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
          ).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the effective payment method is manual', () => {
    beforeEach(() => {
      mockUseDisplayedPaymentMethod.mockReturnValue({
        paymentMethod: null,
        isManual: true,
        isInherited: true,
      })
    })

    describe('WHEN the section renders', () => {
      it.each([
        ['immediately', IMMEDIATELY_RADIO_VALUE],
        ['on payment', ON_PAYMENT_RADIO_VALUE],
      ])('THEN should disable the whole group including the "%s" option', (_, testId) => {
        render(<Wrapper />)

        expect(getRadioInput(testId)).toBeDisabled()
      })
    })

    describe('WHEN "activate on payment" was previously selected', () => {
      it('THEN should reset the selection back to "immediately"', async () => {
        const onActivationRuleTypeChange = jest.fn()

        render(
          <Wrapper
            activationRuleType={ActivationRuleFormTypeEnum.OnPayment}
            onActivationRuleTypeChange={onActivationRuleTypeChange}
          />,
        )

        await waitFor(() => {
          expect(onActivationRuleTypeChange).toHaveBeenLastCalledWith(
            ActivationRuleFormTypeEnum.Immediately,
          )
        })
      })

      it('THEN should hide the timeout field once reset', async () => {
        render(<Wrapper activationRuleType={ActivationRuleFormTypeEnum.OnPayment} />)

        await waitFor(() => {
          expect(
            screen.queryByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
          ).not.toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the loaded selection is "activate on payment" but payment methods are still loading', () => {
    beforeEach(() => {
      mockUsePaymentMethodsList.mockReturnValue({
        data: undefined,
        loading: true,
        error: undefined,
        refetch: jest.fn(),
      } as unknown as ReturnType<typeof usePaymentMethodsList>)
      // While the list is unresolved, useDisplayedPaymentMethod falls back to manual
      mockUseDisplayedPaymentMethod.mockReturnValue({
        paymentMethod: null,
        isManual: true,
        isInherited: true,
      })
    })

    describe('WHEN the section renders during the loading window', () => {
      it('THEN should keep "activate on payment" selected and not reset it to "immediately"', async () => {
        const onActivationRuleTypeChange = jest.fn()

        render(
          <Wrapper
            activationRuleType={ActivationRuleFormTypeEnum.OnPayment}
            onActivationRuleTypeChange={onActivationRuleTypeChange}
          />,
        )

        // The timeout field only renders while "on payment" is the active selection,
        // so its presence proves the loaded selection was not clobbered.
        expect(
          screen.getByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
        ).toBeInTheDocument()

        // Give the auto-correction effect a chance to (wrongly) fire before asserting.
        await waitFor(() => {
          expect(
            screen.getByTestId(SUBSCRIPTION_ACTIVATION_TIMEOUT_INPUT_TEST_ID),
          ).toBeInTheDocument()
        })

        expect(onActivationRuleTypeChange).not.toHaveBeenCalledWith(
          ActivationRuleFormTypeEnum.Immediately,
        )
      })
    })
  })

  describe('GIVEN no customer external id (payment methods cannot be resolved)', () => {
    describe('WHEN the section renders', () => {
      it('THEN should disable the activation options', () => {
        render(<Wrapper customerExternalId={null} />)

        expect(getRadioInput(ON_PAYMENT_RADIO_VALUE)).toBeDisabled()
      })
    })
  })

  describe('GIVEN editability rules by form type and status', () => {
    describe('WHEN editing a non-pending subscription', () => {
      it('THEN should disable the activation options', () => {
        render(
          <Wrapper formType={FORM_TYPE_ENUM.edition} subscriptionStatus={StatusTypeEnum.Active} />,
        )

        expect(getRadioInput(IMMEDIATELY_RADIO_VALUE)).toBeDisabled()
      })
    })

    describe('WHEN editing a pending subscription', () => {
      it('THEN should keep the activation options enabled', () => {
        render(
          <Wrapper formType={FORM_TYPE_ENUM.edition} subscriptionStatus={StatusTypeEnum.Pending} />,
        )

        expect(getRadioInput(IMMEDIATELY_RADIO_VALUE)).not.toBeDisabled()
      })
    })
  })
})
