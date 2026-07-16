import { gql } from '@apollo/client'
import { FC, Fragment } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import formatCreditNotesItems from '~/core/formats/formatCreditNotesItems'
import {
  composeChargeFilterDisplayName,
  composeGroupedByDisplayName,
  composeMultipleValuesWithSepator,
} from '~/core/formats/formatInvoiceItemsMap'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import {
  CreditNoteDetailsForOverviewTableFragment,
  CreditNoteItem,
  CurrencyEnum,
  FeeTypesEnum,
  InvoiceTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { tw } from '~/styles/utils'

const CreditNoteTableSection: FC<{ children: React.ReactNode }> = ({ children }) => {
  const tableHeadClasses = tw(
    '[&>table>thead>tr>th]:sticky [&>table>thead>tr>th]:top-[theme("spacing.nav")] [&>table>thead>tr>th]:z-10 [&>table>thead>tr>th]:box-border [&>table>thead>tr>th]:overflow-hidden [&>table>thead>tr>th]:bg-white [&>table>thead>tr>th]:py-8 [&>table>thead>tr>th]:pb-3 [&>table>thead>tr>th]:text-right [&>table>thead>tr>th]:shadow-b [&>table>thead>tr>th]:line-break-anywhere',
    '[&>table>thead>tr>th:not(:last-child)]:pr-3',
    '[&>table>thead>tr>th:nth-child(1)]:w-[70%] [&>table>thead>tr>th:nth-child(1)]:text-left [&>table>thead>tr>th:nth-child(2)]:w-[10%] [&>table>thead>tr>th:nth-child(3)]:w-1/5',
  )

  const tableBodyClasses = tw(
    '[&>table>tbody>tr>td:not(:first-child)]:text-right [&>table>tbody>tr>td:not(:last-child)]:pr-3 [&>table>tbody>tr>td]:min-h-11 [&>table>tbody>tr>td]:overflow-hidden [&>table>tbody>tr>td]:py-3 [&>table>tbody>tr>td]:align-top [&>table>tbody>tr>td]:shadow-b [&>table>tbody>tr>td]:line-break-anywhere',
  )

  const tableFootClasses = tw(
    '[&>table>tfoot>tr>td:nth-child(2)]:text-left [&>table>tfoot>tr>td:nth-child(2)]:shadow-b [&>table>tfoot>tr>td:nth-child(3)]:shadow-b [&>table>tfoot>tr>td]:py-3 [&>table>tfoot>tr>td]:text-right',
    '[&>table>tfoot>tr>td:nth-child(1)]:w-[50%] [&>table>tfoot>tr>td:nth-child(2)]:w-[40%] [&>table>tfoot>tr>td:nth-child(3)]:w-[10%]',
  )

  return (
    <section
      className={tw(
        '[&>table]:w-full [&>table]:table-fixed [&>table]:border-collapse',
        '[&>.main-table:not(:first-child)]:mt-10',
        tableHeadClasses,
        tableBodyClasses,
        tableFootClasses,
      )}
    >
      {children}
    </section>
  )
}

gql`
  fragment CreditNoteDetailsForOverviewTable on CreditNote {
    id
    invoice {
      id
      invoiceType
      number
      purchaseOrderNumber
    }
    items {
      amountCents
      amountCurrency
      fee {
        id
        amountCents
        eventsCount
        units
        feeType
        itemName
        groupedBy
        invoiceName
        appliedTaxes {
          id
          taxRate
        }
        trueUpParentFee {
          id
        }
        charge {
          id
          billableMetric {
            id
            name
            aggregationType
          }
        }
        subscription {
          id
          name
          plan {
            id
            name
            invoiceDisplayName
          }
        }
        chargeFilter {
          invoiceDisplayName
          values
        }
      }
    }
    couponsAdjustmentAmountCents
    currency
    subTotalExcludingTaxesAmountCents
    appliedTaxes {
      id
      amountCents
      baseAmountCents
      taxRate
      taxName
    }
    offsetAmountCents
    creditAmountCents
    refundAmountCents
    totalAmountCents
  }
`

interface CreditNoteDetailsOverviewTableProps {
  loading: boolean
  creditNote?: CreditNoteDetailsForOverviewTableFragment | null
}

// Test IDs for unit testing
export const CREDIT_NOTE_DETAILS_TABLE_TEST_IDS = {
  taxRateColumn: 'credit-note-tax-rate-column',
  couponAdjustmentRow: 'credit-note-coupon-adjustment-row',
  subTotalRow: 'credit-note-sub-total-row',
  taxRow: 'credit-note-tax-row',
  zeroTaxRow: 'credit-note-zero-tax-row',
  appliedToSourceInvoiceRow: 'credit-note-applied-to-source-invoice-row',
  creditRow: 'credit-note-credit-row',
  refundRow: 'credit-note-refund-row',
  totalRow: 'credit-note-total-row',
  footer: 'credit-note-footer',
}

export const CreditNoteDetailsOverviewTable: FC<CreditNoteDetailsOverviewTableProps> = ({
  loading,
  creditNote,
}) => {
  const { translate } = useInternationalization()

  const isPrepaidCreditsInvoice = creditNote?.invoice?.invoiceType === InvoiceTypeEnum.Credit
  const groupedData = formatCreditNotesItems(creditNote?.items as CreditNoteItem[])

  const getFeeDescription = (item: CreditNoteItem, invoiceDisplayName: string) => {
    if (item?.fee?.feeType === FeeTypesEnum.AddOn) {
      return translate('text_6388baa2e514213fed583611', {
        name: item.fee.invoiceName || item?.fee?.itemName,
      })
    }

    if (item?.fee?.feeType === FeeTypesEnum.Commitment) {
      return item.fee.invoiceName || 'Minimum commitment - True up'
    }

    return composeMultipleValuesWithSepator([
      item.fee?.invoiceName || item?.fee?.charge?.billableMetric.name || invoiceDisplayName,
      composeGroupedByDisplayName(item?.fee?.groupedBy),
      composeChargeFilterDisplayName(item.fee.chargeFilter),
      item?.fee?.trueUpParentFee?.id ? ` - ${translate('text_64463aaa34904c00a23be4f7')}` : '',
    ])
  }

  return (
    <CreditNoteTableSection>
      {groupedData.map((groupSubscriptionItem, i) => {
        const subscription =
          groupSubscriptionItem[0] && groupSubscriptionItem[0][0]
            ? groupSubscriptionItem[0][0].fee.subscription
            : undefined
        const invoiceDisplayName = !!subscription
          ? subscription?.name || subscription.plan.invoiceDisplayName || subscription?.plan?.name
          : translate('text_6388b923e514213fed58331c')

        return (
          <Fragment key={`groupSubscriptionItem-${i}`}>
            <table className="main-table">
              <thead>
                <tr>
                  <th>
                    <Typography variant="captionHl" color="grey600">
                      {invoiceDisplayName}
                    </Typography>
                  </th>
                  {!isPrepaidCreditsInvoice && (
                    <th data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.taxRateColumn}>
                      <Typography variant="captionHl" color="grey600">
                        {translate('text_636bedf292786b19d3398f06')}
                      </Typography>
                    </th>
                  )}
                  <th>
                    <Typography variant="captionHl" color="grey600">
                      {translate('text_637655cb50f04bf1c8379d12')}
                    </Typography>
                  </th>
                </tr>
              </thead>
              <tbody>
                {groupSubscriptionItem.map((charge, j) => {
                  return charge.map((item, k) => {
                    return (
                      <Fragment key={`groupSubscriptionItem-${i}-list-item-${k}`}>
                        <tr key={`groupSubscriptionItem-${i}-charge-${j}-item-${k}`}>
                          <td>
                            {isPrepaidCreditsInvoice ? (
                              <Typography variant="bodyHl" color="grey700">
                                {translate('text_1729262241097k3cnpci6p5j')}
                              </Typography>
                            ) : (
                              <Typography variant="bodyHl" color="grey700">
                                {getFeeDescription(item, invoiceDisplayName)}
                              </Typography>
                            )}
                          </td>
                          {!isPrepaidCreditsInvoice && (
                            <td>
                              <Typography variant="body" color="grey700">
                                {item.fee.appliedTaxes?.length
                                  ? item.fee.appliedTaxes?.map((appliedTaxe) => (
                                      <Typography
                                        key={`fee-${item.fee.id}-applied-taxe-${appliedTaxe.id}`}
                                        variant="body"
                                        color="grey700"
                                      >
                                        {intlFormatNumber(appliedTaxe.taxRate / 100 || 0, {
                                          style: 'percent',
                                        })}
                                      </Typography>
                                    ))
                                  : '0%'}
                              </Typography>
                            </td>
                          )}
                          <td>
                            <Typography variant="body" color="success600">
                              -
                              {intlFormatNumber(
                                deserializeAmount(item.amountCents || 0, item.amountCurrency),
                                {
                                  currencyDisplay: 'symbol',
                                  currency: item.amountCurrency,
                                },
                              )}
                            </Typography>
                          </td>
                        </tr>
                      </Fragment>
                    )
                  })
                })}
              </tbody>
            </table>
          </Fragment>
        )
      })}
      {!loading && (
        <table data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.footer}>
          <tfoot>
            {Number(creditNote?.couponsAdjustmentAmountCents || 0) > 0 && (
              <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.couponAdjustmentRow}>
                <td></td>
                <td>
                  <Typography variant="bodyHl" color="grey600">
                    {translate('text_644b9f17623605a945cafdbb')}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="grey700">
                    {intlFormatNumber(
                      deserializeAmount(
                        creditNote?.couponsAdjustmentAmountCents || 0,
                        creditNote?.currency || CurrencyEnum.Usd,
                      ),
                      {
                        currencyDisplay: 'symbol',
                        currency: creditNote?.currency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            {!isPrepaidCreditsInvoice && (
              <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.subTotalRow}>
                <td></td>
                <td>
                  <Typography variant="bodyHl" color="grey600">
                    {translate('text_637655cb50f04bf1c8379d20')}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="success600">
                    -
                    {intlFormatNumber(
                      deserializeAmount(
                        creditNote?.subTotalExcludingTaxesAmountCents || 0,
                        creditNote?.currency || CurrencyEnum.Usd,
                      ),
                      {
                        currencyDisplay: 'symbol',
                        currency: creditNote?.currency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            {!!creditNote?.appliedTaxes?.length ? (
              <>
                {creditNote?.appliedTaxes.map((appliedTax) => (
                  <tr
                    key={`creditNote-${creditNote.id}-applied-tax-${appliedTax.id}`}
                    data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.taxRow}
                  >
                    <td></td>
                    <td>
                      <Typography variant="bodyHl" color="grey600">
                        {translate('text_64c013a424ce2f00dffb7f4d', {
                          name: appliedTax.taxName,
                          rate: intlFormatNumber(appliedTax.taxRate / 100 || 0, {
                            style: 'percent',
                          }),
                          amount: intlFormatNumber(
                            deserializeAmount(
                              appliedTax.baseAmountCents || 0,
                              creditNote?.currency || CurrencyEnum.Usd,
                            ),
                            {
                              currencyDisplay: 'symbol',
                              currency: creditNote?.currency || CurrencyEnum.Usd,
                            },
                          ),
                        })}
                      </Typography>
                    </td>
                    <td>
                      <Typography variant="body" color="success600">
                        -
                        {intlFormatNumber(
                          deserializeAmount(
                            appliedTax.amountCents || 0,
                            creditNote?.currency || CurrencyEnum.Usd,
                          ),
                          {
                            currencyDisplay: 'symbol',
                            currency: creditNote?.currency || CurrencyEnum.Usd,
                          },
                        )}
                      </Typography>
                    </td>
                  </tr>
                ))}
              </>
            ) : (
              <>
                {!isPrepaidCreditsInvoice && (
                  <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.zeroTaxRow}>
                    <td></td>
                    <td>
                      <Typography variant="bodyHl" color="grey600">
                        {`${translate('text_637655cb50f04bf1c8379d24')} (0%)`}
                      </Typography>
                    </td>
                    <td>
                      <Typography variant="body" color="success600">
                        -
                        {intlFormatNumber(0, {
                          currencyDisplay: 'symbol',
                          currency: creditNote?.currency || CurrencyEnum.Usd,
                        })}
                      </Typography>
                    </td>
                  </tr>
                )}
              </>
            )}

            {Number(creditNote?.offsetAmountCents || 0) > 0 && (
              <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.appliedToSourceInvoiceRow}>
                <td></td>
                <td>
                  <Typography variant="bodyHl" color="grey700">
                    {translate('text_17678874117919zdg2q55od0', {
                      invoiceNumber: creditNote?.invoice?.number,
                    })}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="success600">
                    -
                    {intlFormatNumber(
                      deserializeAmount(
                        creditNote?.offsetAmountCents || 0,
                        creditNote?.currency || CurrencyEnum.Usd,
                      ),
                      {
                        currencyDisplay: 'symbol',
                        currency: creditNote?.currency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            {Number(creditNote?.creditAmountCents || 0) > 0 && (
              <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.creditRow}>
                <td></td>
                <td>
                  <Typography variant="bodyHl" color="grey700">
                    {translate('text_637655cb50f04bf1c8379d28')}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="success600">
                    -
                    {intlFormatNumber(
                      deserializeAmount(
                        creditNote?.creditAmountCents || 0,
                        creditNote?.currency || CurrencyEnum.Usd,
                      ),
                      {
                        currencyDisplay: 'symbol',
                        currency: creditNote?.currency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            {Number(creditNote?.refundAmountCents || 0) > 0 && (
              <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.refundRow}>
                <td></td>
                <td>
                  <Typography variant="bodyHl" color="grey700">
                    {translate('text_637de077dca2f885da839287')}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="success600">
                    -
                    {intlFormatNumber(
                      deserializeAmount(
                        creditNote?.refundAmountCents || 0,
                        creditNote?.currency || CurrencyEnum.Usd,
                      ),
                      {
                        currencyDisplay: 'symbol',
                        currency: creditNote?.currency || CurrencyEnum.Usd,
                      },
                    )}
                  </Typography>
                </td>
              </tr>
            )}
            <tr data-test={CREDIT_NOTE_DETAILS_TABLE_TEST_IDS.totalRow}>
              <td></td>
              <td>
                <Typography variant="bodyHl" color="grey700">
                  {translate('text_637655cb50f04bf1c8379d2c')}
                </Typography>
              </td>
              <td>
                <Typography variant="body" color="success600">
                  -
                  {intlFormatNumber(
                    deserializeAmount(
                      creditNote?.totalAmountCents || 0,
                      creditNote?.currency || CurrencyEnum.Usd,
                    ),
                    {
                      currencyDisplay: 'symbol',
                      currency: creditNote?.currency || CurrencyEnum.Usd,
                    },
                  )}
                </Typography>
              </td>
            </tr>
          </tfoot>
        </table>
      )}
    </CreditNoteTableSection>
  )
}
