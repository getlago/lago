import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { FC, useEffect, useRef } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'
import { object, string } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
  ERROR_404_ROUTE,
  useNavigate,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { Locale, LocaleEnum } from '~/core/translations'
import {
  CurrencyEnum,
  CustomerForDunningEmailFragmentDoc,
  CustomerForRequestOverduePaymentFormFragmentDoc,
  FeatureFlagEnum,
  InvoicesForRequestOverduePaymentFormFragmentDoc,
  LagoApiError,
  LastPaymentRequestFragmentDoc,
  OrganizationForDunningEmailFragmentDoc,
  useCreatePaymentRequestMutation,
  useGetRequestOverduePaymentInfosQuery,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useIsCustomerReadyForOverduePayment } from '~/hooks/useIsCustomerReadyForOverduePayment'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { EmailPreview } from '~/pages/CustomerRequestOverduePayment/components/EmailPreview'
import { PageHeader } from '~/styles'

import { FreemiumAlert } from './components/FreemiumAlert'
import {
  CustomerRequestOverduePaymentForm,
  RequestPaymentForm,
} from './components/RequestPaymentForm'

export const SUBMIT_PAYMENT_REQUEST_TEST_ID = 'submit-payment-request'

gql`
  query getRequestOverduePaymentInfos(
    $id: ID!
    $currency: CurrencyEnum
    $billingEntityIds: [ID!]
  ) {
    organization {
      defaultCurrency
      ...OrganizationForDunningEmail
    }

    customer(id: $id) {
      externalId
      currency
      ...CustomerForRequestOverduePaymentForm
      ...CustomerForDunningEmail
    }

    paymentRequests {
      collection {
        ...LastPaymentRequest
      }
    }

    invoices(
      paymentOverdue: true
      customerId: $id
      currency: $currency
      billingEntityIds: $billingEntityIds
    ) {
      collection {
        ...InvoicesForRequestOverduePaymentForm
      }
    }

    ${CustomerForDunningEmailFragmentDoc}
    ${OrganizationForDunningEmailFragmentDoc}
    ${CustomerForRequestOverduePaymentFormFragmentDoc}
    ${InvoicesForRequestOverduePaymentFormFragmentDoc}
    ${LastPaymentRequestFragmentDoc}
  }

  mutation createPaymentRequest($input: PaymentRequestCreateInput!) {
    createPaymentRequest(input: $input) {
      id
    }
  }
`

