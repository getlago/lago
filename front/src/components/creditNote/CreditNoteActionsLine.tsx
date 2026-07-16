import InputAdornment from '@mui/material/InputAdornment'
import { FormikProps, getIn } from 'formik'
import { FC } from 'react'

import { CreditNoteForm } from '~/components/creditNote/types'
import { Typography } from '~/components/designSystem/Typography'
import { AmountInputField } from '~/components/form'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'

interface CreditNoteActionsLineProps {
  details: string
  label: string
  formikProps: FormikProps<Partial<CreditNoteForm>>
  currency: CurrencyEnum
  name: string
  error?: string
  hasError?: boolean
  disabled?: boolean
  testId?: string
  showErrorOnlyWhenTouched?: boolean
}

export const CreditNoteActionsLine: FC<CreditNoteActionsLineProps> = ({
  details,
  label,
  formikProps,
  currency,
  name,
  hasError,
  error,
  disabled,
  testId = '',
  showErrorOnlyWhenTouched = false,
}) => {
  const currencySymbol = getCurrencySymbol(currency)
  const isTouched = getIn(formikProps.touched, name)
  const shouldShowError = showErrorOnlyWhenTouched
    ? isTouched && (!!error || hasError)
    : !!error || hasError

  return (
    <div>
      <div className="flex items-center justify-between">
        <div>
          <Typography variant="bodyHl" color="grey700">
            {label}
          </Typography>
          {details && (
            <Typography variant="caption" color="grey600">
              {details}
            </Typography>
          )}
        </div>

        <AmountInputField
          name={name}
          formikProps={formikProps}
          currency={currency}
          className="max-w-42"
          beforeChangeFormatter={['positiveNumber']}
          error={shouldShowError}
          disabled={disabled}
          inputProps={{ style: { textAlign: 'right' } }}
          InputProps={
            currency && {
              startAdornment: <InputAdornment position="start">{currencySymbol}</InputAdornment>,
            }
          }
          data-test={testId}
        />
      </div>
      {shouldShowError && (
        <Typography variant="caption" color="danger600" className="mt-1 text-right">
          {error}
        </Typography>
      )}
    </div>
  )
}
