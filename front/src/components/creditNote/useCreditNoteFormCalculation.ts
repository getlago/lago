import { gql } from '@apollo/client'
import { FormikProps } from 'formik'
import { debounce } from 'lodash'
import { useCallback, useEffect, useMemo } from 'react'
import { array, number, object, Schema, string, ValidationError } from 'yup'

import { deserializeAmount, getCurrencyPrecision } from '~/core/serializers/serializeAmount'
import {
  CreditNoteItemInput,
  CurrencyEnum,
  InvoiceForCreditNoteFormCalculationFragment,
  InvoiceTypeEnum,
  useCreditNoteEstimateLazyQuery,
} from '~/generated/graphql'
import { DEBOUNCE_SEARCH_MS } from '~/hooks/useDebouncedSearch'

import { CreditNoteForm, PayBackErrorEnum } from './types'
import { getPayBackFields } from './utils'

gql`
  fragment InvoiceForCreditNoteFormCalculation on Invoice {
    id
    couponsAmountCents
    paymentStatus
    creditableAmountCents
    refundableAmountCents
    feesAmountCents
    currency
    versionNumber
    paymentDisputeLostAt
    totalPaidAmountCents
    totalAmountCents
    totalDueAmountCents
    invoiceType
    fees {
      id
      appliedTaxes {
        id
        taxName
        taxRate
      }
    }
  }

  query creditNoteEstimate($invoiceId: ID!, $items: [CreditNoteItemInput!]!) {
    creditNoteEstimate(invoiceId: $invoiceId, items: $items) {
      appliedTaxes {
        taxCode
        taxName
        taxRate
        amountCents
      }
      couponsAdjustmentAmountCents
      currency
      items {
        amountCents
        fee {
          id
        }
      }
      maxCreditableAmountCents
      maxRefundableAmountCents
      maxOffsettableAmountCents
      subTotalExcludingTaxesAmountCents
      taxesAmountCents
      taxesRate
    }
  }
`

export interface TaxInfo {
  label: string
  taxRate: number
  amount: number
}

interface UseCreditNoteFormCalculationProps {
  invoice?: InvoiceForCreditNoteFormCalculationFragment
  formikProps: FormikProps<Partial<CreditNoteForm>>
  feeForEstimate: CreditNoteItemInput[] | undefined
  setPayBackValidation: (value: Schema) => void
}

interface UseCreditNoteFormCalculationReturn {
  // Calculated values
  maxCreditableAmount: number
  maxRefundableAmount: number
  maxOffsettableAmount: number
  proRatedCouponAmount: number
  taxes: Map<string, TaxInfo>
  totalExcludedTax: number
  totalTaxIncluded: number
  amountDue: number
  // Derived flags
  canOnlyCredit: boolean
  hasCouponLine: boolean
  isInvoiceFullyPaid: boolean
  // Loading/error state
  estimationLoading: boolean
  // Invoice-derived values
  currency: CurrencyEnum
}

