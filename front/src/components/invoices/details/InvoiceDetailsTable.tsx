import { gql } from '@apollo/client'
import { tw } from 'lago-design-system'
import { DateTime } from 'luxon'
import { FC, Fragment, memo, ReactNode, RefObject } from 'react'

import { Button } from '~/components/designSystem/Button'
import { EditFeeDrawerRef } from '~/components/invoices/details/EditFeeDrawer'
import {
  getRegenerateModeProps,
  InvoiceDetailsTableBodyLine,
} from '~/components/invoices/details/InvoiceDetailsTableBodyLine'
import { InvoiceDetailsTableFooter } from '~/components/invoices/details/InvoiceDetailsTableFooter'
import { InvoiceDetailsTableHeader } from '~/components/invoices/details/InvoiceDetailsTableHeader'
import { InvoiceDetailsTablePeriodLine } from '~/components/invoices/details/InvoiceDetailsTablePeriodLine'
import { groupAndFormatFees } from '~/core/formats/formatInvoiceItemsMap'
import { intlFormatDateTime } from '~/core/timezone'
import {
  CurrencyEnum,
  Customer,
  ErrorCodesEnum,
  FeeDetailsForInvoiceOverviewFragment,
  FeeForCreateFeeDrawerFragment,
  FeeForInvoiceDetailsTableBodyLineFragment,
  FeeForInvoiceDetailsTableBodyLineFragmentDoc,
  InvoiceForDetailsTableFooterFragmentDoc,
  InvoiceForDetailsTableFragment,
  InvoiceForFormatInvoiceItemMapFragmentDoc,
  InvoiceStatusTypeEnum,
  InvoiceTypeEnum,
} from '~/generated/graphql'
import { TranslateFunc, useInternationalization } from '~/hooks/core/useInternationalization'
import { OnRegeneratedFeeAdd } from '~/pages/CustomerInvoiceRegenerate'

// Test ID constants for testing
export const INVOICE_DETAILS_TABLE_SUBSCRIPTION_TEST_ID = 'invoice-details-subscription-table'
export const INVOICE_DETAILS_TABLE_ADD_FEE_BUTTON_TEST_ID = 'invoice-details-add-fee-button'

gql`
  fragment FeeForCustomerInvoiceRegenerate on Fee {
    id
    appliedTaxes {
      id
      taxCode
    }
  }

  fragment FeeForInvoiceDetailsTable on Fee {
    id
    amountCents
    description
    feeType
    succeededAt
    invoiceDisplayName
    invoiceName
    itemName
    units
    preciseUnitAmount
    charge {
      id
      payInAdvance
      billableMetric {
        id
        name
        aggregationType
      }
    }
    chargeFilter {
      id
      values
    }

    walletTransaction {
      id
      name
      wallet {
        id
        name
      }
    }

    ...FeeForCustomerInvoiceRegenerate
    ...FeeForInvoiceDetailsTableBodyLine
  }

  fragment InvoiceForInvoiceDetailsTable on Invoice {
    subscriptions {
      id
      name
      currentBillingPeriodStartedAt
      currentBillingPeriodEndingAt
      plan {
        id
        name
        interval
        invoiceDisplayName
        amountCents
        amountCurrency
      }
    }
    fees {
      id
      subscription {
        id
      }
      ...FeeForInvoiceDetailsTable
    }

    ...InvoiceForFormatInvoiceItemMap
  }

  fragment InvoiceForDetailsTable on Invoice {
    id
    invoiceType
    subTotalExcludingTaxesAmountCents
    subTotalIncludingTaxesAmountCents
    totalAmountCents
    currency
    issuingDate
    allChargesHaveFees
    allFixedChargesHaveFees
    versionNumber
    subscriptions {
      id
      name
      currentBillingPeriodStartedAt
      currentBillingPeriodEndingAt
      plan {
        id
        name
        interval
      }
    }
    errorDetails {
      errorCode
      errorDetails
    }

    ...InvoiceForDetailsTableFooter
    ...InvoiceForFormatInvoiceItemMap
  }

  ${InvoiceForDetailsTableFooterFragmentDoc}
  ${InvoiceForFormatInvoiceItemMapFragmentDoc}
  ${FeeForInvoiceDetailsTableBodyLineFragmentDoc}
`

