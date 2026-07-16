import { FormikProps, getIn } from 'formik'
import { useMemo } from 'react'

import { CreditNoteActionsLine } from '~/components/creditNote/CreditNoteActionsLine'
import { Alert } from '~/components/designSystem/Alert'
import { Skeleton } from '~/components/designSystem/Skeleton'
import { Typography } from '~/components/designSystem/Typography'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum, LagoApiError } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { CreditNoteForm, PayBackErrorEnum } from './types'
import { getPayBackFields } from './utils'

interface CreditNoteFormAllocationProps {
  formikProps: FormikProps<Partial<CreditNoteForm>>
  currency: CurrencyEnum
  maxCreditableAmount: number
  maxRefundableAmount: number
  maxOffsettableAmount: number
  totalTaxIncluded: number
  estimationLoading?: boolean
}

export const CREDIT_AMOUNT_INPUT_TEST_ID = 'credit-amount-input'
export const REFUND_AMOUNT_INPUT_TEST_ID = 'refund-amount-input'
export const OFFSET_AMOUNT_INPUT_TEST_ID = 'offset-amount-input'

export const CreditNoteFormAllocation = ({
  formikProps,
  currency,
  maxCreditableAmount,
  maxRefundableAmount,
  maxOffsettableAmount,
  totalTaxIncluded,
  estimationLoading,
}: CreditNoteFormAllocationProps) => {
  const { translate } = useInternationalization()

  const maxRefundableAmountFormatted = intlFormatNumber(maxRefundableAmount, { currency })
  const maxCreditableAmountFormatted = intlFormatNumber(maxCreditableAmount, { currency })
  const maxOffsettableAmountFormatted = intlFormatNumber(maxOffsettableAmount, { currency })

  const { credit, refund, offset } = getPayBackFields(formikProps.values.payBack)

  const allocatedSoFar = credit.value + refund.value + offset.value
  const remainingToAllocate = totalTaxIncluded - allocatedSoFar

  // Check if any payBack field has been touched
  const isAnyPayBackFieldTouched =
    (credit.path && getIn(formikProps.touched, credit.path)) ||
    (refund.path && getIn(formikProps.touched, refund.path)) ||
    (offset.path && getIn(formikProps.touched, offset.path))

  const hasPayBackErrors = !!getIn(formikProps.errors, 'payBackErrors')
  const shouldShowPayBackErrors = hasPayBackErrors && isAnyPayBackFieldTouched

  const allocationCaptionColor = shouldShowPayBackErrors ? 'danger600' : 'grey600'
  const allocationValueColor = shouldShowPayBackErrors ? 'danger600' : 'grey700'

  const alertTypographyProps = useMemo(() => {
    const payBackErrors = getIn(formikProps.errors, 'payBackErrors')
    const payBackValueError = getIn(formikProps.errors, 'payBack.0.value')

    if (
      payBackErrors === PayBackErrorEnum.maxTotalInvoice ||
      payBackValueError === LagoApiError.DoesNotMatchItemAmounts
    ) {
      return {
        html: translate('text_637e334680481f653e8caa9d'),
      }
    }

    return {}
  }, [formikProps.errors, translate])

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Typography className="mb-2" variant="subhead1" color="grey700">
          {translate('text_1766135526530syun4t00t28')}
        </Typography>
        <Typography variant="caption" color="grey600">
          {translate('text_1766135526530nw5fnkx9f2x')}
        </Typography>
      </div>

      <div className="grid grid-cols-3 gap-4 rounded-xl bg-grey-100 p-4">
        <div>
          <Typography variant="caption" color="grey600">
            {translate('text_637ccf8133d2c9a7d11ce745')}
          </Typography>
          {estimationLoading ? (
            <Skeleton variant="text" color="dark" className="w-20" />
          ) : (
            <Typography variant="body" color="grey700">
              {intlFormatNumber(totalTaxIncluded, { currency })}
            </Typography>
          )}
        </div>
        <div>
          <Typography variant="caption" color={allocationCaptionColor}>
            {translate('text_1766162940956q60f79xxr11')}
          </Typography>
          {estimationLoading ? (
            <Skeleton variant="text" color="dark" className="w-20" />
          ) : (
            <Typography variant="body" color={allocationValueColor}>
              {intlFormatNumber(allocatedSoFar, { currency })}
            </Typography>
          )}
        </div>
        <div>
          <Typography variant="caption" color={allocationCaptionColor}>
            {translate('text_1766162940956fzxpt25f23k')}
          </Typography>
          {estimationLoading ? (
            <Skeleton variant="text" color="dark" className="w-20" />
          ) : (
            <Typography variant="body" color={allocationValueColor}>
              {intlFormatNumber(remainingToAllocate, { currency })}
            </Typography>
          )}
        </div>
      </div>

      {shouldShowPayBackErrors && (
        <Alert type="danger">
          <Typography variant="bodyHl" color="textSecondary">
            {translate('text_1767884759747gd07dh4ihn9')}
          </Typography>
          <Typography color="textSecondary" {...alertTypographyProps} />
        </Alert>
      )}

      <div className="flex flex-col gap-4">
        {offset.show && (
          <CreditNoteActionsLine
            details={translate('text_1767883339944hsqsrt3tg8a', {
              max: maxOffsettableAmountFormatted,
            })}
            formikProps={formikProps}
            name={offset.path}
            currency={currency}
            label={translate('text_1767883339943r32jn2ioyeu')}
            hasError={!!getIn(formikProps.errors, offset.path)}
            error={
              getIn(formikProps.errors, offset.path) === PayBackErrorEnum.maxOffset
                ? translate('text_1767890728665ukf38vdx6t3', {
                    max: maxOffsettableAmountFormatted,
                  })
                : undefined
            }
            testId={OFFSET_AMOUNT_INPUT_TEST_ID}
            showErrorOnlyWhenTouched
          />
        )}

        {refund.show && (
          <CreditNoteActionsLine
            details={translate('text_17661623560070v25swovor4', {
              max: maxRefundableAmountFormatted,
            })}
            formikProps={formikProps}
            name={refund.path}
            currency={currency}
            label={translate('text_17270794543889mcmuhfq70p')}
            hasError={!!getIn(formikProps.errors, refund.path)}
            error={
              getIn(formikProps.errors, refund.path) === PayBackErrorEnum.maxRefund
                ? translate('text_637e23e47a15bf0bd71e0d03', {
                    max: maxRefundableAmountFormatted,
                  })
                : undefined
            }
            testId={REFUND_AMOUNT_INPUT_TEST_ID}
            showErrorOnlyWhenTouched
          />
        )}

        {credit.show && (
          <CreditNoteActionsLine
            details={translate('text_1766162519559r3f2pkqdp79', {
              max: maxCreditableAmountFormatted,
            })}
            formikProps={formikProps}
            name={credit.path}
            currency={currency}
            label={translate('text_637d0e720ace4ea09aaf0630')}
            hasError={!!getIn(formikProps.errors, credit.path)}
            error={
              getIn(formikProps.errors, credit.path) === PayBackErrorEnum.maxCredit
                ? translate('text_1738751394771xq525lyxj9k', {
                    max: maxCreditableAmountFormatted,
                  })
                : undefined
            }
            testId={CREDIT_AMOUNT_INPUT_TEST_ID}
            showErrorOnlyWhenTouched
          />
        )}
      </div>
    </div>
  )
}
