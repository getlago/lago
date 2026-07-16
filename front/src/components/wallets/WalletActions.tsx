import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { WALLET_ACTIONS_DATA_TEST } from '~/components/wallets/utils/dataTestConstants'
import { VoidWalletDialog } from '~/components/wallets/VoidWalletDialog'
import { CurrencyEnum, WalletStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useWalletActions } from '~/hooks/wallet/useWalletActions'
import { MenuPopper } from '~/styles/designSystem/PopperComponents'

type WalletActionsProps = {
  walletId?: string
  customerId?: string
  status?: WalletStatusEnum
  creditsBalance?: number
  trigger?: (onClick: React.MouseEventHandler) => React.ReactNode
  showActionsTooltip?: boolean
  currency?: CurrencyEnum
  rateAmount?: number
}

const WalletActions = ({
  walletId,
  customerId,
  status,
  creditsBalance,
  trigger,
  showActionsTooltip,
  rateAmount,
  currency,
}: WalletActionsProps) => {
  const { translate } = useInternationalization()
  const { actions, voidDialogRef } = useWalletActions({
    walletId,
    customerId,
    status,
    creditsBalance,
    rateAmount,
    currency,
  })

  const isWalletActive = status === WalletStatusEnum.Active

  if (!walletId || !customerId) {
    return null
  }

  return (
    <div className="pr-1">
      {isWalletActive && (
        <Popper
          PopperProps={{ placement: 'bottom-end' }}
          opener={({ onClick }) => (
            <Tooltip
              placement="top-start"
              title={translate('text_1741251836185jea576d14uj')}
              disableHoverListener={!showActionsTooltip}
            >
              {trigger?.((e) => {
                e.stopPropagation()
                onClick()
              }) || (
                <Button
                  variant="quaternary"
                  icon="dots-horizontal"
                  onClick={(e) => {
                    e.stopPropagation()
                    onClick()
                  }}
                  data-test={WALLET_ACTIONS_DATA_TEST}
                />
              )}
            </Tooltip>
          )}
        >
          {({ closePopper }) => (
            <MenuPopper>
              {actions
                .filter((action) => !action.hidden)
                .map((action) => (
                  <Button
                    key={action.label}
                    startIcon={action.startIcon}
                    variant="quaternary"
                    align="left"
                    fullWidth
                    disabled={action.disabled}
                    danger={action.danger}
                    data-test={action.dataTest}
                    onClick={(e) => {
                      e.stopPropagation()
                      action.onAction(closePopper)
                    }}
                  >
                    {action.label}
                  </Button>
                ))}
            </MenuPopper>
          )}
        </Popper>
      )}

      <VoidWalletDialog ref={voidDialogRef} />
    </div>
  )
}

export default WalletActions
