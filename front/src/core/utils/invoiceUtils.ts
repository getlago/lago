import { gql } from '@apollo/client'
import { DateTime } from 'luxon'

import { intlFormatNumber } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum, FeeInput, Invoice, InvoiceTypeEnum } from '~/generated/graphql'

gql`
  fragment FeeForInvoiceFeesToFeeInput on Fee {
    id
    description
    invoiceDisplayName
    itemName
    preciseUnitAmount
    addOn {
      id
    }
    properties {
      fromDatetime
      toDatetime
    }
  }
`

export const isOneOff = (invoice: Pick<Invoice, 'invoiceType'>) => {
  return [
    InvoiceTypeEnum.AddOn,
    InvoiceTypeEnum.Credit,
    InvoiceTypeEnum.OneOff,
    InvoiceTypeEnum.AdvanceCharges,
  ].includes(invoice.invoiceType)
}

export const isPrepaidCredit = (invoice: Pick<Invoice, 'invoiceType'>) => {
  return [InvoiceTypeEnum.Credit].includes(invoice.invoiceType)
}

export const invoiceFeesToFeeInput = (
  invoice: Pick<Invoice, 'fees'> | undefined,
): FeeInput[] | null | undefined => {
  const today = DateTime.now()

  return invoice?.fees?.map((fee) => ({
    addOnId: fee?.addOn?.id as string,
    description: fee.description,
    invoiceDisplayName: fee.invoiceDisplayName,
    name: fee.itemName,
    unitAmountCents: fee.preciseUnitAmount,
    units: fee.units,
    taxes: fee?.appliedTaxes?.map((appliedTax) => appliedTax.tax) || [],
    fromDatetime: fee.properties?.fromDatetime || today.startOf('day').toISO(),
    toDatetime: fee.properties?.toDatetime || today.endOf('day').toISO(),
  }))
}

export const formatInvoiceDisplayValue = (
  hasTaxProvider: boolean,
  taxProviderCondition: boolean,
  taxProviderValue: number | undefined,
  hasAnyFee: boolean,
  fallbackValue: number,
  currency: CurrencyEnum,
): string => {
  if (hasTaxProvider) {
    if (!taxProviderCondition) {
      return '-'
    }
    return intlFormatNumber(taxProviderValue || 0, {
      currency,
    })
  }

  if (!hasAnyFee) {
    return '-'
  }

  return intlFormatNumber(fallbackValue, {
    currency,
  })
}