const getOneTimeFeeDisplayName = ({
  invoiceType,
  fee,
  translate,
}: {
  invoiceType: InvoiceTypeEnum
  fee: FeeDetailsForInvoiceOverviewFragment
  translate: TranslateFunc
}): string => {
  if (invoiceType === InvoiceTypeEnum.AddOn) {
    return translate('text_6388baa2e514213fed583611', { name: fee.itemName })
  } else if (
    invoiceType === InvoiceTypeEnum.OneOff ||
    invoiceType === InvoiceTypeEnum.AdvanceCharges
  ) {
    return fee.invoiceDisplayName || fee.itemName
  } else if (invoiceType === InvoiceTypeEnum.Credit) {
    if (fee.walletTransaction?.wallet?.name) {
      return fee.walletTransaction?.wallet?.name
    } else if (fee.walletTransaction?.name) {
      return `${translate('text_637ccf8133d2c9a7d11ce6e1')} - ${fee.walletTransaction?.name}`
    }
  }

  return translate('text_637ccf8133d2c9a7d11ce6e1')
}

interface InvoiceDetailsTableProps {
  customer: Pick<Customer, 'id' | 'applicableTimezone'> | null | undefined
  invoice: InvoiceForDetailsTableFragment | null | undefined
  editFeeDrawerRef: RefObject<EditFeeDrawerRef>
  isDraftOverride?: boolean
  fees: FeeDetailsForInvoiceOverviewFragment[] | null | undefined
  onAdd?: OnRegeneratedFeeAdd
  onDelete?: (id: string) => void
  localFees?: FeeForCreateFeeDrawerFragment[]
}

