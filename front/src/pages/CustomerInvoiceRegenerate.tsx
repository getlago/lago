import { gql } from '@apollo/client'
import { useEffect, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { EditFeeDrawer, EditFeeDrawerRef } from '~/components/invoices/details/EditFeeDrawer'
import { InvoiceDetailsTable } from '~/components/invoices/details/InvoiceDetailsTable'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { LocalTaxProviderErrorsEnum } from '~/core/constants/form'
import {
  CustomerDetailsTabsOptions,
  CustomerInvoiceDetailsTabsOptionsEnum,
} from '~/core/constants/tabsOptions'
import {
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import {
  Charge,
  CurrencyEnum,
  Fee,
  FeeAmountDetails,
  FeeAppliedTax,
  FeeForInvoiceDetailsTableFragmentDoc,
  FetchDraftInvoiceTaxesMutation,
  FixedCharge,
  InvoiceStatusTypeEnum,
  LagoApiError,
  useFetchDraftInvoiceTaxesMutation,
  useGetCustomerQuery,
  usePreviewAdjustedFeeMutation,
  useRegenerateInvoiceMutation,
  useVoidInvoiceMutation,
  VoidedInvoiceFeeInput,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useInvoiceBuildRegenerationPreview } from '~/pages/invoiceDetails/common/useInvoiceBuildRegenerationPreview'
import { InvoiceQuickInfo } from '~/pages/InvoiceOverview'
import ErrorImage from '~/public/images/maneki/error.svg'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  mutation regenerateInvoice($input: RegenerateInvoiceInput!) {
    regenerateFromVoided(input: $input) {
      id
      status
    }
  }

  mutation previewAdjustedFee($input: PreviewAdjustedFeeInput!) {
    previewAdjustedFee(input: $input) {
      ...FeeForInvoiceDetailsTable
      subscription {
        id
        plan {
          id
          interval
          name
        }
      }
    }
  }

  ${FeeForInvoiceDetailsTableFragmentDoc}
`

export type OnRegeneratedFeeAdd = (input: {
  feeId?: string | null
  unitPreciseAmount?: string | null
  invoiceDisplayName?: string | null
  units?: number | null
  amountDetails?: FeeAmountDetails | null
  charge?: Charge | null
  fixedCharge?: FixedCharge | null
  chargeFilterId?: string | null
  invoiceSubscriptionId?: string | null
  properties?: {
    fromDatetime?: string | null
    toDatetime?: string | null
  } | null
}) => void

const removeEmptyKeys = (obj: object) => {
  const keys = Object.keys(obj).filter((key) => !!obj[key as keyof typeof obj])

  return Object.fromEntries(keys.map((key) => [key, obj[key as keyof typeof obj]]))
}

const TEMPORARY_ID_PREFIX = 'temporary-id-fee-'

const CustomerInvoiceRegenerate = () => {
  const { translate } = useInternationalization()
  const { goBack } = useLocationHistory()
  const { customerId, invoiceId } = useParams()
  const navigate = useNavigate()

  const editFeeDrawerRef = useRef<EditFeeDrawerRef>(null)

  const {
    invoiceBuildRegenerationPreview: invoice,
    loading,
    error,
  } = useInvoiceBuildRegenerationPreview(invoiceId)

  const { data: fullCustomer } = useGetCustomerQuery({
    variables: {
      id: invoice?.customer?.id as string,
    },
    skip: !invoice?.customer?.id,
  })

  const fullFees = invoice?.fees

  const customer = invoice?.customer
  const billingEntity = invoice?.billingEntity
  const hasTaxProvider =
    !!fullCustomer?.customer?.anrokCustomer?.id || !!fullCustomer?.customer?.avalaraCustomer?.id

  const [fees, setFees] = useState(fullFees || [])
  // Store a deep copy of the original fees from the query, to avoid Apollo cache pollution
  // when previewAdjustedFee mutation returns partial fee data that gets merged into cache.
  const originalFeesRef = useRef<typeof fullFees>(null)
  const hasInitializedFees = useRef(false)

  // Update fees state when fullFees becomes available from the query.
  // This is needed because useState only uses its initial value on the first render,
  // but fullFees is typically undefined at that point since the query hasn't completed yet.
  // We only want to do this once on initial load, not on subsequent refetches.
  useEffect(() => {
    if (fullFees?.length && !hasInitializedFees.current) {
      // Deep clone to preserve original data independent of Apollo cache mutations
      originalFeesRef.current = JSON.parse(JSON.stringify(fullFees))
      setFees(fullFees)
      hasInitializedFees.current = true
    }
  }, [fullFees])

  const [taxProviderTaxesResult, setTaxProviderTaxesResult] =
    useState<FetchDraftInvoiceTaxesMutation['fetchDraftInvoiceTaxes']>(null)
  const [taxProviderTaxesErrorMessage, setTaxProviderTaxesErrorMessage] =
    useState<LocalTaxProviderErrorsEnum | null>()

  const [regenerateInvoice] = useRegenerateInvoiceMutation({
    onCompleted(regeneratedData) {
      const newInvoice = regeneratedData?.regenerateFromVoided

      if (newInvoice?.id && customerId) {
        addToast({
          message: translate('text_17512809059243nam2ohm0ul'),
          severity: 'success',
        })

        // If invoice is status closed, redirect to invoices list
        // because closed invoices are not visible via the API and it would result in a 404 page
        if (newInvoice.status === InvoiceStatusTypeEnum.Closed) {
          navigate(
            generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
              customerId,
              tab: CustomerDetailsTabsOptions.invoices,
            }),
          )
        } else {
          navigate(
            generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
              customerId,
              invoiceId: newInvoice.id,
              tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
            }),
          )
        }
      }
    },
  })

  const [getTaxFromTaxProvider] = useFetchDraftInvoiceTaxesMutation({
    fetchPolicy: 'no-cache',
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
  })

  const [voidInvoice] = useVoidInvoiceMutation()
  const [previewAdjustedFee] = usePreviewAdjustedFeeMutation()

  const onAdd: OnRegeneratedFeeAdd = async (input) => {
    const previewedFee = await previewAdjustedFee({
      variables: {
        input: {
          invoiceId: invoiceId as string,
          ...removeEmptyKeys({
            feeId: input?.feeId,
            units: input?.units,
            unitPreciseAmount: input?.unitPreciseAmount,
            invoiceSubscriptionId: input?.invoiceSubscriptionId,
            chargeId: input?.charge?.id,
            fixedChargeId: input?.fixedCharge?.id,
            chargeFilterId: input?.chargeFilterId,
            invoiceDisplayName: input?.invoiceDisplayName,
          }),
        },
      },
    })

    const feeData = previewedFee?.data?.previewAdjustedFee

    const isUpdate = fees?.find((f) => f.id === input?.feeId)

    const calculatedFee = {
      ...feeData,
      // Preserve properties from input if mutation doesn't return them (needed for boundary grouping)
      properties: feeData?.properties ?? input?.properties,
      id: isUpdate ? input?.feeId : `${TEMPORARY_ID_PREFIX}-${Math.random().toString()}`,
      adjustedFee: true,
      wasOnlyUnitsUpdate: typeof input?.unitPreciseAmount === 'undefined',
    } as Fee & {
      wasOnlyUnitsUpdate: boolean
    }

    if (isUpdate) {
      return setFees((f) => f.map((fee) => (fee.id === input.feeId ? calculatedFee : fee)))
    }

    return setFees((f) => [...f, calculatedFee])
  }

  const onDelete = (id: string) => {
    // Use originalFeesRef to get untouched fee data, avoiding Apollo cache pollution
    const original = originalFeesRef.current?.find((f) => f.id === id)

    if (original && !original.adjustedFee) {
      return setFees((f) => f.map((fee) => (fee.id === id ? original : fee)))
    }

    return setFees((f) => f.filter((fee) => fee.id !== id))
  }

  const onSubmit = async () => {
    if (!invoiceId) {
      return
    }

    if (!invoice?.voidedAt) {
      await voidInvoice({
        variables: {
          input: {
            id: invoiceId,
            generateCreditNote: false,
          },
        },
      })
    }

    const feesInput: VoidedInvoiceFeeInput[] = fees
      .map((fee) => ({
        id: fee.id.includes(TEMPORARY_ID_PREFIX) ? null : fee.id,
        addOnId: fee?.addOn?.id,
        chargeId: fee?.charge?.id,
        chargeFilterId: fee?.chargeFilter?.id,
        description: fee?.description,
        invoiceDisplayName: fee?.invoiceDisplayName,
        subscriptionId: fee?.subscription?.id,
        unitAmountCents: (fee as { wasOnlyUnitsUpdate?: boolean })?.wasOnlyUnitsUpdate
          ? null
          : fee?.preciseUnitAmount,
        units: fee?.units,
      }))
      .map((fee) => removeEmptyKeys(fee))

    await regenerateInvoice({
      variables: {
        input: {
          voidedInvoiceId: invoiceId,
          fees: feesInput,
        },
      },
    })
  }

  const onClose = () => {
    if (customerId && invoiceId) {
      goBack(
        generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
          customerId,
          invoiceId,
          tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
        }),
      )
    }
  }

  const getFormattedDate = (date: string): string => {
    if (!date) return '-'

    return intlFormatDateTime(date, {
      timezone: customer?.applicableTimezone,
    }).date
  }

  if (error) {
    return (
      <GenericPlaceholder
        className="pt-12"
        title={translate('text_634812d6f16b31ce5cbf4126')}
        subtitle={translate('text_634812d6f16b31ce5cbf4128')}
        buttonTitle={translate('text_634812d6f16b31ce5cbf412a')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <CenteredPage.Wrapper>
      <CenteredPage.Header>
        <Typography className="font-medium text-grey-700">
          {translate(
            !!invoice?.voidedAt ? 'text_1750678506388s7bfu2qjzhn' : 'text_17519912068281q4wys5q1g2',
          )}
        </Typography>

        <Button variant="quaternary" icon="close" onClick={() => onClose()} />
      </CenteredPage.Header>

      {loading && (
        <CenteredPage.Container>
          <FormLoadingSkeleton id="customer-invoice-regenerate" />
        </CenteredPage.Container>
      )}

      {!loading && (
        <>
          <CenteredPage.Container className="pb-12">
            <div className="flex flex-col gap-12">
              <Alert type="info">
                <Typography className="text-grey-700">
                  {!!invoice?.voidedAt
                    ? translate('text_17506785063887oto6r0hcq0', {
                        invoiceNumber: invoice?.number,
                        issuingDate: getFormattedDate(invoice?.issuingDate),
                        voidDate: getFormattedDate(invoice?.voidedAt),
                      })
                    : translate('text_1751991206828m0rxpmddapo', {
                        invoiceNumber: invoice?.number,
                        issuingDate: getFormattedDate(invoice?.issuingDate),
                      })}
                </Typography>
              </Alert>
              <div className="flex flex-col gap-1">
                <Typography className="text-2xl font-semibold text-grey-700">
                  {translate(
                    !!invoice?.voidedAt
                      ? 'text_1750678506388s7bfu2qjzhn'
                      : 'text_17519912068281q4wys5q1g2',
                  )}
                </Typography>

                <Typography className="text-grey-600">
                  {translate(
                    !!invoice?.voidedAt
                      ? 'text_1750678506388d8u5rv893gn'
                      : 'text_17519914705750hjw95snsdf',
                  )}
                </Typography>
              </div>
            </div>
          </CenteredPage.Container>

          <div className="px-40">
            {invoice && customer && billingEntity && (
              <InvoiceQuickInfo
                customer={customer}
                invoice={invoice}
                billingEntity={billingEntity}
              />
            )}
            {invoice && customer && (
              <InvoiceDetailsTable
                customer={customer}
                invoice={invoice}
                editFeeDrawerRef={editFeeDrawerRef}
                isDraftOverride={true}
                onAdd={onAdd}
                onDelete={onDelete}
                fees={fees}
                localFees={fees}
              />
            )}
          </div>
        </>
      )}

      <CenteredPage.Container>
        {!!taxProviderTaxesErrorMessage && (
          <Alert type="warning">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_1723831735547ttel1jl0yva')}
            </Typography>
            <Typography variant="caption" color="grey600">
              {translate(taxProviderTaxesErrorMessage)}
            </Typography>
          </Alert>
        )}
      </CenteredPage.Container>

      <CenteredPage.StickyFooter>
        <Button variant="quaternary" onClick={() => onClose()}>
          {translate('text_6411e6b530cb47007488b027')}
        </Button>

        {!!hasTaxProvider && (
          <Button
            variant="secondary"
            disabled={!!taxProviderTaxesResult}
            onClick={async () => {
              setTaxProviderTaxesErrorMessage(null)

              const taxProviderResult = await getTaxFromTaxProvider({
                variables: {
                  input: {
                    currency: invoice?.currency,
                    customerId: customer?.id as string,
                    fees: fees.map((f) => ({
                      addOnId: f.id,
                      description: f.description,
                      invoiceDisplayName: f.invoiceDisplayName,
                      name: f.itemName,
                      taxCodes: fullFees
                        ?.find((x) => x.id === f.id)
                        ?.appliedTaxes?.map((t) => t.taxCode) || [''],
                      unitAmountCents: String(
                        serializeAmount(f.preciseUnitAmount, invoice?.currency || CurrencyEnum.Usd),
                      ),
                      units: f.units,
                      fromDatetime: f.properties?.fromDatetime,
                      toDatetime: f.properties?.toDatetime,
                    })),
                  },
                },
              })

              const { data: taxProviderResultData, errors } = taxProviderResult

              if (!!errors?.length) {
                if (
                  // Anrok
                  hasDefinedGQLError('CurrencyCodeNotSupported', errors) ||
                  // Avalara
                  hasDefinedGQLError('InvalidEnumValue', errors)
                ) {
                  setTaxProviderTaxesErrorMessage(
                    LocalTaxProviderErrorsEnum.CurrencyCodeNotSupported,
                  )
                } else if (
                  // Anrok
                  hasDefinedGQLError('CustomerAddressCountryNotSupported', errors) ||
                  hasDefinedGQLError('CustomerAddressCouldNotResolve', errors) ||
                  // Avalara
                  hasDefinedGQLError('MissingAddress', errors) ||
                  hasDefinedGQLError('NotEnoughAddressesInfo', errors) ||
                  hasDefinedGQLError('InvalidAddress', errors) ||
                  hasDefinedGQLError('InvalidPostalCode', errors) ||
                  hasDefinedGQLError('AddressLocationNotFound', errors)
                ) {
                  setTaxProviderTaxesErrorMessage(LocalTaxProviderErrorsEnum.CustomerAddressError)
                } else if (
                  // Anrok
                  hasDefinedGQLError('ProductExternalIdUnknown', errors) ||
                  // Avalara
                  hasDefinedGQLError('TaxCodeAssociatedWithItemCodeNotFound', errors) ||
                  hasDefinedGQLError('EntityNotFoundError', errors)
                ) {
                  setTaxProviderTaxesErrorMessage(
                    LocalTaxProviderErrorsEnum.ProductExternalIdUnknown,
                  )
                } else {
                  setTaxProviderTaxesErrorMessage(LocalTaxProviderErrorsEnum.GenericErrorMessage)
                }

                // Scroll bottom of the screen once the error message is displayed
                setTimeout(() => {
                  const rootElement = document.getElementById('root')

                  rootElement?.scrollTo({
                    top: rootElement.scrollHeight,
                    behavior: 'smooth',
                  })
                }, 1)

                return
              }

              const taxes = taxProviderResultData?.fetchDraftInvoiceTaxes?.collection

              setFees((_fees) =>
                _fees.map((f) => {
                  const tax = taxes?.find((t) => t.itemId === f.id)

                  if (!tax) {
                    return f
                  }

                  const newFee = {
                    ...f,
                    appliedTaxes: [
                      ...(tax.taxBreakdown || []).map(
                        (breakdown) =>
                          ({
                            id: Math.random().toString(),
                            taxRate: (breakdown.rate || 0) * 100,
                            taxName: breakdown.name,
                            amountCents: breakdown.taxAmount,
                          }) as FeeAppliedTax,
                      ),
                    ],
                  }

                  return newFee
                }),
              )

              setTaxProviderTaxesResult(taxProviderResultData?.fetchDraftInvoiceTaxes)
            }}
          >
            {translate('text_172383173554743nq9isxpje')}
          </Button>
        )}

        <Button variant="primary" size="large" onClick={() => onSubmit()}>
          {translate(
            !!invoice?.voidedAt ? 'text_1750678506388ssxh1yacay0' : 'text_1751991518313o0xwbo9xf0y',
          )}
        </Button>
      </CenteredPage.StickyFooter>

      <EditFeeDrawer ref={editFeeDrawerRef} />
    </CenteredPage.Wrapper>
  )
}

export default CustomerInvoiceRegenerate