const CustomerRequestOverduePayment: FC = () => {
  const { translate } = useInternationalization()
  const { customerId } = useParams()
  const navigate = useNavigate()
  const { goBack } = useLocationHistory()
  const { isPremium } = useCurrentUser()
  const { isCustomerReadyForOverduePayment, loading: isPaymentProcessingStatusLoading } =
    useIsCustomerReadyForOverduePayment()

  // After a successful submit, the parent invoices refetch from `refetchQueries`
  // can briefly resolve to `isCustomerReadyForOverduePayment=false` and
  // `totalAmount=0` before this page unmounts — which would re-fire
  // `handlePaymentNotReady` (danger toast) and the empty-amount redirect to
  // 404. Latch a ref on submit to short-circuit those guards.
  const hasSubmittedRef = useRef(false)

  const [searchParams] = useSearchParams()
  const currencyParam = (searchParams.get('currency') as CurrencyEnum | null) ?? undefined
  const billingEntityIdParam = searchParams.get('billingEntityId') ?? undefined

  const { hasFeatureFlag } = useOrganizationInfos()
  const hasMultiCurrency = hasFeatureFlag(FeatureFlagEnum.MultiCurrency)
  const hasMultiEntityBilling = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)

  // Guard: each enabled flag introduces an axis that must be scoped explicitly
  // — `multi_currency` requires `currency`, `multi_entity_billing` requires
  // `billingEntityId`. Without scoping, the total amount would sum across
  // mismatched buckets and the BE would later reject the mutation
  // (invoices_have_different_currencies / _billing_entities). Redirect the
  // operator back to the invoices tab so they pick a row from the breakdown.
  const needsCurrencyScope = hasMultiCurrency && !currencyParam
  const needsEntityScope = hasMultiEntityBilling && !billingEntityIdParam
  const isUnscopedAccess = needsCurrencyScope || needsEntityScope

  useEffect(() => {
    if (hasSubmittedRef.current) return
    if (!customerId) return
    if (!isUnscopedAccess) return

    // Pick the most specific message based on which scope is missing.
    let translateKey = 'text_1779717897186t9k8by4zb4u' // billing entity only

    if (needsCurrencyScope && needsEntityScope) {
      translateKey = 'text_1779717247377c9a3lpk4f4r' // both
    } else if (needsCurrencyScope) {
      translateKey = 'text_17797178971869lkybw92uxi' // currency only
    }

    addToast({
      severity: 'info',
      translateKey,
    })
    navigate(
      generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
        customerId,
        tab: CustomerDetailsTabsOptions.invoices,
      }),
    )
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [customerId, isUnscopedAccess])

  const { data, loading, error } = useGetRequestOverduePaymentInfosQuery({
    // Skip when the URL is unscoped under multi-axis flags — the guard above
    // will redirect synchronously and this query would otherwise burn a
    // wasted network call before unmount.
    skip: !customerId || isUnscopedAccess,
    variables: {
      id: customerId ?? '',
      currency: currencyParam,
      billingEntityIds: billingEntityIdParam ? [billingEntityIdParam] : undefined,
    },
  })

  const customer = data?.customer
  const organization = data?.organization
  const paymentRequests = data?.paymentRequests
  const invoices = data?.invoices

  const hasDunningIntegration = !!isPremium

  const [paymentRequest, paymentRequestStatus] = useCreatePaymentRequestMutation({
    refetchQueries: ['getCustomerOverdueBalances'],
    context: {
      silentErrorCodes: [
        LagoApiError.InvoicesNotOverdue,
        LagoApiError.InvoicesNotReadyForPaymentProcessing,
        LagoApiError.InvoicesHaveDifferentBillingEntities,
        LagoApiError.InvoicesHaveDifferentCurrencies,
      ],
    },
    onCompleted() {
      hasSubmittedRef.current = true

      addToast({
        severity: 'success',
        translateKey: 'text_66b9e095a7dc6c6d3dabeed4',
      })

      navigate(generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: customerId ?? '' }))
    },
    onError(mutationError) {
      if (hasDefinedGQLError('InvoicesNotOverdue', mutationError)) {
        addToast({
          severity: 'danger',
          translateKey: 'text_17254494987274bsus9jsnb5',
        })
        paymentRequestStatus.client.refetchQueries({ include: ['getRequestOverduePaymentInfos'] })
      }

      if (hasDefinedGQLError('InvoicesNotReadyForPaymentProcessing', mutationError)) {
        handlePaymentNotReady()
      }

      if (hasDefinedGQLError('InvoicesHaveDifferentBillingEntities', mutationError)) {
        addToast({
          severity: 'danger',
          translateKey: 'text_1779287451539r5rgwbiz2k1',
        })
        paymentRequestStatus.client.refetchQueries({ include: ['getRequestOverduePaymentInfos'] })
      }

      if (hasDefinedGQLError('InvoicesHaveDifferentCurrencies', mutationError)) {
        addToast({
          severity: 'danger',
          translateKey: 'text_1779717091374n898sy7ygtm',
        })
        paymentRequestStatus.client.refetchQueries({ include: ['getRequestOverduePaymentInfos'] })
      }
    },
  })

  const handlePaymentNotReady = () => {
    addToast({
      severity: 'danger',
      translateKey: 'text_1763545922743q5ic2kklick',
    })

    navigate(generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: customerId ?? '' }))
  }

  const documentLocale =
    (customer?.billingConfiguration?.documentLocale as Locale) ||
    (organization?.billingConfiguration?.documentLocale as Locale) ||
    'en'

  const formikProps = useFormik<CustomerRequestOverduePaymentForm>({
    initialValues: {
      emails: customer?.email || '',
      paymentMethod: {
        paymentMethodId: undefined,
        paymentMethodType: undefined,
      },
    },
    validationSchema: object({
      emails: string().required('').emails('text_66b258f62100490d0eb5ca8b'),
    }),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async (values) => {
      if (!hasDunningIntegration) {
        return
      }

      await paymentRequest({
        variables: {
          input: {
            externalCustomerId: customer?.externalId ?? '',
            email: values.emails.replaceAll(' ', ''),
            lagoInvoiceIds: invoices?.collection?.map((invoice) => invoice.id),
            paymentMethod: values.paymentMethod.paymentMethodId
              ? {
                  paymentMethodId: values.paymentMethod.paymentMethodId,
                  paymentMethodType: values.paymentMethod.paymentMethodType,
                }
              : undefined,
          },
        },
      })
    },
  })

  const defaultCurrency = customer?.currency || organization?.defaultCurrency || CurrencyEnum.Usd
  const invoicesCollection = invoices?.collection ?? []
  const totalAmount = invoicesCollection.reduce(
    (acc, { totalDueAmountCents, currency }) =>
      acc + deserializeAmount(totalDueAmountCents, currency || defaultCurrency),
    0,
  )
  const totalInvoices = invoicesCollection.length

  useEffect(
    () => {
      if (hasDefinedGQLError('NotFound', error, 'customer')) {
        navigate(ERROR_404_ROUTE)
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [error],
  )

  useEffect(
    () => {
      if (hasSubmittedRef.current) return
      if (loading === false && totalAmount <= 0) {
        navigate(ERROR_404_ROUTE)
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [loading, totalAmount],
  )

  useEffect(() => {
    if (hasSubmittedRef.current) return
    // Check and redirect if invoices are not ready for payment processing
    // Runs when payment status changes (on mount and when dependencies update)
    if (!isPaymentProcessingStatusLoading && !isCustomerReadyForOverduePayment) {
      handlePaymentNotReady()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isCustomerReadyForOverduePayment, isPaymentProcessingStatusLoading])

  return (
    <>
      <PageHeader.Wrapper>
        {loading ? (
          <Skeleton variant="text" className="w-60" />
        ) : (
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate(
              'text_66b258f62100490d0eb5ca73',
              {
                amount: intlFormatNumber(totalAmount, {
                  currency: defaultCurrency,
                  currencyDisplay: 'narrowSymbol',
                }),
                count: totalInvoices,
              },
              totalInvoices,
            )}
          </Typography>
        )}

        <Button
          variant="quaternary"
          icon="close"
          onClick={() =>
            goBack(generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: customerId ?? '' }), {
              exclude: CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
            })
          }
        />
      </PageHeader.Wrapper>

      <main className="height-minus-nav-footer overflow-auto md:height-minus-nav md:flex md:overflow-auto">
        <section className="bg-white md:height-minus-nav-footer md:shrink md:grow md:basis-1/2 md:overflow-auto">
          {!hasDunningIntegration && <FreemiumAlert />}
          <div className="px-4 py-12 md:px-12">
            <RequestPaymentForm
              invoicesLoading={loading}
              formikProps={formikProps}
              overdueAmount={totalAmount}
              currency={defaultCurrency}
              invoices={invoicesCollection}
              lastSentDate={paymentRequests?.collection?.[0]}
              externalCustomerId={customer?.externalId}
            />
          </div>
        </section>
        <section className="bg-grey-100 md:shrink md:grow md:basis-1/2 md:overflow-auto md:shadow-l">
          <div className="px-4 py-12 md:px-12">
            <EmailPreview
              isLoading={loading}
              locale={LocaleEnum[documentLocale]}
              customer={customer ?? undefined}
              organization={organization ?? undefined}
              overdueAmount={totalAmount}
              currency={defaultCurrency}
              invoices={invoicesCollection}
            />
          </div>
        </section>
      </main>

      <footer className="fixed bottom-0 z-navBar h-footer w-full bg-white shadow-t md:w-1/2">
        <div className="flex h-full items-center justify-end gap-3 px-4 md:px-12">
          <Button
            variant="quaternary"
            size="large"
            onClick={() =>
              goBack(generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: customerId ?? '' }), {
                exclude: CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
              })
            }
          >
            {translate('text_6411e6b530cb47007488b027')}
          </Button>
          <Button
            variant="primary"
            size="large"
            onClick={formikProps.submitForm}
            data-test={SUBMIT_PAYMENT_REQUEST_TEST_ID}
            disabled={!hasDunningIntegration || totalAmount === 0 || !formikProps.isValid}
          >
            {translate('text_66b258f62100490d0eb5caa2')}
          </Button>
        </div>
      </footer>
    </>
  )
}

export default CustomerRequestOverduePayment
