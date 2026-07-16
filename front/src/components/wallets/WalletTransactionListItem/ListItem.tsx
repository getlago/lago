import { Icon, IconName } from 'lago-design-system'
import { FC } from 'react'

import { Avatar, AvatarBadge } from '~/components/designSystem/Avatar'
import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography, TypographyColor } from '~/components/designSystem/Typography'
import {
  TRANSACTION_AMOUNT_DATA_TEST,
  TRANSACTION_CREDITS_DATA_TEST,
  TRANSACTION_LABEL_DATA_TEST,
  TRANSACTION_PRIORITY_DATA_TEST,
  TRANSACTION_REMAINING_CREDITS_DATA_TEST,
} from '~/components/wallets/utils/dataTestConstants'
import { addToast } from '~/core/apolloClient'
import { intlFormatDateTime } from '~/core/timezone'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import {
  TimezoneEnum,
  WalletTransactionStatusEnum,
  WalletTransactionTransactionTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { MenuPopper } from '~/styles'
import { tw } from '~/styles/utils'

const concatInfosTextForDisplay = ({
  name,
  date,
  timezone,
}: {
  name: string | null | undefined
  date: string | null | undefined
  timezone: TimezoneEnum | undefined
}) => {
  const formattedDate = date ? intlFormatDateTime(date, { timezone }).date : ''

  return [formattedDate, name].filter(Boolean).join(' • ')
}

interface ListItemProps {
  amount: string
  credits: string
  creditsColor: TypographyColor
  priority?: number
  remainingAmountCents: string
  remainingCreditAmount: string
  transactionType: WalletTransactionTransactionTypeEnum
  isRealTimeTransaction?: boolean
  date?: string
  hasAction?: boolean
  iconName: IconName
  isBlurry?: boolean
  label: string
  labelColor: TypographyColor
  name?: string | null
  status?: WalletTransactionStatusEnum
  timezone?: TimezoneEnum
  transactionId: string
  onClick?: () => void
  rowClassName?: string
}
export const ListItem: FC<ListItemProps> = ({
  amount,
  credits,
  creditsColor,
  priority,
  remainingAmountCents,
  remainingCreditAmount,
  transactionType,
  isRealTimeTransaction,
  date,
  hasAction,
  iconName,
  isBlurry,
  label,
  labelColor,
  name,
  status,
  timezone,
  transactionId,
  onClick,
  rowClassName,
  ...props
}) => {
  const { translate } = useInternationalization()

  const isClickable = !!onClick
  const isPending = status === WalletTransactionStatusEnum.Pending
  const isFailed = status === WalletTransactionStatusEnum.Failed
  const displayText = concatInfosTextForDisplay({ name, date, timezone })

  const isInbound = transactionType === WalletTransactionTransactionTypeEnum.Inbound

  return (
    <li className={tw('relative shadow-b', isClickable && 'hover:bg-grey-100')}>
      <div
        role={isClickable ? 'button' : undefined}
        tabIndex={isClickable ? 0 : undefined}
        onClick={onClick}
        onKeyDown={(e) => {
          if (e.key === 'Enter' && onClick) {
            onClick()
          }
        }}
        className={tw(
          'grid grid-cols-4 items-center justify-between gap-2 px-4 py-3',
          isClickable && 'focus-visible:bg-grey-200 focus-visible:ring focus-visible:ring-inset',
          rowClassName,
        )}
        {...props}
      >
        <div className="col-span-3 flex min-w-0 flex-1 items-center">
          <Avatar className="mr-3" size="big" variant="connector">
            <Icon name={iconName} color="dark" />
            {isPending && <AvatarBadge icon="sync" color="dark" />}
            {isFailed && <AvatarBadge icon="stop" color="warning" />}
          </Avatar>
          <div className="flex flex-col overflow-hidden">
            <Typography
              noWrap
              variant="bodyHl"
              color={isPending || isFailed ? 'grey500' : labelColor}
              data-test={TRANSACTION_LABEL_DATA_TEST}
            >
              {label}
            </Typography>
            {!!displayText && (
              <Typography noWrap variant="caption" color="grey600">
                {displayText}
              </Typography>
            )}
          </div>
        </div>

        {isRealTimeTransaction && (
          <div className="grid h-full grid-cols-7">
            <div className="col-start-5 col-end-8 flex items-center justify-end">
              <div className="flex flex-col items-end">
                <Typography
                  variant="bodyHl"
                  color={isPending || isFailed ? 'grey500' : creditsColor}
                  blur={isBlurry}
                  data-test={TRANSACTION_CREDITS_DATA_TEST}
                  className={tw(isFailed && 'line-through')}
                >
                  {credits}
                </Typography>
                <Typography
                  variant="caption"
                  color="grey600"
                  blur={isBlurry}
                  data-test={TRANSACTION_AMOUNT_DATA_TEST}
                >
                  {amount}
                </Typography>
              </div>
            </div>
          </div>
        )}

        {!isRealTimeTransaction && (
          <div className="grid grid-cols-7">
            <div className="col-span-2 flex flex-row justify-end">
              <Typography
                variant="body"
                color="grey600"
                blur={isBlurry}
                data-test={TRANSACTION_PRIORITY_DATA_TEST}
              >
                {!isInbound ? '-' : priority}
              </Typography>
            </div>

            <div className="col-span-2 flex flex-row items-center justify-end">
              <div className="flex flex-col items-end">
                <Typography
                  variant="bodyHl"
                  color={isPending || isFailed ? 'grey500' : creditsColor}
                  blur={isBlurry}
                  data-test={TRANSACTION_CREDITS_DATA_TEST}
                  className={tw(isFailed && 'line-through')}
                >
                  {credits}
                </Typography>
                <Typography
                  variant="caption"
                  color="grey600"
                  blur={isBlurry}
                  data-test={TRANSACTION_AMOUNT_DATA_TEST}
                >
                  {amount}
                </Typography>
              </div>
            </div>

            <div className="col-span-2 flex flex-row items-center justify-end">
              <div className="flex flex-col items-end">
                <Typography
                  variant="bodyHl"
                  color={isPending || isFailed ? 'grey500' : 'grey700'}
                  blur={isBlurry}
                  data-test={TRANSACTION_REMAINING_CREDITS_DATA_TEST}
                >
                  {!isInbound
                    ? '-'
                    : translate(
                        'text_62da6ec24a8e24e44f812896',
                        {
                          amount: remainingCreditAmount,
                        },
                        Number(remainingCreditAmount) || 0,
                      )}
                </Typography>
                <Typography
                  variant="caption"
                  color="grey600"
                  blur={isBlurry}
                  data-test={TRANSACTION_AMOUNT_DATA_TEST}
                >
                  {!isInbound ? '-' : remainingAmountCents}
                </Typography>
              </div>
            </div>

            {hasAction && (
              <Popper
                PopperProps={{ placement: 'bottom-end' }}
                opener={(opener) => (
                  <div className="flex h-full items-center justify-end">
                    <Tooltip
                      placement="top-start"
                      disableHoverListener={opener.isOpen}
                      title={translate('text_1741251836185jea576d14uj')}
                    >
                      <Button
                        size="medium"
                        variant="quaternary"
                        icon="dots-horizontal"
                        onClick={(e) => {
                          e.preventDefault()
                          e.stopPropagation()
                          opener.onClick()
                        }}
                      />
                    </Tooltip>
                  </div>
                )}
              >
                {({ closePopper }) => (
                  <MenuPopper>
                    {!!onClick && (
                      <Button
                        startIcon="eye"
                        variant="quaternary"
                        align="left"
                        fullWidth
                        onClick={(e) => {
                          e.preventDefault()
                          e.stopPropagation()
                          onClick()
                          closePopper()
                        }}
                      >
                        {translate('text_1742218191558g0ysnnxbb32')}
                      </Button>
                    )}
                    <Button
                      startIcon="duplicate"
                      variant="quaternary"
                      align="left"
                      fullWidth
                      onClick={(e) => {
                        e.stopPropagation()
                        copyToClipboard(transactionId)
                        addToast({
                          severity: 'info',
                          translateKey: 'text_17412580835361rm20fysfba',
                        })
                        closePopper()
                      }}
                    >
                      {translate('text_1741258064758s59ws4fg2l9')}
                    </Button>
                  </MenuPopper>
                )}
              </Popper>
            )}
          </div>
        )}
      </div>
    </li>
  )
}
