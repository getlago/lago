import { gql } from '@apollo/client'
import { useMemo } from 'react'
import { generatePath, useParams } from 'react-router-dom'

import { ButtonLink } from '~/components/designSystem/ButtonLink'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { MainHeaderAction } from '~/components/MainHeader/types'
import { useMainHeaderTabContent } from '~/components/MainHeader/useMainHeaderTabContent'
import { VoidWalletDialog } from '~/components/wallets/VoidWalletDialog'
import WalletAlerts from '~/components/wallets/WalletAlerts'
import WalletInformations from '~/components/wallets/WalletInformations'
import { WalletTransactions } from '~/components/wallets/WalletTransactions'
import { CustomerDetailsTabsOptions } from '~/core/constants/tabsOptions'
import {
  CREATE_ALERT_WALLET_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMERS_LIST_ROUTE,
  EDIT_WALLET_ROUTE,
  WALLET_DETAILS_ROUTE,
} from '~/core/router'
import { getCustomerDisplayName } from '~/core/utils/getCustomerDisplayName'
import {
  useGetWalletDetailsQuery,
  WalletInfosForTransactionsFragmentDoc,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import { useWalletActions } from '~/hooks/wallet/useWalletActions'
import ErrorImage from '~/public/images/maneki/error.svg'

gql`
  fragment WalletDetails on Wallet {
    id
    code
    balanceCents
    consumedAmountCents
    consumedCredits
    createdAt
    creditsBalance
    currency
    expirationAt
    lastBalanceSyncAt
    lastConsumedCreditAt
    lastOngoingBalanceSyncAt
    name
    rateAmount
    status
    terminatedAt
    ongoingBalanceCents
    creditsOngoingBalance
    priority
    paidTopUpMinAmountCents
    paidTopUpMinCredits
    paidTopUpMaxAmountCents
    paymentMethodType
    paymentMethod {
      id
      details {
        type
        brand
        last4
      }
    }
    billingEntityId
    customer {
      id
      name
      firstname
      lastname
      externalId
      billingEntity {
        id
        code
        name
      }
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
        name
        code
      }
    }
    recurringTransactionRules {
      method
      transactionName
      paidCredits
      grantedCredits
      grantsTargetTopUp
      trigger
      thresholdCredits
      expirationAt
      interval
    }

    ...WalletInfosForTransactions
  }

  query getWalletDetails($walletId: ID!) {
    wallet(id: $walletId) {
      ...WalletDetails
    }
  }

  ${WalletInfosForTransactionsFragmentDoc}
`
export enum WalletDetailsTabsOptionsEnum {
  overview = 'overview',
  transactions = 'transactions',
  alerts = 'alerts',
}

const SectionTitle = ({
  title,
  description,
  action,
}: {
  title: string
  description: string
  action?: React.ReactNode
}) => (
  <div className="flex justify-between">
    <div className="flex flex-col gap-1">
      <Typography variant="subhead1">{title}</Typography>
      <Typography variant="caption">{description}</Typography>
    </div>

    {!!action && action}
  </div>
)

const WalletDetails = () => {
  const { translate } = useInternationalization()
  const { walletId, customerId } = useParams()
  const { intlFormatDateTimeOrgaTZ } = useOrganizationInfos()
  const { hasPermissions } = usePermissions()
  const activeTabContent = useMainHeaderTabContent()

  const { data, error, loading } = useGetWalletDetailsQuery({
    variables: { walletId: walletId as string },
    skip: !walletId,
  })

  const wallet = data?.wallet

  const customerName = getCustomerDisplayName({
    customer: wallet?.customer,
    fallback: wallet?.customer?.externalId,
  })

  const { actions: walletActionItems, voidDialogRef } = useWalletActions({
    walletId,
    customerId,
    status: wallet?.status,
    creditsBalance: wallet?.creditsBalance,
    rateAmount: wallet?.rateAmount,
    currency: wallet?.currency,
  })

  const createdAtTitle = translate('text_62da6ec24a8e24e44f8128b2', {
    createdAt: intlFormatDateTimeOrgaTZ(wallet?.createdAt).date,
  })

  // The MainHeader config snapshot strips the tabs' `content` ReactNode, so a balance
  // change alone would not re-push the config and the header would keep stale values.
  // Bumping this key on balance changes forces the fresh content through (credits fields
  // are derived from their *Cents counterparts, so the cents alone are enough).
  const walletSnapshotKey = [
    wallet?.balanceCents,
    wallet?.ongoingBalanceCents,
    wallet?.ongoingUsageBalanceCents,
    wallet?.consumedAmountCents,
    wallet?.status,
  ].join('|')

  const tabs = useMemo(() => {
    return [
      {
        title: translate('text_1772536695408epr1ktf2hy9'),
        link: generatePath(WALLET_DETAILS_ROUTE, {
          walletId: walletId as string,
          customerId: customerId as string,
          tab: WalletDetailsTabsOptionsEnum.overview,
        }),
        content: (
          <DetailsPage.Container className="mt-12">
            <SectionTitle
              title={translate('text_1772536695408epr1ktf2hy9')}
              description={translate('text_177304332434241ihblh0jyp')}
              action={
                <>
                  {hasPermissions(['walletsUpdate']) && (
                    <ButtonLink
                      buttonProps={{
                        variant: 'quaternary',
                      }}
                      type="button"
                      to={generatePath(EDIT_WALLET_ROUTE, {
                        walletId: walletId as string,
                        customerId: customerId ?? null,
                      })}
                      data-test="edit-wallet"
                    >
                      {translate('text_62e161ceb87c201025388aa2')}
                    </ButtonLink>
                  )}
                </>
              }
            />

            <WalletInformations wallet={wallet} />
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_1772536695408zfepv8jb948'),
        link: generatePath(WALLET_DETAILS_ROUTE, {
          walletId: walletId as string,
          customerId: customerId as string,
          tab: WalletDetailsTabsOptionsEnum.transactions,
        }),
        content: (
          <DetailsPage.Container className="mt-12 max-w-full gap-12">
            <SectionTitle
              title={translate('text_1772536695408zfepv8jb948')}
              description={translate('text_1773043324342ka1zcxto0pg')}
            />

            {!!wallet && <WalletTransactions wallet={wallet} loading={loading} />}
          </DetailsPage.Container>
        ),
      },
      {
        title: translate('text_177253669540873hdqaoks8e'),
        link: generatePath(WALLET_DETAILS_ROUTE, {
          walletId: walletId as string,
          customerId: customerId as string,
          tab: WalletDetailsTabsOptionsEnum.alerts,
        }),
        content: (
          <DetailsPage.Container className="mt-12 gap-8">
            <SectionTitle
              title={translate('text_177253669540873hdqaoks8e')}
              description={translate('text_1773043324342mrttreav4qk')}
              action={
                <>
                  {hasPermissions(['walletsUpdate']) && (
                    <ButtonLink
                      buttonProps={{
                        variant: 'quaternary',
                      }}
                      type="button"
                      to={generatePath(CREATE_ALERT_WALLET_ROUTE, {
                        walletId: walletId as string,
                        customerId: customerId ?? null,
                      })}
                      data-test="create-wallet-alert"
                    >
                      {translate('text_1773051593208ih6ikwtebg0')}
                    </ButtonLink>
                  )}
                </>
              }
            />

            {!!wallet && <WalletAlerts wallet={wallet} />}
          </DetailsPage.Container>
        ),
      },
    ]
  }, [translate, walletId, customerId, wallet, loading, hasPermissions])

  const headerActions: MainHeaderAction[] = [
    {
      type: 'dropdown',
      label: translate('text_634687079be251fdb438338f'),
      items: walletActionItems.map((action) => ({
        label: action.label,
        startIcon: action.startIcon,
        hidden: action.hidden,
        disabled: action.disabled,
        danger: action.danger,
        dataTest: action.dataTest,
        onClick: action.onAction,
      })),
    },
  ]

  if (!loading && !!error) {
    return (
      <GenericPlaceholder
        title={translate('text_62e0ee200a543924c8f6775e')}
        subtitle={translate('text_62e0ee200a543924c8f67760')}
        image={<ErrorImage width="136" height="104" />}
      />
    )
  }

  return (
    <>
      <MainHeader.Configure
        breadcrumb={[
          {
            label: translate('text_624efab67eb2570101d117a5'),
            path: CUSTOMERS_LIST_ROUTE,
          },
          {
            label: customerName,
            path: generatePath(CUSTOMER_DETAILS_TAB_ROUTE, {
              customerId: customerId as string,
              tab: CustomerDetailsTabsOptions.wallet,
            }),
            loading,
          },
        ]}
        entity={{
          viewName: wallet?.name || createdAtTitle || '-',
          viewNameLoading: loading,
          metadata: wallet?.id || '',
          metadataLoading: loading,
        }}
        actions={{ items: headerActions, loading }}
        tabs={tabs}
        snapshotKey={walletSnapshotKey}
      />

      <>{activeTabContent}</>

      <VoidWalletDialog ref={voidDialogRef} />
    </>
  )
}

export default WalletDetails
