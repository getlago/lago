import { gql } from '@apollo/client'

import { useCustomerPortalData } from '~/components/customerPortal/common/hooks/useCustomerPortalData'
import SectionError from '~/components/customerPortal/common/SectionError'
import { LoaderWalletSection } from '~/components/customerPortal/common/SectionLoading'
import SectionTitle from '~/components/customerPortal/common/SectionTitle'
import useCustomerPortalTranslate from '~/components/customerPortal/common/useCustomerPortalTranslate'
import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { intlFormatDateTime } from '~/core/timezone/utils'
import {
  CustomerPortalWalletInfoFragment,
  useGetPortalWalletsQuery,
  WalletStatusEnum,
} from '~/generated/graphql'

export const WALLET_SECTION_ERROR_TEST_ID = 'wallet-section-error'
export const WALLET_SECTION_CONTENT_TEST_ID = 'wallet-section-content'
export const WALLET_SECTION_WALLET_ITEM_TEST_ID = 'wallet-section-wallet-item'
export const WALLET_SECTION_VIEW_BUTTON_TEST_ID = 'wallet-section-view-button'
export const WALLET_SECTION_LOAD_MORE_TEST_ID = 'wallet-section-load-more'

gql`
  fragment CustomerPortalWalletInfo on CustomerPortalWallet {
    id
    name
    currency
    balanceCents
    creditsBalance
    expirationAt
    consumedCredits
    consumedAmountCents
    status
    creditsOngoingBalance
    ongoingBalanceCents
    rateAmount
    lastBalanceSyncAt
    paidTopUpMinAmountCents
    paidTopUpMaxAmountCents
  }

  query getPortalWallets($limit: Int, $page: Int, $status: WalletStatusEnum) {
    customerPortalWallets(limit: $limit, page: $page, status: $status) {
      collection {
        ...CustomerPortalWalletInfo
      }
      metadata {
        currentPage
        totalPages
      }
    }
  }
`

type WalletSectionProps = {
  viewWallet: (walletId: string) => void
}

export const parseWalletBalance = (
  wallet: CustomerPortalWalletInfoFragment,
  isPremium: boolean,
) => {
  const [creditAmountUnit = '0', creditAmountCents = '00'] = String(wallet?.creditsBalance).split(
    '.',
  )
  const [consumedCreditUnit = '0', consumedCreditCents = '00'] = String(
    wallet?.creditsOngoingBalance,
  ).split('.')

  const [unit, cents, balance] = isPremium
    ? [consumedCreditUnit, consumedCreditCents, wallet?.ongoingBalanceCents]
    : [creditAmountUnit, creditAmountCents, wallet?.balanceCents]

  return { unit, cents, balance }
}

