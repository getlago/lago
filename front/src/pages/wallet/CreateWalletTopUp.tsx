import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { getIn, useFormik } from 'formik'
import { useCallback, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'
import { boolean, number, object, string } from 'yup'

import { Accordion } from '~/components/designSystem/Accordion'
import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { AmountInputField, SwitchField, TextInputField } from '~/components/form'
import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { toInvoiceCustomSectionReference } from '~/components/invoceCustomFooter/utils'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import { PaymentMethodsInvoiceSettings } from '~/components/paymentMethodsInvoiceSettings/PaymentMethodsInvoiceSettings'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import {
  ADD_METADATA_DATA_TEST,
  CLOSE_CREATE_TOPUP_BUTTON_DATA_TEST,
  CREATE_WALLET_TOP_UP_FORM_TEST_ID,
  IGNORE_PAID_TOPUP_LIMITS_SWITCH_DATA_TEST,
  INVOICE_REQUIRES_SUCCESSFUL_PAYMENT_SWITCH_DATA_TEST,
  SUBMIT_WALLET_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import { addToast } from '~/core/apolloClient'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_DETAILS_TAB_ROUTE, useNavigate, WALLET_DETAILS_ROUTE } from '~/core/router'
import { deserializeAmount, getCurrencyPrecision } from '~/core/serializers/serializeAmount'
import {
  METADATA_VALUE_MAX_LENGTH_DEFAULT,
  MetadataErrorsEnum,
  metadataSchema,
} from '~/formValidation/metadataSchema'
import {
  CreateCustomerWalletTransactionInput,
  CurrencyEnum,
  useCreateCustomerWalletTransactionMutation,
  useGetCustomerInfosForWalletFormQuery,
  useGetCustomerWalletListQuery,
  useGetInvoiceStatusQuery,
  useGetWalletForTopUpQuery,
  useVoidInvoiceMutation,
  WalletDetailsFragmentDoc,
  WalletStatusEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useLocationHistory } from '~/hooks/core/useLocationHistory'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissionsInvoiceActions } from '~/hooks/usePermissionsInvoiceActions'
import TopUpTypeSelector, {
  WalletTransactionType,
} from '~/pages/wallet/components/TopUpTypeSelector'
import { topUpAmountError } from '~/pages/wallet/form'
import { WalletDetailsTabsOptionsEnum } from '~/pages/wallet/WalletDetails'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

gql`
  query getWalletForTopUp($walletId: ID!) {
    wallet(id: $walletId) {
      id
      ...WalletForTopUp
    }
  }

  mutation createCustomerWalletTransaction($input: CreateCustomerWalletTransactionInput!) {
    createCustomerWalletTransaction(input: $input) {
      collection {
        id
        wallet {
          id
          ...WalletDetails
        }
      }
    }
  }

  fragment WalletForTopUp on Wallet {
    id
    name
    currency
    rateAmount
    invoiceRequiresSuccessfulPayment
    paidTopUpMinAmountCents
    paidTopUpMaxAmountCents
    priority
  }

  ${WalletDetailsFragmentDoc}
`

export const CREATE_ACTIVE_WALLET_TOP_UP_ID = 'active-wallet'
const WALLET_TOP_UP_DEFAULT_PRIORITY = '50'

