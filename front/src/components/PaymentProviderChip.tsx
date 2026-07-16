import type { TypographyProps as MuiTypographyProps } from '@mui/material/Typography'
import { Icon } from 'lago-design-system'
import { FC } from 'react'

import { Avatar } from '~/components/designSystem/Avatar'
import { Typography, TypographyColor } from '~/components/designSystem/Typography'
import { ProviderTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import Adyen from '~/public/images/adyen.svg'
import Cashfree from '~/public/images/cashfree.svg'
import Flutterwave from '~/public/images/flutterwave.svg'
import Gocardless from '~/public/images/gocardless.svg'
import Moneyhash from '~/public/images/moneyhash.svg'
import Stripe from '~/public/images/stripe.svg'
import { tw } from '~/styles/utils'

interface PaymentProviderChipProps {
  paymentProvider?: ProviderTypeEnum | 'manual' | 'manual_long'
  label?: string | null | undefined
  className?: string
  textVariant?: MuiTypographyProps['variant']
  textColor?: TypographyColor
  showAvatar?: boolean
}

const providerLabels: Record<ProviderTypeEnum, string> = {
  [ProviderTypeEnum.Stripe]: 'text_62b1edddbf5f461ab971277d',
  [ProviderTypeEnum.Adyen]: 'text_645d071272418a14c1c76a6d',
  [ProviderTypeEnum.Gocardless]: 'text_634ea0ecc6147de10ddb6625',
  [ProviderTypeEnum.Cashfree]: 'text_17367626793434wkg1rk0114',
  [ProviderTypeEnum.Flutterwave]: 'text_1749724395108m0swrna0zt4',
  [ProviderTypeEnum.Moneyhash]: 'text_1733427981129n3wxjui0bex',
}

const ProviderIcon: FC<{ provider: ProviderTypeEnum }> = ({ provider }) => {
  const icons: Record<ProviderTypeEnum, JSX.Element> = {
    [ProviderTypeEnum.Stripe]: <Stripe />,
    [ProviderTypeEnum.Adyen]: <Adyen />,
    [ProviderTypeEnum.Gocardless]: <Gocardless />,
    [ProviderTypeEnum.Cashfree]: <Cashfree />,
    [ProviderTypeEnum.Flutterwave]: <Flutterwave />,
    [ProviderTypeEnum.Moneyhash]: <Moneyhash />,
  }

  return icons[provider]
}

export const PaymentProviderChip: FC<PaymentProviderChipProps> = ({
  paymentProvider,
  label,
  className,
  textVariant = 'body',
  textColor = 'textSecondary',
  showAvatar = true,
}) => {
  const { translate } = useInternationalization()

  if (paymentProvider === undefined) {
    return null
  }

  const isManual = paymentProvider === 'manual' || paymentProvider === 'manual_long'
  const manualLabel =
    paymentProvider === 'manual' ? 'text_1737110192586abtitcui0xt' : 'text_173799550683709p2rqkoqd5'

  const displayLabel = isManual
    ? translate(manualLabel)
    : label || translate(providerLabels[paymentProvider])

  return (
    <div className={tw('flex flex-nowrap items-center gap-2', className)}>
      {showAvatar && (
        <Avatar className="bg-white" variant="connector" size="small">
          {isManual ? (
            <Icon name="receipt" color="dark" size="small" />
          ) : (
            <ProviderIcon provider={paymentProvider} />
          )}
        </Avatar>
      )}
      <Typography variant={textVariant} color={textColor} noWrap>
        {displayLabel}
      </Typography>
    </div>
  )
}
