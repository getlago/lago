import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { memo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment PackageCharge on Properties {
    amount
    packageSize
    freeUnits
  }
`

export const PACKAGE_CHARGE_EMPTY_ALERT_TEST_ID = 'package-charge-empty-alert'
export const PACKAGE_CHARGE_FILLED_ALERT_TEST_ID = 'package-charge-filled-alert'
export const PACKAGE_CHARGE_FREE_UNITS_ALERT_TEST_ID = 'package-charge-free-units-alert'

export const PackageCharge = memo(() => {
  const { form, propertyCursor, currency, disabled, chargePricingUnitShortName } =
    useChargeFormContext()
  const { translate } = useInternationalization()
  const valuePointer = usePropertyValues(form, propertyCursor)

  const serializedPackageCharge = Number(valuePointer?.packageSize || 0)
  const serializedFreeUnits = Number(valuePointer?.freeUnits || 0)

  return (
    <>
      <form.AppField name={`${propertyCursor}.amount`}>
        {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
        {(field: any) => (
          <field.AmountInputField
            currency={currency}
            beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
            disabled={disabled}
            label={translate('text_6282085b4f283b0102655870')}
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
      <form.AppField name={`${propertyCursor}.packageSize`}>
        {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
        {(field: any) => (
          <field.TextInputField
            beforeChangeFormatter={['positiveNumber', 'int']}
            disabled={disabled}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Typography color={disabled ? 'disabled' : 'textSecondary'}>
                    {translate('text_6282085b4f283b010265587c')}
                  </Typography>
                </InputAdornment>
              ),
              endAdornment: (
                <InputAdornment position="end">
                  {translate('text_6282085b4f283b0102655884')}
                </InputAdornment>
              ),
            }}
          />
        )}
      </form.AppField>
      <form.AppField name={`${propertyCursor}.freeUnits`}>
        {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
        {(field: any) => (
          <field.TextInputField
            label={translate('text_6282085b4f283b010265588c')}
            placeholder={translate('text_62824f0e5d93bc008d268d00')}
            beforeChangeFormatter={['positiveNumber', 'int']}
            disabled={disabled}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  {translate('text_6282085b4f283b0102655894')}
                </InputAdornment>
              ),
            }}
          />
        )}
      </form.AppField>
      <Alert
        type="info"
        data-test={
          valuePointer?.packageSize
            ? PACKAGE_CHARGE_FILLED_ALERT_TEST_ID
            : PACKAGE_CHARGE_EMPTY_ALERT_TEST_ID
        }
      >
        {valuePointer?.packageSize ? (
          <>
            <Typography variant="bodyHl" color="textSecondary">
              {translate('text_6282085b4f283b0102655892', {
                units: serializedPackageCharge + serializedFreeUnits + 1,
                cost: intlFormatNumber(Number(valuePointer?.amount || 0) * 2, {
                  currencyDisplay: 'symbol',
                  maximumFractionDigits: 15,
                  currency,
                  pricingUnitShortName: chargePricingUnitShortName,
                }),
              })}
            </Typography>
            {valuePointer?.freeUnits && (
              <Typography color="textSecondary" data-test={PACKAGE_CHARGE_FREE_UNITS_ALERT_TEST_ID}>
                {translate('text_6282085b4f283b0102655896', {
                  unit: 1,
                  unitInPackage: serializedFreeUnits,
                  cost: intlFormatNumber(0, {
                    currencyDisplay: 'symbol',
                    maximumFractionDigits: 15,
                    currency,
                    pricingUnitShortName: chargePricingUnitShortName,
                  }),
                })}
              </Typography>
            )}

            <Typography color="textSecondary">
              {translate('text_6282085b4f283b0102655896', {
                unit: serializedFreeUnits + 1,
                unitInPackage: serializedPackageCharge + serializedFreeUnits,
                cost: intlFormatNumber(Number(valuePointer?.amount || 0), {
                  currencyDisplay: 'symbol',
                  maximumFractionDigits: 15,
                  currency,
                  pricingUnitShortName: chargePricingUnitShortName,
                }),
              })}
            </Typography>
            <Typography color="textSecondary">
              {translate('text_6282085b4f283b0102655896', {
                unit: serializedFreeUnits + serializedPackageCharge + 1,
                unitInPackage: serializedPackageCharge * 2 + serializedFreeUnits,
                cost: intlFormatNumber(Number(valuePointer?.amount || 0) * 2, {
                  currencyDisplay: 'symbol',
                  maximumFractionDigits: 15,
                  currency,
                  pricingUnitShortName: chargePricingUnitShortName,
                }),
              })}
            </Typography>
          </>
        ) : (
          <Typography color="textSecondary">
            {translate('text_6282085b4f283b0102655898')}
          </Typography>
        )}
      </Alert>
    </>
  )
})

PackageCharge.displayName = 'PackageCharge'
