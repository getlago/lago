import { useEffect, useState } from 'react'

import { Dialog } from '~/components/designSystem/Dialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { EditInvoiceCustomSectionDialogActions } from './EditInvoiceCustomSectionDialogActions'
import { InvoiceCustomSectionFields } from './InvoiceCustomSectionFields'
import {
  deriveInvoiceCustomSectionBehavior,
  InvoiceCustomSectionBasic,
  InvoiceCustomSectionBehavior,
  InvoiceCustomSectionInput,
} from './types'

import { VIEW_TYPE_TRANSLATION_KEYS, ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

export interface InvoiceCustomSectionSelection {
  behavior: InvoiceCustomSectionBehavior
  selectedSections: InvoiceCustomSectionBasic[]
}

interface EditInvoiceCustomSectionDialogProps {
  open: boolean
  onClose: () => void
  customerId: string
  selectedSections: InvoiceCustomSectionBasic[]
  skipInvoiceCustomSections: boolean
  onSave: (selection: InvoiceCustomSectionSelection) => void
  viewType: ViewTypeEnum
}

// Dialog container for the invoice custom-section selector. The selector itself
// is the shared `InvoiceCustomSectionFields` (also used inline in the
// subscription Invoicing settings drawer) — this component only adds the dialog
// shell + a commit-on-save draft.
export const EditInvoiceCustomSectionDialog = ({
  open,
  onClose,
  customerId,
  selectedSections,
  skipInvoiceCustomSections,
  onSave,
  viewType,
}: EditInvoiceCustomSectionDialogProps) => {
  const { translate } = useInternationalization()

  // `seedValue` comes straight from props (always current), so the fields
  // component — which seeds from `value` on mount and remounts per open — never
  // shows a stale draft. `draft`/`behavior` mirror the fields' working state so
  // the Save button can enforce the "apply needs a selection" guard.
  const seedValue: InvoiceCustomSectionInput = {
    invoiceCustomSections: selectedSections,
    skipInvoiceCustomSections,
  }

  const [draft, setDraft] = useState<InvoiceCustomSectionInput>(seedValue)
  const [behavior, setBehavior] = useState<InvoiceCustomSectionBehavior>(
    deriveInvoiceCustomSectionBehavior(seedValue),
  )

  useEffect(() => {
    if (open) {
      const next: InvoiceCustomSectionInput = {
        invoiceCustomSections: selectedSections,
        skipInvoiceCustomSections,
      }

      setDraft(next)
      setBehavior(deriveInvoiceCustomSectionBehavior(next))
    }
  }, [open, selectedSections, skipInvoiceCustomSections])

  // Picking "apply" without any section must block save (legacy guard).
  const isSaveDisabled =
    behavior === InvoiceCustomSectionBehavior.APPLY && draft.invoiceCustomSections.length === 0

  const handleSave = (): void => {
    onSave({
      behavior: deriveInvoiceCustomSectionBehavior(draft),
      selectedSections: draft.invoiceCustomSections,
    })
    onClose()
  }

  const viewTypeLabel = translate(VIEW_TYPE_TRANSLATION_KEYS[viewType])

  return (
    <Dialog
      open={open}
      title={translate('text_1765363318309snvsqc74nit', { object: viewTypeLabel })}
      description={translate('text_1765363318310io596s2cy1y', { object: viewTypeLabel })}
      onClose={onClose}
      actions={({ closeDialog }) => (
        <EditInvoiceCustomSectionDialogActions
          closeDialog={closeDialog}
          onSave={handleSave}
          isSaveDisabled={isSaveDisabled}
          translate={translate}
        />
      )}
    >
      <div className="mb-8">
        <InvoiceCustomSectionFields
          viewType={viewType}
          customerId={customerId}
          value={seedValue}
          onChange={setDraft}
          onBehaviorChange={setBehavior}
        />
      </div>
    </Dialog>
  )
}
