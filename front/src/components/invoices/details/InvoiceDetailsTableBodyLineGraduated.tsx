import { gql } from '@apollo/client'
import { tw } from 'lago-design-system'
import { memo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { useViewFeeDetailsDrawer } from '~/components/invoices/details/ViewFeeDetailsDrawer'
import { FeeMetadata } from '~/core/formats/formatInvoiceItemsMap'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum, FeeForInvoiceDetailsTableBodyLineFragment } from '~/generated/graphql'

import { FeeActionsCell } from './FeeActionsCell'
import { useGetRangeLabel } from './useGetRangeLabel'

gql`
  fragment FeeForInvoiceDetailsTableBodyLineGraduated on Fee {
    id
    appliedTaxes {
      id
      taxRate
    }
    amountDetails {
      graduatedRanges {
        flatUnitAmount
        fromValue
        perUnitAmount
        perUnitTotalAmount
        toValue
        totalWithFlatAmount
        units
      }
    }
    pricingUnitUsage {
      shortName
    }
  }
`

type InvoiceDetailsTableBodyLineGraduatedProps = {
  currency: CurrencyEnum
  fee: (FeeForInvoiceDetailsTableBodyLineFragment & { metadata: FeeMetadata }) | undefined
  hideVat?: boolean
}

export const InvoiceDetailsTableBodyLineGraduated = memo(
  ({ currency, fee, hideVat }: InvoiceDetailsTableBodyLineGraduatedProps) => {
    const { getRangeLabel } = useGetRangeLabel()

    const viewFeeDetails = useViewFeeDetailsDrawer()
    const handleRowClick = () => {
      if (fee) viewFeeDetails.open(fee)
    }
    const rowClickableClass = fee ? 'cursor-pointer hover:bg-grey-100' : undefined

    return (
      <>
        {fee?.amountDetails?.graduatedRanges?.map((graduatedRange, i) => (
          <tr
            key={`fee-${fee.id}-graduated-range-fee-per-unit-${i}`}
            className={tw('details-line', rowClickableClass)}
            onClick={fee ? handleRowClick : undefined}
          >
            <td>
              <Typography variant="body" color="grey600">
                {getRangeLabel(
                  i,
                  fee?.amountDetails?.graduatedRanges?.length || 0,
                  Number(graduatedRange?.fromValue),
                  Number(graduatedRange?.toValue),
                  false,
                )}
              </Typography>
            </td>
            <td>
              <Typography variant="body" color="grey600">
                {Number(graduatedRange.units)}
              </Typography>
            </td>
            <td>
              <Typography variant="body" color="grey600">
                {intlFormatNumber(Number(graduatedRange?.perUnitAmount) || 0, {
                  pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                  currencyDisplay: 'symbol',
                  currency,
                  maximumFractionDigits: 15,
                })}
              </Typography>
            </td>
            {!hideVat && (
              <td>
                <Typography variant="body" color="grey600">
                  {fee?.appliedTaxes?.length
                    ? fee?.appliedTaxes.map((appliedTaxes) => (
                        <Typography
                          key={`fee-${fee?.id}-applied-taxe-${appliedTaxes.id}`}
                          variant="body"
                          color="grey600"
                        >
                          {intlFormatNumber(appliedTaxes.taxRate / 100 || 0, {
                            style: 'percent',
                          })}
                        </Typography>
                      ))
                    : '0%'}
                </Typography>
              </td>
            )}
            <td>
              <Typography variant="body" color="grey600">
                {intlFormatNumber(Number(graduatedRange.perUnitTotalAmount || 0), {
                  pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                  currencyDisplay: 'symbol',
                  currency,
                })}
              </Typography>
            </td>
            <FeeActionsCell fee={fee} />
          </tr>
        ))}

        {!!fee?.amountDetails?.graduatedRanges?.length &&
          fee?.amountDetails?.graduatedRanges?.map((graduatedRange, i) => {
            if (Number(graduatedRange?.flatUnitAmount) === 0) return null

            return (
              <tr
                key={`fee-${fee.id}-graduated-range-flat-fee-${i}`}
                className={tw('details-line', rowClickableClass)}
                onClick={fee ? handleRowClick : undefined}
              >
                <td>
                  <Typography variant="body" color="grey600">
                    {getRangeLabel(
                      i,
                      fee?.amountDetails?.graduatedRanges?.length || 0,
                      Number(graduatedRange?.fromValue),
                      Number(graduatedRange?.toValue),
                      true,
                    )}
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="grey600">
                    1
                  </Typography>
                </td>
                <td>
                  <Typography variant="body" color="grey600">
                    {intlFormatNumber(Number(graduatedRange?.flatUnitAmount) || 0, {
                      pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                      currencyDisplay: 'symbol',
                      currency,
                    })}
                  </Typography>
                </td>
                {!hideVat && (
                  <td>
                    <Typography variant="body" color="grey600">
                      {fee?.appliedTaxes?.length
                        ? fee?.appliedTaxes.map((appliedTaxes) => (
                            <Typography
                              key={`fee-${fee?.id}-applied-taxe-${appliedTaxes.id}`}
                              variant="body"
                              color="grey600"
                            >
                              {intlFormatNumber(appliedTaxes.taxRate / 100 || 0, {
                                style: 'percent',
                              })}
                            </Typography>
                          ))
                        : '0%'}
                    </Typography>
                  </td>
                )}
                <td>
                  <Typography variant="body" color="grey600">
                    {intlFormatNumber(Number(graduatedRange.flatUnitAmount || 0), {
                      pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                      currencyDisplay: 'symbol',
                      currency,
                    })}
                  </Typography>
                </td>
                <FeeActionsCell fee={fee} />
              </tr>
            )
          })}
      </>
    )
  },
)

InvoiceDetailsTableBodyLineGraduated.displayName = 'InvoiceDetailsTableBodyLineGraduated'
