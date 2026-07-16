import { Typography } from '~/components/designSystem/Typography'
import {
  INVOICE_TAX_ITEM,
  INVOICE_TAX_ITEM_LABEL_SUFFIX,
  INVOICE_TAX_ITEM_NO_TAX,
  INVOICE_TAX_ITEM_VALUE_SUFFIX,
} from '~/components/invoices/dataTestConstants'
import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export type TaxMapType = Map<
  string,
  {
    label: string
    amount: number
    taxRate: number
    hasEnumedTaxCode?: boolean
  }
>

interface InvoiceTaxesDisplayProps {
  hasTaxProvider: boolean
  taxProviderTaxesToDisplay: TaxMapType
  taxesToDisplay: TaxMapType
  hasAnyFee: boolean
  currency: CurrencyEnum
  invoiceFooterLineClassname: string
}

export const InvoiceTaxesDisplay = ({
  hasTaxProvider,
  taxProviderTaxesToDisplay,
  taxesToDisplay,
  hasAnyFee,
  currency,
  invoiceFooterLineClassname,
}: InvoiceTaxesDisplayProps) => {
  const { translate } = useInternationalization()

  if (hasTaxProvider) {
    if (!taxProviderTaxesToDisplay.size) {
      return (
        <div className={invoiceFooterLineClassname}>
          <Typography variant="bodyHl" color="grey600">
            {translate('text_6453819268763979024ad0e9')}
          </Typography>
          <Typography variant="body" color="grey700">
            {'-'}
          </Typography>
        </div>
      )
    }

    return (
      <>
        {Array.from(taxProviderTaxesToDisplay.values())
          .sort((a, b) => b.taxRate - a.taxRate)
          .map((taxToDisplay, i) => {
            let taxValue

            if (taxToDisplay.hasEnumedTaxCode) {
              taxValue = null
            } else if (!hasAnyFee) {
              taxValue = '-'
            } else {
              taxValue = intlFormatNumber(deserializeAmount(taxToDisplay.amount || 0, currency), {
                currency,
              })
            }

            return (
              <div
                className={invoiceFooterLineClassname}
                key={`${INVOICE_TAX_ITEM}-${i}`}
                data-test={`${INVOICE_TAX_ITEM}-${i}`}
              >
                <Typography
                  variant="bodyHl"
                  color="grey600"
                  data-test={`${INVOICE_TAX_ITEM}-${i}${INVOICE_TAX_ITEM_LABEL_SUFFIX}`}
                >
                  {taxToDisplay.label}
                </Typography>
                <Typography
                  variant="body"
                  color="grey700"
                  data-test={`${INVOICE_TAX_ITEM}-${i}${INVOICE_TAX_ITEM_VALUE_SUFFIX}`}
                >
                  {taxValue}
                </Typography>
              </div>
            )
          })}
      </>
    )
  }

  if (!!taxesToDisplay?.size) {
    return (
      <>
        {Array.from(taxesToDisplay.values())
          .sort((a, b) => b.taxRate - a.taxRate)
          .map((taxToDisplay, i) => {
            return (
              <div
                className={invoiceFooterLineClassname}
                key={`${INVOICE_TAX_ITEM}-${i}`}
                data-test={`${INVOICE_TAX_ITEM}-${i}`}
              >
                <Typography
                  variant="bodyHl"
                  color="grey600"
                  data-test={`${INVOICE_TAX_ITEM}-${i}${INVOICE_TAX_ITEM_LABEL_SUFFIX}`}
                >
                  {taxToDisplay.label}
                </Typography>
                <Typography
                  variant="body"
                  color="grey700"
                  data-test={`${INVOICE_TAX_ITEM}-${i}${INVOICE_TAX_ITEM_VALUE_SUFFIX}`}
                >
                  {!hasAnyFee
                    ? '-'
                    : intlFormatNumber(taxToDisplay.amount, {
                        currency,
                      })}
                </Typography>
              </div>
            )
          })}
      </>
    )
  }

  return (
    <div className={invoiceFooterLineClassname} data-test={INVOICE_TAX_ITEM_NO_TAX}>
      <Typography variant="bodyHl" color="grey600">
        {`${translate('text_6453819268763979024ad0e9')} (0%)`}
      </Typography>
      <Typography variant="body" color="grey700">
        {!hasAnyFee
          ? '-'
          : intlFormatNumber(0, {
              currency,
            })}
      </Typography>
    </div>
  )
}
