import { gql } from '@apollo/client'
import { useEffect, useMemo, useRef, useState } from 'react'

import { LinkedPaymentProvider } from '~/components/customers/types'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Dialog, DialogRef } from '~/components/designSystem/Dialog'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { ComboBox } from '~/components/form'
import { PageSectionTitle } from '~/components/layouts/Section'
import { PaymentMethodsList } from '~/components/paymentMethodsList/PaymentMethodList'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  CustomerMainInfosFragment,
  ProviderPaymentMethodsEnum,
  useGenerateCheckoutUrlMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const ADD_PAYMENT_METHOD_TEST_ID = 'add-payment-method-dialog'
export const INELIGIBLE_PAYMENT_METHODS_TEST_ID = 'ineligible-payment-methods-text'
export const GENERATE_CHECKOUT_URL_BUTTON_TEST_ID = 'generate-checkout-url-button'
export const CANCEL_DIALOG_BUTTON_TEST_ID = 'cancel-dialog-button'
export const ERROR_ALERT_TEST_ID = 'error-alert'
export const CHECKOUT_URL_TEXT_TEST_ID = 'checkout-url-text'
export const PAYMENT_METHODS_LIST_TEST_ID = 'payment-methods-list'

const INELIGIBLE_PAYMENT_METHODS: ProviderPaymentMethodsEnum[] = [
  ProviderPaymentMethodsEnum.CustomerBalance,
  ProviderPaymentMethodsEnum.Crypto,
]

interface Props {
  customer: CustomerMainInfosFragment
  linkedPaymentProvider: LinkedPaymentProvider
}

gql`
  mutation generateCheckoutUrl($input: GenerateCheckoutUrlInput!) {
    generateCheckoutUrl(input: $input) {
      checkoutUrl
    }
  }
`

export const CustomerPaymentMethods = ({ customer, linkedPaymentProvider }: Props) => {
  const { translate } = useInternationalization()
  const addPaymentDialogRef = useRef<DialogRef>(null)
  const [selectedPaymentProvider, setSelectedPaymentProvider] = useState<string>('')

  const [generateCheckoutUrlMutation, { data, loading, error, reset }] =
    useGenerateCheckoutUrlMutation({
      variables: {
        input: { customerId: customer.id },
      },
    })

  const hasOnlyIneligiblePaymentMethods = useMemo(() => {
    const linkedProviderCustomer = customer.providerCustomer
    const availableProviderPaymentMethods = linkedProviderCustomer?.providerPaymentMethods

    if (!linkedProviderCustomer || !availableProviderPaymentMethods) return false

    const canAddPaymentMethods = availableProviderPaymentMethods.some(
      (method) => !INELIGIBLE_PAYMENT_METHODS.includes(method),
    )

    return (
      !!linkedProviderCustomer &&
      availableProviderPaymentMethods.length > 0 &&
      !canAddPaymentMethods
    )
  }, [customer.providerCustomer])

  const paymentProviderOptions = useMemo(() => {
    if (!linkedPaymentProvider) return []

    return [
      {
        value: linkedPaymentProvider.code,
        label: linkedPaymentProvider.name,
      },
    ]
  }, [linkedPaymentProvider])

  const hasOneAvailableOption = paymentProviderOptions.length === 1

  useEffect(() => {
    if (hasOneAvailableOption) {
      setSelectedPaymentProvider(paymentProviderOptions[0].value)
    }
  }, [hasOneAvailableOption, paymentProviderOptions])

  const checkoutUrl = data?.generateCheckoutUrl?.checkoutUrl || ''

  return (
    <>
      <PageSectionTitle
        className="mb-4"
        title={translate('text_64aeb7b998c4322918c84204')}
        subtitle={translate('text_17619148029867qcebvr5eui')}
        action={{
          title: translate('text_1761914802986ww4ima0w9w9'),
          onClick: () => addPaymentDialogRef.current?.openDialog(),
          isDisabled: hasOnlyIneligiblePaymentMethods,
          dataTest: ADD_PAYMENT_METHOD_TEST_ID,
        }}
      />

      {!hasOnlyIneligiblePaymentMethods && (
        <Dialog
          ref={addPaymentDialogRef}
          title={translate('text_1761914802986ww4ima0w9w9')}
          description={translate('text_1761914802986ipq0aot8fas')}
          onClose={() => {
            if (!!error) {
              reset()
            }
          }}
          actions={({ closeDialog }) => (
            <>
              <Button
                variant="quaternary"
                onClick={() => closeDialog()}
                data-test={CANCEL_DIALOG_BUTTON_TEST_ID}
              >
                {translate('text_63e51ef4985f0ebd75c21313')}
              </Button>
              <Button
                loading={loading}
                disabled={!selectedPaymentProvider}
                onClick={async () => {
                  await generateCheckoutUrlMutation()
                }}
                data-test={GENERATE_CHECKOUT_URL_BUTTON_TEST_ID}
              >
                {translate('text_1761914802986cu9mjc19csx')}
              </Button>
            </>
          )}
        >
          <>
            <ComboBox
              className="mb-8"
              disabled={hasOneAvailableOption}
              disableClearable={hasOneAvailableOption}
              name="selectPaymentProvider"
              data={paymentProviderOptions}
              label={translate('text_634ea0ecc6147de10ddb6631')}
              placeholder={translate('text_1762173848714al2j36a59ce')}
              emptyText={translate('text_1762173891817jhfenej7eho')}
              PopperProps={{ displayInDialog: true }}
              value={selectedPaymentProvider}
              onChange={(value) => {
                setSelectedPaymentProvider(value)
              }}
            />

            {!!error && (
              <Alert type="danger" className="mb-8" data-test={ERROR_ALERT_TEST_ID}>
                {translate('text_1762182354095wfjiizpju0e')}
              </Alert>
            )}

            {(checkoutUrl || loading) && (
              <div className="mb-8">
                <Typography className="mb-2 font-medium" color="grey700" variant="caption">
                  {translate('text_1762184099398x60go694x4g')}
                </Typography>

                {loading && <Skeleton className="w-60" variant="text" textVariant="caption" />}

                {checkoutUrl && (
                  <Tooltip placement="top" title={translate('text_17621837056900geit2h3mg6')}>
                    <Typography
                      className="w-full cursor-pointer truncate"
                      color="grey700"
                      variant="captionCode"
                      data-test={CHECKOUT_URL_TEXT_TEST_ID}
                      onClick={() => {
                        copyToClipboard(checkoutUrl)
                        addToast({
                          severity: 'info',
                          translateKey: 'text_1762185015908yvajftyvcnq',
                        })
                      }}
                    >
                      {checkoutUrl}
                    </Typography>
                  </Tooltip>
                )}
              </div>
            )}
          </>
        </Dialog>
      )}

      {hasOnlyIneligiblePaymentMethods && (
        <Typography color="grey500" className="mb-4" data-test={INELIGIBLE_PAYMENT_METHODS_TEST_ID}>
          {translate('text_17619148029863fx3w8kwfdp')}
        </Typography>
      )}

      {!hasOnlyIneligiblePaymentMethods && (
        <div data-test={PAYMENT_METHODS_LIST_TEST_ID}>
          <PaymentMethodsList externalCustomerId={customer.externalId} />
        </div>
      )}
    </>
  )
}
