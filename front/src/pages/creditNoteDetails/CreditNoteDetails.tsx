import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { CreditNoteDetailsActivityLogs } from '~/components/creditNote/CreditNoteDetailsActivityLogs'
import { CreditNoteDetailsExternalSync } from '~/components/creditNote/CreditNoteDetailsExternalSync'
import { CreditNoteDetailsOverview } from '~/components/creditNote/CreditNoteDetailsOverview'
import {
  CREDIT_NOTE_TYPE_TRANSLATIONS_MAP,
  getCreditNoteTypes,
} from '~/components/creditNote/utils'
import { useVoidCreditNoteDialog } from '~/components/customers/creditNotes/VoidCreditNoteDialog'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { StatusType } from '~/components/designSystem/Status'
import { buildCreditNoteDocumentData } from '~/components/emails/buildDocumentData'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { addToast, envGlobalVar } from '~/core/apolloClient'
import { CreditNoteDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import {
  CREDIT_NOTES_ROUTE,
  CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE,
} from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  BillingEntityEmailSettingsEnum,
  CurrencyEnum,
  CustomerForCreditNoteDetailsExternalSyncFragmentDoc,
  LagoApiError,
  useGetCreditNoteForDetailsQuery,
  useRetryTaxReportingMutation,
  useSyncIntegrationCreditNoteMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useNotFoundRedirect } from '~/hooks/useNotFoundRedirect'
import { usePermissions } from '~/hooks/usePermissions'
import { useResendEmailDialog } from '~/hooks/useResendEmailDialog'
import { useDownloadCreditNote } from '~/pages/creditNoteDetails/common/useDownloadCreditNote'
import ErrorImage from '~/public/images/maneki/error.svg'

import CreditNoteDetailsMetadata from './creditNoteDetailsMetadata/CreditNoteDetailsMetadata'

const { disablePdfGeneration } = envGlobalVar()

gql`
  query getCreditNoteForDetails($id: ID!) {
    creditNote(id: $id) {
      id
      number
      canBeVoided
      totalAmountCents
      creditAmountCents
      refundAmountCents
      offsetAmountCents
      currency
      integrationSyncable
      taxProviderSyncable
      externalIntegrationId
      taxProviderId
      xmlUrl
      refundStatus
      metadata {
        key
        value
      }
      billingEntity {
        id
        name
        email
        einvoicing
        emailSettings
        logoUrl
      }
      customer {
        id
        email
        ...CustomerForCreditNoteDetailsExternalSync
      }
    }
  }

  mutation syncIntegrationCreditNote($input: SyncIntegrationCreditNoteInput!) {
    syncIntegrationCreditNote(input: $input) {
      creditNoteId
    }
  }

  mutation retryTaxReporting($input: RetryTaxReportingInput!) {
    retryTaxReporting(input: $input) {
      id
    }
  }

  ${CustomerForCreditNoteDetailsExternalSyncFragmentDoc}
`

