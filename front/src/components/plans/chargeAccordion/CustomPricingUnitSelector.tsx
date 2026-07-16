import InputAdornment from '@mui/material/InputAdornment'
import { useMemo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { ComboBox, ComboboxItem, TextInput } from '~/components/form'
import { LocalPricingUnitType, LocalUsageChargeInput } from '~/components/plans/types'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomPricingUnits } from '~/hooks/plans/useCustomPricingUnits'

const CUSTOM_PRICING_UNIT_SEPARATOR = '::-::'

export const PRICING_UNIT_COMBOBOX_TEST_ID = 'pricing-unit-combobox'
export const PRICING_UNIT_CONVERSION_RATE_TEST_ID = 'pricing-unit-conversion-rate'

export const CustomPricingUnitSelector = ({
  currency,
  isInSubscriptionForm,
  disabled,
  localCharge,
  handleUpdate,
}: {
  currency: CurrencyEnum
  isInSubscriptionForm: boolean | undefined
  disabled: boolean | undefined
  localCharge: LocalUsageChargeInput
  handleUpdate: (name: string, value: unknown) => void
}) => {
  const { translate } = useInternationalization()
  const { pricingUnits } = useCustomPricingUnits()

  const pricingUnitDataForCombobox = useMemo(() => {
    const formatedPricingUnits = pricingUnits.map((pricingUnit) => ({
      label: pricingUnit.name,
      value: `${pricingUnit.code}${CUSTOM_PRICING_UNIT_SEPARATOR}${pricingUnit.shortName}${CUSTOM_PRICING_UNIT_SEPARATOR}${LocalPricingUnitType.Custom}`,
      labelNode: (
        <ComboboxItem>
          <Typography variant="body" color="grey700" noWrap>
            {pricingUnit.name}
          </Typography>
          <Typography variant="caption" color="grey600" noWrap>
            {pricingUnit.code}
          </Typography>
        </ComboboxItem>
      ),
    }))

    return [
      {
        label: currency,
        value: `${currency}${CUSTOM_PRICING_UNIT_SEPARATOR}${currency}${CUSTOM_PRICING_UNIT_SEPARATOR}${LocalPricingUnitType.Fiat}`,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {currency}
            </Typography>
            <Typography variant="caption" color="grey600" noWrap>
              {translate('text_1750411499858a87tkuylqms')}
            </Typography>
          </ComboboxItem>
        ),
      },
      ...formatedPricingUnits,
    ]
  }, [currency, pricingUnits, translate])

  return (
    <div className="flex flex-col gap-3">
      <ComboBox
        data-test={PRICING_UNIT_COMBOBOX_TEST_ID}
        disableClearable
        disabled={isInSubscriptionForm || disabled}
        name="pricingUnit"
        label={translate('text_1750411499858etvdxpxm4vd')}
        sortValues={false}
        data={pricingUnitDataForCombobox}
        value={localCharge.appliedPricingUnit?.code}
        onChange={(value) => {
          const [code, shortName, type] = value.split(CUSTOM_PRICING_UNIT_SEPARATOR)

          return handleUpdate('appliedPricingUnit', {
            code,
            shortName,
            type,
            conversionRate:
              type === LocalPricingUnitType.Custom
                ? localCharge.appliedPricingUnit?.conversionRate
                : undefined,
          })
        }}
      />

      {localCharge.appliedPricingUnit?.type === LocalPricingUnitType.Custom && (
        <div
          data-test={PRICING_UNIT_CONVERSION_RATE_TEST_ID}
          className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1"
        >
          <Typography variant="captionHl" color="textSecondary">
            {translate('text_1750411499858qxgqjoqtr3e')}
          </Typography>

          <Typography variant="captionHl" color="textSecondary">
            {translate('text_1750411499858su5b7bbp5t9')}
          </Typography>

          <div className="flex items-center gap-4">
            <div className="flex size-12 items-center justify-center rounded-xl border border-grey-300 bg-grey-100">
              1
            </div>

            <div className="flex size-12 items-center justify-center rounded-xl border border-grey-300 bg-grey-100">
              =
            </div>
          </div>

          <TextInput
            name="conversionRate"
            beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
            value={localCharge.appliedPricingUnit?.conversionRate}
            placeholder={translate('text_643e592657fc1ba5ce110c80')}
            onChange={(value) => {
              handleUpdate('appliedPricingUnit', {
                ...localCharge.appliedPricingUnit,
                conversionRate: value,
              })
            }}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">{getCurrencySymbol(currency)}</InputAdornment>
              ),
            }}
          />
        </div>
      )}
    </div>
  )
}
