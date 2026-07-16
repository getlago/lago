import { useMemo } from 'react'

import { Chip } from '~/components/designSystem/Chip'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerInvoiceCustomSections } from '~/hooks/useCustomerInvoiceCustomSections'

import { InvoiceCustomSectionBasic } from './types'

import { VIEW_TYPE_TRANSLATION_KEYS, ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

export const SECTION_CHIP = (sectionId: string) =>
  `invoice-custom-section-display-chip-${sectionId}`
export const FALLBACK_BILLING_ENTITY_LABEL =
  'invoice-custom-section-display-fallback-billing-entity'
export const FALLBACK_CUSTOMER_SECTIONS_LABEL =
  'invoice-custom-section-display-fallback-customer-sections'
export const SKIP_LABEL = 'invoice-custom-section-display-skip-label'

interface InvoiceCustomSectionChipsProps {
  sections: InvoiceCustomSectionBasic[]
}

type DisplayState =
  | { type: 'apply'; sections: InvoiceCustomSectionBasic[] }
  | { type: 'none' }
  | { type: 'fallback_customer_sections'; sections: InvoiceCustomSectionBasic[] }
  | { type: 'fallback_customer_skip' }
  | { type: 'fallback_billing_entity'; sections: InvoiceCustomSectionBasic[] }
  | { type: 'fallback_empty' }

interface InvoiceCustomSectionDisplayProps {
  selectedSections?: InvoiceCustomSectionBasic[] | null
  skipSections?: boolean | null
  customerId?: string
  viewType: ViewTypeEnum
}

/**
 * Renders a list of invoice custom section chips.
 */
const InvoiceCustomSectionChips = ({ sections }: InvoiceCustomSectionChipsProps) => {
  return (
    <div className="flex flex-wrap gap-2">
      {sections.map((section) => (
        <Chip key={section.id} label={section.name} data-test={SECTION_CHIP(section.id)} />
      ))}
    </div>
  )
}

/**
 * Renders the display content for invoice custom sections.
 * This works such that if the customer has explicitly selected sections, we display them.
 * Otherwise, we fallback to the customer's ICSs data or the billing entity's ICSs data.
 */
export const InvoiceCustomSectionDisplay = ({
  selectedSections,
  skipSections,
  customerId,
  viewType,
}: InvoiceCustomSectionDisplayProps) => {
  const { translate } = useInternationalization()

  // Customer-level ICS data for fallback
  const { data: customerData } = useCustomerInvoiceCustomSections(customerId || '')

  const displayState = useMemo((): DisplayState => {
    // NONE - explicitly skip all ICS (takes precedence)
    if (skipSections === true) {
      return { type: 'none' }
    }

    // APPLY - use explicit section selection (not customer data)
    if (selectedSections?.length) {
      return { type: 'apply', sections: selectedSections }
    }

    // FALLBACK - inherit from customer/billing entity
    if (customerData) {
      const sections = customerData.configurableInvoiceCustomSections
      const hasOverwritten = customerData.hasOverwrittenInvoiceCustomSectionsSelection
      const customerSkipSections = customerData.skipInvoiceCustomSections

      // Customer explicitly skipped ICS
      if (!hasOverwritten && customerSkipSections) {
        return { type: 'fallback_customer_skip' }
      }

      // Customer has overwritten selection with specific sections
      if (hasOverwritten && !customerSkipSections && sections.length > 0) {
        return { type: 'fallback_customer_sections', sections }
      }

      // Fallback to billing entity
      if (!hasOverwritten && !customerSkipSections && sections.length > 0) {
        return { type: 'fallback_billing_entity', sections }
      }
    }

    // No sections anywhere
    return { type: 'fallback_empty' }
  }, [selectedSections, skipSections, customerData])

  const viewTypeLabel = translate(VIEW_TYPE_TRANSLATION_KEYS[viewType])

  switch (displayState.type) {
    case 'apply':
      return <InvoiceCustomSectionChips sections={displayState.sections} />

    case 'none':
      return (
        <Typography variant="body" color="grey700" data-test={SKIP_LABEL}>
          {translate('text_176537313551954twfx3pys9', { object: viewTypeLabel })}
        </Typography>
      )

    case 'fallback_customer_sections':
      return (
        <>
          <Typography variant="body" color="grey700" data-test={FALLBACK_CUSTOMER_SECTIONS_LABEL}>
            {translate('text_1765373135518xm96ypchuls')}
          </Typography>
          <InvoiceCustomSectionChips sections={displayState.sections} />
        </>
      )

    case 'fallback_customer_skip':
      return (
        <Typography variant="body" color="grey700" data-test={SKIP_LABEL}>
          {translate('text_17653731355193nuiojugqom', { object: viewTypeLabel })}
        </Typography>
      )

    case 'fallback_billing_entity':
      return (
        <>
          <Typography variant="body" color="grey700" data-test={FALLBACK_BILLING_ENTITY_LABEL}>
            {translate('text_1765373135519xqsbx2q5h1h')}
          </Typography>
          <InvoiceCustomSectionChips sections={displayState.sections} />
        </>
      )

    case 'fallback_empty':
      return null
  }
}