const CreditNoteDetails = () => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { customerId, invoiceId, creditNoteId } = useParams()
  const { openVoidCreditNoteDialog } = useVoidCreditNoteDialog()
  const { isPremium } = useCurrentUser()
  const activeTabContent = useMainHeaderTabContent()

  const {
    downloadCreditNote,
    loadingCreditNoteDownload,
    downloadCreditNoteXml,
    loadingCreditNoteXmlDownload,
  } = useDownloadCreditNote()

  const { data, loading, error } = useGetCreditNoteForDetailsQuery({
    variables: { id: creditNoteId as string },
    skip: !creditNoteId || !customerId,
    context: { silentErrorCodes: [LagoApiError.NotFound] },
  })

  useNotFoundRedirect({
    error,
    loading,
    redirectTo: CREDIT_NOTES_ROUTE,
    translateKey: 'text_1777995443788l05iwih1hig',
  })

  const { showResendEmailDialog } = useResendEmailDialog()

  const [syncIntegrationCreditNote, { loading: loadingSyncIntegrationCreditNote }] =
    useSyncIntegrationCreditNoteMutation({
      variables: { input: { creditNoteId: creditNoteId || '' } },
      onCompleted({ syncIntegrationCreditNote: syncIntegrationCreditNoteResult }) {
        if (syncIntegrationCreditNoteResult?.creditNoteId) {
          addToast({
            severity: 'success',
            translateKey: data?.creditNote?.customer.netsuiteCustomer
              ? 'text_6655a88569eed300ee8c4d44'
              : 'text_17268445285571pwim3q27vl',
          })
        }
      },
    })

  const [retryTaxReporting] = useRetryTaxReportingMutation({
    onCompleted() {
      addToast({
        severity: 'success',
        translateKey: 'text_1727068261852148l97frl5q',
      })
    },
    variables: {
      input: {
        id: data?.creditNote?.id as string,
      },
    },
    refetchQueries: ['getCreditNote'],
  })

  const creditNote = data?.creditNote
  const hasError = (!!error || !creditNote) && !loading

  const retryTaxSync = async () => {
    if (!data?.creditNote?.id) return
    await retryTaxReporting()
  }

  const hasIntegration = {
    netsuite:
      !!creditNote?.customer.netsuiteCustomer?.integrationId && creditNote?.externalIntegrationId,
    xero: !!creditNote?.customer.xeroCustomer?.integrationId && creditNote?.externalIntegrationId,
    anrok:
      !!creditNote?.customer.anrokCustomer?.integrationId &&
      (!!creditNote?.taxProviderId || !!creditNote?.taxProviderSyncable),
    avalara:
      !!creditNote?.customer.avalaraCustomer?.id &&
      (!!creditNote?.taxProviderId || !!creditNote?.taxProviderSyncable),
  }

  const canShowExternalSyncTab = Object.values(hasIntegration).some(Boolean)

  const actions = useMemo(() => {
    return {
      canDownload: hasPermissions(['creditNotesView']) && !disablePdfGeneration,
      canVoid: hasPermissions(['creditNotesVoid']) && creditNote?.canBeVoided,
      canCopy: true,
      canSync: !!creditNote?.integrationSyncable,
      canRetryTaxSync: !!creditNote?.taxProviderSyncable,
      canResendEmail:
        hasPermissions(['creditNotesSend']) &&
        !!creditNote?.billingEntity?.emailSettings?.includes(
          BillingEntityEmailSettingsEnum.CreditNoteCreated,
        ),
    }
  }, [creditNote, hasPermissions])

  const canDownloadXmlFile = useMemo(() => {
    return creditNote?.billingEntity.einvoicing || !!creditNote?.xmlUrl
  }, [creditNote])

  const resendEmail = () => {
    showResendEmailDialog({
      subject: translate('text_17706311399872btwgaui8va', {
        organization: creditNote?.billingEntity.name,
        creditNoteNumber: creditNote?.number,
      }),
      type: BillingEntityEmailSettingsEnum.CreditNoteCreated,
      billingEntity: creditNote?.billingEntity,
      documentId: creditNote?.id,
      customerEmail: creditNote?.customer?.email,
      documentData: buildCreditNoteDocumentData(creditNote),
    })
  }

  const headerActions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_637655cb50f04bf1c8379ce8'),
      items: [
        {
          label: translate('text_637655cb50f04bf1c8379cee'),
          onClick: (closePopper) => {
            copyToClipboard(creditNote?.id || '')
            addToast({
              severity: 'info',
              translateKey: 'text_63766b1c4eeb35667c48f26d',
            })
            closePopper()
          },
        },
        {
          label: translate('text_637655cb50f04bf1c8379cea'),
          hidden: !actions.canDownload || !!canDownloadXmlFile,
          disabled: !!loadingCreditNoteDownload,
          onClick: async (closePopper) => {
            await downloadCreditNote({
              variables: { input: { id: creditNote?.id || '' } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_17604478530211cbzl70dt83'),
          hidden: !actions.canDownload || !canDownloadXmlFile,
          disabled: !!loadingCreditNoteDownload,
          onClick: async (closePopper) => {
            await downloadCreditNote({
              variables: { input: { id: creditNote?.id || '' } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_1760447853022mkp6gwgqukb'),
          hidden: !canDownloadXmlFile,
          disabled: !!loadingCreditNoteXmlDownload,
          onClick: async (closePopper) => {
            await downloadCreditNoteXml({
              variables: { input: { id: creditNote?.id || '' } },
            })
            closePopper()
          },
        },
        {
          label: translate('text_1770392315728uyw3zhs7kzh'),
          hidden: !actions.canResendEmail,
          onClick: (closePopper) => {
            resendEmail()
            closePopper()
          },
        },
        {
          label: translate('text_637655cb50f04bf1c8379cec'),
          hidden: !actions.canVoid,
          onClick: (closePopper) => {
            if (!creditNote?.id) return

            openVoidCreditNoteDialog({
              id: creditNote?.id,
              totalAmountCents: creditNote?.totalAmountCents,
              currency: creditNote?.currency,
            })
            closePopper()
          },
        },
        {
          label: translate(
            creditNote?.customer.netsuiteCustomer
              ? 'text_665d742ee9853200e3a6be7f'
              : 'text_66911d4b4b3c3e005c62ab49',
          ),
          hidden: !actions.canSync,
          disabled: loadingSyncIntegrationCreditNote,
          onClick: async (closePopper) => {
            await syncIntegrationCreditNote()
            closePopper()
          },
        },
        {
          label: translate('text_17270681462632d46dh3r1vu'),
          hidden: !actions.canRetryTaxSync,
          disabled: loadingSyncIntegrationCreditNote,
          onClick: async (closePopper) => {
            await retryTaxSync()
            closePopper()
          },
        },
      ],
    },
  ]

  const creditNoteTypes = getCreditNoteTypes({
    creditAmountCents: creditNote?.creditAmountCents,
    refundAmountCents: creditNote?.refundAmountCents,
    offsetAmountCents: creditNote?.offsetAmountCents,
  })

  const headerEntity = {
    viewName: creditNote?.number || '',
    viewNameLoading: loading,
    metadata: `${translate('text_637655cb50f04bf1c8379cf2', {
      amount: intlFormatNumber(
        deserializeAmount(
          creditNote?.totalAmountCents || 0,
          creditNote?.currency || CurrencyEnum.Usd,
        ),
        {
          currencyDisplay: 'symbol',
          currency: creditNote?.currency || CurrencyEnum.Usd,
        },
      ),
    })} • ${creditNote?.id}`,
    metadataLoading: loading,
    badges: creditNoteTypes.map((type) => ({
      type: StatusType.default,
      label: translate(CREDIT_NOTE_TYPE_TRANSLATIONS_MAP[type]),
    })),
  }

  const tabs = [
    {
      title: translate('text_637655cb50f04bf1c8379cfa'),
      link: generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE, {
        customerId: customerId as string,
        invoiceId: invoiceId as string,
        creditNoteId: creditNoteId as string,
        tab: CreditNoteDetailsTabsOptionsEnum.overview,
      }),
      match: [
        generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          creditNoteId: creditNoteId as string,
        }),
        generatePath(CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE, {
          customerId: customerId as string,
          creditNoteId: creditNoteId as string,
        }),
        generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          creditNoteId: creditNoteId as string,
          tab: CreditNoteDetailsTabsOptionsEnum.overview,
        }),
      ],
      content: (
        <DetailsPage.Container>
          <CreditNoteDetailsOverview
            loadingCreditNoteDownload={loadingCreditNoteDownload}
            downloadCreditNote={downloadCreditNote}
            downloadCreditNoteXml={downloadCreditNoteXml}
          />
          <CreditNoteDetailsMetadata creditNote={creditNote} />
        </DetailsPage.Container>
      ),
    },
    {
      title: translate('text_17489570558986035g3zp16t'),
      link: generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE, {
        customerId: customerId as string,
        invoiceId: invoiceId as string,
        creditNoteId: creditNoteId as string,
        tab: CreditNoteDetailsTabsOptionsEnum.externalSync,
      }),
      match: [
        generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          creditNoteId: creditNoteId as string,
        }),
        generatePath(CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE, {
          customerId: customerId as string,
          creditNoteId: creditNoteId as string,
        }),
        generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          creditNoteId: creditNoteId as string,
          tab: CreditNoteDetailsTabsOptionsEnum.externalSync,
        }),
      ],
      content: (
        <DetailsPage.Container>
          <CreditNoteDetailsExternalSync retryTaxSync={retryTaxSync} />
        </DetailsPage.Container>
      ),
      hidden: !canShowExternalSyncTab,
    },
    {
      title: translate('text_1747314141347qq6rasuxisl'),
      link: generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE, {
        customerId: customerId as string,
        invoiceId: invoiceId as string,
        creditNoteId: creditNoteId as string,
        tab: CreditNoteDetailsTabsOptionsEnum.activityLogs,
      }),
      match: [
        generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          creditNoteId: creditNoteId as string,
        }),
        generatePath(CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE, {
          customerId: customerId as string,
          creditNoteId: creditNoteId as string,
        }),
        generatePath(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE, {
          customerId: customerId as string,
          invoiceId: invoiceId as string,
          creditNoteId: creditNoteId as string,
          tab: CreditNoteDetailsTabsOptionsEnum.activityLogs,
        }),
      ],
      content: (
        <DetailsPage.Container>
          <CreditNoteDetailsActivityLogs creditNoteId={creditNoteId as string} />
        </DetailsPage.Container>
      ),
      hidden: !creditNoteId || !isPremium || !hasPermissions(['auditLogsView']),
    },
  ]

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          { label: translate('text_66461ada56a84401188e8c63'), path: CREDIT_NOTES_ROUTE },
        ]}
        entity={headerEntity}
        actions={{ items: headerActions, loading }}
        tabs={tabs}
      />

      {hasError ? (
        <GenericPlaceholder
          title={translate('text_634812d6f16b31ce5cbf4111')}
          subtitle={translate('text_634812d6f16b31ce5cbf411f')}
          buttonTitle={translate('text_634812d6f16b31ce5cbf4123')}
          buttonVariant="primary"
          buttonAction={() => location.reload()}
          image={<ErrorImage width="136" height="104" />}
        />
      ) : (
        <>{activeTabContent}</>
      )}
    </>
  )
}

export default CreditNoteDetails
