import { revalidateLogic, useStore } from '@tanstack/react-form'
import { forwardRef, useImperativeHandle } from 'react'
import { z } from 'zod'

import { useFormDrawer } from '~/components/drawers/useDrawer'
import { focusFirstInput } from '~/components/drawers/useFocusTrap'
import { InvoiceCustomSectionFields } from '~/components/invoceCustomFooter/InvoiceCustomSectionFields'
import {
  deriveInvoiceCustomSectionBehavior,
  InvoiceCustomSectionBehavior,
  InvoiceCustomSectionInput,
} from '~/components/invoceCustomFooter/types'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import {
  VIEW_TYPE_TRANSLATION_KEYS,
  ViewTypeEnum,
} from '~/components/paymentMethodsInvoiceSettings/types'
import { SubscriptionInvoiceConsolidationSection } from '~/components/subscriptions/SubscriptionInvoiceConsolidationSection'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useAppForm, withForm } from '~/hooks/forms/useAppform'

const INVOICING_SETTINGS_FORM_ID = 'invoicing-settings-drawer-form'

interface InvoicingSettingsValues {
  consolidateInvoice: boolean
  invoiceCustomSection: InvoiceCustomSectionInput
}

interface InvoicingSettingsFormValues extends InvoicingSettingsValues {
  invoiceCustomSectionBehavior: InvoiceCustomSectionBehavior
}

const DEFAULT_VALUES: InvoicingSettingsFormValues = {
  consolidateInvoice: true,
  invoiceCustomSection: { invoiceCustomSections: [], skipInvoiceCustomSections: false },
  invoiceCustomSectionBehavior: InvoiceCustomSectionBehavior.FALLBACK,
}

const invoicingSettingsValidationSchema = z
  .object({
    consolidateInvoice: z.boolean(),
    invoiceCustomSection: z.custom<InvoiceCustomSectionInput>(),
    invoiceCustomSectionBehavior: z.enum(InvoiceCustomSectionBehavior),
  })
  .superRefine((values, ctx) => {
    if (
      values.invoiceCustomSectionBehavior === InvoiceCustomSectionBehavior.APPLY &&
      values.invoiceCustomSection.invoiceCustomSections.length === 0
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['invoiceCustomSection'],
        message: 'text_624ea7c29103fd010732ab7d',
      })
    }
  })

interface InvoicingSettingsDrawerContentExtraProps {
  viewType: ViewTypeEnum
  customerId?: string
  showCustomSection: boolean
}

const invoicingSettingsDrawerContentDefaultProps: InvoicingSettingsDrawerContentExtraProps = {
  viewType: ViewTypeEnum.Subscription,
  customerId: undefined,
  showCustomSection: false,
}

const InvoicingSettingsDrawerContent = withForm({
  defaultValues: DEFAULT_VALUES,
  props: invoicingSettingsDrawerContentDefaultProps,
  render: function InvoicingSettingsDrawerContentRender({
    form,
    viewType,
    customerId,
    showCustomSection,
  }) {
    const { translate } = useInternationalization()
    const viewTypeLabel = translate(VIEW_TYPE_TRANSLATION_KEYS[viewType])
    const invoiceCustomSection = useStore(form.store, (s) => s.values.invoiceCustomSection)
    const invoiceCustomSectionError = useStore(
      form.store,
      (s) => s.fieldMeta.invoiceCustomSection?.errors?.[0]?.message,
    )

    return (
      <CenteredPage.SectionWrapper>
        <CenteredPage.PageTitle
          title={translate('text_17423672025282dl7iozy1ru')}
          description={translate('text_1782738644346p066xtwa8yj')}
        />

        <CenteredPage.SubsectionWrapper>
          <CenteredPage.PageSection>
            <CenteredPage.PageSectionTitle
              title={translate('text_177874535109128tmqdq682k')}
              description={translate('text_17827386443477iuks0kxmx5')}
            />
            <SubscriptionInvoiceConsolidationSection
              form={form}
              fields={{ consolidateInvoice: 'consolidateInvoice' }}
            />
          </CenteredPage.PageSection>

          {showCustomSection && customerId && (
            <CenteredPage.PageSection>
              <CenteredPage.PageSectionTitle
                title={translate('text_1749024634192ov41w9fp6r2')}
                description={translate('text_1782738644347o1c2bvdta8j', { object: viewTypeLabel })}
              />
              <InvoiceCustomSectionFields
                viewType={viewType}
                customerId={customerId}
                value={invoiceCustomSection}
                onChange={(value) => form.setFieldValue('invoiceCustomSection', value)}
                onBehaviorChange={(behavior) =>
                  form.setFieldValue('invoiceCustomSectionBehavior', behavior)
                }
                error={invoiceCustomSectionError ? translate(invoiceCustomSectionError) : undefined}
              />
            </CenteredPage.PageSection>
          )}
        </CenteredPage.SubsectionWrapper>
      </CenteredPage.SectionWrapper>
    )
  },
})

export interface InvoicingSettingsDrawerRef {
  openDrawer: (values: {
    consolidateInvoice: boolean
    invoiceCustomSection?: InvoiceCustomSectionInput | null
  }) => void
  closeDrawer: () => void
}

interface InvoicingSettingsDrawerProps {
  viewType: ViewTypeEnum
  customerId?: string
  showCustomSection: boolean
  onSave: (values: InvoicingSettingsValues) => void | Promise<void>
}

export const InvoicingSettingsDrawer = forwardRef<
  InvoicingSettingsDrawerRef,
  InvoicingSettingsDrawerProps
>(({ viewType, customerId, showCustomSection, onSave }, ref) => {
  const { translate } = useInternationalization()
  const drawer = useFormDrawer()

  const form = useAppForm({
    defaultValues: DEFAULT_VALUES,
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: invoicingSettingsValidationSchema,
    },
    onSubmit: async ({ value }) => {
      await onSave({
        consolidateInvoice: value.consolidateInvoice,
        invoiceCustomSection: value.invoiceCustomSection,
      })
      drawer.close()
    },
  })

  const openInvoicingSettingsDrawer = (): void => {
    drawer.open({
      title: translate('text_17423672025282dl7iozy1ru'),
      form: { id: INVOICING_SETTINGS_FORM_ID, submit: form.handleSubmit },
      closeOnSubmitSuccess: false,
      shouldPromptOnClose: () => form.state.isDirty,
      onClose: () => form.reset(),
      onEntered: (container) => focusFirstInput(container),
      children: (
        <InvoicingSettingsDrawerContent
          form={form}
          viewType={viewType}
          customerId={customerId}
          showCustomSection={showCustomSection}
        />
      ),
      mainAction: (
        <form.AppForm>
          <form.SubmitButton dataTest="invoicing-settings-drawer-save">
            {translate('text_17295436903260tlyb1gp1i7')}
          </form.SubmitButton>
        </form.AppForm>
      ),
    })
  }

  useImperativeHandle(ref, () => ({
    openDrawer: (values) => {
      const invoiceCustomSection =
        values.invoiceCustomSection ?? DEFAULT_VALUES.invoiceCustomSection

      form.reset(
        {
          consolidateInvoice: values.consolidateInvoice,
          invoiceCustomSection,
          invoiceCustomSectionBehavior: deriveInvoiceCustomSectionBehavior(invoiceCustomSection),
        },
        { keepDefaultValues: true },
      )
      openInvoicingSettingsDrawer()
    },
    closeDrawer: () => {
      drawer.close()
    },
  }))

  return null
})

InvoicingSettingsDrawer.displayName = 'InvoicingSettingsDrawer'
