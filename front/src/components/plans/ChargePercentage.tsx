import { gql } from '@apollo/client'
import InputAdornment from '@mui/material/InputAdornment'
import { memo, useCallback } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Button } from '~/components/designSystem/Button'
import { Popper } from '~/components/designSystem/Popper'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'
import { MenuPopper } from '~/styles'

import {
  CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID,
  CHARGE_PERCENTAGE_ADD_FREE_UNITS_TEST_ID,
  CHARGE_PERCENTAGE_ADD_MAX_CTA_TEST_ID,
  CHARGE_PERCENTAGE_ADD_MIN_CTA_TEST_ID,
  CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID,
  CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID,
} from './chargeTestIds'

gql`
  fragment PercentageCharge on Properties {
    fixedAmount
    freeUnitsPerEvents
    freeUnitsPerTotalAggregation
    rate
    perTransactionMinAmount
    perTransactionMaxAmount
  }
`

export const ChargePercentage = memo(() => {
  const { form, propertyCursor, currency, disabled, chargePricingUnitShortName } =
    useChargeFormContext()
  const { translate } = useInternationalization()
  const { isPremium } = useCurrentUser()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const valuePointer = usePropertyValues(form, propertyCursor)

  const showFixedAmount = valuePointer?.fixedAmount !== undefined
  const showFreeUnitsPerEvents = valuePointer?.freeUnitsPerEvents !== undefined
  const showFreeUnitsPerTotalAggregation = valuePointer?.freeUnitsPerTotalAggregation !== undefined
  const showPerTransactionMinAmount = valuePointer?.perTransactionMinAmount !== undefined
  const showPerTransactionMaxAmount = valuePointer?.perTransactionMaxAmount !== undefined
  let freeUnitsPerTotalAggregationTranslation = translate('text_6303351deffd2a0d70498677', {
    freeAmountUnits: intlFormatNumber(Number(valuePointer?.freeUnitsPerTotalAggregation) || 0, {
      currencyDisplay: 'symbol',
      pricingUnitShortName: chargePricingUnitShortName,
      currency,
      maximumFractionDigits: 15,
    }),
  })

  const setPropertyValue = useCallback(
    (value: unknown) => {
      form.setFieldValue(propertyCursor, value)
    },
    [form, propertyCursor],
  )

  if (!showFreeUnitsPerEvents && showFreeUnitsPerTotalAggregation) {
    freeUnitsPerTotalAggregationTranslation =
      freeUnitsPerTotalAggregationTranslation.charAt(0).toUpperCase() +
      freeUnitsPerTotalAggregationTranslation.slice(1)
  }

  return (
    <>
      <form.AppField name={`${propertyCursor}.rate`}>
        {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
        {(field: any) => (
          <field.TextInputField
            className="flex-1"
            label={translate('text_62a0b7107afa2700a65ef6f6')}
            beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
            disabled={disabled}
            placeholder={translate('text_62a0b7107afa2700a65ef700')}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  {translate('text_62a0b7107afa2700a65ef70a')}
                </InputAdornment>
              ),
            }}
          />
        )}
      </form.AppField>

      {valuePointer?.fixedAmount !== undefined && (
        <div className="flex gap-3">
          <form.AppField name={`${propertyCursor}.fixedAmount`}>
            {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
            {(field: any) => (
              <field.AmountInputField
                className="flex-1"
                currency={currency}
                beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
                disabled={disabled}
                label={translate('text_62ff5d01a306e274d4ffcc1e')}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      {chargePricingUnitShortName || getCurrencySymbol(currency)}
                    </InputAdornment>
                  ),
                }}
                helperText={translate('text_62ff5d01a306e274d4ffcc30')}
              />
            )}
          </form.AppField>
          <Tooltip
            className="mt-8"
            disableHoverListener={disabled}
            title={translate('text_62ff5d01a306e274d4ffcc28')}
            placement="top-end"
          >
            <Button
              icon="trash"
              disabled={disabled}
              variant="quaternary"
              onClick={() => {
                setPropertyValue({
                  ...valuePointer,
                  fixedAmount: undefined,
                })
              }}
              data-test={CHARGE_PERCENTAGE_REMOVE_FIXED_FEE_TEST_ID}
            />
          </Tooltip>
        </div>
      )}

      {valuePointer?.freeUnitsPerEvents !== undefined && (
        <div className="flex gap-3">
          <form.AppField name={`${propertyCursor}.freeUnitsPerEvents`}>
            {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
            {(field: any) => (
              <field.TextInputField
                className="flex-1"
                beforeChangeFormatter={['positiveNumber', 'int']}
                disabled={disabled}
                label={translate('text_62ff5d01a306e274d4ffcc36')}
                placeholder={translate('text_62ff5d01a306e274d4ffcc3c')}
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">
                      {translate('text_62ff5d01a306e274d4ffcc42')}
                    </InputAdornment>
                  ),
                }}
                data-test="free-unit-per-event"
              />
            )}
          </form.AppField>
          <Tooltip
            className="mt-8"
            disableHoverListener={disabled}
            title={translate('text_62ff5d01a306e274d4ffcc46')}
            placement="top-end"
          >
            <Button
              icon="trash"
              disabled={disabled}
              variant="quaternary"
              onClick={() => {
                setPropertyValue({
                  ...valuePointer,
                  freeUnitsPerEvents: undefined,
                })
              }}
              data-test="remove-free-units-per-event"
            />
          </Tooltip>
        </div>
      )}

      {valuePointer?.freeUnitsPerTotalAggregation !== undefined && (
        <div className="flex gap-3">
          {valuePointer?.freeUnitsPerEvents !== undefined &&
            valuePointer?.freeUnitsPerTotalAggregation !== undefined && (
              <Typography className="mt-10 flex-initial" variant="body">
                {translate('text_62ff5d01a306e274d4ffcc59')}
              </Typography>
            )}
          <form.AppField name={`${propertyCursor}.freeUnitsPerTotalAggregation`}>
            {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
            {(field: any) => (
              <field.AmountInputField
                className="flex-1"
                currency={currency}
                beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
                disabled={disabled}
                label={translate('text_62ff5d01a306e274d4ffcc48')}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      {chargePricingUnitShortName || getCurrencySymbol(currency)}
                    </InputAdornment>
                  ),
                }}
                data-test="free-unit-per-total-aggregation"
              />
            )}
          </form.AppField>
          <Tooltip
            className="mt-8"
            disableHoverListener={disabled}
            title={translate('text_62ff5d01a306e274d4ffcc5b')}
            placement="top-end"
          >
            <Button
              icon="trash"
              disabled={disabled}
              variant="quaternary"
              onClick={() => {
                setPropertyValue({
                  ...valuePointer,
                  freeUnitsPerTotalAggregation: undefined,
                })
              }}
              data-test="remove-free-unit-per-total-aggregation"
            />
          </Tooltip>
        </div>
      )}

      {valuePointer?.perTransactionMinAmount !== undefined && (
        <div className="flex gap-3">
          <form.AppField name={`${propertyCursor}.perTransactionMinAmount`}>
            {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
            {(field: any) => {
              const hasMinAmountError = field.state.meta.errors.some(
                // eslint-disable-next-line @typescript-eslint/no-explicit-any
                (e: any) => e?.message === 'minAmountShouldBeLowerThanMax',
              )

              return (
                <field.AmountInputField
                  className="flex-1"
                  beforeChangeFormatter={['positiveNumber']}
                  currency={currency}
                  disabled={disabled}
                  label={translate('text_64e7b273b046851c46d781e5')}
                  placeholder={translate('text_632d68358f1fedc68eed3e86')}
                  helperText={translate('text_64e7b273b046851c46d78201')}
                  errorOverride={
                    hasMinAmountError
                      ? translate('text_64e7b273b046851c46d78207', {
                          transac_max: intlFormatNumber(
                            Number(valuePointer?.perTransactionMaxAmount || 0),
                            {
                              currency,
                              currencyDisplay: 'symbol',
                              minimumFractionDigits: 2,
                            },
                          ),
                        })
                      : undefined
                  }
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        {chargePricingUnitShortName || getCurrencySymbol(currency)}
                      </InputAdornment>
                    ),
                  }}
                  data-test="per-transaction-min-amount"
                />
              )
            }}
          </form.AppField>
          <Tooltip
            className="mt-8"
            disableHoverListener={disabled}
            title={translate('text_64e7b273b046851c46d78249')}
            placement="top-end"
          >
            <Button
              icon="trash"
              disabled={disabled}
              variant="quaternary"
              onClick={() => {
                setPropertyValue({
                  ...valuePointer,
                  perTransactionMinAmount: undefined,
                })
              }}
              data-test="remove-per-transaction-min-amount-cta"
            />
          </Tooltip>
        </div>
      )}

      {valuePointer?.perTransactionMaxAmount !== undefined && (
        <div className="flex gap-3">
          <form.AppField name={`${propertyCursor}.perTransactionMaxAmount`}>
            {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
            {(field: any) => {
              const hasMaxAmountError = field.state.meta.errors.some(
                // eslint-disable-next-line @typescript-eslint/no-explicit-any
                (e: any) => e?.message === 'maxAmountShouldBeHigherThanMin',
              )

              return (
                <field.AmountInputField
                  className="flex-1"
                  beforeChangeFormatter={['positiveNumber']}
                  currency={currency}
                  disabled={disabled}
                  label={translate('text_64e7b273b046851c46d78205')}
                  placeholder={translate('text_632d68358f1fedc68eed3e86')}
                  helperText={translate('text_64e7b273b046851c46d78221')}
                  errorOverride={
                    hasMaxAmountError
                      ? translate('text_17728283714577s8i2c87bva', {
                          transac_min: intlFormatNumber(
                            Number(valuePointer?.perTransactionMinAmount || 0),
                            {
                              currency,
                              currencyDisplay: 'symbol',
                              minimumFractionDigits: 2,
                            },
                          ),
                        })
                      : undefined
                  }
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        {chargePricingUnitShortName || getCurrencySymbol(currency)}
                      </InputAdornment>
                    ),
                  }}
                  data-test="per-transaction-max-amount"
                />
              )
            }}
          </form.AppField>
          <Tooltip
            className="mt-8"
            disableHoverListener={disabled}
            title={translate('text_64e7b273b046851c46d782d6')}
            placement="top-end"
          >
            <Button
              icon="trash"
              disabled={disabled}
              variant="quaternary"
              onClick={() => {
                setPropertyValue({
                  ...valuePointer,
                  perTransactionMaxAmount: undefined,
                })
              }}
              data-test="remove-per-transaction-max-amount-cta"
            />
          </Tooltip>
        </div>
      )}

      <div className="flex flex-wrap gap-3">
        <Button
          startIcon="plus"
          variant="inline"
          disabled={disabled || valuePointer?.fixedAmount !== undefined}
          onClick={() =>
            setPropertyValue({
              ...valuePointer,
              fixedAmount: '',
            })
          }
          data-test={CHARGE_PERCENTAGE_ADD_FIXED_FEE_TEST_ID}
        >
          {translate('text_62ff5d01a306e274d4ffcc5d')}
        </Button>

        <Popper
          PopperProps={{ placement: 'bottom-end' }}
          opener={
            <Button
              startIcon="plus"
              endIcon="chevron-down"
              variant="inline"
              disabled={
                disabled ||
                (valuePointer?.freeUnitsPerEvents !== undefined &&
                  valuePointer?.freeUnitsPerTotalAggregation !== undefined)
              }
              data-test={CHARGE_PERCENTAGE_ADD_FREE_UNITS_TEST_ID}
            >
              {translate('text_62ff5d01a306e274d4ffcc61')}
            </Button>
          }
        >
          {({ closePopper }) => (
            <MenuPopper>
              <Button
                className="justify-start"
                variant="quaternary"
                disabled={disabled || valuePointer?.freeUnitsPerEvents !== undefined}
                onClick={() => {
                  setPropertyValue({
                    ...valuePointer,
                    freeUnitsPerEvents: '',
                  })
                  closePopper()
                }}
                data-test="add-free-units-events"
              >
                {translate('text_62ff5d01a306e274d4ffcc3e')}
              </Button>
              <Button
                className="justify-start"
                variant="quaternary"
                disabled={disabled || valuePointer?.freeUnitsPerTotalAggregation !== undefined}
                onClick={() => {
                  setPropertyValue({
                    ...valuePointer,
                    freeUnitsPerTotalAggregation: '',
                  })

                  closePopper()
                }}
                data-test="add-free-units-total-amount"
              >
                {translate('text_62ff5d01a306e274d4ffcc44')}
              </Button>
            </MenuPopper>
          )}
        </Popper>

        <Popper
          PopperProps={{ placement: 'bottom-end' }}
          opener={
            <Button
              startIcon="plus"
              endIcon="chevron-down"
              variant="inline"
              disabled={
                disabled ||
                (valuePointer?.perTransactionMinAmount !== undefined &&
                  valuePointer?.perTransactionMaxAmount !== undefined)
              }
              data-test={CHARGE_PERCENTAGE_ADD_MIN_MAX_TEST_ID}
            >
              {translate('text_64e7b273b046851c46d78235')}
            </Button>
          }
        >
          {({ closePopper }) => (
            <MenuPopper>
              <Button
                className="justify-start"
                variant="quaternary"
                endIcon={isPremium ? undefined : 'sparkles'}
                disabled={disabled || valuePointer?.perTransactionMinAmount !== undefined}
                onClick={() => {
                  if (isPremium) {
                    setPropertyValue({
                      ...valuePointer,
                      perTransactionMinAmount: '',
                    })
                  } else {
                    openPremiumWarningDialog()
                  }

                  closePopper()
                }}
                data-test={CHARGE_PERCENTAGE_ADD_MIN_CTA_TEST_ID}
              >
                {translate('text_64e7b273b046851c46d781e5')}
              </Button>
              <Button
                className="justify-start"
                variant="quaternary"
                endIcon={isPremium ? undefined : 'sparkles'}
                disabled={disabled || valuePointer?.perTransactionMaxAmount !== undefined}
                onClick={() => {
                  if (isPremium) {
                    setPropertyValue({
                      ...valuePointer,
                      perTransactionMaxAmount: '',
                    })
                  } else {
                    openPremiumWarningDialog()
                  }

                  closePopper()
                }}
                data-test={CHARGE_PERCENTAGE_ADD_MAX_CTA_TEST_ID}
              >
                {translate('text_64e7b273b046851c46d78205')}
              </Button>
            </MenuPopper>
          )}
        </Popper>
      </div>

      <Alert type="info">
        <Typography color="textSecondary">
          {translate('text_62ff5d01a306e274d4ffcc65', {
            percentageFee: intlFormatNumber(Number(valuePointer?.rate) / 100 || 0, {
              maximumFractionDigits: 15,
              style: 'percent',
            }),
          })}
        </Typography>

        {(showFreeUnitsPerEvents || showFreeUnitsPerTotalAggregation) && (
          <Typography color="textSecondary">
            {showFreeUnitsPerEvents &&
              translate(
                'text_62ff5d01a306e274d4ffcc6d',
                {
                  freeEventUnits: valuePointer?.freeUnitsPerEvents || 0,
                },
                Math.max(Number(valuePointer?.freeUnitsPerEvents) || 0),
              )}

            {/* Spaces bellow are important */}
            {showFreeUnitsPerEvents &&
              showFreeUnitsPerTotalAggregation &&
              ` ${translate('text_6303351deffd2a0d70498675')} `}

            {showFreeUnitsPerTotalAggregation && freeUnitsPerTotalAggregationTranslation}

            {` ${translate(
              'text_6303351deffd2a0d70498679',
              {
                freeEventUnits: valuePointer?.freeUnitsPerEvents || 0,
              },
              (valuePointer?.freeUnitsPerEvents || 0) < 2 && !showFreeUnitsPerTotalAggregation
                ? 1
                : 2,
            )}`}
          </Typography>
        )}

        {showFixedAmount && (
          <Typography color="textSecondary">
            {translate('text_62ff5d01a306e274d4ffcc69', {
              fixedFeeValue: intlFormatNumber(Number(valuePointer?.fixedAmount) || 0, {
                currency,
                currencyDisplay: 'symbol',
                maximumFractionDigits: 15,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
            })}
          </Typography>
        )}

        {/* Min max alert message */}
        {!!showPerTransactionMinAmount && !showPerTransactionMaxAmount && (
          <Typography color="textSecondary">
            {translate('text_64e7b273b046851c46d78241', {
              minAmount: intlFormatNumber(Number(valuePointer?.perTransactionMinAmount || 0), {
                pricingUnitShortName: chargePricingUnitShortName,
                currency,
                currencyDisplay: 'symbol',
                minimumFractionDigits: 2,
              }),
            })}
          </Typography>
        )}
        {!showPerTransactionMinAmount && !!showPerTransactionMaxAmount && (
          <Typography color="textSecondary">
            {translate('text_64e7b273b046851c46d78245', {
              maxAmount: intlFormatNumber(Number(valuePointer?.perTransactionMaxAmount || 0), {
                currency,
                currencyDisplay: 'symbol',
                minimumFractionDigits: 2,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
            })}
          </Typography>
        )}
        {!!showPerTransactionMinAmount && !!showPerTransactionMaxAmount && (
          <Typography color="textSecondary">
            {translate('text_64e7b273b046851c46d78250', {
              minAmount: intlFormatNumber(Number(valuePointer?.perTransactionMinAmount || 0), {
                currency,
                currencyDisplay: 'symbol',
                minimumFractionDigits: 2,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
              maxAmount: intlFormatNumber(Number(valuePointer?.perTransactionMaxAmount || 0), {
                currency,
                currencyDisplay: 'symbol',
                minimumFractionDigits: 2,
                pricingUnitShortName: chargePricingUnitShortName,
              }),
            })}
          </Typography>
        )}
      </Alert>
    </>
  )
})

ChargePercentage.displayName = 'ChargePercentage'
