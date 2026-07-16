import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { memo } from 'react'

import { useChargeFormContext } from '~/contexts/ChargeFormContext'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment StandardCharge on Properties {
    amount
    pricingGroupKeys
  }
`

export const StandardCharge = memo(() => {
  const { form, propertyCursor, currency, disabled, chargePricingUnitShortName } =
    useChargeFormContext()
  const { translate } = useInternationalization()

  return (
    <form.AppField name={`${propertyCursor}.amount`}>
      {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
      {(field: any) => (
        <field.AmountInputField
          currency={currency}
          beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
          disabled={disabled}
          label={translate('text_624453d52e945301380e49b6')}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                {chargePricingUnitShortName || getCurrencySymbol(currency)}
              </InputAdornment>
            ),
          }}
        />
      )}
    </form.AppField>
  )
})

StandardCharge.displayName = 'StandardCharge'
