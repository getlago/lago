import { gql } from '@apollo/client'
import { generatePath, useParams } from 'react-router-dom'

import { Accordion } from '~/components/designSystem/Accordion'
import { Button } from '~/components/designSystem/Button'
import { GenericPlaceholder } from '~/components/designSystem/GenericPlaceholder'
import { Popper } from '~/components/designSystem/Popper'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { ChargeTable } from '~/components/designSystem/Table'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { DetailsPage } from '~/components/layouts/DetailsPage'
import PremiumFeature from '~/components/premium/PremiumFeature'
import { useDeleteWalletAlertDialog } from '~/components/wallets/DeleteWalletAlertDialog'
import { formatAmount, formatCredits } from '~/components/wallets/utils'
import { UPDATE_ALERT_WALLET_ROUTE, useNavigate } from '~/core/router'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  Alert,
  AlertTypeEnum,
  CurrencyEnum,
  useGetWalletAlertsQuery,
  WalletDetailsFragment,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'
import { usePermissions } from '~/hooks/usePermissions'
import ErrorImage from '~/public/images/maneki/error.svg'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

gql`
  query getWalletAlerts($walletId: String!) {
    walletAlerts(walletId: $walletId) {
      collection {
        id
        alertType
        walletId
        code
        name
        thresholds {
          code
          recurring
          value
        }
      }
    }
  }
`

type WalletAlertsProps = {
  wallet: WalletDetailsFragment
}

const WALLET_ALERT_ACTIONS_DATA_TEST = 'wallet-alert-actions-data-test'

export const WALLET_ALERTS_LOADING_TEST_ID = 'wallet-alerts-loading'
export const WALLET_ALERTS_EMPTY_TEST_ID = 'wallet-alerts-empty'
export const WALLET_ALERTS_LIST_TEST_ID = 'wallet-alerts-list'

const WALLET_ALERT_TYPE_TRANSLATION_MAP: Record<string, string> = {
  [AlertTypeEnum.WalletBalanceAmount]: 'text_17730515932099j2rzezwwf0',
  [AlertTypeEnum.WalletCreditsBalance]: 'text_1773051593209b2tulsrwgoq',
  [AlertTypeEnum.WalletOngoingBalanceAmount]: 'text_1773051593209gg3667wtxse',
  [AlertTypeEnum.WalletCreditsOngoingBalance]: 'text_1773051593209u4yacfcm339',
}
const WALLET_ALERT_CHARGE_TABLE_TITLE: Record<string, string> = {
  [AlertTypeEnum.WalletBalanceAmount]: 'text_1773051593209e5voclo66w7',
  [AlertTypeEnum.WalletCreditsBalance]: 'text_1773051593209e5voclo66w7',
  [AlertTypeEnum.WalletOngoingBalanceAmount]: 'text_17730515932098df701xv9ai',
  [AlertTypeEnum.WalletCreditsOngoingBalance]: 'text_17730515932098df701xv9ai',
}

