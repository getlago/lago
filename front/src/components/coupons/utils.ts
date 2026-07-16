import { StatusType } from '~/components/designSystem/Status'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { AppliedCouponStatusEnum, CouponTypeEnum, CurrencyEnum } from '~/generated/graphql'

export const APPLIED_COUPON_STATUS_CONFIG: Record<
  AppliedCouponStatusEnum,
  { type: StatusType; label: string }
> = {
  [AppliedCouponStatusEnum.Active]: {
    type: StatusType.success,
    label: 'text_624efab67eb2570101d1180e',
  },
  [AppliedCouponStatusEnum.Terminated]: {
    type: StatusType.danger,
    label: 'text_62e2a2f2a79d60429eff3035',
  },
}

export function formatCouponValue(params: {
  couponType?: CouponTypeEnum | null
  percentageRate?: number | string | null
  amountCents?: number | null
  amountCurrency?: CurrencyEnum | null
}): string {
  const { couponType, percentageRate, amountCents, amountCurrency } = params

  if (couponType === CouponTypeEnum.Percentage) {
    // Format as percent
    return intlFormatNumber(Number(percentageRate) / 100 || 0, {
      style: 'percent',
    })
  }
  // Format as amount with currency
  return intlFormatNumber(
    deserializeAmount(amountCents ?? 0, amountCurrency || CurrencyEnum.Usd) || 0,
    {
      currencyDisplay: 'symbol',
      currency: amountCurrency || CurrencyEnum.Usd,
      minimumFractionDigits: 2,
      maximumFractionDigits: 15,
    },
  )
}
