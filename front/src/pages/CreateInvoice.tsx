import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { useFormik } from 'formik'
import _get from 'lodash/get'
import { DateTime } from 'luxon'
import { useCallback, useMemo, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { array, number, object, string } from 'yup'

import { BillingEntityFormPicker } from '~/components/billingEntity/BillingEntityFormPicker'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Card } from '~/components/designSystem/Card'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { AmountInput, ComboBox, ComboBoxField, ComboboxItem, TextInput } from '~/components/form'
import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { toInvoiceCustomSectionReference } from '~/components/invoceCustomFooter/utils'
import { useEditFeeBillingPeriodDialog } from '~/components/invoices/EditFeeBillingPeriod'
import { useEditInvoiceItemDescriptionDialog } from '~/components/invoices/EditInvoiceItemDescriptionDialog'
import { useEditInvoiceItemTaxDialog } from '~/components/invoices/EditInvoiceItemTaxDialog'
import { InvoiceTaxesDisplay, TaxMapType } from '~/components/invoices/InvoiceTaxesDisplay'
import { InvoiceFormInput, LocalFeeInput } from '~/components/invoices/types'
import { useEditInvoiceDisplayNameDialog } from '~/components/invoices/useEditInvoiceDisplayName'
import { PaymentMethodsInvoiceSettings } from '~/components/paymentMethodsInvoiceSettings/PaymentMethodsInvoiceSettings'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { normalizePurchaseOrderNumber, PO } from '~/components/purchaseOrder/PO'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import {
  ADD_ITEM_FOR_INVOICE_INPUT_NAME,
  appliedTaxEnumedTaxCodeTranslationKey,
  LocalTaxProviderErrorsEnum,
  MUI_INPUT_BASE_ROOT_CLASSNAME,
} from '~/core/constants/form'
import { CustomerInvoiceDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { formatAddress } from '~/core/formats/formatAddress'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_DETAILS_ROUTE, CUSTOMER_INVOICE_DETAILS_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone'
import { formatInvoiceDisplayValue, invoiceFeesToFeeInput } from '~/core/utils/invoiceUtils'
import {
  AddOnForInvoiceEditTaxDialogFragmentDoc,
  CurrencyEnum,
  CustomerAccountTypeEnum,
  FeatureFlagEnum,
  FeeForInvoiceFeesToFeeInputFragmentDoc,
  FetchDraftInvoiceTaxesMutation,
  Invoice,
  LagoApiError,
  TaxInfosForCreateInvoiceFragment,
  useCreateInvoiceMutation,
  useFetchDraftInvoiceTaxesMutation,
  useGetAddonListForInfoiceLazyQuery,
  useGetBillingEntityQuery,
  useGetBillingEntityTaxesForCreateInvoiceQuery,
  useGetInfosForCreateInvoiceQuery,
  useVoidInvoiceMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useBillingEntitiesOptions } from '~/hooks/useBillingEntitiesOptions'
import { useIframeConfig } from '~/hooks/useIframeConfig'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissionsInvoiceActions } from '~/hooks/usePermissionsInvoiceActions'
import { useInvoiceBuildRegenerationPreview } from '~/pages/invoiceDetails/common/useInvoiceBuildRegenerationPreview'
import ErrorImage from '~/public/images/maneki/error.svg'
import { MenuPopper, PageHeader } from '~/styles'
import { tw } from '~/styles/utils'

export const computeHasTaxProvider = (
  customer?: {
    anrokCustomer?: { id: string } | null
    avalaraCustomer?: { id: string } | null
  } | null,
): boolean => {
  return !!customer?.anrokCustomer?.id || !!customer?.avalaraCustomer?.id
}

export const resolveCustomerApplicableTax = ({
  hasTaxProvider,
  customerTaxes,
  billingEntityTaxes,
  orgTaxes,
}: {
  hasTaxProvider: boolean
  customerTaxes?: TaxInfosForCreateInvoiceFragment[] | null
  billingEntityTaxes?: TaxInfosForCreateInvoiceFragment[] | null
  orgTaxes?: TaxInfosForCreateInvoiceFragment[]
}): TaxInfosForCreateInvoiceFragment[] | undefined => {
  if (hasTaxProvider) return []
  if (!!customerTaxes?.length) return customerTaxes

  if (!!billingEntityTaxes?.length) return billingEntityTaxes

  return orgTaxes
}

