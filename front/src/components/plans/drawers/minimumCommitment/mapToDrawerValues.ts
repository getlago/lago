import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { CurrencyEnum, TaxForPlanAndChargesInPlanFormFragment } from '~/generated/graphql'

import { MinimumCommitmentFormValues } from './MinimumCommitmentDrawer'

type CommitmentSource = {
  amountCents?: string | number | null
  invoiceDisplayName?: string | null
  taxes?: ReadonlyArray<TaxForPlanAndChargesInPlanFormFragment> | null
}

type MapOptions = {
  /** When true, amountCents is treated as backend cents and converted to major units. */
  deserialize?: boolean
  currency?: CurrencyEnum
}

export const mapCommitmentToDrawerValues = (
  commitment: CommitmentSource | null | undefined,
  { deserialize = false, currency }: MapOptions = {},
): MinimumCommitmentFormValues => {
  const raw = commitment?.amountCents
  let amountCents = ''

  if (raw !== undefined && raw !== null && raw !== '') {
    amountCents = deserialize && currency ? String(deserializeAmount(raw, currency)) : String(raw)
  }

  return {
    amountCents,
    invoiceDisplayName: commitment?.invoiceDisplayName || undefined,
    taxes: commitment?.taxes ? [...commitment.taxes] : [],
  }
}