export const InvoiceTableSection: FC<{
  children: ReactNode
  isDraftInvoice?: boolean
  canHaveUnitPrice?: boolean
  className?: string
}> = ({ children, isDraftInvoice, canHaveUnitPrice, className }) => {
  const tableHeadClasses = tw(
    '[&_table>thead>tr>th]:sticky [&_table>thead>tr>th]:top-[theme("spacing.nav")] [&_table>thead>tr>th]:z-10 [&_table>thead>tr>th]:bg-white [&_table>thead>tr>th]:pb-3 [&_table>thead>tr>th]:pt-8 [&_table>thead>tr>th]:shadow-b',
    '[&_table>thead>tr>th:not(:first-child)]:line-break-anywhere [&_table>thead>tr>th:not(:last-child)]:pr-3 [&_table>thead>tr>th:nth-child(1)]:text-left [&_table>thead>tr>th]:overflow-hidden [&_table>thead>tr>th]:text-right',
  )

  const tableBodyClasses = tw(
    '[&_table>tbody>tr>td:not(:first-child)]:line-break-anywhere [&_table>tbody>tr>td:not(:last-child)]:pr-3 [&_table>tbody>tr>td:nth-child(1)]:text-left',
    '[&_table>tbody>tr>td]:min-h-11 [&_table>tbody>tr>td]:overflow-hidden [&_table>tbody>tr>td]:py-3 [&_table>tbody>tr>td]:text-right [&_table>tbody>tr>td]:align-top [&_table>tbody>tr>td]:shadow-b',
    '[&_table>tbody>tr.has-details>td]:min-h-6 [&_table>tbody>tr.has-details>td]:pb-1 [&_table>tbody>tr.has-details>td]:pl-0 [&_table>tbody>tr.has-details>td]:pr-3 [&_table>tbody>tr.has-details>td]:pt-3 [&_table>tbody>tr.has-details>td]:shadow-none',
    '[&_table>tbody>tr.details-line>td:last-child]:pr-0 [&_table>tbody>tr.details-line>td]:min-h-6 [&_table>tbody>tr.details-line>td]:py-1 [&_table>tbody>tr.details-line>td]:pl-4 [&_table>tbody>tr.details-line>td]:pr-3 [&_table>tbody>tr.details-line>td]:align-top [&_table>tbody>tr.details-line>td]:shadow-none',
    '[&_table>tbody>tr.subtotal>td:last-child]:pr-0 [&_table>tbody>tr.subtotal>td]:pb-3 [&_table>tbody>tr.subtotal>td]:pl-4 [&_table>tbody>tr.subtotal>td]:pr-3 [&_table>tbody>tr.subtotal>td]:pt-1 [&_table>tbody>tr.subtotal>td]:shadow-b',
    '[&_table>tbody>tr.line-collapse>td]:!p-0 [&_table>tbody>tr.line-collapse>td_.collapse-header]:block [&_table>tbody>tr.line-collapse>td_.collapse-header]:w-full [&_table>tbody>tr.line-collapse>td_.collapse-header]:py-3 [&_table>tbody>tr.line-collapse>td_.collapse-header]:shadow-b',
  )

  const tableFootClasses = tw(
    '[&_table>tfoot>tr>td]:px-0 [&_table>tfoot>tr>td]:py-3 [&_table>tfoot>tr>td]:text-right',
    '[&_table>tfoot>tr>td:nth-child(2)]:text-left [&_table>tfoot>tr>td:nth-child(2)]:shadow-b [&_table>tfoot>tr>td:nth-child(3)]:shadow-b [&_table>tfoot>tr>td:nth-child(3)]:line-break-anywhere',
    '[&_table>tfoot>tr>td:nth-child(1)]:w-[50%] [&_table>tfoot>tr>td:nth-child(2)]:w-[35%] [&_table>tfoot>tr>td:nth-child(3)]:w-[15%]',
  )

  let tableStructureClasses: string

  const actionColumnClasses = tw(
    '[&_table>tbody>tr>td:last-child]:size-6 [&_table>tbody>tr>td:last-child]:overflow-visible [&_table>tbody>tr>td:last-child]:pr-0 [&_table>tbody>tr>td:last-child]:pt-[10px] [&_table>tbody>tr>td:nth-last-child(2)]:!pr-3',
  )

  if (isDraftInvoice) {
    tableStructureClasses = tw(
      '[&_table>thead>tr>th:nth-child(1)]:w-[45%] [&_table>thead>tr>th:nth-child(2)]:w-[15%] [&_table>thead>tr>th:nth-child(3)]:w-[15%] [&_table>thead>tr>th:nth-child(4)]:w-[10%] [&_table>thead>tr>th:nth-child(5)]:w-[15%] [&_table>thead>tr>th:nth-child(6)]:w-6 [&_table>thead>tr>th:nth-child(6)]:overflow-visible',
      '[&_table>tbody>tr>td:nth-child(1)]:w-[45%] [&_table>tbody>tr>td:nth-child(2)]:w-[15%] [&_table>tbody>tr>td:nth-child(3)]:w-[15%] [&_table>tbody>tr>td:nth-child(4)]:w-[10%] [&_table>tbody>tr>td:nth-child(5)]:w-[15%] [&_table>tbody>tr>td:nth-child(6)]:w-6 [&_table>tbody>tr>td:nth-child(6)]:overflow-visible',
      actionColumnClasses,
    )
  } else if (canHaveUnitPrice) {
    tableStructureClasses = tw(
      '[&_table>thead>tr>th:nth-child(1)]:w-[45%] [&_table>thead>tr>th:nth-child(2)]:w-[15%] [&_table>thead>tr>th:nth-child(3)]:w-[15%] [&_table>thead>tr>th:nth-child(4)]:w-[10%] [&_table>thead>tr>th:nth-child(5)]:w-[15%] [&_table>thead>tr>th:nth-child(6)]:w-6 [&_table>thead>tr>th:nth-child(6)]:overflow-visible',
      '[&_table>tbody>tr>td:nth-child(1)]:w-[45%] [&_table>tbody>tr>td:nth-child(2)]:w-[15%] [&_table>tbody>tr>td:nth-child(3)]:w-[15%] [&_table>tbody>tr>td:nth-child(4)]:w-[10%] [&_table>tbody>tr>td:nth-child(5)]:w-[15%] [&_table>tbody>tr>td:nth-child(6)]:w-6 [&_table>tbody>tr>td:nth-child(6)]:overflow-visible',
      actionColumnClasses,
    )
  } else {
    tableStructureClasses = tw(
      '[&_table>thead>tr>th:nth-child(1)]:w-[50%] [&_table>thead>tr>th:nth-child(2)]:w-[20%] [&_table>thead>tr>th:nth-child(3)]:w-[10%] [&_table>thead>tr>th:nth-child(4)]:w-[20%] [&_table>thead>tr>th:nth-child(5)]:w-6 [&_table>thead>tr>th:nth-child(5)]:overflow-visible',
      '[&_table>tbody>tr>td:nth-child(1)]:w-[50%] [&_table>tbody>tr>td:nth-child(2)]:w-[20%] [&_table>tbody>tr>td:nth-child(3)]:w-[10%] [&_table>tbody>tr>td:nth-child(4)]:w-[20%] [&_table>tbody>tr>td:nth-child(5)]:w-6 [&_table>tbody>tr>td:nth-child(5)]:overflow-visible',
      actionColumnClasses,
    )
  }

  return (
    <section
      className={tw(
        '[&_table]:w-full [&_table]:table-fixed [&_table]:border-collapse',
        tableHeadClasses,
        tableBodyClasses,
        tableFootClasses,
        tableStructureClasses,
        className,
      )}
    >
      {children}
    </section>
  )
}

