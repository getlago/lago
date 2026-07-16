import { gql } from '@apollo/client'
import { memo } from 'react'

import { Alert } from '~/components/designSystem/Alert'
import { Typography } from '~/components/designSystem/Typography'
import { appliedTaxEnumedTaxCodeTranslationKey } from '~/core/constants/form'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  FeeForInvoiceDetailsTableFooterFragment,
  InvoiceForDetailsTableFooterFragment,
  InvoiceStatusTypeEnum,
  InvoiceTaxStatusTypeEnum,
  InvoiceTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment FeeForInvoiceDetailsTableFooter on Fee {
    id
    amountCents
  }

  fragment InvoiceForDetailsTableFooter on Invoice {
    couponsAmountCents
    creditNotesAmountCents
    subTotalExcludingTaxesAmountCents
    subTotalIncludingTaxesAmountCents
    totalAmountCents
    totalDueAmountCents
    totalSettledAmountCents
    currency
    invoiceType
    status
    taxStatus
    prepaidCreditAmountCents
    prepaidGrantedCreditAmountCents
    prepaidPurchasedCreditAmountCents
    progressiveBillingCreditAmountCents
    versionNumber
    appliedTaxes {
      id
      amountCents
      feesAmountCents
      taxableAmountCents
      taxRate
      taxName
      taxCode
      enumedTaxCode
    }
  }
