import { gql } from '@apollo/client'
import type { TypographyProps } from '@mui/material/Typography'
import { memo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  AppliedCouponCaptionFragment,
  CouponCaptionFragment,
  CouponFrequency,
  CouponTypeEnum,
  CurrencyEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment CouponCaption on Coupon {
    id
    amountCurrency
    amountCents
    couponType
    percentageRate
    frequency
    frequencyDuration
  }

  fragment AppliedCouponCaption on AppliedCoupon {
    id
    amountCurrency
    amountCents
    amountCentsRemaining
    percentageRate
    frequency
    frequencyDuration
    frequencyDurationRemaining
  }
`

interface CouponCaptionProps {
  coupon: CouponCaptionFragment | AppliedCouponCaptionFragment
  variant?: TypographyProps['variant']
  className?: string
}

export const CouponCaption = memo(
  ({ coupon, variant = 'caption', className }: CouponCaptionProps) => {
    const { translate } = useInternationalization()

    const getCaption = () => {
      const { amountCurrency, amountCents, percentageRate, frequency, frequencyDuration } = coupon
      const amountCentsRemaining =
        'amountCentsRemaining' in coupon ? coupon.amountCentsRemaining : undefined
      const frequencyDurationRemaining =
        'frequencyDurationRemaining' in coupon ? coupon.frequencyDurationRemaining : undefined
      const couponType = amountCents ? CouponTypeEnum.FixedAmount : CouponTypeEnum.Percentage

      if (couponType === CouponTypeEnum.FixedAmount && frequency === CouponFrequency.Once) {
        return translate(
          amountCentsRemaining ? 'text_637b4da08cd0118cd0c4486f' : 'text_632d68358f1fedc68eed3e70',
          {
            amount: intlFormatNumber(
              deserializeAmount(
                Number(amountCentsRemaining) || Number(amountCents),
                amountCurrency || CurrencyEnum.Usd,
              ) || 0,
              {
                currencyDisplay: 'symbol',
                currency: amountCurrency || undefined,
              },
            ),
          },
        )
      } else if (couponType === CouponTypeEnum.Percentage && frequency === CouponFrequency.Once) {
        return translate('text_632d68358f1fedc68eed3eb5', {
          rate: intlFormatNumber(Number(percentageRate) / 100 || 0, {
            style: 'percent',
          }),
        })
      } else if (
        couponType === CouponTypeEnum.FixedAmount &&
        frequency === CouponFrequency.Recurring
      ) {
        return translate(
          'text_632d68358f1fedc68eed3ede',
          {
            amount: intlFormatNumber(
              deserializeAmount(
                Number(amountCentsRemaining) || Number(amountCents),
                amountCurrency || CurrencyEnum.Usd,
              ) || 0,
              {
                currencyDisplay: 'symbol',
                currency: amountCurrency || undefined,
              },
            ),
            duration: frequencyDurationRemaining || frequencyDuration,
          },
          frequencyDurationRemaining || frequencyDuration || 1,
        )
      } else if (
        couponType === CouponTypeEnum.Percentage &&
        frequency === CouponFrequency.Recurring
      ) {
        return translate(
          'text_632d68358f1fedc68eed3ef9',
          {
            rate: intlFormatNumber(Number(percentageRate) / 100 || 0, {
              style: 'percent',
            }),
            duration: frequencyDurationRemaining || frequencyDuration,
          },
          frequencyDurationRemaining || frequencyDuration || 1,
        )
      } else if (
        couponType === CouponTypeEnum.FixedAmount &&
        frequency === CouponFrequency.Forever
      ) {
        return translate('text_63c946e8bef768ead2fee35c', {
          amount: intlFormatNumber(
            deserializeAmount(Number(amountCents), amountCurrency || CurrencyEnum.Usd) || 0,
            {
              currencyDisplay: 'symbol',
              currency: amountCurrency || undefined,
            },
          ),
        })
      } else if (
        couponType === CouponTypeEnum.Percentage &&
        frequency === CouponFrequency.Forever
      ) {
        return translate('text_63c96b18bfbf40e9ef600e99', {
          rate: intlFormatNumber(Number(percentageRate) / 100 || 0, {
            style: 'percent',
          }),
        })
      }
    }

    return (
      <>
        {!className && (
          <Typography variant={variant} color="grey600" noWrap data-test="coupon-caption">
            {getCaption()}
          </Typography>
        )}

        {className && (
          <Typography className={className} data-test="coupon-caption">
            {getCaption()}
          </Typography>
        )}
      </>
    )
  },
)

CouponCaption.displayName = 'CouponCaption'
