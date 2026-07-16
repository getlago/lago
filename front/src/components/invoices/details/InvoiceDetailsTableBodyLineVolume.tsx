import { gql } from '@apollo/client'
import { tw } from 'lago-design-system'
import { memo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { useViewFeeDetailsDrawer } from '~/components/invoices/details/ViewFeeDetailsDrawer'
import { FeeMetadata } from '~/core/formats/formatInvoiceItemsMap'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum, FeeForInvoiceDetailsTableBodyLineFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FeeActionsCell } from './FeeActionsCell'

gql`
  fragment FeeForInvoiceDetailsTableBodyLineVolume on Fee {
    id
    units
    appliedTaxes {
      id
      taxRate
    }
    amountDetails {
      flatUnitAmount
      perUnitAmount
      perUnitTotalAmount
    }
    pricingUnitUsage {
      shortName
    }
  }
`

type InvoiceDetailsTableBodyLineVolumeProps = {
  currency: CurrencyEnum
  fee: (FeeForInvoiceDetailsTableBodyLineFragment & { metadata: FeeMetadata }) | undefined
  hideVat?: boolean
}

export const InvoiceDetailsTableBodyLineVolume = memo(
  ({ currency, fee, hideVat }: InvoiceDetailsTableBodyLineVolumeProps) => {
    const { translate } = useInternationalization()
    const amountDetails = fee?.amountDetails

    const viewFeeDetails = useViewFeeDetailsDrawer()
    const handleRowClick = () => {
      if (fee) viewFeeDetails.open(fee)
    }
    const rowClickableClass = fee ? 'cursor-pointer hover:bg-grey-100' : undefined

    return (
      <>
        <tr
          className={tw('details-line', rowClickableClass)}
          onClick={fee ? handleRowClick : undefined}
        >
          <td>
            <Typography variant="body" color="grey600">
              {translate('text_659e67cd63512ef532843078')}
            </Typography>
          </td>
          <td>
            <Typography variant="body" color="grey600">
              {Number(fee?.units || 0)}
            </Typography>
          </td>
          <td>
            <Typography variant="body" color="grey600">
              {intlFormatNumber(Number(amountDetails?.perUnitAmount) || 0, {
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
              {intlFormatNumber(Number(amountDetails?.perUnitTotalAmount || 0), {
                pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                currencyDisplay: 'symbol',
                currency,
              })}
            </Typography>
          </td>
          <FeeActionsCell fee={fee} />
        </tr>

        {Number(amountDetails?.flatUnitAmount || 0) > 0 && (
          <>
            <tr
              className={tw('details-line', rowClickableClass)}
              onClick={fee ? handleRowClick : undefined}
            >
              <td>
                <Typography variant="body" color="grey600">
                  {translate('text_659e67cd63512ef5328430b5')}
                </Typography>
              </td>
              <td>
                <Typography variant="body" color="grey600">
                  1
                </Typography>
              </td>
              <td>
                <Typography variant="body" color="grey600">
                  {intlFormatNumber(Number(amountDetails?.flatUnitAmount) || 0, {
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
                  {intlFormatNumber(Number(amountDetails?.flatUnitAmount || 0), {
                    pricingUnitShortName: fee?.pricingUnitUsage?.shortName,
                    currencyDisplay: 'symbol',
                    currency,
                  })}
                </Typography>
              </td>
              <FeeActionsCell fee={fee} />
            </tr>
          </>
        )}
      </>
    )
  },
)

InvoiceDetailsTableBodyLineVolume.displayName = 'InvoiceDetailsTableBodyLineVolume'
