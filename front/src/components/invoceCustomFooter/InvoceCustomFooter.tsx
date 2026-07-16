import { useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import {
  EditInvoiceCustomSectionDialog,
  InvoiceCustomSectionSelection,
} from '~/components/invoceCustomFooter/EditInvoiceCustomSectionDialog'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { InvoiceCustomSectionDisplay } from './InvoiceCustomSectionDisplay'
import { InvoiceCustomSectionBehavior, InvoiceCustomSectionInput } from './types'

import { VIEW_TYPE_TRANSLATION_KEYS, ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

export const EDIT_BUTTON = 'invoice-custom-footer-edit-button'

interface InvoceCustomFooterProps {
  customerId: string
  viewType: ViewTypeEnum
  invoiceCustomSection?: InvoiceCustomSectionInput
  setInvoiceCustomSection?: (item: InvoiceCustomSectionInput) => void
}

export const InvoceCustomFooter = ({
  customerId,
  viewType,
  invoiceCustomSection,
  setInvoiceCustomSection,
}: InvoceCustomFooterProps) => {
  const { translate } = useInternationalization()
  const [isDialogOpen, setIsDialogOpen] = useState(false)

  const selectedSections = invoiceCustomSection?.invoiceCustomSections || []
  const skipSections = invoiceCustomSection?.skipInvoiceCustomSections || false

  const handleDialogSave = (selection: InvoiceCustomSectionSelection) => {
    const { behavior, selectedSections: newSelectedSections } = selection

    if (behavior === InvoiceCustomSectionBehavior.FALLBACK) {
      setInvoiceCustomSection?.({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: false,
      })
    } else if (behavior === InvoiceCustomSectionBehavior.APPLY) {
      setInvoiceCustomSection?.({
        invoiceCustomSections: newSelectedSections,
        skipInvoiceCustomSections: false,
      })
    } else if (behavior === InvoiceCustomSectionBehavior.NONE) {
      setInvoiceCustomSection?.({
        invoiceCustomSections: [],
        skipInvoiceCustomSections: true,
      })
    }
  }

  return (
    <div>
      <Typography variant="captionHl" color="textSecondary">
        {translate('text_17628623882713knw0jtohiw')}
      </Typography>

      <Typography variant="caption" className="mb-3">
        {translate('text_1762862855282gldrtploh46', {
          object: translate(VIEW_TYPE_TRANSLATION_KEYS[viewType]),
        })}
      </Typography>

      <div className="flex flex-col gap-3">
        <InvoiceCustomSectionDisplay
          selectedSections={selectedSections}
          skipSections={skipSections}
          customerId={customerId}
          viewType={viewType}
        />

        <div className="flex items-start">
          <Button
            variant="inline"
            startIcon="pen"
            onClick={() => setIsDialogOpen(true)}
            data-test={EDIT_BUTTON}
          >
            {translate('text_1765363318310jm7wdrj7zzk')}
          </Button>
        </div>
      </div>

      <EditInvoiceCustomSectionDialog
        open={isDialogOpen}
        onClose={() => setIsDialogOpen(false)}
        customerId={customerId}
        selectedSections={selectedSections}
        skipInvoiceCustomSections={skipSections}
        onSave={handleDialogSave}
        viewType={viewType}
      />
    </div>
  )
}
