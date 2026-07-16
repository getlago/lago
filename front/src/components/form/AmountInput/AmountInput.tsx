import { forwardRef, useMemo } from 'react'

import {
  TextInput,
  TextInputProps,
  ValueFormatter,
  ValueFormatterType,
} from '~/components/form/TextInput'
import { getCurrencyPrecision } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'

export type AmountValueFormatter = Exclude<
  keyof typeof ValueFormatter,
  'int' | 'decimal' | 'triDecimal' | 'quadDecimal'
>

type AmountValueFormatterType = AmountValueFormatter

export interface AmountInputProps extends Omit<TextInputProps, 'beforeChangeFormatter'> {
  currency: CurrencyEnum
  chargePricingUnitShortName?: string
  beforeChangeFormatter?: AmountValueFormatterType[] | AmountValueFormatterType
}

const defineNewBeforeChangeFormatter = ({
  beforeChangeFormatter,
  currency,
  chargePricingUnitShortName,
}: {
  beforeChangeFormatter: AmountInputProps['beforeChangeFormatter']
  currency: CurrencyEnum
  chargePricingUnitShortName?: string
}) => {
  const newBeforeChangeFormatter: ValueFormatterType[] = [
    (() => {
      if (!beforeChangeFormatter) return []
      if (typeof beforeChangeFormatter === 'string') return beforeChangeFormatter
      return [beforeChangeFormatter].flat()
    })(),
  ].flat()

  if (beforeChangeFormatter?.includes('chargeDecimal')) {
    return beforeChangeFormatter
  }

  if (!!chargePricingUnitShortName) {
    newBeforeChangeFormatter.push('decimal')
  } else if (getCurrencyPrecision(currency) === 0) {
    newBeforeChangeFormatter.push('int')
  } else if (getCurrencyPrecision(currency) === 3) {
    newBeforeChangeFormatter.push('triDecimal')
  } else if (getCurrencyPrecision(currency) === 4) {
    newBeforeChangeFormatter.push('quadDecimal')
  } else {
    newBeforeChangeFormatter.push('decimal')
  }

  return newBeforeChangeFormatter
}

const definedDefaultPlaceholder = ({
  currency,
  translate,
  chargePricingUnitShortName,
}: {
  currency: CurrencyEnum
  translate: TranslateFunc
  chargePricingUnitShortName?: string
}) => {
  if (!!chargePricingUnitShortName) {
    return translate('text_63971043c9668f1ba5221bac', undefined, 1)
  } else if (getCurrencyPrecision(currency) === 0) {
    return translate('text_63971043c9668f1ba5221bac', undefined, 0)
  } else if (getCurrencyPrecision(currency) === 3) {
    return translate('text_63971043c9668f1ba5221bac', undefined, 2)
  } else if (getCurrencyPrecision(currency) === 4) {
    return translate('text_644250cc64306c00c12fc2ca')
  }

  return translate('text_63971043c9668f1ba5221bac', undefined, 1)
}

export const AmountInput = forwardRef<HTMLDivElement, AmountInputProps>(
  (
    {
      currency,
      beforeChangeFormatter,
      placeholder,
      chargePricingUnitShortName,
      ...props
    }: AmountInputProps,
    ref,
  ) => {
    const { translate } = useInternationalization()
    const newBeforeChangeFormatter = useMemo(
      () =>
        defineNewBeforeChangeFormatter({
          beforeChangeFormatter,
          currency,
          chargePricingUnitShortName,
        }),
      [beforeChangeFormatter, currency, chargePricingUnitShortName],
    )
    const newPlaceholder = useMemo(
      () =>
        placeholder ??
        definedDefaultPlaceholder({ currency, translate, chargePricingUnitShortName }),
      [placeholder, currency, translate, chargePricingUnitShortName],
    )

    return (
      <TextInput
        ref={ref}
        beforeChangeFormatter={newBeforeChangeFormatter}
        placeholder={newPlaceholder}
        {...props}
      />
    )
  },
)

AmountInput.displayName = 'AmountInput'