gql`
  fragment TaxInfosForCreateInvoice on Tax {
    id
    name
    code
    rate
  }

  query getInfosForCreateInvoice($id: ID!) {
    customer(id: $id) {
      id
      externalId
      addressLine1
      addressLine2
      city
      country
      currency
      email
      name
      displayName
      legalName
      legalNumber
      taxIdentificationNumber
      state
      zipcode
      accountType
      billingEntity {
        id
        code
      }
      taxes {
        id
        ...TaxInfosForCreateInvoice
      }
      anrokCustomer {
        id
      }
      avalaraCustomer {
        id
      }
    }

    taxes(page: 1, limit: 1000, appliedToOrganization: true) {
      collection {
        id
        ...TaxInfosForCreateInvoice
      }
    }
  }

  query getBillingEntityTaxesForCreateInvoice($billingEntityId: ID!) {
    billingEntityTaxes(billingEntityId: $billingEntityId) {
      collection {
        id
        ...TaxInfosForCreateInvoice
      }
    }
  }

  query getAddonListForInfoice($page: Int, $limit: Int, $searchTerm: String) {
    addOns(page: $page, limit: $limit, searchTerm: $searchTerm) {
      metadata {
        currentPage
        totalPages
      }
      collection {
        id
        name
        description
        amountCents
        amountCurrency
        invoiceDisplayName
        ...AddOnForInvoiceEditTaxDialog
        taxes {
          id
          ...TaxInfosForCreateInvoice
        }
      }
    }
  }

  mutation fetchDraftInvoiceTaxes($input: FetchDraftInvoiceTaxesInput!) {
    fetchDraftInvoiceTaxes(input: $input) {
      collection {
        amountCents
        itemId # used to match addon-fee and tax provider data
        taxAmountCents
        taxBreakdown {
          name
          rate
          taxAmount
          enumedTaxCode
        }
      }
    }
  }

  mutation createInvoice($input: CreateInvoiceInput!) {
    createInvoice(input: $input) {
      id
    }
  }

  ${FeeForInvoiceFeesToFeeInputFragmentDoc}
  ${AddOnForInvoiceEditTaxDialogFragmentDoc}
`

