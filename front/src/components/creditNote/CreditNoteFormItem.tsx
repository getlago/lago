import InputAdornment from '@mui/material/InputAdornment'
import { FormikProps } from 'formik'
import _get from 'lodash/get'

import { CreditNoteFeeErrorEnum } from '~/components/creditNote/types'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { Typography } from '~/components/designSystem/Typography'
import { AmountInputField, CheckboxField } from '~/components/form'
import { getCurrencySymbol, intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { CreditNoteForm } from './types'

interface CreditNoteFormItemProps {
  formikProps: FormikProps<Partial<CreditNoteForm>>
  currency: CurrencyEnum
  feeName: string
  formikKey: string
  maxValue: number
  feeSucceededAt?: string
  isReadOnly?: boolean
}

export const CreditNoteFormItem = ({
  formikProps,
  currency,
  formikKey,
  maxValue,
  feeName,
  feeSucceededAt,
  isReadOnly,
}: CreditNoteFormItemProps) => {
  const { translate } = useInternationalization()
  const error = _get(formikProps.errors, `${formikKey}.value`)

  return (
    <div className="flex min-h-17 items-center justify-between gap-8 py-2 shadow-b">
      <CheckboxField
        name={`${formikKey}.checked`}
        formikProps={formikProps}
        label={
          <Typography color="grey700">
            {feeName}
            <Typography variant="caption">
              {feeSucceededAt && `${feeSucceededAt} • `}
              {translate('text_636bedf292786b19d3398efc', {
                max: intlFormatNumber(deserializeAmount(maxValue || 0, currency), {
                  currencyDisplay: 'symbol',
                  currency,
                }),
              })}
            </Typography>
          </Typography>
        }
      />
      <Tooltip
        className="shrink-0"
        placement="top-end"
        title={
          error === CreditNoteFeeErrorEnum?.minZero
            ? translate('text_6374e868262bab8719eac121', {
                min: intlFormatNumber(0, {
                  currencyDisplay: 'symbol',
                  currency,
                }),
              })
            : translate('text_6374e868262bab8719eac11f', {
                max: intlFormatNumber(deserializeAmount(maxValue || 0, currency), {
                  currencyDisplay: 'symbol',
                  currency,
                }),
              })
        }
        disableHoverListener={!error}
      >
        <AmountInputField
          className="max-w-42"
          inputProps={{
            style: {
              textAlign: 'right',
            },
          }}
          name={`${formikKey}.value`}
          currency={currency}
          displayErrorText={false}
          disabled={!_get(formikProps.values, `${formikKey}.checked`) || isReadOnly}
          beforeChangeFormatter={['positiveNumber']}
          InputProps={
            currency
              ? {
                  startAdornment: (
                    <InputAdornment position="start">{getCurrencySymbol(currency)}</InputAdornment>
                  ),
                }
              : {}
          }
          formikProps={formikProps}
        />
      </Tooltip>
    </div>
  )
}
