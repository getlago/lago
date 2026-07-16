import { revalidateLogic, useStore } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle } from 'react'
import { z } from 'zod'

import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { PaymentMethodFields } from '~/components/paymentMethodSelection/PaymentMethodFields'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'

const PAYMENT_SETTINGS_FORM_ID = 'payment-settings-drawer-form'

interface PaymentSettingsValues {
  paymentMethod: SelectedPaymentMethod
}

const DEFAULT_VALUES: PaymentSettingsValues = { paymentMethod: undefined }

const paymentSettingsValidationSchema = z.object({
  paymentMethod: z
    .custom<SelectedPaymentMethod>()
    .refine(
      (value) =>
        !(
          value?.paymentMethodType === PaymentMethodTypeEnum.Provider &&
          value?.paymentMethodId === undefined
        ),
      { message: 'text_624ea7c29103fd010732ab7d' },
    ),
})

interface PaymentSettingsDrawerContentExtraProps {
  viewType: ViewTypeEnum
  externalCustomerId: string
}

const paymentSettingsDrawerContentDefaultProps: PaymentSettingsDrawerContentExtraProps = {
  viewType: ViewTypeEnum.Subscription,
  externalCustomerId: '',
}

const PaymentSettingsDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: paymentSettingsDrawerContentDefaultProps,
  render: function PaymentSettingsDrawerContentRender({ form, viewType, externalCustomerId }) {
    const { translate } = useInternationalization()
    const paymentMethod = useStore(form.store, (s) => s.values.paymentMethod)
    const paymentMethodError = useStore(
      form.store,
      (s) => s.fieldMeta.paymentMethod?.errors?.[0]?.message,
    )

    return (
      <CenteredPage.SectionWrapper>
        <CenteredPage.PageTitle
          title={translate('text_17828013737948943pe3k8nc')}
          description={translate('text_17828013737955532qxu3wq4')}
        />

        <CenteredPage.PageSection>
          <CenteredPage.PageSectionTitle
            title={translate('text_17440371192353kif37ol194')}
            description={translate('text_1782804838056cnj8mzoxrd3')}
          />
          <PaymentMethodFields
            viewType={viewType}
            externalCustomerId={externalCustomerId}
            value={paymentMethod}
            onChange={(value) => form.setFieldValue('paymentMethod', value)}
            error={paymentMethodError ? translate(paymentMethodError) : undefined}
          />
        </CenteredPage.PageSection>
      </CenteredPage.SectionWrapper>
    )
  },
})

export interface PaymentSettingsDrawerRef {
  openDrawer: (values: { paymentMethod?: SelectedPaymentMethod }) => void
  closeDrawer: () => void
}

interface PaymentSettingsDrawerProps {
  viewType: ViewTypeEnum
  externalCustomerId: string
  onSave: (values: PaymentSettingsValues) => void | Promise<void>
}

export const PaymentSettingsDrawer = forwardRef<
  PaymentSettingsDrawerRef,
  PaymentSettingsDrawerProps
>(({ viewType, externalCustomerId, onSave }, ref) => {
  const { translate } = useInternationalization()
  const drawer = useFormDrawer()

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: paymentSettingsValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await onSave({ paymentMethod: value.paymentMethod })
      drawer.close()
    },
  })

  const openPaymentSettingsDrawer = (): void => {
    drawer.open({
      title: translate('text_17828013737948943pe3k8nc'),
      form: { id: PAYMENT_SETTINGS_FORM_ID, submit: form.handleSubmit },
      closeOnSubmitSuccess: false,
      shouldPromptOnClose: () => form.state.isDirty,
      onClose: () => form.reset(),
      onEntered: (container) => focusFirstInput(container),
      children: (
        <PaymentSettingsDrawerContent
          form={form}
          viewType={viewType}
          externalCustomerId={externalCustomerId}
        />
      ),
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest="payment-settings-drawer-save">
            {translate('text_17295436903260tlyb1gp1i7')}
          </form.SubmitButton>
        </form.AppForm>
      ),
    })
  }

  useImperativeHandle(ref, () => ({
    openDrawer: (values) => {
      form.reset(
        { paymentMethod: values.paymentMethod ?? DEFAULT_VALUES.paymentMethod },
        { keepDefaultValues: true },
      )
      openPaymentSettingsDrawer()
    },
    closeDrawer: () => {
      drawer.close()
    },
  }))

  return null
})

PaymentSettingsDrawer.displayName = 'PaymentSettingsDrawer'