export const useCreditNoteFormCalculation = ({
  invoice,
  formikProps,
  feeForEstimate,
  setPayBackValidation,
}: UseCreditNoteFormCalculationProps): UseCreditNoteFormCalculationReturn => {
  const totalPaidAmountCents = Number(invoice?.totalPaidAmountCents) || 0
  const totalDueAmountCents = Number(invoice?.totalDueAmountCents) || 0
  const hasNoPayment = totalPaidAmountCents === 0
  const isInvoiceFullyPaid = totalDueAmountCents <= 0

  const isPrepaidCreditsInvoice = invoice?.invoiceType === InvoiceTypeEnum.Credit
  const currency = invoice?.currency || CurrencyEnum.Usd
  const currencyPrecision = getCurrencyPrecision(currency)
  const isLegacyInvoice = (invoice?.versionNumber || 0) < 3
  const hasCouponLine = Number(invoice?.couponsAmountCents || 0) > 0 && !isLegacyInvoice
  const amountDue = deserializeAmount(totalDueAmountCents, currency)

  const canOnlyCredit = hasNoPayment || !!invoice?.paymentDisputeLostAt

  const [
    getEstimate,
    { data: estimationData, error: estimationError, loading: estimationLoading },
  ] = useCreditNoteEstimateLazyQuery()

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const debouncedQuery = useCallback(
    debounce(() => {
      getEstimate &&
        invoice?.id &&
        feeForEstimate &&
        getEstimate({
          variables: {
            invoiceId: invoice?.id,
            items: feeForEstimate,
          },
        })
    }, DEBOUNCE_SEARCH_MS),
    [invoice?.id, feeForEstimate, getEstimate],
  )

  useEffect(() => {
    debouncedQuery()

    return () => {
      debouncedQuery.cancel()
    }
  }, [getEstimate, debouncedQuery, feeForEstimate, formikProps.values.fees, invoice?.id])

  const {
    maxCreditableAmount,
    maxRefundableAmount,
    maxOffsettableAmount,
    proRatedCouponAmount,
    taxes,
    totalExcludedTax,
    totalTaxIncluded,
  } = useMemo(() => {
    const isError =
      estimationError ||
      estimationData?.creditNoteEstimate === null ||
      estimationData?.creditNoteEstimate === undefined

    if (isError) {
      return {
        maxCreditableAmount: 0,
        maxRefundableAmount: 0,
        maxOffsettableAmount: 0,
        totalTaxIncluded: 0,
        proRatedCouponAmount: 0,
        totalExcludedTax: 0,
        taxes: new Map(),
        hasCreditOrCoupon: false,
      }
    }

    const {
      maxCreditableAmountCents,
      maxRefundableAmountCents,
      maxOffsettableAmountCents,
      subTotalExcludingTaxesAmountCents,
      taxesAmountCents,
      couponsAdjustmentAmountCents,
      appliedTaxes,
    } = estimationData?.creditNoteEstimate || {}

    return {
      maxCreditableAmount: deserializeAmount(maxCreditableAmountCents || 0, currency),
      maxRefundableAmount: deserializeAmount(maxRefundableAmountCents || 0, currency),
      maxOffsettableAmount: deserializeAmount(maxOffsettableAmountCents || 0, currency),
      totalTaxIncluded: deserializeAmount(
        (Number(subTotalExcludingTaxesAmountCents) || 0) + (Number(taxesAmountCents) || 0),
        currency,
      ),
      proRatedCouponAmount: deserializeAmount(couponsAdjustmentAmountCents || 0, currency),
      totalExcludedTax: deserializeAmount(subTotalExcludingTaxesAmountCents || 0, currency),
      taxes: new Map(
        appliedTaxes?.map((tax) => [
          tax.taxCode,
          {
            label: tax.taxName,
            taxRate: tax.taxRate,
            amount: deserializeAmount(tax.amountCents || 0, currency),
          },
        ]),
      ),
    }
  }, [currency, estimationData?.creditNoteEstimate, estimationError])

  useEffect(() => {
    // Skip validation setup for prepaid credits invoices
    // They use a different payBack structure (single refund element)
    // and don't use the estimation API
    if (isPrepaidCreditsInvoice) {
      setPayBackValidation(array())
      return
    }

    setPayBackValidation(
      array()
        .of(
          object().shape({
            type: string().required(''),
            value: number(),
          }),
        )
        .test({
          test: (payback, { createError }) => {
            const {
              credit: creditFields,
              refund: refundFields,
              offset: offsetFields,
            } = getPayBackFields(payback)
            const errors: ValidationError[] = []

            // Check if the sum of credit, refund and offset is different than the total tax included
            const sum = creditFields.value + refundFields.value + offsetFields.value
            const sumPrecision = Number(sum.toFixed(currencyPrecision))
            const totalPrecision = Number(totalTaxIncluded.toFixed(currencyPrecision))

            // Sum error goes to payBackErrors to show Alert
            if (sumPrecision !== totalPrecision) {
              errors.push(
                createError({
                  message: PayBackErrorEnum.maxTotalInvoice,
                  path: 'payBackErrors',
                }),
              )
            }
            // Individual field errors go to specific field paths
            if (refundFields.show && refundFields.value > maxRefundableAmount) {
              errors.push(
                createError({
                  message: PayBackErrorEnum.maxRefund,
                  path: refundFields.path,
                }),
              )
            }
            if (creditFields.show && creditFields.value > maxCreditableAmount) {
              errors.push(
                createError({
                  message: PayBackErrorEnum.maxCredit,
                  path: creditFields.path,
                }),
              )
            }
            if (offsetFields.show && offsetFields.value > maxOffsettableAmount) {
              errors.push(
                createError({
                  message: PayBackErrorEnum.maxOffset,
                  path: offsetFields.path,
                }),
              )
            }

            return errors.length ? new ValidationError(errors) : true
          },
        }),
    )
  }, [
    currencyPrecision,
    canOnlyCredit,
    isPrepaidCreditsInvoice,
    maxOffsettableAmount,
    maxCreditableAmount,
    maxRefundableAmount,
    setPayBackValidation,
    totalTaxIncluded,
  ])

  return {
    // Calculated values
    maxCreditableAmount,
    maxRefundableAmount,
    maxOffsettableAmount,
    proRatedCouponAmount,
    taxes,
    totalExcludedTax,
    totalTaxIncluded,
    amountDue,
    // Derived flags
    canOnlyCredit,
    hasCouponLine,
    isInvoiceFullyPaid,
    // Loading/error state
    estimationLoading,
    // Invoice-derived values
    currency,
  }
}
