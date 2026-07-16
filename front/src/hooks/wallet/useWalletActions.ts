import { IconName } from 'lago-design-system'
import { useRef } from 'react'
import { generatePath } from 'react-router-dom'

import { buildLinkToActivityLog } from '~/components/activityLogs/utils'
import { AvailableFiltersEnum } from '~/components/designSystem/Filters'
import { useTerminateCustomerWalletDialog } from '~/components/wallets/TerminateCustomerWalletDialog'
import { VoidWalletDialogRef } from '~/components/wallets/VoidWalletDialog'
import { addToast } from '~/core/apolloClient'
import {
  CREATE_WALLET_TOP_UP_ROUTE,
  EDIT_WALLET_ROUTE,
  useNavigate,
  WALLET_DETAILS_ROUTE,
} from '~/core/router'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { CurrencyEnum, WalletStatusEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { useDeveloperTool } from '~/hooks/useDeveloperTool'
import { usePermissions } from '~/hooks/usePermissions'
import { WalletDetailsTabsOptionsEnum } from '~/pages/wallet/WalletDetails'

export interface WalletActionItem {
  label: string
  startIcon: IconName
  onAction: (closePopper: () => void) => void
  hidden?: boolean
  disabled?: boolean
  danger?: boolean
  dataTest?: string
}

interface UseWalletActionsParams {
  walletId?: string
  customerId?: string
  status?: WalletStatusEnum
  creditsBalance?: number
  rateAmount?: number
  currency?: CurrencyEnum
}

interface UseWalletActionsReturn {
  actions: WalletActionItem[]
  voidDialogRef: React.RefObject<VoidWalletDialogRef>
}

export const useWalletActions = ({
  walletId,
  customerId,
  status,
  creditsBalance,
  rateAmount,
  currency,
}: UseWalletActionsParams): UseWalletActionsReturn => {
  const navigate = useNavigate()
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const { isPremium } = useCurrentUser()
  const { setUrl, openPanel: open } = useDeveloperTool()
  const { openTerminateCustomerWalletDialog } = useTerminateCustomerWalletDialog()
  const voidDialogRef = useRef<VoidWalletDialogRef>(null) as React.RefObject<VoidWalletDialogRef>

  const isWalletActive = status === WalletStatusEnum.Active

  const actions: WalletActionItem[] = [
    {
      label: translate('text_1741253143637fb7iatyka9w'),
      startIcon: 'plus',
      hidden: !isWalletActive,
      dataTest: 'wallet-topup-button',
      onAction: (closePopper) => {
        navigate(
          generatePath(CREATE_WALLET_TOP_UP_ROUTE, {
            walletId: walletId as string,
            customerId: customerId ?? null,
          }),
        )
        closePopper()
      },
    },
    {
      label: translate('text_1741253143637fwbbxxn9195'),
      startIcon: 'duplicate',
      hidden: !isWalletActive,
      onAction: (closePopper) => {
        copyToClipboard(walletId || '')
        addToast({
          severity: 'info',
          translateKey: 'text_1741253143637w2e9cbec620',
        })
        closePopper()
      },
    },
    {
      label: translate('text_62e161ceb87c201025388aa2'),
      startIcon: 'pen',
      hidden: !isWalletActive || !hasPermissions(['walletsUpdate']),
      onAction: (closePopper) => {
        navigate(
          generatePath(EDIT_WALLET_ROUTE, {
            walletId: walletId as string,
            customerId: customerId ?? null,
          }),
        )
        closePopper()
      },
    },
    {
      label: translate('text_63720bd734e1344aea75b7e9'),
      startIcon: 'minus',
      hidden: !isWalletActive || !hasPermissions(['walletsTerminate']),
      disabled: !!(creditsBalance && creditsBalance <= 0),
      onAction: (closePopper) => {
        voidDialogRef.current?.openDialog({
          walletId: walletId as string,
          rateAmount,
          creditsBalance,
          currency,
        })
        closePopper()
      },
    },
    {
      label: translate('text_1772536695408i54gtdrmatk'),
      startIcon: 'bell',
      hidden: !isWalletActive,
      onAction: (closePopper) => {
        navigate(
          generatePath(WALLET_DETAILS_ROUTE, {
            walletId: walletId as string,
            customerId: customerId as string,
            tab: WalletDetailsTabsOptionsEnum.alerts,
          }),
        )
        closePopper()
      },
    },
    {
      label: translate('text_17494778224951pa9u6uvz3t'),
      startIcon: 'pulse',
      hidden: !isWalletActive || !isPremium || !hasPermissions(['auditLogsView']),
      onAction: (closePopper) => {
        const url = buildLinkToActivityLog(walletId as string, AvailableFiltersEnum.resourceIds)

        setUrl(url)
        open()
        closePopper()
      },
    },
    {
      label: translate('text_62d9430e8b9fe36851cddd17'),
      startIcon: 'trash',
      hidden: !isWalletActive || !hasPermissions(['walletsTerminate']),
      danger: true,
      onAction: (closePopper) => {
        openTerminateCustomerWalletDialog({
          walletId: walletId as string,
        })
        closePopper()
      },
    },
  ]

  return { actions, voidDialogRef }
}