const WalletAlerts = ({ wallet }: WalletAlertsProps) => {
  const { translate } = useInternationalization()
  const { organization: { defaultCurrency } = {} } = useOrganizationInfos()
  const { isPremium } = useCurrentUser()
  const { hasPermissions } = usePermissions()
  const { customerId } = useParams()
  const navigate = useNavigate()
  const { openDeleteWalletAlertDialog } = useDeleteWalletAlertDialog()

  const { data, error, loading } = useGetWalletAlertsQuery({
    variables: {
      walletId: wallet?.id as string,
    },
    skip: !wallet?.id,
  })

  const alerts = data?.walletAlerts?.collection

  const currency = wallet?.currency || defaultCurrency || CurrencyEnum.Usd

  const formatAlertThresholdValue = ({
    value,
    currentAlert,
  }: {
    value: string
    currentAlert: Pick<Alert, 'alertType'>
  }) => {
    const isCredits = [
      AlertTypeEnum.WalletCreditsBalance,
      AlertTypeEnum.WalletCreditsOngoingBalance,
    ].includes(currentAlert.alertType)

    if (isCredits) {
      const formatted = formatCredits({ credits: value })

      return translate(
        'text_62da6ec24a8e24e44f812896',
        {
          amount: formatted,
        },
        Number(formatted) || 0,
      )
    }

    return formatAmount({
      amountCents: deserializeAmount(value, currency || CurrencyEnum.Usd)?.toString(),
      currency,
    })
  }

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

  return (
    <div>
      {!isPremium && (
        <PremiumFeature
          title={translate('text_1773043324342l1bo3jcx5ps')}
          description={translate('text_1773043324342ri2pz74hrea')}
          feature={translate('text_1773051593208etigz7rxlhp')}
        />
      )}

      {isPremium && loading && (
        <div data-test={WALLET_ALERTS_LOADING_TEST_ID}>
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={`key-skeleton-line-${i}`} className="mt-7 flex">
              <Skeleton variant="text" className="mr-[6.4%]" />
              <Skeleton variant="text" className="mr-[11.2%]" />
              <Skeleton variant="text" className="mr-[6.4%]" />
              <Skeleton variant="text" className="mr-[9.25%]" />
            </div>
          ))}
        </div>
      )}

      {isPremium && !loading && !alerts?.length && (
        <Typography data-test={WALLET_ALERTS_EMPTY_TEST_ID} variant="body">
          {translate('text_1773051593208hl4ku8oq9rf')}
        </Typography>
      )}

      {isPremium && !loading && !!alerts?.length && (
        <div data-test={WALLET_ALERTS_LIST_TEST_ID} className="flex flex-col gap-4">
          {alerts.map((currentAlert) => (
            <Accordion
              key={`wallet-alerts-${currentAlert.id}`}
              transitionProps={{ unmountOnExit: false }}
              summary={
                <div className="flex flex-1 items-center justify-between gap-3">
                  <div className="flex flex-col">
                    <Typography variant="bodyHl" color="grey700">
                      {currentAlert?.name}
                    </Typography>

                    <Typography variant="caption" color="grey600">
                      {currentAlert?.code}
                    </Typography>
                  </div>

                  <div className="flex flex-row items-center gap-3">
                    <Popper
                      PopperProps={{ placement: 'bottom-end' }}
                      opener={({ onClick }) => (
                        <Tooltip
                          placement="top-start"
                          title={translate('text_1741251836185jea576d14uj')}
                        >
                          <Button
                            variant="quaternary"
                            icon="dots-horizontal"
                            onClick={(e) => {
                              e.stopPropagation()
                              onClick()
                            }}
                            data-test={WALLET_ALERT_ACTIONS_DATA_TEST}
                          />
                        </Tooltip>
                      )}
                    >
                      {({ closePopper }) => (
                        <MenuPopper>
                          {hasPermissions(['walletsUpdate']) && (
                            <>
                              <Button
                                startIcon="pen"
                                variant="quaternary"
                                align="left"
                                fullWidth
                                onClick={(e) => {
                                  e.stopPropagation()
                                  navigate(
                                    generatePath(UPDATE_ALERT_WALLET_ROUTE, {
                                      walletId: wallet.id,
                                      customerId: customerId ?? null,
                                      alertId: currentAlert.id,
                                    }),
                                  )
                                  closePopper()
                                }}
                              >
                                {translate('text_1773051593208w1akrget7fg')}
                              </Button>

                              <Button
                                startIcon="trash"
                                variant="quaternary"
                                align="left"
                                fullWidth
                                onClick={(e) => {
                                  e.stopPropagation()

                                  openDeleteWalletAlertDialog({
                                    alertId: currentAlert.id,
                                  })

                                  closePopper()
                                }}
                              >
                                {translate('text_1773051593208bjs37e577ir')}
                              </Button>
                            </>
                          )}
                        </MenuPopper>
                      )}
                    </Popper>
                  </div>
                </div>
              }
            >
              {() => (
                <div className="flex flex-col gap-4">
                  <DetailsPage.InfoGrid
                    grid={[
                      {
                        label: translate('text_1773051593208t1k4f2qw7z9'),
                        value: currentAlert?.name,
                      },
                      {
                        label: translate('text_1773051593209lul0ssht3rk'),
                        value: currentAlert?.code,
                      },
                      {
                        label: translate('text_1773051593209zqnmllcrxk9'),
                        value: translate(
                          WALLET_ALERT_TYPE_TRANSLATION_MAP[currentAlert?.alertType],
                        ),
                      },
                    ]}
                  />

                  <ChargeTable
                    className="w-full"
                    name="wallet-alerts-table"
                    data={
                      currentAlert?.thresholds?.filter((threshold) => !threshold.recurring) || []
                    }
                    headerCellClassName="rounded-xl bg-grey-100"
                    columns={[
                      {
                        size: 228,
                        content: (_, i) => (
                          <Typography className="px-4 py-2.5" variant="body" color="grey700">
                            {translate(
                              i === 0
                                ? WALLET_ALERT_CHARGE_TABLE_TITLE[currentAlert?.alertType]
                                : 'text_1724179887723917j8ezkd9v',
                            )}
                          </Typography>
                        ),
                      },
                      {
                        size: 158,
                        title: (
                          <Typography className="px-4 py-2.5" variant="captionHl" color="grey600">
                            {translate('text_1724179887723eh12a0kqbdw')}
                          </Typography>
                        ),
                        content: (row) => (
                          <Typography className="px-4 py-2.5" variant="body" color="grey700">
                            {formatAlertThresholdValue({
                              value: row.value,
                              currentAlert,
                            })}
                          </Typography>
                        ),
                      },
                      {
                        size: 158,
                        title: (
                          <Typography className="px-4 py-2.5" variant="captionHl" color="grey600">
                            {translate('text_17241798877234jhvoho4ci9')}
                          </Typography>
                        ),
                        content: (row) => (
                          <Typography className="px-4 py-2.5" variant="body" color="grey700">
                            {row.code}
                          </Typography>
                        ),
                      },
                    ]}
                  />

                  <ChargeTable
                    className="w-full rounded-xl"
                    name="wallet-alerts-recurring-table"
                    data={
                      currentAlert?.thresholds?.filter((threshold) => threshold.recurring) || []
                    }
                    columns={[
                      {
                        size: 228,
                        content: () => (
                          <Typography className="px-4 py-2.5" variant="body" color="grey700">
                            {translate('text_17241798877230y851fdxzqu')}
                          </Typography>
                        ),
                      },
                      {
                        size: 158,
                        content: (row) => (
                          <Typography className="px-4 py-2.5" variant="body" color="grey700">
                            {formatAlertThresholdValue({
                              value: row.value,
                              currentAlert,
                            })}
                          </Typography>
                        ),
                      },
                      {
                        size: 158,
                        content: (row) => (
                          <Typography className="px-4 py-2.5" variant="body" color="grey700">
                            {row.code}
                          </Typography>
                        ),
                      },
                    ]}
                  />
                </div>
              )}
            </Accordion>
          ))}
        </div>
      )}
    </div>
  )
}

export default WalletAlerts
