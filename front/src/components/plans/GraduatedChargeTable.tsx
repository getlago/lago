import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { memo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Typography } from '~/components/designSystem/Typography'
import { FieldErrorTooltip } from '~/components/form/FieldErrorTooltip'
import { DisabledAmountCell } from '~/components/plans/DisabledAmountCell'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { ONE_TIER_EXAMPLE_UNITS } from '~/core/constants/form'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useGraduatedChargeForm } from '~/hooks/plans/useGraduatedChargeForm'

import { GRADUATED_CHARGE_TABLE_ADD_TIER_TEST_ID } from './chargeTestIds'

gql`
  fragment GraduatedCharge on GraduatedRange {
    flatAmount
    fromValue
    perUnitAmount
    toValue
  }
`

export const GraduatedChargeTable = memo(() => {
  const { form, propertyCursor, currency, disabled, chargePricingUnitShortName } =
    useChargeFormContext()
  const { translate } = useInternationalization()
  const valuePointer = usePropertyValues(form, propertyCursor)
  const { tableDatas, addRange, handleUpdate, deleteRange, infosCalculation } =
    useGraduatedChargeForm({
      disabled,
      propertyCursor,
      form,
      valuePointer,
    })

  return (
    <div className="flex flex-col">
      <Button
        className="mb-2 ml-auto"
        startIcon="plus"
        variant="inline"
        onClick={addRange}
        disabled={disabled}
        data-test={GRADUATED_CHARGE_TABLE_ADD_TIER_TEST_ID}
      >
        {translate('text_62793bbb599f1c01522e91a5')}
      </Button>
      <div className="-mx-4 overflow-auto px-4 pb-6">
        <ChargeTable
          name="graduated-charge-table"
          data={tableDatas}
          onDeleteRow={(_, i) => deleteRange(i)}
          columns={[
            {
              size: 144,
              content: (_, i) => (
                <Typography className="px-4" variant="captionHl">
                  {translate(
                    i === 0 ? 'text_62793bbb599f1c01522e91c0' : 'text_62793bbb599f1c01522e91fc',
                  )}
                </Typography>
              ),
            },
            {
              title: (
                <Typography className="px-4" variant="captionHl">
                  {translate('text_62793bbb599f1c01522e91ab')}
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
                  {translate('text_62793bbb599f1c01522e91b1')}
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
                    name={`${propertyCursor}.graduatedRanges[${i}].toValue`}
                    listeners={{
                      onChange: ({ value }: { value: string }) => {
                        handleUpdate(i, 'toValue', value)
                      },
                    }}
                  >
                    {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                    {(field: any) => (
                      <FieldErrorTooltip
                        title={translate('text_62793bbb599f1c01522e9232', {
                          value: row.fromValue,
                        })}
                      >
                        <field.TextInputField
                          variant="outlined"
                          beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
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
                  {translate('text_62793bbb599f1c01522e91b6')}
                </Typography>
              ),
              size: 144,
              content: (row, i) =>
                disabled ? (
                  <DisabledAmountCell amount={row.perUnitAmount} currency={currency} />
                ) : (
                  <form.AppField name={`${propertyCursor}.graduatedRanges[${i}].perUnitAmount`}>
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
                  {translate('text_62793bbb599f1c01522e91bc')}
                </Typography>
              ),
              size: 144,
              content: (row, i) =>
                disabled ? (
                  <DisabledAmountCell amount={row.flatAmount} currency={currency} />
                ) : (
                  <form.AppField name={`${propertyCursor}.graduatedRanges[${i}].flatAmount`}>
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
          <>
            {infosCalculation.map((calculation, i) => {
              if (i === 0) {
                return (
                  <Typography variant="bodyHl" key={`calculation-alert-${i}`} color="textSecondary">
                    {translate('text_627b69c9fe95530136833956', {
                      lastRowUnit: calculation.firstUnit,
                      value: intlFormatNumber(calculation.total, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                    })}
                  </Typography>
                )
              }
              if (i === 1) {
                return infosCalculation.length === 2 ? (
                  <Typography key={`calculation-alert-${i}`} color="textSecondary">
                    {translate('text_64cac576a11db000acb130b2', {
                      tier1LastUnit: ONE_TIER_EXAMPLE_UNITS,
                      tier1PerUnit: intlFormatNumber(calculation.perUnit, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                      tier1FlatFee: intlFormatNumber(calculation.flatFee, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                      totalTier1: intlFormatNumber(calculation.total, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                    })}
                  </Typography>
                ) : (
                  <Typography key={`calculation-alert-${i}`} color="textSecondary">
                    {translate('text_627b69c9fe95530136833958', {
                      tier1LastUnit: calculation.units,
                      tier1PerUnit: intlFormatNumber(calculation.perUnit, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                      tier1FlatFee: intlFormatNumber(calculation.flatFee, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                      totalTier1: intlFormatNumber(calculation.total, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                    })}
                  </Typography>
                )
              }

              return (
                <Typography key={`calculation-alert-${i}`} color="textSecondary">
                  {translate('text_627b69c9fe9553013683395a', {
                    unitCount: calculation.units,
                    tierPerUnit: intlFormatNumber(calculation.perUnit, {
                      pricingUnitShortName: chargePricingUnitShortName,
                      currencyDisplay: 'symbol',
                      maximumFractionDigits: 15,
                      currency,
                    }),
                    tierFlatFee: intlFormatNumber(calculation.flatFee, {
                      pricingUnitShortName: chargePricingUnitShortName,
                      currencyDisplay: 'symbol',
                      maximumFractionDigits: 15,
                      currency,
                    }),
                    totalTier: intlFormatNumber(calculation.total, {
                      pricingUnitShortName: chargePricingUnitShortName,
                      currencyDisplay: 'symbol',
                      maximumFractionDigits: 15,
                      currency,
                    }),
                  })}
                </Typography>
              )
            })}
          </>
        </Alert>
      </div>
    </div>
  )
})

GraduatedChargeTable.displayName = 'GraduatedChargeTable'
