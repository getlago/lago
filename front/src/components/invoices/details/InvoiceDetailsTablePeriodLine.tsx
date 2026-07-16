import { Typography } from '~/components/designSystem/Typography'

type InvoiceDetailsTablePeriodLineProps = {
  canHaveUnitPrice: boolean
  isDraftInvoice: boolean
  period: string
}

export const InvoiceDetailsTablePeriodLine = ({
  canHaveUnitPrice,
  isDraftInvoice,
  period,
}: InvoiceDetailsTablePeriodLineProps): JSX.Element => {
  // Column counts match `InvoiceTableSection`'s table-structure classes:
  // - draft (canHaveUnitPrice): 6 columns (incl. action)
  // - non-draft, canHaveUnitPrice: 6 columns (incl. action)
  // - non-draft, no canHaveUnitPrice: 5 columns (incl. action)
  let colSpan = 5

  if (isDraftInvoice || canHaveUnitPrice) {
    colSpan = 6
  }

  return (
    <tr>
      <td colSpan={colSpan}>
        <Typography variant="captionHl" color="grey600">
          {period}
        </Typography>
      </td>
    </tr>
  )
}
