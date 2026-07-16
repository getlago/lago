import { useStore } from '@tanstack/react-form'
import { useMemo, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Selector } from '~/components/designSystem/Selector'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

import { buildSubscriptionDefaultValues } from './buildSubscriptionDefaultValues'
import { InvoicingSettingsDrawer, InvoicingSettingsDrawerRef } from './InvoicingSettingsDrawer'

const TYPING_PLACEHOLDER_DATE = '2026-01-01'

interface InvoicingSettingsSectionExtraProps {
  customerId?: string
}

const invoicingSettingsSectionDefaultProps: InvoicingSettingsSectionExtraProps = {
  customerId: undefined,
}

// Entry point for the subscription invoicing settings: a Selector card that
// previews the current choices and opens the InvoicingSettingsDrawer. Keeps the
// preview summary, the drawer ref and the save wiring in one place instead of
// scattering them across the (already large) CreateSubscription form.
export const InvoicingSettingsSection = withForm({
  defaultValues: buildSubscriptionDefaultValues(
    undefined,
    FORM_TYPE_ENUM.creation,
    TYPING_PLACEHOLDER_DATE,
  ),
  props: invoicingSettingsSectionDefaultProps,
  render: function InvoicingSettingsSectionRender({ form, customerId }) {
    const { translate } = useInternationalization()
    const drawerRef = useRef<InvoicingSettingsDrawerRef>(null)

    // Reactive slices so the card preview re-renders when the drawer saves.
    const consolidateInvoice = useStore(form.store, (s) => s.values.consolidateInvoice)
    const invoiceCustomSection = useStore(form.store, (s) => s.values.invoiceCustomSection)

    const showCustomSection = !!customerId

    const summary = useMemo(() => {
      const consolidationKey =
        (consolidateInvoice ?? true)
          ? 'text_1778745351091h7z5baw0ta6'
          : 'text_1778745351091fxaqr5dwok8'

      const parts = [translate(consolidationKey)]

      if (showCustomSection) {
        let icsKey = 'text_1782738644347svkr94bf4aw'

        if (invoiceCustomSection?.skipInvoiceCustomSections) {
          icsKey = 'text_1782738644347z3azl4u1f15'
        } else if (invoiceCustomSection?.invoiceCustomSections?.length) {
          icsKey = 'text_1782738644347qh5s13lol1p'
        }

        parts.push(translate(icsKey))
      }

      return parts.join(' • ')
    }, [consolidateInvoice, invoiceCustomSection, showCustomSection, translate])

    return (
      <>
        <Selector
          icon="document"
          title={translate('text_17423672025282dl7iozy1ru')}
          subtitle={summary}
          endContent={<Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />}
          onClick={() =>
            drawerRef.current?.openDrawer({
              consolidateInvoice: consolidateInvoice ?? true,
              invoiceCustomSection,
            })
          }
          data-test="invoicing-settings-selector"
        />

        <InvoicingSettingsDrawer
          ref={drawerRef}
          viewType={ViewTypeEnum.Subscription}
          customerId={customerId}
          showCustomSection={showCustomSection}
          onSave={({
            consolidateInvoice: nextConsolidateInvoice,
            invoiceCustomSection: nextIcs,
          }) => {
            form.setFieldValue('consolidateInvoice', nextConsolidateInvoice)
            form.setFieldValue('invoiceCustomSection', nextIcs)
          }}
        />
      </>
    )
  },
})
