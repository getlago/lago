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
  fragment FeeForInvoiceDetailsTableBodyLineGraduatedPercentage on Fee {
    id
    appliedTaxes {
      id
      taxRate
    }
    amountDetails {
      graduatedPercentageRanges {
        flatUnitAmount
        fromValue
        perUnitTotalAmount
        rate
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

type InvoiceDetailsTableBodyLineGraduatedPercentageProps = {
  currency: CurrencyEnum
  fee: (FeeForInvoiceDetailsTableBodyLineFragment & { metadata: FeeMetadata }) | undefined
  hideVat?: boolean
}

export const InvoiceDetailsTableBodyLineGraduatedPercentage = memo(
  ({ currency, fee, hideVat }: InvoiceDetailsTableBodyLineGraduatedPercentageProps) => {
    const { getRangeLabel } = useGetRangeLabel()

    const viewFeeDetails = useViewFeeDetailsDrawer()
    const handleRowClick = () => {
      if (fee) viewFeeDetails.open(fee)
    }
    const rowClickableClass = fee ? 'cursor-pointer hover:bg-grey-100' : undefined

    return (
      <>
        {fee?.amountDetails?.graduatedPercentageRanges?.map((graduatedPercentageRange, i) => (
          <tr
            key={`fee-${fee.id}-graduated-percentage-range-fee-per-unit-${i}`}
            className={tw('details-line', rowClickableClass)}
            onClick={fee ? handleRowClick : undefined}
          >
            <td>
              <Typography variant="body" color="grey600">
                {getRangeLabel(
                  i,
                  fee?.amountDetails?.graduatedPercentageRanges?.length || 0,
                  Number(graduatedPercentageRange?.fromValue),
                  Number(graduatedPercentageRange?.toValue),
                  false,
                )}
              </Typography>
            </td>
            <td>
              <Typography variant="body" color="grey600">
                {Number(graduatedPercentageRange.units)}
              </Typography>
            </td>
            {!hideVat && (
              <td>
                <Typography variant="body" color="grey600">
                  {graduatedPercentageRange?.rate}%
                </Typography>
              </td>
            )}
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
            <td>
              <Typography variant="body" color="grey600">
                {intlFormatNumber(Number(graduatedPercentageRange.perUnitTotalAmount || 0), {
                  pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                  currencyDisplay: 'symbol',
                  currency,
                })}
              </Typography>
            </td>
            <FeeActionsCell fee={fee} />
          </tr>
        ))}

        {!!fee?.amountDetails?.graduatedPercentageRanges?.length &&
          fee?.amountDetails?.graduatedPercentageRanges?.map((graduatedPercentageRange, i) => {
            if (Number(graduatedPercentageRange?.flatUnitAmount) === 0) return null

            return (
              <tr
                key={`fee-${fee.id}-graduated-percentage-range-flat-fee-${i}`}
                className={tw('details-line', rowClickableClass)}
                onClick={fee ? handleRowClick : undefined}
              >
                <td>
                  <Typography variant="body" color="grey600">
                    {getRangeLabel(
                      i,
                      fee?.amountDetails?.graduatedPercentageRanges?.length || 0,
                      Number(graduatedPercentageRange?.fromValue),
                      Number(graduatedPercentageRange?.toValue),
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
                    {intlFormatNumber(Number(graduatedPercentageRange?.flatUnitAmount) || 0, {
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
                    {intlFormatNumber(Number(graduatedPercentageRange.flatUnitAmount || 0), {
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

InvoiceDetailsTableBodyLineGraduatedPercentage.displayName =
  'InvoiceDetailsTableBodyLineGraduatedPercentage'