const WalletSection = ({ viewWallet }: WalletSectionProps) => {
  const { translate, documentLocale } = useCustomerPortalTranslate()

  const {
    data: customerPortalData,
    loading: customerPortalUserLoading,
    error: customerPortalUserError,
    refetch: customerPortalUserRefetch,
  } = useCustomerPortalData()

  const customerPortalUser = customerPortalData?.customerPortalUser
  const customerTimezone = customerPortalUser?.applicableTimezone
  const isPremium = !!customerPortalUser?.premium

  const {
    data: customerWalletData,
    loading: customerWalletLoading,
    error: customerWalletError,
    refetch: customerWalletRefetch,
    fetchMore,
  } = useGetPortalWalletsQuery({
    variables: {
      limit: 3,
      status: WalletStatusEnum.Active,
    },
  })

  const wallets = customerWalletData?.customerPortalWallets?.collection
  const { currentPage = 0, totalPages = 0 } =
    customerWalletData?.customerPortalWallets?.metadata || {}
  const isLoading = customerWalletLoading || customerPortalUserLoading
  const isError = !isLoading && (customerWalletError || customerPortalUserError)

  const refreshSection = () => {
    customerPortalUserError && customerPortalUserRefetch()
    customerWalletError && customerWalletRefetch()
  }

  if (isError) {
    return (
      <section data-test={WALLET_SECTION_ERROR_TEST_ID}>
        <SectionTitle title={translate('text_1728377307159q3otzyv9tey')} />

        <SectionError refresh={refreshSection} />
      </section>
    )
  }

  if (!isLoading && !wallets?.length) {
    return null
  }

  return (
    <div data-test={WALLET_SECTION_CONTENT_TEST_ID}>
      <SectionTitle
        title={translate('text_1728377307159q3otzyv9tey')}
        className="justify-between"
        loading={customerPortalUserLoading}
      />

      {isLoading && !wallets?.length && <LoaderWalletSection />}

      {!!wallets?.length &&
        wallets.map((wallet, index) => {
          const { unit, cents, balance } = parseWalletBalance(wallet, isPremium)

          return (
            <div
              className="mt-6 flex flex-col gap-1 pb-4 shadow-b"
              key={`customer-portal-wallet-${index}`}
              data-test={WALLET_SECTION_WALLET_ITEM_TEST_ID}
            >
              <div className="flex items-center justify-between gap-6">
                <Typography variant="captionHl" color="grey600">
                  {!!wallet?.name && `${wallet?.name} - `}
                  {translate('text_1728377307160cbszddumfkg')}
                </Typography>

                <Button
                  variant="inline"
                  size="medium"
                  data-test={WALLET_SECTION_VIEW_BUTTON_TEST_ID}
                  onClick={() => viewWallet(wallet.id)}
                >
                  {translate('text_1728377307160cludx1c0cfb')}
                </Button>
              </div>

              <div className="flex items-center justify-between gap-8 [&>*]:flex-1">
                <div className="flex flex-col gap-1">
                  <div className="flex gap-1">
                    <Typography variant="body" color="grey700">
                      {unit}.{cents}
                    </Typography>

                    <Typography variant="body" color="grey700">
                      {translate('text_62da6ec24a8e24e44f81287a', undefined, Number(unit) || 0)}
                    </Typography>
                  </div>

                  <Typography variant="caption" color="grey600">
                    {intlFormatNumber(deserializeAmount(balance, wallet.currency), {
                      currencyDisplay: 'narrowSymbol',
                      currency: wallet.currency,
                      locale: documentLocale,
                    })}
                  </Typography>
                </div>

                <div className="flex flex-col gap-1">
                  <Typography variant="caption" color="grey600">
                    {translate('text_1728377307160sh06zbhqebt')}
                  </Typography>

                  <div className="flex items-center">
                    <Typography variant="body" color="grey700">
                      {wallet?.consumedCredits}&nbsp;
                      {translate(
                        'text_62da6ec24a8e24e44f812884',
                        undefined,
                        Number(wallet?.consumedCredits) || 0,
                      )}
                      &nbsp;(
                      {intlFormatNumber(
                        deserializeAmount(wallet?.consumedAmountCents, wallet.currency),
                        {
                          currencyDisplay: 'narrowSymbol',
                          currency: wallet.currency,
                          locale: documentLocale,
                        },
                      )}
                      )
                    </Typography>
                  </div>
                </div>

                <div className="flex flex-col gap-1">
                  <Typography variant="caption" color="grey600">
                    {translate('text_1728377307160dqj0b2q59f6')}
                  </Typography>

                  <Typography variant="body" color="grey700">
                    {!!wallet?.expirationAt &&
                      intlFormatDateTime(wallet?.expirationAt, {
                        timezone: customerTimezone,
                        locale: documentLocale,
                      }).date}
                    {!wallet?.expirationAt && translate('text_62da6ec24a8e24e44f81288c')}
                  </Typography>
                </div>
              </div>
            </div>
          )
        })}

      {currentPage < totalPages && (
        <Button
          className="mt-2"
          variant="inline"
          size="medium"
          startIcon="chevron-down"
          data-test={WALLET_SECTION_LOAD_MORE_TEST_ID}
          onClick={() =>
            fetchMore({
              variables: { page: currentPage + 1 },
            })
          }
        >
          {translate('text_62da6ec24a8e24e44f8128aa')}
        </Button>
      )}
    </div>
  )
}

export default WalletSection
