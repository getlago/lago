import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { memo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Typography } from '~/components/designSystem/Typography'
import { FieldErrorTooltip } from '~/components/form/FieldErrorTooltip'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useVolumeChargeForm } from '~/hooks/plans/useVolumeChargeForm'

import { VOLUME_CHARGE_TABLE_ADD_TIER_TEST_ID } from './chargeTestIds'

gql`
  fragment VolumeRanges on VolumeRange {
    flatAmount
    fromValue
    perUnitAmount
    toValue
  }
`

const DisabledAmountCell = ({ amount, currency }: { amount?: string; currency: CurrencyEnum }) => (
  <div className="flex max-w-31 items-center gap-2 px-4">
    <Typography color="textSecondary">{getCurrencySymbol(currency)}</Typography>
    <Typography color="disabled" noWrap>
      {amount || '0.0'}
    </Typography>
  </div>
)

export const VolumeChargeTable = memo(() => {
  const { form, propertyCursor, currency, disabled, chargePricingUnitShortName } =
    useChargeFormContext()
  const { translate } = useInternationalization()
  const valuePointer = usePropertyValues(form, propertyCursor)
  const { tableDatas, addRange, handleUpdate, deleteRange, infosCalculation } = useVolumeChargeForm(
    {
      disabled,
      propertyCursor,
      form,
      valuePointer,
    },
  )

  return (
    <div className="flex flex-col">
      <Button
        className="mb-2 ml-auto"
        startIcon="plus"
        variant="inline"
        onClick={addRange}
        disabled={disabled}
        data-test={VOLUME_CHARGE_TABLE_ADD_TIER_TEST_ID}
      >
        {translate('text_6304e74aab6dbc18d615f38e')}
      </Button>
      <div className="-mx-4 overflow-auto px-4 pb-6">
        <ChargeTable
          name="volume-charge-table"
          data={tableDatas}
          onDeleteRow={(_, i) => deleteRange(i)}
          columns={[
            {
              size: 144,
              content: () => (
                <Typography className="px-4" variant="captionHl">
                  {translate('text_6304e74aab6dbc18d615f3a2')}
                </Typography>
              ),
            },
            {
              title: (
                <Typography className="px-4" variant="captionHl">
                  {translate('text_6304e74aab6dbc18d615f392')}
                </Typography>
              ),
              size: 144,
              content: (row) => (
                <Typography className="px-4" color="disabled" noWrap>
                  {row?.fromValue}
                </Typography>
              ),
            },
            {
              title: (
                <Typography className="px-4" variant="captionHl" noWrap>
                  {translate('text_6304e74aab6dbc18d615f396')}
                </Typography>
              ),
              size: 144,
              content: (row, i) =>
                disabled || i === tableDatas?.length - 1 ? (
                  <Typography className="px-4" variant="body" color="disabled" noWrap>
                    {row.toValue || '∞'}
                  </Typography>
                ) : (
                  <form.AppField
                    name={`${propertyCursor}.volumeRanges[${i}].toValue`}
                    listeners={{
                      onChange: ({ value }: { value: string }) => {
                        handleUpdate(i, 'toValue', value)
                      },
                    }}
                  >
                    {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                    {(field: any) => (
                      <FieldErrorTooltip
                        title={translate('text_6304e74aab6dbc18d615f420', {
                          value: Number(row.fromValue) - 1,
                        })}
                      >
                        <field.TextInputField
                          variant="outlined"
                          beforeChangeFormatter={['int', 'positiveNumber']}
                          displayErrorText={false}
                        />
                      </FieldErrorTooltip>
                    )}
                  </form.AppField>
                ),
            },
            {
              title: (
                <Typography className="px-4" variant="captionHl">
                  {translate('text_6304e74aab6dbc18d615f39a')}
                </Typography>
              ),
              size: 144,
              content: (row, i) =>
                disabled ? (
                  <DisabledAmountCell currency={currency} amount={row.perUnitAmount} />
                ) : (
                  <form.AppField name={`${propertyCursor}.volumeRanges[${i}].perUnitAmount`}>
                    {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                    {(field: any) => (
                      <FieldErrorTooltip>
                        <field.AmountInputField
                          variant="outlined"
                          beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
                          currency={currency}
                          displayErrorText={false}
                          InputProps={{
                            startAdornment: (
                              <InputAdornment position="start">
                                {chargePricingUnitShortName || getCurrencySymbol(currency)}
                              </InputAdornment>
                            ),
                          }}
                          data-test={`cell-amount-${i}`}
                        />
                      </FieldErrorTooltip>
                    )}
                  </form.AppField>
                ),
            },
            {
              title: (
                <Typography className="px-4" variant="captionHl">
                  {translate('text_6304e74aab6dbc18d615f39e')}
                </Typography>
              ),
              size: 144,
              content: (row, i) =>
                disabled ? (
                  <DisabledAmountCell currency={currency} amount={row.flatAmount} />
                ) : (
                  <form.AppField name={`${propertyCursor}.volumeRanges[${i}].flatAmount`}>
                    {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                    {(field: any) => (
                      <FieldErrorTooltip>
                        <field.AmountInputField
                          variant="outlined"
                          beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
                          currency={currency}
                          displayErrorText={false}
                          InputProps={{
                            startAdornment: (
                              <InputAdornment position="start">
                                {chargePricingUnitShortName || getCurrencySymbol(currency)}
                              </InputAdornment>
                            ),
                          }}
                        />
                      </FieldErrorTooltip>
                    )}
                  </form.AppField>
                ),
            },
          ]}
        />
      </div>

      <div className="flex flex-col gap-6">
        <Alert type="info">
          <Typography variant="bodyHl" color="textSecondary">
            {translate('text_6304e74aab6dbc18d615f412', {
              lastRowFirstUnit: infosCalculation.lastRowFirstUnit,
              value: intlFormatNumber(infosCalculation.value, {
                currencyDisplay: 'symbol',
                maximumFractionDigits: 15,
                currency,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
            })}
          </Typography>
          <Typography variant="body" color="textSecondary">
            {translate('text_6304e74aab6dbc18d615f416', {
              lastRowFirstUnit: infosCalculation.lastRowFirstUnit,
              lastRowPerUnit: intlFormatNumber(infosCalculation.lastRowPerUnit, {
                currencyDisplay: 'symbol',
                maximumFractionDigits: 15,
                currency,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
              lastRowFlatFee: intlFormatNumber(infosCalculation.lastRowFlatFee, {
                currencyDisplay: 'symbol',
                maximumFractionDigits: 15,
                currency,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
              value: intlFormatNumber(infosCalculation.value, {
                currencyDisplay: 'symbol',
                maximumFractionDigits: 15,
                currency,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
            })}
          </Typography>
        </Alert>
      </div>
    </div>
  )
})

VolumeChargeTable.displayName = 'VolumeChargeTable'
