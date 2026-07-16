import { gql } from '@apollo/client'
import { useFormik } from 'formik'
import { DateTime } from 'luxon'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { WarningDialog, WarningDialogRef } from '~/components/designSystem/WarningDialog'
import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { toInvoiceCustomSectionReference } from '~/components/invoceCustomFooter/utils'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  CLOSE_CREATE_WALLET_BUTTON_DATA_TEST,
  SUBMIT_WALLET_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import { addToast } from '~/core/apolloClient'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CUSTOMER_DETAILS_TAB_ROUTE, useNavigate, WALLET_DETAILS_ROUTE } from '~/core/router'
import {
  deserializeAmount,
  getCurrencyPrecision,
  serializeAmount,
} from '~/core/serializers/serializeAmount'
import {
  CreateCustomerWalletInput,
  CurrencyEnum,
  GetWalletInfosForWalletFormQuery,
  LagoApiError,
  RecurringTransactionMethodEnum,
  RecurringTransactionTriggerEnum,
  UpdateCustomerWalletInput,
  useCreateCustomerWalletMutation,
  useGetCustomerInfosForWalletFormQuery,
  useGetWalletInfosForWalletFormQuery,
  useUpdateCustomerWalletMutation,
  WalletForScopeSectionFragmentDoc,
  WalletForUpdateFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { ScopeSection } from '~/pages/wallet/components/ScopeSection'
import { SettingsSection } from '~/pages/wallet/components/SettingsSection'
import { TopUpSection } from '~/pages/wallet/components/TopUpSection'
import { walletFormSchema } from '~/pages/wallet/form'
import { TWalletDataForm } from '~/pages/wallet/types'
import { transformRecurringTransactionRule } from '~/pages/wallet/utils/transformRecurringTransactionRule'
import { WalletDetailsTabsOptionsEnum } from '~/pages/wallet/WalletDetails'
import { FormLoadingSkeleton } from '~/styles/mainObjectsForm'

const WALLET_DEFAULT_PRIORITY = 50

gql`
  fragment WalletForUpdate on Wallet {
    id
    billingEntityId
    currency
    expirationAt
    name
    rateAmount
    invoiceRequiresSuccessfulPayment
    paidTopUpMinAmountCents
    paidTopUpMaxAmountCents
    priority
    paymentMethodType
    paymentMethod {
      id
    }
    skipInvoiceCustomSections
    selectedInvoiceCustomSections {
      id
      name
    }
    appliesTo {
      feeTypes
      billableMetrics {
        id
      }
    }
    recurringTransactionRules {
      expirationAt
      grantedCredits
      grantsTargetTopUp
      interval
      invoiceRequiresSuccessfulPayment
      lagoId
      method
      paidCredits
      startedAt
      targetOngoingBalance
      thresholdCredits
      transactionName
      trigger
      ignorePaidTopUpLimits
      paymentMethodType
      paymentMethod {
        id
      }
      skipInvoiceCustomSections
      selectedInvoiceCustomSections {
        id
        name
      }
      transactionMetadata {
        key
        value
      }
    }

    ...WalletForScopeSection
  }

  query getCustomerInfosForWalletForm($id: ID!) {
    customer(id: $id) {
      id
      externalId
      currency
      timezone
      billingEntity {
        id
      }
    }
  }

  query getWalletInfosForWalletForm($id: ID!) {
    wallet(id: $id) {
      id
      ...WalletForUpdate
    }
  }

  mutation createCustomerWallet($input: CreateCustomerWalletInput!) {
    createCustomerWallet(input: $input) {
      id
      customer {
        id
        hasActiveWallet
      }
    }
  }

  mutation updateCustomerWallet($input: UpdateCustomerWalletInput!) {
    updateCustomerWallet(input: $input) {
      ...WalletForUpdate
    }
  }

  ${WalletForUpdateFragmentDoc}
  ${WalletForScopeSectionFragmentDoc}
`

function hasWalletRecurringTopUpEnabled(
  wallet: GetWalletInfosForWalletFormQuery['wallet'],
): boolean {
  return !!wallet?.recurringTransactionRules?.[0]?.trigger
}

const CreateWallet = () => {
  const navigate = useNavigate()

  const { customerId = '', walletId = '' } = useParams()
  const { translate } = useInternationalization()
  const { organization } = useOrganizationInfos()

  const warningDialogRef = useRef<WarningDialogRef>(null)
  const formType = useMemo(() => {
    if (!!walletId) return FORM_TYPE_ENUM.edition

    return FORM_TYPE_ENUM.creation
  }, [walletId])

  const { data: customerData, loading: customerLoading } = useGetCustomerInfosForWalletFormQuery({
    variables: { id: customerId },
    skip: !customerId,
  })
  const { data: walletData, loading: walletLoading } = useGetWalletInfosForWalletFormQuery({
    variables: { id: walletId },
    skip: !walletId,
  })
  const isLoading = customerLoading || walletLoading
  const wallet = walletData?.wallet

  const [showExpirationDate, setShowExpirationDate] = useState(!!wallet?.expirationAt)
  const [isRecurringTopUpEnabled, setIsRecurringTopUpEnabled] = useState(
    hasWalletRecurringTopUpEnabled(wallet),
  )
  const [showMinTopUp, setShowMinTopUp] = useState(!!wallet?.paidTopUpMinAmountCents)
  const [showMaxTopUp, setShowMaxTopUp] = useState(!!wallet?.paidTopUpMaxAmountCents)

  useEffect(() => {
    if (wallet) {
      setIsRecurringTopUpEnabled(hasWalletRecurringTopUpEnabled(wallet))
      setShowMinTopUp(!!wallet?.paidTopUpMinAmountCents)
      setShowMaxTopUp(!!wallet?.paidTopUpMaxAmountCents)
    }

    if (!!wallet?.expirationAt) {
      setShowExpirationDate(true)
    }
  }, [wallet])

  const currency =
    wallet?.currency ||
    customerData?.customer?.currency ||
    organization?.defaultCurrency ||
    CurrencyEnum.Usd

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

  const [createWallet] = useCreateCustomerWalletMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    onCompleted(res) {
      if (res?.createCustomerWallet) {
        addToast({
          severity: 'success',
          translateKey: 'text_656080d120cad1fe708621fe',
        })
      }
    },
  })

  const [updateWallet] = useUpdateCustomerWalletMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    onCompleted(res) {
      if (res?.updateCustomerWallet) {
        addToast({
          severity: 'success',
          translateKey: 'text_6560809d38fb9de88d8a549c',
        })
      }
    },
  })

  const formikProps = useFormik<TWalletDataForm>({
    initialValues: {
      currency,
      billingEntityId:
        wallet?.billingEntityId || customerData?.customer?.billingEntity?.id || undefined,
      expirationAt: wallet?.expirationAt || undefined,
      grantedCredits: '',
      name: wallet?.name || '',
      transactionName: undefined,
      appliesTo: wallet?.appliesTo || {
        feeTypes: [],
        billableMetrics: [],
      },
      paidCredits: '',
      rateAmount: intlFormatNumber(wallet?.rateAmount ?? 1, {
        currency,
        style: 'decimal',
        minimumFractionDigits: getCurrencyPrecision(currency),
      }),
      recurringTransactionRules:
        wallet?.recurringTransactionRules?.map(transformRecurringTransactionRule) || undefined,
      invoiceRequiresSuccessfulPayment: wallet?.invoiceRequiresSuccessfulPayment ?? false,
      paidTopUpMinAmountCents: wallet?.paidTopUpMinAmountCents
        ? deserializeAmount(wallet.paidTopUpMinAmountCents, currency)
        : undefined,
      paidTopUpMaxAmountCents: wallet?.paidTopUpMaxAmountCents
        ? deserializeAmount(wallet.paidTopUpMaxAmountCents, currency)
        : undefined,
      ignorePaidTopUpLimitsOnCreation: false,
      priority: wallet?.priority || WALLET_DEFAULT_PRIORITY,
      paymentMethod: {
        paymentMethodType: wallet?.paymentMethodType,
        paymentMethodId: wallet?.paymentMethod?.id,
      },
      invoiceCustomSection: {
        invoiceCustomSections: wallet?.selectedInvoiceCustomSections || [],
        skipInvoiceCustomSections: wallet?.skipInvoiceCustomSections || false,
      },
    },
    validationSchema: walletFormSchema(),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async ({
      grantedCredits,
      paidCredits,
      rateAmount,
      currency: valuesCurrency,
      recurringTransactionRules,
      appliesTo,
      priority,
      paymentMethod,
      invoiceCustomSection,
      billingEntityId,
      ...values
    }) => {
      const recurringTransactionRulesFormatted =
        recurringTransactionRules && recurringTransactionRules?.length > 0
          ? recurringTransactionRules.map((rule) => {
              const {
                interval,
                trigger,
                thresholdCredits,
                method,
                targetOngoingBalance,
                startedAt,
                invoiceRequiresSuccessfulPayment,
                paidCredits: rulePaidCredit,
                grantedCredits: ruleGrantedCredit,
                grantsTargetTopUp,
                expirationAt,
                ignorePaidTopUpLimits,
                invoiceCustomSection: ruleInvoiceCustomSection,
                ...rest
              } = rule

              let targetedBalance: string | null = null

              if (method === RecurringTransactionMethodEnum.Target && targetOngoingBalance === '') {
                targetedBalance = '0'
              } else if (method === RecurringTransactionMethodEnum.Target) {
                targetedBalance = String(targetOngoingBalance)
              }

              return {
                ...rest,
                lagoId:
                  'lagoId' in rule && formType === FORM_TYPE_ENUM.edition
                    ? (rule.lagoId as string | undefined)
                    : undefined,
                method: method as RecurringTransactionMethodEnum,
                trigger: trigger as RecurringTransactionTriggerEnum,
                interval: trigger === RecurringTransactionTriggerEnum.Interval ? interval : null,
                startedAt:
                  trigger === RecurringTransactionTriggerEnum.Interval
                    ? (startedAt ?? DateTime.now().toISO())
                    : null,
                thresholdCredits:
                  trigger === RecurringTransactionTriggerEnum.Threshold ? thresholdCredits : null,
                paidCredits: rulePaidCredit === '' ? '0' : String(rulePaidCredit),
                grantedCredits: ruleGrantedCredit === '' ? '0' : String(ruleGrantedCredit),
                targetOngoingBalance: targetedBalance,
                grantsTargetTopUp:
                  method === RecurringTransactionMethodEnum.Target
                    ? Boolean(grantsTargetTopUp)
                    : null,
                invoiceRequiresSuccessfulPayment,
                ignorePaidTopUpLimits,
                expirationAt: expirationAt === '' ? null : expirationAt,
                invoiceCustomSection: toInvoiceCustomSectionReference(
                  ruleInvoiceCustomSection as InvoiceCustomSectionInput,
                ),
              }
            })
          : []

      const formattedAppliesTo = {
        feeTypes: appliesTo?.feeTypes || [],
        billableMetricIds: appliesTo?.billableMetrics?.map((bm) => bm.id) || [],
      }

      if (formType === FORM_TYPE_ENUM.edition) {
        const input = {
          ...values,
          recurringTransactionRules: recurringTransactionRulesFormatted,
          id: walletId,
          // `null` (not `undefined`) on clear → BE stores NULL on the
          // wallet column, meaning "inherit from customer".
          billingEntityId: billingEntityId || null,
          appliesTo: formattedAppliesTo,
          paymentMethod,
          invoiceCustomSection: toInvoiceCustomSectionReference(invoiceCustomSection),
          ...(values.paidTopUpMinAmountCents
            ? {
                paidTopUpMinAmountCents: serializeAmount(
                  values.paidTopUpMinAmountCents,
                  valuesCurrency,
                ),
              }
            : {
                paidTopUpMinAmountCents: null,
              }),
          ...(values.paidTopUpMaxAmountCents
            ? {
                paidTopUpMaxAmountCents: serializeAmount(
                  values.paidTopUpMaxAmountCents,
                  valuesCurrency,
                ),
              }
            : {
                paidTopUpMaxAmountCents: null,
              }),
          priority: priority || WALLET_DEFAULT_PRIORITY,
        } satisfies UpdateCustomerWalletInput

        // eslint-disable-next-line
        const { ignorePaidTopUpLimitsOnCreation, ...ignoreMutationInput } = input

        const { errors } = await updateWallet({ variables: { input: ignoreMutationInput } })

        if (!!errors?.length) return
      } else {
        const input = {
          ...values,
          customerId,
          // `null` (not `undefined`) on clear → BE stores NULL on the
          // wallet column, meaning "inherit from customer".
          billingEntityId: billingEntityId || null,
          currency: valuesCurrency,
          rateAmount: String(rateAmount),
          grantedCredits: grantedCredits === '' ? '0' : String(grantedCredits),
          paidCredits: paidCredits === '' ? '0' : String(paidCredits),
          recurringTransactionRules: recurringTransactionRulesFormatted,
          appliesTo: formattedAppliesTo,
          paymentMethod,
          invoiceCustomSection: toInvoiceCustomSectionReference(invoiceCustomSection),
          ...(values.paidTopUpMinAmountCents
            ? {
                paidTopUpMinAmountCents: serializeAmount(
                  values.paidTopUpMinAmountCents,
                  valuesCurrency,
                ),
              }
            : {}),
          ...(values.paidTopUpMaxAmountCents
            ? {
                paidTopUpMaxAmountCents: serializeAmount(
                  values.paidTopUpMaxAmountCents,
                  valuesCurrency,
                ),
              }
            : {}),
          priority: priority || WALLET_DEFAULT_PRIORITY,
        } satisfies CreateCustomerWalletInput

        const { errors } = await createWallet({ variables: { input } })

        if (!!errors?.length) return
      }

      navigateToCustomerWalletTab(walletId)
    },
  })

  const onAbort = useCallback(() => {
    formikProps.dirty
      ? warningDialogRef.current?.openDialog()
      : navigateToCustomerWalletTab(walletId)
  }, [formikProps.dirty, navigateToCustomerWalletTab, walletId])

  return (
    <>
      <CenteredPage.Wrapper>
        <CenteredPage.Header>
          <Typography variant="bodyHl" color="textSecondary" noWrap>
            {translate(
              formType === FORM_TYPE_ENUM.edition
                ? 'text_62d9430e8b9fe36851cddd09'
                : 'text_6560809c38fb9de88d8a505e',
            )}
          </Typography>
          <Button
            variant="quaternary"
            icon="close"
            onClick={onAbort}
            data-test={CLOSE_CREATE_WALLET_BUTTON_DATA_TEST}
          />
        </CenteredPage.Header>

        {isLoading && !wallet && (
          <CenteredPage.Container>
            <FormLoadingSkeleton id="create-wallet" />
          </CenteredPage.Container>
        )}

        {!isLoading && (
          <CenteredPage.Container>
            <CenteredPage.PageTitle
              title={translate(
                formType === FORM_TYPE_ENUM.edition
                  ? 'text_62d9430e8b9fe36851cddd09'
                  : 'text_6560809c38fb9de88d8a505e',
              )}
              description={translate('text_1748422458559917eelhobh5')}
            />

            <SettingsSection
              formikProps={formikProps}
              formType={formType}
              customerData={customerData}
              showExpirationDate={showExpirationDate}
              setShowExpirationDate={setShowExpirationDate}
              showMinTopUp={showMinTopUp}
              setShowMinTopUp={setShowMinTopUp}
              showMaxTopUp={showMaxTopUp}
              setShowMaxTopUp={setShowMaxTopUp}
            />

            <ScopeSection formikProps={formikProps} />

            <TopUpSection
              formikProps={formikProps}
              formType={formType}
              customerData={customerData}
              isRecurringTopUpEnabled={isRecurringTopUpEnabled}
              setIsRecurringTopUpEnabled={setIsRecurringTopUpEnabled}
            />
          </CenteredPage.Container>
        )}

        <CenteredPage.StickyFooter>
          <Button variant="quaternary" onClick={onAbort}>
            {translate('text_62e79671d23ae6ff149de968')}
          </Button>
          <Button
            variant="primary"
            disabled={!formikProps.isValid}
            onClick={formikProps.submitForm}
            data-test={SUBMIT_WALLET_DATA_TEST}
          >
            {translate(
              formType === FORM_TYPE_ENUM.edition
                ? 'text_62e161ceb87c201025388aa2'
                : 'text_6560809c38fb9de88d8a505e',
            )}
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

export default CreateWallet
