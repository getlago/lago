import { PreviewTable, type PreviewTableColumn } from '~/components/designSystem/Table/PreviewTable'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import type { LocaleEnum } from '~/core/translations'
import { CouponFrequency, CouponTypeEnum, type CurrencyEnum } from '~/generated/graphql'
import type { TranslateFunc } from '~/hooks/core/useInternationalization'

import type { EntityData } from '../common/RichTextEditorContext'

export const DISCOUNT_PREVIEW_TABLE_TEST_ID = 'preview-table-discount-preview'

const K = {
  discountLabel: 'text_1782889379261hdcd0jhzdm6',
  discountValue: 'text_1783090333139dnllq2q6ege',
  duration: 'text_632d68358f1fedc68eed3e80',
  once: 'text_632d68358f1fedc68eed3ea3',
  forever: 'text_63c83a3476e46bc6ab9d85d6',
  billingPeriods: 'text_17830875698228lpz4i09jop',
} as const

interface DiscountPreviewTableProps {
  entity: EntityData
  translate: TranslateFunc
  currency: CurrencyEnum
  locale?: LocaleEnum
}

const formatValue = (entity: EntityData, currency: CurrencyEnum, locale?: LocaleEnum): string => {
  if (
    entity.couponType === CouponTypeEnum.Percentage &&
    typeof entity.percentageRate === 'number'
  ) {
    return `${entity.percentageRate}%`
  }

  if (entity.couponType === CouponTypeEnum.FixedAmount && entity.amountCents) {
    const ccy = entity.amountCurrency ?? currency

    return intlFormatNumber(deserializeAmount(entity.amountCents, ccy), { currency: ccy, locale })
  }

  return ''
}

const formatDuration = (entity: EntityData, translate: TranslateFunc): string => {
  if (entity.frequency === CouponFrequency.Once) {
    return translate(K.once)
  }

  if (entity.frequency === CouponFrequency.Forever) {
    return translate(K.forever)
  }

  if (entity.frequency === CouponFrequency.Recurring) {
    const count = entity.frequencyDuration ?? 0

    return translate(K.billingPeriods, { count }, count)
  }

  return ''
}

export const DiscountPreviewTable = ({
  entity,
  translate,
  currency,
  locale,
}: DiscountPreviewTableProps) => {
  const columns: PreviewTableColumn<EntityData>[] = [
    {
      key: 'name',
      title: translate(K.discountLabel),
      maxSpace: true,
      content: (item) => (
        <Typography variant="bodyHl" color="grey700">
          {item.name}
        </Typography>
      ),
    },
    {
      key: 'value',
      title: translate(K.discountValue),
      textAlign: 'right',
      minWidth: 180,
      content: (item) => (
        <Typography variant="body" color="grey700">
          {formatValue(item, currency, locale)}
        </Typography>
      ),
    },
    {
      key: 'duration',
      title: translate(K.duration),
      textAlign: 'right',
      minWidth: 200,
      content: (item) => (
        <Typography variant="body" color="grey700">
          {formatDuration(item, translate)}
        </Typography>
      ),
    },
  ]

  return <PreviewTable name="discount-preview" data={[entity]} columns={columns} />
}
