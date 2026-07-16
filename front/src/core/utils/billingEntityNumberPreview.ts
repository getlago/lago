import { DateTime } from 'luxon'

import { BillingEntityDocumentNumberingEnum } from '~/generated/graphql'

export const getBillingEntityNumberPreview = (
  documentNumbering: BillingEntityDocumentNumberingEnum,
  documentNumberPrefix: string,
) => {
  const date = DateTime.now().toFormat('yyyyMM')

  const numberEnding = {
    [BillingEntityDocumentNumberingEnum.PerCustomer]: '001-001',
    [BillingEntityDocumentNumberingEnum.PerBillingEntity]: `${date}-001`,
  }

  return `${documentNumberPrefix}-${numberEnding[documentNumbering]}`
}