const CreateWalletTopUp = () => {
  const { translate } = useInternationalization()
  const navigate = useNavigate()
  const { goBack } = useLocationHistory()
  const actions = usePermissionsInvoiceActions()

  const { organization: { defaultCurrency } = {} } = useOrganizationInfos()
  const { customerId = '', walletId = '', voidedInvoiceId = '' } = useParams()
  const warningDialogRef = useRef<WarningDialogRef>(null)

  const [transactionType, setTransactionType] = useState(WalletTransactionType.PrepaidCredits)

  const { data: voidedInvoice } = useGetInvoiceStatusQuery({
    variables: {
      id: voidedInvoiceId as string,
    },
    skip: !voidedInvoiceId,
  })

  const { data: customerWalletData } = useGetCustomerWalletListQuery({
    variables: { customerId, page: 0, limit: 20 },
    skip: walletId !== CREATE_ACTIVE_WALLET_TOP_UP_ID,
  })

  const list = customerWalletData?.wallets?.collection || []
  const activeWallet = list.find((wallet) => wallet.status === WalletStatusEnum.Active)

  const fetchedWalletId = walletId === CREATE_ACTIVE_WALLET_TOP_UP_ID ? activeWallet?.id : walletId

  const { data, loading } = useGetWalletForTopUpQuery({
    variables: {
      walletId: fetchedWalletId as string,
    },
    skip: !fetchedWalletId,
  })

  const wallet = data?.wallet

  const { data: customerData } = useGetCustomerInfosForWalletFormQuery({
    variables: { id: customerId },
    skip: !customerId,
  })

  const currency = wallet?.currency || defaultCurrency || CurrencyEnum.Usd

  const [createWallet] = useCreateCustomerWalletTransactionMutation({
    onCompleted(res) {
      if (res?.createCustomerWalletTransaction) {
        addToast({
          severity: 'success',
          translateKey: 'text_62e79671d23ae6ff149dea26',
        })
      }
    },
  })

  const [voidInvoice] = useVoidInvoiceMutation({})

  const paidTopUpMinAmountCents = wallet?.paidTopUpMinAmountCents
    ? deserializeAmount(wallet?.paidTopUpMinAmountCents, currency)?.toString()
    : undefined

  const paidTopUpMaxAmountCents = wallet?.paidTopUpMaxAmountCents
    ? deserializeAmount(wallet?.paidTopUpMaxAmountCents, currency)?.toString()
    : undefined

  const formikProps = useFormik<Omit<CreateCustomerWalletTransactionInput, 'walletId'>>({
    initialValues: {
      grantedCredits: '',
      invoiceRequiresSuccessfulPayment: wallet?.invoiceRequiresSuccessfulPayment,
      paidCredits: '',
      name: undefined,
      metadata: undefined,
      ignorePaidTopUpLimits: undefined,
      priority: 50,
    },
    validationSchema: object().shape({
      paidCredits: string().test({
        test: function (paidCredits) {
          const { ignorePaidTopUpLimits, grantedCredits } = this?.parent || {}

          const error = topUpAmountError({
            skip: ignorePaidTopUpLimits,
            paidCredits,
            rateAmount: wallet?.rateAmount?.toString(),
            paidTopUpMinAmountCents,
            paidTopUpMaxAmountCents,
            currency: wallet?.currency,
          })

          if (error?.error) {
            return false
          }

          return !isNaN(Number(paidCredits)) || !isNaN(Number(grantedCredits))
        },
      }),
      invoiceRequiresSuccessfulPayment: boolean(),
      grantedCredits: string().test({
        test: function (grantedCredits) {
          const { paidCredits } = this?.parent || {}

          return !isNaN(Number(grantedCredits)) || !isNaN(Number(paidCredits))
        },
      }),
      metadata: metadataSchema().nullable(),
      priority: number(),
    }),
    validateOnMount: true,
    onSubmit: async ({
      grantedCredits,
      paidCredits,
      invoiceRequiresSuccessfulPayment,
      ignorePaidTopUpLimits,
      invoiceCustomSection,
      paymentMethod,
      priority,
      ...rest
    }) => {
      if (!wallet) return

      if (
        voidedInvoiceId &&
        voidedInvoice?.invoice?.id &&
        actions.canVoid(voidedInvoice?.invoice)
      ) {
        const res = await voidInvoice({
          variables: {
            input: {
              id: voidedInvoiceId,
              generateCreditNote: false,
            },
          },
        })

        if (!res?.data?.voidInvoice?.id) {
          return
        }
      }

      await createWallet({
        variables: {
          input: {
            ...rest,
            walletId: wallet.id,
            priority: Number(priority) || Number(WALLET_TOP_UP_DEFAULT_PRIORITY),
            grantedCredits: grantedCredits === '' ? '0' : String(grantedCredits),
            paidCredits: paidCredits === '' ? '0' : String(paidCredits),
            invoiceRequiresSuccessfulPayment,
            ignorePaidTopUpLimits,
            paymentMethod,
            invoiceCustomSection: toInvoiceCustomSectionReference(
              invoiceCustomSection as InvoiceCustomSectionInput,
            ),
          },
        },
        refetchQueries: ['getCustomerWalletList', 'getWalletTransactions'],
        notifyOnNetworkStatusChange: true,
      })

      navigateToCustomerWalletTab(wallet.id)
    },
  })

  const updateTransactionType = (type: WalletTransactionType) => {
    setTransactionType(type)

    formikProps.setFieldValue('grantedCredits', '')
    formikProps.setFieldValue('paidCredits', '')
  }

  const navigateBack = useCallback(
    () =>
      goBack(
        generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
          customerId: customerId,
          tab: CustomerDetailsTabsOptions.wallet,
        }),
      ),
    [customerId, goBack],
  )

  const navigateToCustomerWalletTab = useCallback(
    (id?: string) => {
      if (id) {
        return navigate(
          generatePath(WALLET_DETAILS_ROUTE, {
            walletId: id,
            customerId: customerId,
            tab: WalletDetailsTabsOptionsEnum.overview,
          }),
        )
      }

      return navigate(
        generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
          customerId: customerId,
          tab: CustomerDetailsTabsOptions.wallet,
        }),
      )
    },
    [customerId, navigate],
  )

  const onAbort = useCallback(() => {
    formikProps.dirty ? warningDialogRef.current?.openDialog() : navigateBack()
  }, [formikProps.dirty, navigateBack])

  const hasMinMax =
    (wallet?.paidTopUpMinAmountCents !== null && wallet?.paidTopUpMinAmountCents !== undefined) ||
    (wallet?.paidTopUpMaxAmountCents !== null && wallet?.paidTopUpMaxAmountCents !== undefined)

  const paidCreditsError = topUpAmountError({
    rateAmount: wallet?.rateAmount?.toString(),
    paidCredits: formikProps?.values?.paidCredits?.toString(),
    paidTopUpMinAmountCents,
    paidTopUpMaxAmountCents,
    currency: wallet?.currency,
    skip: !!formikProps?.values?.ignorePaidTopUpLimits,
    translate,
  })

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate('text_62e161ceb87c201025388ada')}
          </Typography>
          <Button
            variant="quaternary"
            icon="close"
            onClick={onAbort}
            data-test={CLOSE_CREATE_TOPUP_BUTTON_DATA_TEST}
          />
        </CenteredPage.Header>

        {loading && !wallet && (
          <CenteredPage.Container>
            <FormLoadingSkeleton id="create-wallet" />
          </CenteredPage.Container>
        )}

        {!loading && wallet && (
          <CenteredPage.Container>
            <CenteredPage.PageTitle
              title={translate('text_62e79671d23ae6ff149de924')}
              description={translate('text_1741103892833sy9e4va0pvb')}
            />

            <section className="flex flex-col gap-6 pb-12 shadow-b">
              <div className="flex flex-col gap-1">
                <Typography variant="subhead1">
                  {translate('text_6560809c38fb9de88d8a5090')}
                </Typography>
                <Typography variant="caption">
                  {translate('text_17411038928332xzx1hb4wjx')}
                </Typography>
              </div>

              <WalletSettingsInfosDisplay
                infos={[
                  { label: translate('text_6419c64eace749372fc72b0f'), value: wallet.name },
                  {
                    label: translate('text_1755695821678c8hkgkxkh73'),
                    value: wallet.priority,
                  },
                  {
                    label: translate('text_1750411499858su5b7bbp5t9'),
                    value: translate('text_62da6ec24a8e24e44f812872', {
                      rateAmount: intlFormatNumber(wallet.rateAmount, {
                        currency,
                        minimumFractionDigits: getCurrencyPrecision(currency),
                        currencyDisplay: 'symbol',
                      }),
                    }),
                  },
                  {
                    label: translate('text_1759387047166vuoep9t72ny'),
                    value: intlFormatNumber(
                      deserializeAmount(wallet?.paidTopUpMinAmountCents, currency),
                      {
                        currency,
                      },
                    ),
                    hide: !wallet?.paidTopUpMinAmountCents,
                  },
                  {
                    label: translate('text_1759387047167hwbqm5hx7ye'),
                    value: intlFormatNumber(
                      deserializeAmount(wallet?.paidTopUpMaxAmountCents, currency),
                      {
                        currency,
                      },
                    ),
                    hide: !wallet?.paidTopUpMaxAmountCents,
                  },
                ]}
              />
            </section>

            <section
              data-test={CREATE_WALLET_TOP_UP_FORM_TEST_ID}
              className="flex flex-col gap-6 pb-12 shadow-b"
            >
              <div className="flex flex-col gap-1">
                <Typography variant="subhead1">
                  {translate('text_6657be42151661006d2f3b89')}
                </Typography>
                <Typography variant="caption">
                  {translate('text_1741103892833plsi99wvuop')}
                </Typography>
              </div>
              <TextInputField
                // eslint-disable-next-line jsx-a11y/no-autofocus
                autoFocus
                name="name"
                formikProps={formikProps}
                label={translate('text_17580145853389xkffv9cs1d')}
                placeholder={translate('text_17580145853390n3v83gao69')}
                helperText={translate('text_1758014585339ly8tof8ub3r')}
              />
              <TopUpTypeSelector
                selectedType={transactionType}
                setSelectedType={updateTransactionType}
              />
              {transactionType === WalletTransactionType.PrepaidCredits && (
                <>
                  <AmountInputField
                    name="paidCredits"
                    currency={wallet.currency}
                    beforeChangeFormatter={['positiveNumber']}
                    label={translate('text_62e79671d23ae6ff149de944')}
                    formikProps={formikProps}
                    silentError={true}
                    error={paidCreditsError?.label}
                    helperText={translate('text_62d18855b22699e5cf55f88b', {
                      paidCredits: intlFormatNumber(
                        isNaN(Number(formikProps.values.paidCredits))
                          ? 0
                          : Number(formikProps.values.paidCredits) * Number(wallet.rateAmount),

                        {
                          currencyDisplay: 'symbol',
                          currency: wallet.currency,
                        },
                      ),
                    })}
                    InputProps={{
                      endAdornment: (
                        <InputAdornment position="end">
                          {translate('text_62e79671d23ae6ff149de94c')}
                        </InputAdornment>
                      ),
                    }}
                  />
                  {formikProps.values.paidCredits && (
                    <>
                      {hasMinMax && (
                        <SwitchField
                          name={'ignorePaidTopUpLimits'}
                          formikProps={formikProps}
                          label={translate('text_17587075291282to3nmogezj')}
                          data-test={IGNORE_PAID_TOPUP_LIMITS_SWITCH_DATA_TEST}
                        />
                      )}

                      <SwitchField
                        name="invoiceRequiresSuccessfulPayment"
                        formikProps={formikProps}
                        label={translate('text_66a8aed1c3e07b277ec3990d')}
                        subLabel={translate('text_66a8aed1c3e07b277ec3990f')}
                        data-test={INVOICE_REQUIRES_SUCCESSFUL_PAYMENT_SWITCH_DATA_TEST}
                      />
                    </>
                  )}
                </>
              )}
              {transactionType === WalletTransactionType.FreeCredits && (
                <AmountInputField
                  name="grantedCredits"
                  currency={wallet.currency}
                  beforeChangeFormatter={['positiveNumber']}
                  label={translate('text_62d18855b22699e5cf55f88d')}
                  formikProps={formikProps}
                  silentError={true}
                  helperText={translate('text_62d18855b22699e5cf55f893', {
                    grantedCredits: intlFormatNumber(
                      isNaN(Number(formikProps.values.grantedCredits))
                        ? 0
                        : Number(formikProps.values.grantedCredits) * Number(wallet.rateAmount),
                      {
                        currencyDisplay: 'symbol',
                        currency: wallet.currency,
                      },
                    ),
                  })}
                  InputProps={{
                    endAdornment: (
                      <InputAdornment position="end">
                        {translate('text_62e79671d23ae6ff149de95c')}
                      </InputAdornment>
                    ),
                  }}
                />
              )}
              <Alert type="info">
                <Typography color="textSecondary">
                  {translate('text_17411038928333ksu96fbmam', {
                    totalCreditCount:
                      Math.round(
                        Number(formikProps.values.paidCredits || 0) * 100 +
                          Number(formikProps.values.grantedCredits || 0) * 100,
                      ) / 100,
                  })}
                </Typography>
              </Alert>

              <TextInputField
                name="priority"
                type="number"
                beforeChangeFormatter={['positiveNumber', 'int']}
                label={translate('text_17708227222843peys0u3ywu')}
                description={translate('text_17708227222846t71arrz7dn')}
                placeholder={WALLET_TOP_UP_DEFAULT_PRIORITY}
                formikProps={formikProps}
              />
            </section>

            {(customerData?.customer?.externalId || customerData?.customer?.id) && (
              <section className="flex flex-col gap-6 pb-12 shadow-b">
                <div className="flex flex-col gap-1">
                  <Typography variant="subhead1">
                    {translate('text_17634566456760qoj7hs7jrh')}
                  </Typography>
                </div>
                <PaymentMethodsInvoiceSettings
                  customer={customerData?.customer}
                  form={formikProps}
                  viewType={ViewTypeEnum.WalletTransactionTopUp}
                />
              </section>
            )}

            <section className="flex flex-col gap-6">
              <Accordion
                variant="borderless"
                summary={
                  <div className="flex flex-col gap-2">
                    <Typography variant="subhead1">
                      {translate('text_63fcc3218d35b9377840f59b')}
                    </Typography>
                    <Typography variant="caption">
                      {translate('text_1741706729331emiq4h111k8')}
                    </Typography>
                  </div>
                }
              >
                <div className="flex flex-col gap-6">
                  {(formikProps.values.metadata ?? []).map((_metadata, index) => {
                    const metadataItemKeyError = getIn(formikProps.errors, `metadata.${index}.key`)
                    const metadataItemValueError = getIn(
                      formikProps.errors,
                      `metadata.${index}.value`,
                    )

                    const hasCustomKeyError =
                      Object.keys(MetadataErrorsEnum).includes(metadataItemKeyError)
                    const hasCustomValueError =
                      Object.keys(MetadataErrorsEnum).includes(metadataItemValueError)

                    return (
                      <div
                        className="flex w-full flex-row items-center gap-3"
                        key={`metadata-item-${index}`}
                      >
                        <div className="basis-[200px]">
                          <Tooltip
                            placement="top-end"
                            title={
                              (metadataItemKeyError === MetadataErrorsEnum.uniqueness &&
                                translate('text_63fcc3218d35b9377840f5dd')) ||
                              (metadataItemKeyError === MetadataErrorsEnum.maxLength &&
                                translate('text_63fcc3218d35b9377840f5d9', { max: 20 }))
                            }
                            disableHoverListener={!hasCustomKeyError}
                          >
                            <TextInputField
                              name={`metadata.${index}.key`}
                              label={translate('text_63fcc3218d35b9377840f5a3')}
                              silentError={!hasCustomKeyError}
                              placeholder={translate('text_63fcc3218d35b9377840f5a7')}
                              formikProps={formikProps}
                              displayErrorText={false}
                            />
                          </Tooltip>
                        </div>
                        <div className="grow">
                          <Tooltip
                            placement="top-end"
                            title={
                              metadataItemValueError === MetadataErrorsEnum.maxLength
                                ? translate('text_63fcc3218d35b9377840f5e5', {
                                    max: METADATA_VALUE_MAX_LENGTH_DEFAULT,
                                  })
                                : undefined
                            }
                            disableHoverListener={!hasCustomValueError}
                          >
                            <TextInputField
                              name={`metadata.${index}.value`}
                              label={translate('text_63fcc3218d35b9377840f5ab')}
                              silentError={!hasCustomValueError}
                              placeholder={translate('text_63fcc3218d35b9377840f5af')}
                              formikProps={formikProps}
                              displayErrorText={false}
                            />
                          </Tooltip>
                        </div>
                        <Tooltip
                          className="flex items-center"
                          placement="top-end"
                          title={translate('text_63fcc3218d35b9377840f5e1')}
                        >
                          <Button
                            className="mt-7"
                            variant="quaternary"
                            size="medium"
                            icon="trash"
                            onClick={() => {
                              formikProps.setFieldValue(
                                'metadata',
                                (formikProps.values.metadata ?? []).filter((_, i) => i !== index),
                              )
                            }}
                          />
                        </Tooltip>
                      </div>
                    )
                  })}

                  <Button
                    className="self-start"
                    startIcon="plus"
                    variant="inline"
                    onClick={() =>
                      formikProps.setFieldValue('metadata', [
                        ...(formikProps.values.metadata ?? []),
                        { key: '', value: '' },
                      ])
                    }
                    data-test={ADD_METADATA_DATA_TEST}
                  >
                    {translate('text_63fcc3218d35b9377840f5bb')}
                  </Button>
                </div>
              </Accordion>
            </section>
          </CenteredPage.Container>
        )}

        <CenteredPage.StickyFooter>
          <Button variant="quaternary" onClick={onAbort}>
            {translate('text_62e79671d23ae6ff149de968')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={formikProps.submitForm}
            data-test={SUBMIT_WALLET_DATA_TEST}
          >
            {translate('text_1741103892833yi7redcuhoc')}
          </Button>
        </CenteredPage.StickyFooter>
      </CenteredPage.Wrapper>

      <WarningDialog
        ref={warningDialogRef}
        title={translate('text_665deda4babaf700d603ea13')}
        description={translate('text_665dedd557dc3c00c62eb83d')}
        continueText={translate('text_645388d5bdbd7b00abffa033')}
        onContinue={() => navigateToCustomerWalletTab(wallet?.id)}
      />
    </>
  )
}

const WalletSettingsInfosDisplay = ({
  infos,
}: {
  infos?: {
    label: string
    value?: string | number | null
    hide?: boolean
  }[]
}) => {
  if (!infos?.length) return null

  return (
    <div className="flex flex-col gap-1">
      {infos
        .filter((info) => !info.hide)
        .map((info, infoIndex) => (
          <div key={infoIndex} className="flex min-h-10 items-center">
            <Typography variant="body" color="grey600" className="w-55 shrink-0">
              {info.label}
            </Typography>
            <Typography variant="body" color="grey700" className="grow">
              {info.value || '-'}
            </Typography>
          </div>
        ))}
    </div>
  )
}

export default CreateWalletTopUp