const CreateInvoice = () => {
  const { translate } = useInternationalization()
  const { customerId, voidedInvoiceId = '' } = useParams()
  const navigate = useNavigate()
  const { goBack } = useLocationHistory()
  const actions = usePermissionsInvoiceActions()
  const { hasFeatureFlag } = useOrganizationInfos()
  const {
    emitIframeMessage,
    emitSalesForceEvent,
    isRunningInIframeContext,
    isRunningInSalesForceIframe,
  } = useIframeConfig()

  const [showAddItem, setShowAddItem] = useState(false)
  const [taxProviderTaxesResult, setTaxProviderTaxesResult] =
    useState<FetchDraftInvoiceTaxesMutation['fetchDraftInvoiceTaxes']>(null)
  const [taxProviderTaxesErrorMessage, setTaxProviderTaxesErrorMessage] =
    useState<LocalTaxProviderErrorsEnum | null>(null)

  const warningDialogRef = useRef<WarningDialogRef>(null)
  const { openEditInvoiceItemDescriptionDialog } = useEditInvoiceItemDescriptionDialog()
  const { openEditInvoiceItemTaxDialog } = useEditInvoiceItemTaxDialog()
  const { openEditInvoiceDisplayNameDialog } = useEditInvoiceDisplayNameDialog()
  const { openEditFeeBillingPeriodDialog } = useEditFeeBillingPeriodDialog()

  const handleClosePage = useCallback(() => {
    goBack(generatePath(CUSTOMER_DETAILS_ROUTE, { customerId: customerId as string }))
  }, [goBack, customerId])

  const { data, loading, error } = useGetInfosForCreateInvoiceQuery({
    variables: { id: customerId as string },
    skip: !customerId,
    notifyOnNetworkStatusChange: true,
  })
  const { customer, taxes } = data || {}

  const { invoiceBuildRegenerationPreview: prefillInvoice } =
    useInvoiceBuildRegenerationPreview(voidedInvoiceId)

  const prefillFees = useMemo(() => {
    const fees = prefillInvoice?.fees

    if (!fees) {
      return
    }

    return invoiceFeesToFeeInput(prefillInvoice as Invoice)
  }, [prefillInvoice])

  const { options: billingEntityOptions } = useBillingEntitiesOptions()
  const [pickedBillingEntityId, setPickedBillingEntityId] = useState<string | undefined>(undefined)
  const activeBillingEntityCode =
    billingEntityOptions.find((o) => o.id === pickedBillingEntityId)?.value ??
    customer?.billingEntity?.code

  const { data: billingEntityData } = useGetBillingEntityQuery({
    variables: {
      code: activeBillingEntityCode as string,
    },
    skip: !activeBillingEntityCode,
  })

  const billingEntity = billingEntityData?.billingEntity

  const { data: billingEntityTaxesData } = useGetBillingEntityTaxesForCreateInvoiceQuery({
    variables: {
      billingEntityId: billingEntity?.id as string,
    },
    skip: !billingEntity?.id,
  })

  const hasTaxProvider = computeHasTaxProvider(customer)
  const customerName = customer?.displayName
  const customerIsPartner = customer?.accountType === CustomerAccountTypeEnum.Partner

  const formattedBillingAddress = formatAddress({
    addressLine1: billingEntity?.addressLine1,
    addressLine2: billingEntity?.addressLine2,
    city: billingEntity?.city,
    country: billingEntity?.country,
    state: billingEntity?.state,
    zipcode: billingEntity?.zipcode,
  })

  const formattedCustomerAddress = formatAddress({
    addressLine1: customer?.addressLine1,
    addressLine2: customer?.addressLine2,
    city: customer?.city,
    country: customer?.country,
    state: customer?.state,
    zipcode: customer?.zipcode,
  })

  const customerApplicableTax = useMemo(
    () =>
      resolveCustomerApplicableTax({
        hasTaxProvider,
        customerTaxes: customer?.taxes,
        billingEntityTaxes: billingEntityTaxesData?.billingEntityTaxes?.collection,
        orgTaxes: taxes?.collection,
      }),
    [
      billingEntityTaxesData?.billingEntityTaxes?.collection,
      customer?.taxes,
      hasTaxProvider,
      taxes?.collection,
    ],
  )

  const [getAddOns, { data: addOnData }] = useGetAddonListForInfoiceLazyQuery({
    variables: { limit: 20 },
  })

  const [getTaxFromTaxProvider] = useFetchDraftInvoiceTaxesMutation({
    fetchPolicy: 'no-cache',
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
  })

  const [createInvoice] = useCreateInvoiceMutation({
    onCompleted({ createInvoice: createInvoiceResult }) {
      if (!!createInvoiceResult?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_6453819268763979024ad144',
        })
        if (isRunningInSalesForceIframe) {
          emitSalesForceEvent({
            action: 'close',
            rel: 'create-invoice',
            invoiceId: createInvoiceResult.id,
          })
        } else if (isRunningInIframeContext) {
          emitIframeMessage({
            action: 'DONE',
            rel: 'create-invoice',
            invoiceId: createInvoiceResult.id,
          })
        } else {
          navigate(
            generatePath(CUSTOMER_INVOICE_DETAILS_ROUTE, {
              customerId: customerId as string,
              invoiceId: createInvoiceResult.id,
              tab: CustomerInvoiceDetailsTabsOptionsEnum.overview,
            }),
          )
        }
      }
    },
  })

  const [voidInvoice] = useVoidInvoiceMutation({})

  const formikProps = useFormik<InvoiceFormInput>({
    initialValues: {
      customerId: customerId || '',
      billingEntityId: customer?.billingEntity?.id || undefined,
      currency: data?.customer?.currency || billingEntity?.defaultCurrency || CurrencyEnum.Usd,
      fees: prefillFees || [],
      paymentMethod: undefined,
      invoiceCustomSection: undefined,
      purchaseOrderNumber: prefillInvoice?.purchaseOrderNumber || undefined,
    },
    validationSchema: object().shape({
      customerId: string().required(''),
      currency: string().required(''),
      fees: array()
        .of(
          object().shape({
            addOnId: string().required(''),
            description: string().nullable(),
            units: number().min(1, 'text_645381a65b99559adf6401f0').required(''),
          }),
        )
        .required(''),
      purchaseOrderNumber: string().nullable(),
    }),
    enableReinitialize: true,
    validateOnMount: true,
    onSubmit: async ({
      fees,
      paymentMethod,
      invoiceCustomSection,
      purchaseOrderNumber,
      ...values
    }) => {
      if (voidedInvoiceId && prefillInvoice?.id && actions.canVoid(prefillInvoice)) {
        const res = await voidInvoice({
          variables: {
            input: {
              id: voidedInvoiceId,
              generateCreditNote: false,
            },
          },
        })

        if (!res.data?.voidInvoice?.id) {
          return
        }
      }

      await createInvoice({
        variables: {
          input: {
            ...values,
            purchaseOrderNumber: normalizePurchaseOrderNumber(purchaseOrderNumber),
            ...(prefillInvoice?.id ? { voidedInvoiceId: prefillInvoice.id } : {}),
            paymentMethod,
            invoiceCustomSection: toInvoiceCustomSectionReference(
              invoiceCustomSection as InvoiceCustomSectionInput,
            ),
            fees: fees.map(({ unitAmountCents, taxes: addonTaxes, ...fee }) => {
              return {
                ...fee,
                unitAmountCents: Number(serializeAmount(unitAmountCents, currency) || 0),
                taxCodes: hasTaxProvider ? [] : addonTaxes?.map(({ code }) => code) || [],
              }
            }),
          },
        },
      })
    },
  })
  const currency = formikProps.values.currency || CurrencyEnum.Usd
  const hasAnyFee = formikProps.values.fees.length > 0

  const addOns = useMemo(() => {
    if (!addOnData || !addOnData?.addOns || !addOnData?.addOns?.collection) return []

    return addOnData?.addOns?.collection.map(({ id, name, amountCents, amountCurrency }) => {
      return {
        label: name,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {name}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {intlFormatNumber(deserializeAmount(amountCents, amountCurrency) || 0, {
                currencyDisplay: 'symbol',
                currency: amountCurrency,
              })}
            </Typography>
          </ComboboxItem>
        ),
        value: id,
      }
    })
  }, [addOnData])

  const {
    subTotal,
    taxesToDisplay,
    total,
  }: { subTotal: number; taxesToDisplay: TaxMapType; total: number } = useMemo(() => {
    if (hasTaxProvider) {
      return { subTotal: 0, taxesToDisplay: new Map(), total: 0 }
    }

    const updateOrCreateTaxMap = (
      currentTaxesMap: TaxMapType,
      feeAmount?: number,
      feeUnits?: number,
      feeAppliedTaxes?: TaxInfosForCreateInvoiceFragment[],
    ) => {
      if (!feeAppliedTaxes?.length) return currentTaxesMap
      if (!currentTaxesMap) currentTaxesMap = new Map()

      feeAppliedTaxes.forEach((appliedTax) => {
        const { id, name, rate } = appliedTax
        const amount = ((Number(feeAmount) || 0) * Number(feeUnits || 0) * rate) / 100

        const previousTax = currentTaxesMap?.get(id)

        if (previousTax) {
          previousTax.amount += amount
          currentTaxesMap?.set(id, previousTax)
        } else {
          currentTaxesMap?.set(id, { amount, label: `${name} (${rate}%)`, taxRate: rate })
        }
      })

      return currentTaxesMap
    }

    const totalsReduced = formikProps.values.fees.reduce(
      (acc, fee) => {
        acc = {
          subTotal: acc.subTotal + (fee?.units || 0) * (fee?.unitAmountCents || 0),
          taxesToDisplay: updateOrCreateTaxMap(
            acc.taxesToDisplay,
            fee.unitAmountCents,
            fee.units || 0,
            fee?.taxes || undefined,
          ),
        }
        return acc
      },
      { subTotal: 0, taxesToDisplay: new Map() },
    )

    const vatTotalAmount = totalsReduced?.taxesToDisplay?.size
      ? Array.from(totalsReduced?.taxesToDisplay.values()).reduce((acc, tax) => acc + tax.amount, 0)
      : 0
    const localTotal = totalsReduced.subTotal + vatTotalAmount

    return {
      subTotal: totalsReduced.subTotal,
      taxesToDisplay: totalsReduced.taxesToDisplay,
      total: localTotal,
    }
  }, [formikProps.values.fees, hasTaxProvider])

  const {
    taxProviderTaxesToDisplay,
    taxProviderSubtotalHT,
    taxProviderTotalTTC,
  }: {
    taxProviderTaxesToDisplay: TaxMapType
    taxProviderSubtotalHT: number
    taxProviderTotalTTC: number
  } = useMemo(() => {
    if (!hasTaxProvider)
      return {
        taxProviderTaxesToDisplay: new Map(),
        taxProviderSubtotalHT: 0,
        taxProviderTotalTTC: 0,
      }

    const localTaxProviderTaxesToDisplay = !taxProviderTaxesResult?.collection?.length
      ? new Map()
      : taxProviderTaxesResult.collection.reduce((acc, cur) => {
          cur.taxBreakdown?.forEach((tax) => {
            const previousTax = acc.get(tax.rate)

            if (previousTax) {
              previousTax.amount += Number(tax.taxAmount || 0)
              acc.set(tax.rate, previousTax)
            } else {
              acc.set(tax.rate, {
                amount: Number(tax.taxAmount || 0),
                label: !!tax.enumedTaxCode
                  ? translate(appliedTaxEnumedTaxCodeTranslationKey[tax.enumedTaxCode])
                  : `${tax.name} (${!tax?.rate || tax?.rate === 0 ? 0 : tax.rate * 100}%)`,
                taxRate: (tax.rate || 0) * 100,
                hasEnumedTaxCode: !!tax.enumedTaxCode,
              })
            }
          })

          return acc
        }, new Map())

    const taxesTotalAmount = Array.from(localTaxProviderTaxesToDisplay.values()).reduce(
      (acc, tax) => acc + deserializeAmount(tax.amount, currency),
      0,
    )

    const localTaxProviderSubtotalHT =
      formikProps.values.fees.reduce((acc, fee) => {
        acc += (fee.units || 0) * (fee.unitAmountCents || 0)
        return acc
      }, 0) || 0

    return {
      taxProviderTaxesToDisplay: localTaxProviderTaxesToDisplay,
      taxProviderSubtotalHT: localTaxProviderSubtotalHT,
      taxProviderTotalTTC: localTaxProviderSubtotalHT + taxesTotalAmount,
    }
  }, [
    currency,
    formikProps.values.fees,
    hasTaxProvider,
    taxProviderTaxesResult?.collection,
    translate,
  ])

  const showBillingEntityPicker = hasFeatureFlag(FeatureFlagEnum.MultiEntityBilling)
  const hasMultiCurrency = hasFeatureFlag(FeatureFlagEnum.MultiCurrency)

  if (!!error && !loading) {
    return (
      <GenericPlaceholder
        title={translate('text_629728388c4d2300e2d380d5')}
        subtitle={translate('text_629728388c4d2300e2d380eb')}
        buttonTitle={translate('text_629728388c4d2300e2d38110')}
        buttonVariant="primary"
        buttonAction={() => location.reload()}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  const gridClassname =
    'grid  grid-cols-[minmax(0,1fr)_minmax(0,80px)_minmax(0,168px)_minmax(0,64px)_minmax(0,160px)_minmax(0,24px)] gap-3 [&>*:nth-last-child(-n+3)]:flex [&>*:nth-last-child(-n+3)]:justify-end'
  const invoiceFooterLineClassname =
    'flex items-center [&>*:first-child]:mr-4 [&>*:first-child]:flex-1 [&>*:last-child]:w-42 [&>*:last-child]:text-end'

  const canSubmit = formikProps.isValid && hasAnyFee && (!!voidedInvoiceId || formikProps.dirty)

  const subtotalDisplayValue = formatInvoiceDisplayValue(
    hasTaxProvider,
    !!taxProviderSubtotalHT,
    taxProviderSubtotalHT,
    hasAnyFee,
    subTotal,
    currency,
  )

  const amountDueValue = formatInvoiceDisplayValue(
    hasTaxProvider,
    !!taxProviderTaxesToDisplay.size,
    taxProviderTotalTTC,
    hasAnyFee,
    total,
    currency,
  )

  return (
    <>
      <PageHeader.Wrapper>
        <Typography variant="bodyHl" color="textSecondary" noWrap>
          {translate('text_6453819268763979024acfe9')}
        </Typography>

        {!isRunningInSalesForceIframe && !isRunningInIframeContext && (
          <Button
            variant="quaternary"
            icon="close"
            onClick={() =>
              formikProps.dirty ? warningDialogRef.current?.openDialog() : handleClosePage()
            }
          />
        )}
      </PageHeader.Wrapper>
      <div className="size-full">
        <div className="mx-auto my-12 min-h-full max-w-5xl px-4">
          <Card className="mb-12 gap-8">
            {loading ? (
              <>
                <div className="flex items-center justify-between">
                  <Skeleton variant="text" className="w-30" />
                  <Skeleton className="rounded-lg" variant="connectorAvatar" size="big" />
                </div>
                <div>
                  <div className="flex items-center py-2">
                    <Skeleton variant="text" className="mr-13 w-26" />
                    <Skeleton variant="text" className="w-24" />
                  </div>
                  <div className="flex items-center py-2">
                    <Skeleton variant="text" className="mr-13 w-26" />
                    <Skeleton variant="text" className="w-24" />
                  </div>
                </div>
                <div className="flex gap-4">
                  <div className="flex-1">
                    <Skeleton className="mb-3 w-26" variant="text" />
                    <Skeleton className="mb-3 w-26" variant="text" />
                    <Skeleton className="mb-3 w-26" variant="text" />
                    <Skeleton className="mb-3 w-26" variant="text" />
                  </div>
                  <div className="flex-1">
                    <Skeleton className="mb-3 w-26" variant="text" />
                    <Skeleton className="mb-3 w-26" variant="text" />
                    <Skeleton className="mb-3 w-26" variant="text" />
                    <Skeleton className="w-26" variant="text" />
                  </div>
                </div>
              </>
            ) : (
              <>
                <div className="flex items-center justify-between">
                  <Typography variant="headline" color="textSecondary">
                    {translate('text_6453819268763979024acff5')}
                  </Typography>
                  {!!billingEntity?.logoUrl && (
                    <Avatar size="big" variant="connector">
                      <img src={billingEntity?.logoUrl ?? undefined} alt="company-logo" />
                    </Avatar>
                  )}
                </div>

                {customerIsPartner && (
                  <Alert type="info">
                    <Typography variant="body" color="grey700">
                      {translate('text_1738593143437uebmu9jwtc4')}
                    </Typography>

                    <Typography variant="caption" color="grey600">
                      {translate('text_1738593143438173lt8105a5')}
                    </Typography>
                  </Alert>
                )}

                <div className="flex flex-col gap-2">
                  <div className="grid grid-cols-[200px_auto] items-baseline gap-4">
                    <Typography variant="caption" color="grey600">
                      {translate('text_6453819268763979024ad01b')}
                    </Typography>
                    <Typography variant="body" color="grey700">
                      {intlFormatDateTime(DateTime.now().toISO()).date}
                    </Typography>
                  </div>

                  <PO
                    className="flex-row items-center gap-4"
                    value={formikProps.values.purchaseOrderNumber}
                    onChange={(value) => {
                      formikProps.setFieldValue('purchaseOrderNumber', value || undefined)
                    }}
                    description={translate('text_1782219771286e8qwitkefxr')}
                  >
                    <PO.Title className="min-w-[200px]" variant="caption" color="grey600" />

                    {formikProps.values.purchaseOrderNumber ? (
                      <div className="flex items-center gap-2">
                        <PO.Number variant="body" color="grey700" />
                        <PO.EditButton />
                        <PO.TrashButton />
                      </div>
                    ) : (
                      <PO.AddButton>{translate('text_17822197712864tnvgq76xou')}</PO.AddButton>
                    )}
                  </PO>
                </div>

                <div className="flex flex-row items-start gap-4">
                  {showBillingEntityPicker && (
                    <div className="w-80">
                      <BillingEntityFormPicker
                        label={translate('text_1743611497157teaa1zu8l24')}
                        value={formikProps.values.billingEntityId}
                        onChange={(id) => {
                          formikProps.setFieldValue('billingEntityId', id)
                          setPickedBillingEntityId(id)
                        }}
                      />
                    </div>
                  )}
                  <div className="w-40">
                    <ComboBoxField
                      disableClearable
                      data={Object.values(CurrencyEnum).map((currencyType) => ({
                        value: currencyType,
                      }))}
                      disabled={!!customer?.currency && !hasMultiCurrency}
                      formikProps={formikProps}
                      label={translate('text_6453819268763979024ad057')}
                      name="currency"
                    />
                  </div>
                </div>

                <div className={tw('flex gap-4', customerIsPartner && 'flex-row-reverse')}>
                  <div className="flex-1">
                    <Typography variant="caption" color="grey600">
                      {translate(
                        customerIsPartner
                          ? 'text_6453819268763979024ad03f'
                          : 'text_6453819268763979024ad027',
                      )}
                    </Typography>
                    <Typography variant="body" color="grey700" forceBreak>
                      {billingEntity?.legalName || billingEntity?.name}
                    </Typography>
                    {billingEntity?.legalNumber && (
                      <Typography variant="body" color="grey700">
                        {billingEntity?.legalNumber}
                      </Typography>
                    )}
                    {!!formattedBillingAddress && (
                      <Typography variant="body" color="grey700">
                        {formattedBillingAddress}
                      </Typography>
                    )}
                    {billingEntity?.email && (
                      <Typography variant="body" color="grey700">
                        {billingEntity?.email}
                      </Typography>
                    )}
                    {billingEntity?.taxIdentificationNumber && (
                      <Typography variant="body" color="grey700">
                        {translate('text_648053ee819b60364c675c78', {
                          taxIdentificationNumber: billingEntity.taxIdentificationNumber,
                        })}
                      </Typography>
                    )}
                  </div>
                  <div className="flex-1">
                    <Typography variant="caption" color="grey600">
                      {translate(
                        customerIsPartner
                          ? 'text_6453819268763979024ad027'
                          : 'text_6453819268763979024ad03f',
                      )}
                    </Typography>
                    <Typography variant="body" color="grey700" forceBreak>
                      {customer?.legalName || customerName}
                    </Typography>
                    {customer?.legalNumber && (
                      <Typography variant="body" color="grey700">
                        {customer?.legalNumber}
                      </Typography>
                    )}
                    {!!formattedCustomerAddress && (
                      <Typography variant="body" color="grey700">
                        {formattedCustomerAddress}
                      </Typography>
                    )}
                    {customer?.email && (
                      <Typography variant="body" color="grey700">
                        {customer?.email}
                      </Typography>
                    )}
                    {customer?.taxIdentificationNumber && (
                      <Typography variant="body" color="grey700">
                        {translate('text_648053ee819b60364c675c78', {
                          taxIdentificationNumber: customer.taxIdentificationNumber,
                        })}
                      </Typography>
                    )}
                  </div>
                </div>

                <div className="w-full">
                  <div className={tw(gridClassname, 'h-12 shadow-b [&>*]:flex [&>*]:items-center')}>
                    <Typography variant="bodyHl" color="grey500">
                      {translate('text_6453819268763979024ad071')}
                    </Typography>
                    <Typography variant="bodyHl" color="grey500">
                      {translate('text_6453819268763979024ad07d')}
                    </Typography>
                    <Typography variant="bodyHl" color="grey500">
                      {translate('text_6453819268763979024ad089')}
                    </Typography>
                    <Typography variant="bodyHl" color="grey500">
                      {translate('text_636bedf292786b19d3398f06')}
                    </Typography>
                    <Typography variant="bodyHl" color="grey500">
                      {translate('text_6453819268763979024ad097')}
                    </Typography>
                    {/* Action column */}
                    <div></div>
                  </div>
                  {!!formikProps?.values?.fees?.length &&
                    formikProps?.values?.fees?.map((fee, i) => {
                      const unitValidationErrorKey = _get(formikProps.errors, `fees.${i}.units`)

                      // Compute tax display content
                      let taxDisplayContent

                      if (hasTaxProvider) {
                        const hasTaxProviderResult = !!taxProviderTaxesResult?.collection.length

                        if (hasTaxProviderResult) {
                          const taxItem = taxProviderTaxesResult?.collection.find(
                            (t) => t.itemId === fee.addOnId,
                          )

                          taxDisplayContent = taxItem?.taxBreakdown?.map((tax) => (
                            <Typography
                              key={`fee-${i}-applied-taxe-${tax.name}`}
                              variant="body"
                              color="grey700"
                            >
                              {intlFormatNumber(tax?.rate || 0, {
                                style: 'percent',
                              })}
                            </Typography>
                          ))
                        } else {
                          taxDisplayContent = '-'
                        }
                      } else {
                        if (fee.taxes?.length) {
                          taxDisplayContent = fee.taxes.map((tax) => (
                            <Typography
                              key={`fee-${i}-applied-taxe-${tax.id}`}
                              variant="body"
                              color="grey700"
                            >
                              {intlFormatNumber(tax.rate / 100 || 0, {
                                style: 'percent',
                              })}
                            </Typography>
                          ))
                        } else {
                          taxDisplayContent = '0%'
                        }
                      }

                      return (
                        <div
                          className={tw(gridClassname, 'min-h-17 items-center py-3 shadow-b')}
                          key={`item-${i}`}
                          data-test="invoice-item"
                        >
                          <div>
                            <Typography variant="captionHl" color="grey600" noWrap>
                              {translate('text_633dae57ca9a923dd53c2097', {
                                fromDate: intlFormatDateTime(fee.fromDatetime).date,
                                toDate: intlFormatDateTime(fee.toDatetime).date,
                              })}
                            </Typography>

                            <div className="flex items-center gap-2">
                              <Typography variant="body" color="grey700" noWrap>
                                {fee.invoiceDisplayName || fee.name}
                              </Typography>
                              <Tooltip
                                title={translate('text_65018c8e5c6b626f030bcf8d')}
                                placement="top-end"
                              >
                                <Button
                                  icon="pen"
                                  variant="quaternary"
                                  size="small"
                                  onClick={(e) => {
                                    e.stopPropagation()

                                    openEditInvoiceDisplayNameDialog({
                                      invoiceDisplayName: fee.invoiceDisplayName,
                                      callback: (invoiceDisplayName: string) => {
                                        formikProps.setFieldValue(
                                          `fees.${i}.invoiceDisplayName`,
                                          invoiceDisplayName,
                                        )
                                      },
                                    })
                                  }}
                                />
                              </Tooltip>
                            </div>
                            {!!fee.description && (
                              <Typography variant="caption" color="grey600" noWrap>
                                {fee.description}
                              </Typography>
                            )}
                          </div>
                          <Tooltip
                            placement="top-end"
                            title={
                              !!unitValidationErrorKey && translate(`${unitValidationErrorKey}`)
                            }
                            disableHoverListener={!unitValidationErrorKey}
                          >
                            <TextInput
                              name={`fees.${i}.units`}
                              type="number"
                              beforeChangeFormatter={['triDecimal', 'positiveNumber']}
                              error={false}
                              placeholder={translate('text_62824f0e5d93bc008d268d00')}
                              value={formikProps.values.fees[i].units || undefined}
                              onChange={(value) => {
                                formikProps.setFieldValue(`fees.${i}.units`, Number(value))
                                !!hasTaxProvider && setTaxProviderTaxesResult(null)
                              }}
                            />
                          </Tooltip>
                          <AmountInput
                            beforeChangeFormatter={['positiveNumber']}
                            value={formikProps.values.fees[i].unitAmountCents || 0}
                            currency={currency}
                            InputProps={{
                              startAdornment: (
                                <InputAdornment position="start">
                                  {getCurrencySymbol(currency)}
                                </InputAdornment>
                              ),
                            }}
                            onChange={(value) => {
                              formikProps.setFieldValue(`fees.${i}.unitAmountCents`, value)
                              !!hasTaxProvider && setTaxProviderTaxesResult(null)
                            }}
                          />
                          <Typography
                            className="flex flex-col items-end py-1"
                            variant="body"
                            color="grey700"
                          >
                            {taxDisplayContent}
                          </Typography>
                          <Typography variant="body" color="grey700">
                            {!fee.units
                              ? '-'
                              : intlFormatNumber((fee.units || 0) * (fee.unitAmountCents || 0), {
                                  style: 'currency',
                                  currency,
                                })}
                          </Typography>
                          <Popper
                            PopperProps={{ placement: 'bottom-end' }}
                            opener={() => (
                              <Button
                                icon="dots-horizontal"
                                variant="quaternary"
                                size="small"
                                data-test="invoice-item-actions-button"
                              />
                            )}
                          >
                            {({ closePopper }) => (
                              <MenuPopper>
                                <Button
                                  startIcon="calendar"
                                  variant="quaternary"
                                  align="left"
                                  onClick={() => {
                                    openEditFeeBillingPeriodDialog({
                                      fromDatetime: fee.fromDatetime,
                                      toDatetime: fee.toDatetime,
                                      callback: (fromDatetime: string, toDatetime: string) => {
                                        formikProps.setValues({
                                          ...formikProps.values,
                                          fees: formikProps.values.fees.map((f, j) =>
                                            j === i ? { ...f, fromDatetime, toDatetime } : f,
                                          ),
                                        })
                                      },
                                    })
                                    closePopper()
                                  }}
                                >
                                  {translate('text_1754596347194200100004000')}
                                </Button>
                                <Button
                                  startIcon="text"
                                  variant="quaternary"
                                  align="left"
                                  onClick={() => {
                                    openEditInvoiceItemDescriptionDialog({
                                      description: fee.description || '',
                                      callback: (newDescription?: string) => {
                                        formikProps.setFieldValue(
                                          `fees.${i}.description`,
                                          newDescription,
                                        )
                                      },
                                    })
                                    closePopper()
                                  }}
                                >
                                  {translate('text_6453819268763979024ad124')}
                                </Button>
                                {!hasTaxProvider && (
                                  <Button
                                    startIcon="percentage"
                                    variant="quaternary"
                                    align="left"
                                    onClick={() => {
                                      openEditInvoiceItemTaxDialog({
                                        taxes: fee.taxes,
                                        callback: (newTaxesArray?: LocalFeeInput['taxes']) => {
                                          formikProps.setFieldValue(
                                            `fees.${i}.taxes`,
                                            newTaxesArray,
                                          )
                                        },
                                      })
                                      closePopper()
                                    }}
                                    data-test="invoice-item-edit-taxes"
                                  >
                                    {translate('text_64d40b7e80e64e40710a49ba')}
                                  </Button>
                                )}
                                <Button
                                  startIcon="trash"
                                  variant="quaternary"
                                  align="left"
                                  onClick={() => {
                                    const fees = [...formikProps.values.fees]

                                    fees.splice(i, 1)
                                    formikProps.setFieldValue('fees', fees)
                                    !!hasTaxProvider && setTaxProviderTaxesResult(null)

                                    closePopper()
                                  }}
                                >
                                  {translate('text_6453819268763979024ad12c')}
                                </Button>
                              </MenuPopper>
                            )}
                          </Popper>
                        </div>
                      )
                    })}
                  <div className="mt-6">
                    {showAddItem ? (
                      <div className="flex items-center gap-3">
                        <ComboBox
                          containerClassName="flex-1"
                          className={ADD_ITEM_FOR_INVOICE_INPUT_NAME}
                          data={addOns}
                          loading={loading}
                          searchQuery={getAddOns}
                          placeholder={translate('text_6453819268763979024ad0ad')}
                          onChange={(value) => {
                            const addOn = addOnData?.addOns?.collection.find((c) => c.id === value)
                            const today = DateTime.now()
                            const addonApplicableTaxes = () => {
                              if (hasTaxProvider) return undefined
                              if (!!addOn?.taxes?.length) return addOn?.taxes
                              return customerApplicableTax
                            }

                            if (!!addOn) {
                              formikProps.setFieldValue('fees', [
                                ...formikProps.values.fees,
                                {
                                  addOnId: addOn.id,
                                  name: addOn.name,
                                  description: addOn.description,
                                  invoiceDisplayName: addOn.invoiceDisplayName || '',
                                  units: 1,
                                  unitAmountCents: deserializeAmount(addOn.amountCents, currency),
                                  taxes: addonApplicableTaxes(),
                                  fromDatetime: today.startOf('day').toISO(),
                                  toDatetime: today.endOf('day').toISO(),
                                },
                              ])

                              !!hasTaxProvider && setTaxProviderTaxesResult(null)
                            }

                            setShowAddItem(false)
                          }}
                        />
                        <Tooltip
                          title={translate('text_628b8c693e464200e00e4a10')}
                          placement="top-end"
                        >
                          <Button
                            icon="trash"
                            variant="quaternary"
                            size="small"
                            onClick={() => setShowAddItem(false)}
                          />
                        </Tooltip>
                      </div>
                    ) : (
                      <Button
                        variant="inline"
                        startIcon="plus"
                        onClick={() => {
                          setShowAddItem(true)
                          setTimeout(() => {
                            ;(
                              document.querySelector(
                                `.${ADD_ITEM_FOR_INVOICE_INPUT_NAME} .${MUI_INPUT_BASE_ROOT_CLASSNAME}`,
                              ) as HTMLElement
                            ).click()
                          }, 0)
                        }}
                        data-test="add-item-button"
                      >
                        {translate('text_6453819268763979024ad0d7')}
                      </Button>
                    )}
                  </div>
                </div>

                <div className="flex w-full flex-col gap-8">
                  <div className="ml-auto w-[472px]">
                    <div className="flex w-[472px] flex-col gap-3">
                      <div className={invoiceFooterLineClassname}>
                        <Typography variant="bodyHl" color="grey600">
                          {translate('text_6453819268763979024ad0db')}
                        </Typography>
                        <Typography
                          variant="body"
                          color="grey700"
                          data-test="one-off-invoice-subtotal-value"
                        >
                          {subtotalDisplayValue}
                        </Typography>
                      </div>
                      <InvoiceTaxesDisplay
                        hasTaxProvider={hasTaxProvider}
                        taxProviderTaxesToDisplay={taxProviderTaxesToDisplay}
                        taxesToDisplay={taxesToDisplay}
                        hasAnyFee={hasAnyFee}
                        currency={currency}
                        invoiceFooterLineClassname={invoiceFooterLineClassname}
                      />
                      <div className={invoiceFooterLineClassname}>
                        <Typography variant="bodyHl" color="grey600">
                          {translate('text_6453819268763979024ad0ff')}
                        </Typography>
                        <Typography
                          variant="body"
                          color="grey700"
                          data-test="one-off-invoice-subtotal-amount-due-value"
                        >
                          {amountDueValue}
                        </Typography>
                      </div>
                      <div className={invoiceFooterLineClassname}>
                        <Typography variant="bodyHl" color="grey700">
                          {translate('text_6453819268763979024ad10f')}
                        </Typography>
                        <Typography
                          variant="body"
                          color="grey700"
                          data-test="one-off-invoice-total-amount-due-value"
                        >
                          {amountDueValue}
                        </Typography>
                      </div>

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
                    </div>
                  </div>
                </div>
              </>
            )}
          </Card>

          {(customer?.externalId || customer?.id) && (
            <Card>
              <div className="flex flex-col gap-1">
                <Typography variant="subhead1">
                  {translate('text_17634566456760qoj7hs7jrh')}
                </Typography>
              </div>
              <PaymentMethodsInvoiceSettings
                customer={customer}
                form={formikProps}
                viewType={ViewTypeEnum.OneOffInvoice}
              />
            </Card>
          )}
        </div>

        {!loading && (
          <div className="sticky bottom-0 z-navBar border-t border-t-grey-200 bg-white">
            <div className="mx-auto flex h-20 max-w-5xl items-center justify-end gap-3 px-4">
              {!!hasTaxProvider && (
                <Button
                  size="large"
                  variant="secondary"
                  disabled={!formikProps.isValid || !formikProps.dirty || !!taxProviderTaxesResult}
                  onClick={async () => {
                    setTaxProviderTaxesErrorMessage(null)

                    const taxProviderResult = await getTaxFromTaxProvider({
                      variables: {
                        input: {
                          currency,
                          customerId: formikProps.values.customerId,
                          fees: formikProps.values.fees.map((f) => ({
                            ...f,
                            unitAmountCents: String(serializeAmount(f.unitAmountCents, currency)),
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
                        setTaxProviderTaxesErrorMessage(
                          LocalTaxProviderErrorsEnum.CustomerAddressError,
                        )
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
                        setTaxProviderTaxesErrorMessage(
                          LocalTaxProviderErrorsEnum.GenericErrorMessage,
                        )
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

                    setTaxProviderTaxesResult(taxProviderResultData?.fetchDraftInvoiceTaxes)
                  }}
                >
                  {translate('text_172383173554743nq9isxpje')}
                </Button>
              )}
              <Button
                size="large"
                disabled={!canSubmit}
                onClick={formikProps.submitForm}
                data-test="create-invoice-button"
              >
                {translate('text_6453819268763979024ad134')}
              </Button>
            </div>
          </div>
        )}
      </div>
      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_645388d5bdbd7b00abffa030')}
        description={translate('text_645388d5bdbd7b00abffa031')}
        continueText={translate('text_645388d5bdbd7b00abffa033')}
        onContinue={handleClosePage}
      />
    </>
  )
}

export default CreateInvoice
