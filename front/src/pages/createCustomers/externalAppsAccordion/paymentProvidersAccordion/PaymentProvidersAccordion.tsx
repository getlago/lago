import { useStore } from '@tanstack/react-form'
import { Dispatch, ReactNode, SetStateAction, useMemo } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { ComboboxDataGrouped } from '~/components/form'
import { ADD_CUSTOMER_PAYMENT_PROVIDER_ACCORDION } from '~/core/constants/form'
import {
  AddCustomerDrawerFragment,
  CurrencyEnum,
  ProviderPaymentMethodsEnum,
  ProviderTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { usePaymentProviders } from '~/pages/createCustomers/common/usePaymentProviders'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import Adyen from '~/public/images/adyen.svg'
import Cashfree from '~/public/images/cashfree.svg'
import Flutterwave from '~/public/images/flutterwave.svg'
import GoCardless from '~/public/images/gocardless.svg'
import Moneyhash from '~/public/images/moneyhash.svg'
import Stripe from '~/public/images/stripe.svg'

import StripePaymentProviderContent from './StripePaymentProviderContent'

import { ExternalAppsAccordionLayout } from '../common/ExternalAppsAccordionLayout'

type PaymentProvidersAccordionProps = {
  setShowPaymentSection: Dispatch<SetStateAction<boolean>>
  isEdition: boolean
  customer: AddCustomerDrawerFragment | null | undefined
}

const avatarMapping: Record<ProviderTypeEnum, ReactNode> = {
  [ProviderTypeEnum.Adyen]: <Adyen />,
  [ProviderTypeEnum.Cashfree]: <Cashfree />,
  [ProviderTypeEnum.Flutterwave]: <Flutterwave />,
  [ProviderTypeEnum.Gocardless]: <GoCardless />,
  [ProviderTypeEnum.Stripe]: <Stripe />,
  [ProviderTypeEnum.Moneyhash]: <Moneyhash />,
}

const defaultProps: PaymentProvidersAccordionProps = {
  setShowPaymentSection: () => {},
  isEdition: false,
  customer: null,
}

const PaymentProvidersAccordion = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({ form, customer, setShowPaymentSection }) {
    const { translate } = useInternationalization()

    const { paymentProviders, isLoadingPaymentProviders, getPaymentProvider } =
      usePaymentProviders()

    const paymentProviderCode = useStore(form.store, (state) => state.values.paymentProviderCode)
    const providerCustomer = useStore(form.store, (state) => state.values.paymentProviderCustomer)
    const paymentProvider = getPaymentProvider(paymentProviderCode)
    const currency = useStore(form.store, (state) => state.values.currency)

    const hadPaymentProvider = !!customer?.providerCustomer?.providerCustomerId

    const selectedPaymentProvider = paymentProviders?.paymentProviders?.collection.find(
      (p) => p.code === paymentProviderCode,
    )

    const isSyncWithProviderDisabled = !!providerCustomer?.syncWithProvider

    const connectedPaymentProvidersData: ComboboxDataGrouped[] | [] = useMemo(() => {
      if (!paymentProviders?.paymentProviders?.collection.length) return []

      return paymentProviders?.paymentProviders?.collection.map((provider) => ({
        value: provider.code,
        label: provider.name,
        group: provider.__typename.toLocaleLowerCase().replace('provider', ''),
        labelNode: (
          <ExternalAppsAccordionLayout.ComboboxItem
            label={provider.name}
            subLabel={provider.code}
          />
        ),
      }))
    }, [paymentProviders?.paymentProviders?.collection])

    const isSyncWithProviderSupported = useMemo(() => {
      if (!paymentProvider) return false
      const unsupportedPaymentProviders: ProviderTypeEnum[] = [
        ProviderTypeEnum.Cashfree,
        ProviderTypeEnum.Flutterwave,
      ]

      return !unsupportedPaymentProviders.includes(paymentProvider)
    }, [paymentProvider])

    const handleDeletePaymentProvider = () => {
      form.setFieldValue('paymentProviderCode', undefined)
      form.setFieldValue('paymentProviderCustomer.providerCustomerId', '')
      form.setFieldValue('paymentProviderCustomer.syncWithProvider', false)
      form.setFieldValue('paymentProviderCustomer.providerType', undefined)
      form.setFieldValue(
        'paymentProviderCustomer.providerPaymentMethods',
        currency === CurrencyEnum.Eur
          ? {
              [ProviderPaymentMethodsEnum.Card]: true,
              [ProviderPaymentMethodsEnum.SepaDebit]: true,
            }
          : {
              [ProviderPaymentMethodsEnum.Card]: true,
            },
      )
      setShowPaymentSection(false)
    }

    const handleChangePaymentProviderCode = (value: string | undefined) => {
      const providerType = getPaymentProvider(value)

      form.setFieldValue('paymentProviderCustomer.providerType', providerType || undefined)
    }

    const getSyncWithProviderLabel = () => {
      const suffix = paymentProviderCode
        ? ` • ${
            connectedPaymentProvidersData.find((provider) => provider.value === paymentProviderCode)
              ?.label
          }`
        : ''

      if (paymentProvider === ProviderTypeEnum.Gocardless) {
        return `${translate('text_635bdbda84c98758f9bba8aa')}${suffix}`
      }
      if (paymentProvider === ProviderTypeEnum.Adyen) {
        return `${translate('text_645d0728ea0a5a7bbf76d5c7')}${suffix}`
      }
      if (paymentProvider === ProviderTypeEnum.Moneyhash) {
        return `${translate('text_1733992108437qlovqhjhqj4')}${suffix}`
      }
      return `${translate('text_635bdbda84c98758f9bba89e')}${suffix}`
    }

    const handleSyncWithProviderChange = (checked: boolean | undefined) => {
      if (!checked) return

      const newProviderCustomer = { ...providerCustomer }

      newProviderCustomer.providerCustomerId = ''
      newProviderCustomer.syncWithProvider = true
      form.setFieldValue('paymentProviderCustomer', newProviderCustomer)
    }

    return (
      <div>
        <Typography variant="captionHl" color="grey700" className="mb-1">
          {translate('text_634ea0ecc6147de10ddb6631')}
        </Typography>
        <Accordion
          noContentMargin
          className={ADD_CUSTOMER_PAYMENT_PROVIDER_ACCORDION}
          summary={
            <ExternalAppsAccordionLayout.Summary
              loading={isLoadingPaymentProviders}
              avatar={
                paymentProvider && (
                  <Avatar size="big" variant="connector-full" className="bg-white">
                    {avatarMapping[paymentProvider]}
                  </Avatar>
                )
              }
              label={selectedPaymentProvider?.name}
              subLabel={selectedPaymentProvider?.code}
              onDelete={handleDeletePaymentProvider}
            />
          }
        >
          <div>
            <div className="flex flex-col gap-6 p-4">
              <Typography variant="bodyHl" color="grey700">
                {translate('text_65e1f90471bc198c0c934d6c')}
              </Typography>

              {/* Select connected account */}
              <form.AppField
                name="paymentProviderCode"
                listeners={{
                  onChange: ({ value }) => handleChangePaymentProviderCode(value),
                }}
              >
                {(field) => (
                  <field.ComboBoxField
                    data={connectedPaymentProvidersData}
                    label={translate('text_65940198687ce7b05cd62b61')}
                    placeholder={translate('text_65940198687ce7b05cd62b62')}
                    emptyText={translate('text_6645daa0468420011304aded')}
                    PopperProps={{ displayInDialog: true }}
                  />
                )}
              </form.AppField>

              {!!paymentProviderCode && isSyncWithProviderSupported && (
                <>
                  <form.AppField name="paymentProviderCustomer.providerCustomerId">
                    {(field) => (
                      <field.TextInputField
                        disabled={isSyncWithProviderDisabled || hadPaymentProvider}
                        label={translate('text_62b328ead9a4caef81cd9ca0')}
                        placeholder={translate('text_62b328ead9a4caef81cd9ca2')}
                      />
                    )}
                  </form.AppField>

                  <form.AppField
                    name="paymentProviderCustomer.syncWithProvider"
                    listeners={{
                      onChange: ({ value }) => handleSyncWithProviderChange(value),
                    }}
                  >
                    {(field) => (
                      <field.CheckboxField
                        label={getSyncWithProviderLabel()}
                        disabled={hadPaymentProvider}
                      />
                    )}
                  </form.AppField>
                </>
              )}
            </div>

            {paymentProvider === ProviderTypeEnum.Moneyhash && (
              <div className="border-t border-grey-400 p-4">
                <Alert type="info">{translate('text_64aeb7b998c4322918c84214')}</Alert>
              </div>
            )}

            {paymentProvider === ProviderTypeEnum.Stripe && (
              <StripePaymentProviderContent form={form} />
            )}
          </div>
        </Accordion>
      </div>
    )
  },
})

export default PaymentProvidersAccordion
