import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { Icon } from 'lago-design-system'
import { memo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { ChargeTable } from '~/components/designSystem/Table/ChargeTable'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { FieldErrorTooltip } from '~/components/form/FieldErrorTooltip'
import { DisabledAmountCell } from '~/components/plans/DisabledAmountCell'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useGraduatedPercentageChargeForm } from '~/hooks/plans/useGraduatedPercentageChargeForm'

import { GRADUATED_PERCENTAGE_CHARGE_TABLE_ADD_TIER_TEST_ID } from './chargeTestIds'

gql`
  fragment GraduatedPercentageCharge on GraduatedPercentageRange {
    flatAmount
    fromValue
    rate
    toValue
  }
`

export const GraduatedPercentageChargeTable = memo(() => {
  const { form, propertyCursor, currency, disabled, chargePricingUnitShortName } =
    useChargeFormContext()
  const { translate } = useInternationalization()
  const valuePointer = usePropertyValues(form, propertyCursor)
  const { tableDatas, addRange, handleUpdate, deleteRange, infosCalculation } =
    useGraduatedPercentageChargeForm({
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
        data-test={GRADUATED_PERCENTAGE_CHARGE_TABLE_ADD_TIER_TEST_ID}
      >
        {translate('text_62793bbb599f1c01522e91a5')}
      </Button>
      <div className="-mx-4 overflow-auto px-4 pb-6">
        <ChargeTable
          name="graduated-percentage-charge-table"
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
                    name={`${propertyCursor}.graduatedPercentageRanges[${i}].toValue`}
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
                  {translate('text_64de472463e2da6b31737de0')}
                </Typography>
              ),
              size: 144,
              content: (row, i) =>
                disabled ? (
                  <Typography
                    className="flex max-w-31 items-center gap-2 px-4"
                    color="disabled"
                    noWrap
                  >
                    {intlFormatNumber(Number(row.rate) / 100 || 0, {
                      maximumFractionDigits: 15,
                      style: 'percent',
                    })}
                  </Typography>
                ) : (
                  <form.AppField name={`${propertyCursor}.graduatedPercentageRanges[${i}].rate`}>
                    {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                    {(field: any) => (
                      <FieldErrorTooltip>
                        <field.AmountInputField
                          variant="outlined"
                          beforeChangeFormatter={['chargeDecimal', 'positiveNumber']}
                          currency={currency}
                          displayErrorText={false}
                          InputProps={{
                            endAdornment: (
                              <InputAdornment position="end">
                                {translate('text_632d68358f1fedc68eed3e93')}
                              </InputAdornment>
                            ),
                          }}
                          data-test={`cell-rate-${i}`}
                        />
                      </FieldErrorTooltip>
                    )}
                  </form.AppField>
                ),
            },
            {
              title: (
                <div className="flex items-center">
                  <Typography className="px-4" variant="captionHl">
                    {translate('text_64de472463e2da6b31737df2')}
                  </Typography>
                  <Tooltip
                    className="flex h-5 items-end"
                    placement="top-end"
                    title={translate('text_64de472563e2da6b31737e77')}
                  >
                    <Icon name="info-circle" />
                  </Tooltip>
                </div>
              ),
              size: 144,
              content: (row, i) =>
                disabled ? (
                  <DisabledAmountCell
                    amount={row.flatAmount}
                    currency={currency}
                    pricingUnitShortName={chargePricingUnitShortName}
                  />
                ) : (
                  <form.AppField
                    name={`${propertyCursor}.graduatedPercentageRanges[${i}].flatAmount`}
                  >
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
                // When only one tier
                return infosCalculation.length === 1 ? (
                  <Typography key={`calculation-alert-${i}`} color="textSecondary">
                    {translate('text_64de5dd470cdf80100c15fdb', {
                      rate: intlFormatNumber(calculation.rate / 100, {
                        maximumFractionDigits: 15,
                        style: 'percent',
                      }),
                      flatAmount: intlFormatNumber(calculation.flatAmount, {
                        pricingUnitShortName: chargePricingUnitShortName,
                        currencyDisplay: 'symbol',
                        maximumFractionDigits: 15,
                        currency,
                      }),
                    })}
                  </Typography>
                ) : (
                  <Typography key={`calculation-alert-${i}`} color="textSecondary">
                    {translate('text_64de472563e2da6b31737e6f', {
                      units: calculation.units,
                      rate: intlFormatNumber(calculation.rate / 100, {
                        maximumFractionDigits: 15,
                        style: 'percent',
                      }),
                      flatAmount: intlFormatNumber(calculation.flatAmount, {
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
                  {translate('text_64de472563e2da6b31737e75', {
                    units: calculation.units,
                    rate: intlFormatNumber(calculation.rate / 100, {
                      maximumFractionDigits: 15,
                      style: 'percent',
                    }),
                    flatAmount: intlFormatNumber(calculation.flatAmount, {
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

GraduatedPercentageChargeTable.displayName = 'GraduatedPercentageChargeTable'
