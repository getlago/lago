import { useStore } from '@tanstack/react-form'

import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { ProviderPaymentMethodsEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

const StripePaymentProviderContent = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  render: function Render({ form }) {
    const { translate } = useInternationalization()
    const paymentProviderCustomer = useStore(
      form.store,
      (state) => state.values.paymentProviderCustomer,
    )

    const paymentMethods = paymentProviderCustomer?.providerPaymentMethods || {}
    const isPaymentMethodUnique = Object.values(paymentMethods).filter(Boolean).length === 1
    const isBankTransferEnabled = paymentMethods[ProviderPaymentMethodsEnum.CustomerBalance]

    const handleCardOnChange = (checked: boolean | undefined) => {
      if (!checked) {
        // uncheck link if card is unchecked
        form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.link', false)

        return
      }

      // uncheck bank transfer
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.customer_balance', false)
    }

    const handleCustomerBalanceChange = (checked: boolean | undefined) => {
      if (!checked) return

      // uncheck all except for bank transfer
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.card', false)
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.link', false)
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.sepa_debit', false)
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.us_bank_account', false)
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.bacs_debit', false)
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.boleto', false)
      form.setFieldValue('paymentProviderCustomer.providerPaymentMethods.crypto', false)
    }

    return (
      <div className="flex flex-col gap-6 p-4 shadow-t">
        <div>
          <Typography variant="bodyHl" color="grey700">
            {translate('text_64aeb7b998c4322918c84204')}
          </Typography>
          <Typography variant="caption">{translate('text_64aeb7b998c4322918c84210')}</Typography>
        </div>

        <div className="flex flex-col gap-1">
          <Typography variant="captionHl" color="grey700">
            {translate('text_65e1f90471bc198c0c934d82')}
          </Typography>
          <div className="grid grid-cols-2 gap-4">
            <form.AppField
              name="paymentProviderCustomer.providerPaymentMethods.card"
              listeners={{
                onChange: ({ value: checked }) => handleCardOnChange(checked),
              }}
            >
              {(field) => (
                <field.CheckboxField
                  label={translate('text_64aeb7b998c4322918c84208')}
                  sublabel={translate('text_65e1f90471bc198c0c934d86')}
                />
              )}
            </form.AppField>
            {/* Link can be enabled only if Card is enabled */}
            <form.AppField name="paymentProviderCustomer.providerPaymentMethods.link">
              {(field) => (
                <field.CheckboxField
                  label={translate('text_6686b316b672a6e75a29eea0')}
                  sublabel={translate('text_6686b316b672a6e75a29eea2')}
                  disabled={!paymentMethods[ProviderPaymentMethodsEnum.Card]}
                />
              )}
            </form.AppField>

            <form.AppField
              name="paymentProviderCustomer.providerPaymentMethods.customer_balance"
              listeners={{
                onChange: ({ value: checked }) => handleCustomerBalanceChange(checked),
              }}
            >
              {(field) => (
                <field.CheckboxField
                  label={translate('text_1739432510045wh80q1wdt4z')}
                  sublabel={translate('text_1739432510045brhda8fxidc')}
                />
              )}
            </form.AppField>
          </div>
        </div>
        <div className="flex flex-col gap-1">
          <Typography variant="captionHl" color="grey700">
            {translate('text_65e1f90471bc198c0c934d88')}
          </Typography>

          <div className="grid grid-cols-2 gap-4">
            <form.AppField name="paymentProviderCustomer.providerPaymentMethods.sepa_debit">
              {(field) => (
                <field.CheckboxField
                  label={translate('text_64aeb7b998c4322918c8420c')}
                  sublabel={translate('text_65e1f90471bc198c0c934d8c')}
                  disabled={
                    isBankTransferEnabled ||
                    (isPaymentMethodUnique && paymentMethods[ProviderPaymentMethodsEnum.SepaDebit])
                  }
                />
              )}
            </form.AppField>
            <form.AppField name="paymentProviderCustomer.providerPaymentMethods.us_bank_account">
              {(field) => (
                <field.CheckboxField
                  label={translate('text_65e1f90471bc198c0c934d8e')}
                  sublabel={translate('text_65e1f90471bc198c0c934d90')}
                  disabled={
                    isBankTransferEnabled ||
                    (isPaymentMethodUnique &&
                      paymentMethods[ProviderPaymentMethodsEnum.UsBankAccount])
                  }
                />
              )}
            </form.AppField>
            <form.AppField name="paymentProviderCustomer.providerPaymentMethods.bacs_debit">
              {(field) => (
                <field.CheckboxField
                  label={translate('text_65e1f90471bc198c0c934d92')}
                  sublabel={translate('text_65e1f90471bc198c0c934d94')}
                  disabled={
                    isBankTransferEnabled ||
                    (isPaymentMethodUnique && paymentMethods[ProviderPaymentMethodsEnum.BacsDebit])
                  }
                />
              )}
            </form.AppField>
            <form.AppField name="paymentProviderCustomer.providerPaymentMethods.boleto">
              {(field) => (
                <field.CheckboxField
                  label={translate('text_1738234109827diqh4eswleu')}
                  sublabel={translate('text_1738234109827hev75h17loy')}
                  disabled={
                    isBankTransferEnabled ||
                    (isPaymentMethodUnique && paymentMethods[ProviderPaymentMethodsEnum.Boleto])
                  }
                />
              )}
            </form.AppField>
            <form.AppField name="paymentProviderCustomer.providerPaymentMethods.crypto">
              {(field) => (
                <field.CheckboxField
                  label={translate('text_17394287699017cunbdlhnhf')}
                  sublabel={translate('text_65e1f90471bc198c0c934d90')}
                  disabled={
                    isBankTransferEnabled ||
                    (isPaymentMethodUnique && paymentMethods[ProviderPaymentMethodsEnum.Crypto])
                  }
                />
              )}
            </form.AppField>
          </div>
        </div>

        <Alert type="info">{translate('text_64aeb7b998c4322918c84214')}</Alert>
      </div>
    )
  },
})

export default StripePaymentProviderContent