export const InvoiceDetailsTable = memo(
  ({
    customer,
    editFeeDrawerRef,
    invoice,
    isDraftOverride,
    fees,
    onAdd,
    onDelete,
    localFees,
  }: InvoiceDetailsTableProps) => {
    const { translate } = useInternationalization()

    if (!invoice) return null

    const currency = invoice?.currency || CurrencyEnum.Usd
    const isDraftInvoice = invoice?.status === InvoiceStatusTypeEnum.Draft || !!isDraftOverride
    const canHaveUnitPrice = invoice.versionNumber >= 4 || isDraftInvoice

    const hasTaxProviderError = !!invoice.errorDetails?.find(
      ({ errorCode }) => errorCode === ErrorCodesEnum.TaxError,
    )

    /******************
     * One-off invoice
     ******************/
    if (
      [
        InvoiceTypeEnum.AddOn,
        InvoiceTypeEnum.Credit,
        InvoiceTypeEnum.OneOff,
        InvoiceTypeEnum.AdvanceCharges,
      ].includes(invoice.invoiceType)
    ) {
      return (
        <InvoiceTableSection isDraftInvoice={isDraftInvoice} canHaveUnitPrice={canHaveUnitPrice}>
          <table>
            <InvoiceDetailsTableHeader
              canHaveUnitPrice={canHaveUnitPrice}
              displayName={translate('text_6388b923e514213fed58331c')}
            />
            <tbody>
              {fees?.map((fee, i) => {
                const feeDisplayName = getOneTimeFeeDisplayName({
                  invoiceType: invoice.invoiceType,
                  fee,
                  translate,
                })

                // One-time fees with basic metadata for display
                const feeWithMetadata = {
                  ...fee,
                  metadata: {
                    displayName: feeDisplayName,
                  },
                }

                return (
                  <InvoiceDetailsTableBodyLine
                    key={`one-off-fee-${i}`}
                    canHaveUnitPrice={canHaveUnitPrice}
                    currency={currency}
                    displayFeeBoundaries={true}
                    displayName={feeDisplayName}
                    succeededDate={
                      invoice.invoiceType === InvoiceTypeEnum.AdvanceCharges
                        ? DateTime.fromISO(fee.succeededAt).toFormat('LLL. dd, yyyy')
                        : undefined
                    }
                    editFeeDrawerRef={editFeeDrawerRef}
                    isDraftInvoice={isDraftInvoice}
                    fee={
                      feeWithMetadata as FeeForInvoiceDetailsTableBodyLineFragment & {
                        metadata: { displayName: string }
                      }
                    }
                    hasTaxProviderError={hasTaxProviderError}
                  />
                )
              })}
            </tbody>

            <InvoiceDetailsTableFooter
              invoice={invoice}
              canHaveUnitPrice={canHaveUnitPrice}
              hasTaxProviderError={hasTaxProviderError}
            />
          </table>
        </InvoiceTableSection>
      )
    }

    const newFormattedInvoiceItemsMap = groupAndFormatFees({
      fees,
      subscriptions: invoice.subscriptions,
      invoiceSubscriptions: invoice.invoiceSubscriptions,
      invoiceId: invoice.id,
    })

    /***************************************
     * No fee placeholder (by subscription)
     **************************************/

    if (!newFormattedInvoiceItemsMap?.metadata?.hasAnyFeeParsed) {
      return (
        <>
          {invoice.subscriptions?.map((subscription) => {
            return (
              <InvoiceTableSection
                key={`subscription-${subscription.id}-placeholder`}
                canHaveUnitPrice={canHaveUnitPrice}
                isDraftInvoice={false}
              >
                <table>
                  <InvoiceDetailsTableHeader
                    canHaveUnitPrice={canHaveUnitPrice}
                    displayName={subscription.name || subscription.plan.name}
                  />
                  <tbody>
                    <InvoiceDetailsTablePeriodLine
                      canHaveUnitPrice={canHaveUnitPrice}
                      isDraftInvoice={false}
                      period={translate('text_6499a4e4db5730004703f36b', {
                        from: intlFormatDateTime(subscription.currentBillingPeriodStartedAt, {
                          timezone: customer?.applicableTimezone,
                        }).date,
                        to: intlFormatDateTime(subscription.currentBillingPeriodEndingAt, {
                          timezone: customer?.applicableTimezone,
                        }).date,
                      })}
                    />
                    <InvoiceDetailsTableBodyLine
                      canHaveUnitPrice={canHaveUnitPrice}
                      currency={currency}
                      displayName={subscription.name || subscription.plan.name}
                      editFeeDrawerRef={editFeeDrawerRef}
                      fee={undefined}
                      isDraftInvoice={false}
                      hasTaxProviderError={hasTaxProviderError}
                      {...getRegenerateModeProps(onAdd, onDelete, localFees, subscription.id)}
                    />
                  </tbody>
                  <InvoiceDetailsTableFooter
                    invoice={invoice}
                    canHaveUnitPrice={canHaveUnitPrice}
                    hasTaxProviderError={hasTaxProviderError}
                  />
                </table>
              </InvoiceTableSection>
            )
          })}
        </>
      )
    }

    /************************************************
     * Fees grouped by subscription then by boundary
     ************************************************/
    return (
      <InvoiceTableSection isDraftInvoice={isDraftInvoice} canHaveUnitPrice={canHaveUnitPrice}>
        <div className="[&>table:not(:nth-last-child(2))]:mb-8">
          {Object.entries(newFormattedInvoiceItemsMap.subscriptions).map(
            ([subscriptionId, subscriptionData]) => {
              const canAnyChargeBeAdded =
                !invoice.allChargesHaveFees || !invoice.allFixedChargesHaveFees
              const showAddNewFeeButton =
                !!onAdd || // onAdd is present in void and regenerate flow
                (canAnyChargeBeAdded &&
                  subscriptionData.acceptNewChargeFees &&
                  invoice.status === InvoiceStatusTypeEnum.Draft)

              const addNewFeeOnClick = () => {
                editFeeDrawerRef?.current?.openDrawer(
                  onAdd
                    ? {
                        invoiceId: invoice.id,
                        invoiceSubscriptionId: subscriptionId,
                        mode: 'regenerate',
                        onAdd,
                        localFees,
                      }
                    : {
                        invoiceId: invoice.id,
                        invoiceSubscriptionId: subscriptionId,
                        mode: 'add',
                      },
                )
              }

              return (
                <table
                  key={`subscription-${subscriptionId}`}
                  data-test={INVOICE_DETAILS_TABLE_SUBSCRIPTION_TEST_ID}
                >
                  <InvoiceDetailsTableHeader
                    canHaveUnitPrice={canHaveUnitPrice}
                    displayName={subscriptionData.subscriptionDisplayName}
                  />
                  <tbody>
                    {Object.entries(subscriptionData.boundaries).map(([boundaryKey, boundary]) => {
                      return (
                        <Fragment key={`subscription-${subscriptionId}-boundary-${boundaryKey}`}>
                          <InvoiceDetailsTablePeriodLine
                            canHaveUnitPrice={canHaveUnitPrice}
                            isDraftInvoice={isDraftInvoice}
                            period={translate('text_6499a4e4db5730004703f36b', {
                              from: intlFormatDateTime(boundary.fromDatetime, {
                                timezone: customer?.applicableTimezone,
                              }).date,
                              to: intlFormatDateTime(boundary.toDatetime, {
                                timezone: customer?.applicableTimezone,
                              }).date,
                            })}
                          />
                          {boundary.fees.map((fee) => {
                            const succeededDate = fee.succeededAt
                              ? DateTime.fromISO(fee.succeededAt).toLocaleString(DateTime.DATE_MED)
                              : undefined

                            return (
                              <InvoiceDetailsTableBodyLine
                                key={`fee-${fee.id}`}
                                canHaveUnitPrice={canHaveUnitPrice}
                                currency={currency}
                                displayName={fee.metadata.displayName}
                                succeededDate={succeededDate}
                                editFeeDrawerRef={editFeeDrawerRef}
                                isDraftInvoice={isDraftInvoice}
                                fee={fee}
                                hasTaxProviderError={hasTaxProviderError}
                                {...getRegenerateModeProps(
                                  onAdd,
                                  onDelete,
                                  localFees,
                                  subscriptionId,
                                )}
                              />
                            )
                          })}
                        </Fragment>
                      )
                    })}
                    {showAddNewFeeButton && (
                      <tr>
                        <td colSpan={6}>
                          <div>
                            <Button
                              data-test={INVOICE_DETAILS_TABLE_ADD_FEE_BUTTON_TEST_ID}
                              variant="quaternary"
                              size="small"
                              startIcon="plus"
                              onClick={addNewFeeOnClick}
                            >
                              {translate('text_1737709105343hobdiidr8r9')}
                            </Button>
                          </div>
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              )
            },
          )}
          {/* Footer */}
          <table>
            <InvoiceDetailsTableFooter
              invoice={invoice}
              invoiceFees={onAdd ? fees : null}
              canHaveUnitPrice={canHaveUnitPrice}
              hasTaxProviderError={hasTaxProviderError}
              isRegenerateFlow={!!onAdd}
            />
          </table>
        </div>
      </InvoiceTableSection>
    )
  },
)

InvoiceDetailsTable.displayName = 'InvoiceDetailsTable'