`

interface InvoiceDetailsTableFooterProps {
  canHaveUnitPrice: boolean
  invoice: InvoiceForDetailsTableFooterFragment
  hasTaxProviderError?: boolean
  invoiceFees?: FeeForInvoiceDetailsTableFooterFragment[] | null
  isRegenerateFlow?: boolean
}

const applyTaxRateToAmount = (amount: number, tax: { taxRate: number }) => {
  return (amount * (tax.taxRate || 0)) / 100
}

const computeSubtotal = (
  invoice: InvoiceForDetailsTableFooterFragment,
  invoiceFees: InvoiceDetailsTableFooterProps['invoiceFees'],
) => {
  if (invoiceFees) {
    const subTotalExcludingTax = invoiceFees.reduce((p, c) => {
      return p + Number(c.amountCents)
    }, 0)

    const totalRate = invoice?.appliedTaxes?.reduce((p, c) => p + c.taxRate, 0) || 0

    const subTotalIncludingTaxesAmountCents =
      subTotalExcludingTax + applyTaxRateToAmount(subTotalExcludingTax, { taxRate: totalRate })

    const progressiveBillingCreditAmountCents = Number(
      invoice?.progressiveBillingCreditAmountCents || 0,
    )

    const totalAmountCents = subTotalIncludingTaxesAmountCents - progressiveBillingCreditAmountCents

    return {
      subTotalExcludingTax,
      subTotalIncludingTaxesAmountCents,
      totalAmountCents,
      totalDueAmountCents: totalAmountCents - invoice?.totalSettledAmountCents,
    }
  }

  return {
    subTotalExcludingTax: invoice?.subTotalExcludingTaxesAmountCents,
    subTotalIncludingTaxesAmountCents: invoice?.subTotalIncludingTaxesAmountCents,
    totalAmountCents: invoice?.totalAmountCents,
    totalDueAmountCents: invoice?.totalDueAmountCents,
  }
}

export const CREDIT_ROW_GRANTED_TEST_ID = 'credit-row-granted'
export const CREDIT_ROW_PURCHASED_TEST_ID = 'credit-row-purchased'
export const CREDIT_ROW_LEGACY_TEST_ID = 'credit-row-legacy'
export const REGENERATE_ALERT_TEST_ID = 'invoice-details-table-footer-regenerate-alert'

const CreditRow = ({
  label,
  amountCents,
  currency,
  colSpan,
  dataTest,
}: {
  label: string
  amountCents?: number
  currency: CurrencyEnum
  colSpan: number
  dataTest?: string
}) => (
  <tr data-test={dataTest}>
    <td></td>
    <td colSpan={colSpan}>
      <Typography variant="bodyHl" color="grey600">
        {label}
      </Typography>
    </td>

    <td>
      <Typography variant="body" color="success600">
        -
        {intlFormatNumber(deserializeAmount(amountCents || 0, currency), {
          currencyDisplay: 'symbol',
          currency,
        })}
      </Typography>
    </td>
  </tr>
)

export const InvoiceDetailsTableFooter = memo(
  ({
    canHaveUnitPrice,
    invoice,
    hasTaxProviderError,
    invoiceFees,
    isRegenerateFlow,
  }: InvoiceDetailsTableFooterProps) => {
    const { translate } = useInternationalization()

    const colSpan = canHaveUnitPrice ? 3 : 2
    const isLegacyInvoice = invoice?.versionNumber < 3
    const currency = invoice?.currency || CurrencyEnum.Usd
    const hasCreditNotes = !!Number(invoice?.creditNotesAmountCents) && !isRegenerateFlow
    const hasPrepaidCredit = !!Number(invoice?.prepaidCreditAmountCents) && !isRegenerateFlow
    const hasGrantedCredit = !!Number(invoice?.prepaidGrantedCreditAmountCents) && !isRegenerateFlow
    const hasPurchasedCredit =
      !!Number(invoice?.prepaidPurchasedCreditAmountCents) && !isRegenerateFlow
    const hasCoupon = !!Number(invoice?.couponsAmountCents) && !isRegenerateFlow
    const isPending = invoice.status === InvoiceStatusTypeEnum.Pending

    const shouldDisplayPlaceholder = isPending || hasTaxProviderError
    const shouldDisplayCouponRow = invoice.status !== InvoiceStatusTypeEnum.Draft && hasCoupon
    const shouldDisplayPrepaidCreditRow =
      invoice.status !== InvoiceStatusTypeEnum.Draft &&
      (hasPrepaidCredit || hasGrantedCredit || hasPurchasedCredit)

    const {
      subTotalExcludingTax,
      subTotalIncludingTaxesAmountCents,
      totalAmountCents,
      totalDueAmountCents,
    } = computeSubtotal(invoice, invoiceFees)

    return (
      <tfoot>
        {isRegenerateFlow && (
          <tr>
            <td></td>
            <td colSpan={colSpan + 1}>
              <Alert type="info" data-test={REGENERATE_ALERT_TEST_ID}>
                {translate('text_1777385516575oti5gavf3ze')}
              </Alert>
            </td>
          </tr>
        )}
        {invoice.invoiceType !== InvoiceTypeEnum.Credit && (
          <>
            {!!Number(invoice.progressiveBillingCreditAmountCents) && (
              <tr>
                <td></td>
                <td colSpan={colSpan}>
                  <Typography variant="bodyHl" color="grey600">
                    {translate('text_1724936123802q74m2xxak3o')}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="success600">
                    -
                    {intlFormatNumber(
                      deserializeAmount(
                        invoice?.progressiveBillingCreditAmountCents || 0,
                        currency,
                      ),
                      {
                        currencyDisplay: 'symbol',
                        currency,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            {shouldDisplayCouponRow && !isLegacyInvoice && (
              <tr>
                <td></td>
                <td colSpan={colSpan}>
                  <Typography variant="bodyHl" color="grey600">
                    {translate('text_637ccf8133d2c9a7d11ce705')}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="success600">
                    -
                    {intlFormatNumber(
                      deserializeAmount(invoice?.couponsAmountCents || 0, currency),
                      {
                        currencyDisplay: 'symbol',
                        currency,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            <tr>
              <td></td>
              <td colSpan={colSpan}>
                <Typography variant="bodyHl" color="grey600">
                  {translate('text_637ccf8133d2c9a7d11ce6f9')}
                </Typography>
              </td>
              <td>
                <Typography
                  variant="body"
                  color="grey700"
                  data-test="invoice-details-table-footer-subtotal-excl-tax-value"
                >
                  {intlFormatNumber(deserializeAmount(subTotalExcludingTax || 0, currency), {
                    currencyDisplay: 'symbol',
                    currency,
                  })}
                </Typography>
              </td>
            </tr>
            {shouldDisplayPlaceholder && (
              <tr>
                <td></td>
                <td colSpan={colSpan}>
                  <Typography variant="bodyHl" color="grey600">
                    {`${translate('text_637ccf8133d2c9a7d11ce6fd')}`}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="grey700">
                    -
                  </Typography>
                </td>
              </tr>
            )}
            {!shouldDisplayPlaceholder && !!invoice.appliedTaxes?.length && (
              <>
                {invoice.appliedTaxes.map((appliedTax, i) => (
                  <tr key={`invoice-details-table-footer-tax-${appliedTax.id}`}>
                    <td></td>
                    <td colSpan={colSpan}>
                      <Typography
                        variant="bodyHl"
                        color="grey600"
                        data-test={`invoice-details-table-footer-tax-${i}-label`}
                      >
                        <>
                          {!!appliedTax.enumedTaxCode ? (
                            <>
                              {translate(
                                appliedTaxEnumedTaxCodeTranslationKey[appliedTax.enumedTaxCode],
                              )}
                            </>
                          ) : (
                            <>
                              {translate('text_64c013a424ce2f00dffb7f4d', {
                                name: appliedTax.taxName,
                                rate: intlFormatNumber(appliedTax.taxRate / 100 || 0, {
                                  style: 'percent',
                                }),
                                amount: intlFormatNumber(
                                  deserializeAmount(
                                    invoiceFees
                                      ? subTotalExcludingTax
                                      : appliedTax.taxableAmountCents || 0,
                                    currency,
                                  ),
                                  {
                                    currencyDisplay: 'symbol',
                                    currency,
                                  },
                                ),
                              })}
                            </>
                          )}
                        </>
                      </Typography>
                    </td>
                    <td>
                      {!appliedTax.enumedTaxCode && (
                        <Typography
                          variant="body"
                          color="grey700"
                          data-test={`invoice-details-table-footer-tax-${i}-value`}
                        >
                          {intlFormatNumber(
                            deserializeAmount(
                              invoiceFees
                                ? applyTaxRateToAmount(subTotalExcludingTax, appliedTax)
                                : appliedTax.amountCents || 0,
                              currency,
                            ),
                            {
                              currencyDisplay: 'symbol',
                              currency,
                            },
                          )}
                        </Typography>
                      )}
                    </td>
                  </tr>
                ))}
              </>
            )}
            {!shouldDisplayPlaceholder && !invoice.appliedTaxes?.length && (
              <tr>
                <td></td>
                <td colSpan={colSpan}>
                  <Typography variant="bodyHl" color="grey600">
                    {`${translate('text_637ccf8133d2c9a7d11ce6fd')} (0%)`}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="grey700">
                    {intlFormatNumber(0, {
                      currencyDisplay: 'symbol',
                      currency,
                    })}
                  </Typography>
                </td>
              </tr>
            )}
            <tr>
              <td></td>
              <td colSpan={colSpan}>
                <Typography variant="bodyHl" color="grey600">
                  {translate('text_637ccf8133d2c9a7d11ce701')}
                </Typography>
              </td>
              <td>
                <Typography
                  variant="body"
                  color="grey700"
                  data-test="invoice-details-table-footer-subtotal-incl-tax-value"
                >
                  {shouldDisplayPlaceholder
                    ? '-'
                    : intlFormatNumber(
                        deserializeAmount(subTotalIncludingTaxesAmountCents || 0, currency),
                        {
                          currencyDisplay: 'symbol',
                          currency,
                        },
                      )}
                </Typography>
              </td>
            </tr>
          </>
        )}

        {hasCreditNotes && (
          <tr>
            <td></td>
            <td colSpan={colSpan}>
              <Typography variant="bodyHl" color="grey600">
                {translate('text_637ccf8133d2c9a7d11ce708')}
              </Typography>
            </td>
            <td>
              <Typography variant="body" color="success600">
                -
                {intlFormatNumber(
                  deserializeAmount(invoice?.creditNotesAmountCents || 0, currency),
                  {
                    currencyDisplay: 'symbol',
                    currency,
                  },
                )}
              </Typography>
            </td>
          </tr>
        )}

        {shouldDisplayCouponRow && !!isLegacyInvoice && (
          <tr>
            <td></td>
            <td colSpan={colSpan}>
              <Typography variant="bodyHl" color="grey600">
                {translate('text_637ccf8133d2c9a7d11ce705')}
              </Typography>
            </td>
            <td>
              <Typography variant="body" color="success600">
                -
                {intlFormatNumber(deserializeAmount(invoice?.couponsAmountCents || 0, currency), {
                  currencyDisplay: 'symbol',
                  currency,
                })}
              </Typography>
            </td>
          </tr>
        )}

        {shouldDisplayPrepaidCreditRow && (
          <>
            {hasGrantedCredit && (
              <CreditRow
                dataTest={CREDIT_ROW_GRANTED_TEST_ID}
                label={translate('text_17703831122275shrjoh1tl4')}
                amountCents={invoice?.prepaidGrantedCreditAmountCents}
                currency={currency}
                colSpan={colSpan}
              />
            )}

            {hasPurchasedCredit && (
              <CreditRow
                dataTest={CREDIT_ROW_PURCHASED_TEST_ID}
                label={translate('text_17703831122271vwmiptfx10')}
                amountCents={invoice?.prepaidPurchasedCreditAmountCents}
                currency={currency}
                colSpan={colSpan}
              />
            )}

            {!hasGrantedCredit && !hasPurchasedCredit && (
              <CreditRow
                dataTest={CREDIT_ROW_LEGACY_TEST_ID}
                label={translate('text_6391f05df4bf96d81f3660a7')}
                amountCents={invoice?.prepaidCreditAmountCents}
                currency={currency}
                colSpan={colSpan}
              />
            )}
          </>
        )}

        {/* Total  */}
        <tr>
          <td></td>
          <td colSpan={colSpan}>
            <Typography variant="bodyHl" color="grey700">
              {invoice.invoiceType === InvoiceTypeEnum.Credit
                ? translate('text_63887b52e514213fed57fc1c')
                : translate('text_1738063764295zomiafl8b4s')}
            </Typography>
          </td>
          <td>
            <Typography
              variant="body"
              color="grey700"
              data-test="invoice-details-table-footer-total-value"
            >
              {shouldDisplayPlaceholder
                ? '-'
                : intlFormatNumber(deserializeAmount(totalAmountCents || 0, currency), {
                    currencyDisplay: 'symbol',
                    currency,
                  })}
            </Typography>
          </td>
        </tr>
        <tr>
          <td></td>
          <td colSpan={colSpan}>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_1738063681339ucxmt3asspd')}
            </Typography>
          </td>
          <td>
            <Typography
              variant="body"
              color="grey700"
              data-test="invoice-details-table-footer-total-paid-value"
            >
              {shouldDisplayPlaceholder
                ? '-'
                : intlFormatNumber(
                    deserializeAmount(-invoice?.totalSettledAmountCents || 0, currency),
                    {
                      currencyDisplay: 'symbol',
                      currency,
                    },
                  )}
            </Typography>
          </td>
        </tr>
        <tr>
          <td></td>
          <td colSpan={colSpan}>
            <Typography variant="bodyHl" color="grey700">
              {translate('text_17374735502775afvcm9pqxk')}
            </Typography>
          </td>
          <td>
            <Typography
              variant="body"
              color="grey700"
              data-test="invoice-details-table-footer-total-due-value"
            >
              {shouldDisplayPlaceholder
                ? '-'
                : intlFormatNumber(deserializeAmount(totalDueAmountCents || 0, currency), {
                    currencyDisplay: 'symbol',
                    currency,
                  })}
            </Typography>
          </td>
        </tr>

        {invoice.status === InvoiceStatusTypeEnum.Draft && (
          <tr>
            <td></td>
            <td colSpan={4} className="!shadow-none">
              <Alert type="info">{translate('text_63b6f4e9b074e3b8beebb97f')}</Alert>
            </td>
          </tr>
        )}
        {invoice.status !== InvoiceStatusTypeEnum.Draft &&
          (shouldDisplayPlaceholder || invoice.taxStatus === InvoiceTaxStatusTypeEnum.Pending) && (
            <tr>
              <td></td>
              <td colSpan={4} className="!shadow-none">
                <Alert type="info">{translate('text_1724166369123t6c4k8zn80c')}</Alert>
              </td>
            </tr>
          )}
      </tfoot>
    )
  },
)

InvoiceDetailsTableFooter.displayName = 'InvoiceDetailsTableFooter'
