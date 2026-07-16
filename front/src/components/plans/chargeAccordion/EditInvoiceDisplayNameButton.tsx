import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { useEditInvoiceDisplayNameDialog } from '~/components/invoices/useEditInvoiceDisplayName'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const EditInvoiceDisplayNameButton = ({
  currentInvoiceDisplayName,
  onEdit,
}: {
  currentInvoiceDisplayName: string | null | undefined
  onEdit: (invoiceDisplayName: string) => void
}) => {
  const { translate } = useInternationalization()
  const { openEditInvoiceDisplayNameDialog } = useEditInvoiceDisplayNameDialog()

  return (
    <Tooltip title={translate('text_65018c8e5c6b626f030bcf8d')} placement="top-end">
      <Button
        icon="pen"
        variant="quaternary"
        size="small"
        onClick={(e) => {
          e.stopPropagation()

          openEditInvoiceDisplayNameDialog({
            invoiceDisplayName: currentInvoiceDisplayName,
            callback: onEdit,
          })
        }}
      />
    </Tooltip>
  )
}
