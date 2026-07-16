import { CreditNoteEstimationLine } from '~/components/creditNote/CreditNoteEstimationLine'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { TaxInfo } from './useCreditNoteFormCalculation'

export const CREDIT_ONLY_AMOUNT_LINE_TEST_ID = 'credit-only-amount-line'

interface CreditNoteFormCalculationProps {
  hasError: boolean
  currency: CurrencyEnum
  estimationLoading: boolean
  hasCouponLine: boolean
  proRatedCouponAmount: number
  totalExcludedTax: number
  taxes: Map<string, TaxInfo>
  totalTaxIncluded: number
  canOnlyCredit: boolean
}

export const CreditNoteFormCalculation = ({
  hasError,
  currency,
  estimationLoading,
  hasCouponLine,
  proRatedCouponAmount,
  totalExcludedTax,
  taxes,
  totalTaxIncluded,
  canOnlyCredit,
}: CreditNoteFormCalculationProps) => {
  const { translate } = useInternationalization()

  return (
    <div className="ml-auto flex w-full max-w-100 flex-col gap-3">
      {hasCouponLine && (
        <CreditNoteEstimationLine
          label={translate('text_644b9f17623605a945cafdbb')}
          value={
            !proRatedCouponAmount || hasError
              ? '-'
              : `-${intlFormatNumber(proRatedCouponAmount || 0, {
                  currency,
                })}`
          }
          loading={estimationLoading}
          labelColor="grey600"
          tooltipContent={translate('text_644b9f17623605a945cafdb9')}
        />
      )}

      <CreditNoteEstimationLine
        label={translate('text_636bedf292786b19d3398f02')}
        labelColor="grey600"
        loading={estimationLoading}
        value={
          !totalExcludedTax || hasError
            ? '-'
            : intlFormatNumber(totalExcludedTax, {
                currency,
              })
        }
      />

      {!totalExcludedTax && (
        <CreditNoteEstimationLine
          label={translate('text_636bedf292786b19d3398f06')}
          labelColor="grey600"
          value={'-'}
          loading={estimationLoading}
        />
      )}

      {totalExcludedTax && !!taxes?.size ? (
        Array.from(taxes.values())
          .sort((a, b) => b.taxRate - a.taxRate)
          .map((tax) => (
            <CreditNoteEstimationLine
              key={tax.label}
              label={`${tax.label} (${tax.taxRate}%)`}
              labelColor="grey600"
              value={
                !tax.amount || hasError
                  ? '-'
                  : intlFormatNumber(tax.amount, {
                      currency,
                    })
              }
              loading={estimationLoading}
              data-test={`tax-${tax.taxRate}-amount`}
            />
          ))
      ) : (
        <CreditNoteEstimationLine
          label={`${translate('text_636bedf292786b19d3398f06')} (0%)`}
          labelColor="grey600"
          value={
            hasError
              ? '-'
              : intlFormatNumber(0, {
                  currency,
                })
          }
          loading={estimationLoading}
        />
      )}

      <CreditNoteEstimationLine
        label={translate('text_636bedf292786b19d3398f0a')}
        loading={estimationLoading}
        value={
          !totalTaxIncluded || hasError
            ? '-'
            : intlFormatNumber(totalTaxIncluded, {
                currency,
              })
        }
      />

      {canOnlyCredit && (
        <CreditNoteEstimationLine
          label={translate('text_636bedf292786b19d3398f0e')}
          loading={estimationLoading}
          value={
            totalTaxIncluded === undefined || hasError
              ? '-'
              : intlFormatNumber(totalTaxIncluded, {
                  currency,
                })
          }
          data-test={CREDIT_ONLY_AMOUNT_LINE_TEST_ID}
        />
      )}
    </div>
  )
}
