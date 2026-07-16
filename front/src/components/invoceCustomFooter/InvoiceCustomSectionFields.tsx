import { useState } from 'react'

import { Chip } from '~/components/designSystem/Chip'
import { MultipleComboBox } from '~/components/form'
import { Radio } from '~/components/form/Radio/Radio'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCustomerInvoiceCustomSections } from '~/hooks/useCustomerInvoiceCustomSections'
import { useInvoiceCustomSections } from '~/hooks/useInvoiceCustomSections'

import {
  deriveInvoiceCustomSectionBehavior,
  InvoiceCustomSectionBasic,
  InvoiceCustomSectionBehavior,
  InvoiceCustomSectionInput,
} from './types'

import { VIEW_TYPE_TRANSLATION_KEYS, ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

export const ICS_FIELDS_FALLBACK_RADIO_TEST_ID = 'invoice-custom-section-fields-fallback-radio'
export const ICS_FIELDS_APPLY_RADIO_TEST_ID = 'invoice-custom-section-fields-apply-radio'
export const ICS_FIELDS_NONE_RADIO_TEST_ID = 'invoice-custom-section-fields-none-radio'
export const ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID =
  'invoice-custom-section-fields-customer-default-chips'

interface InvoiceCustomSectionFieldsProps {
  viewType: ViewTypeEnum
  customerId: string
  value?: InvoiceCustomSectionInput
  onChange: (value: InvoiceCustomSectionInput) => void
  onBehaviorChange?: (behavior: InvoiceCustomSectionBehavior) => void
  error?: string
}

export const InvoiceCustomSectionFields = ({
  viewType,
  customerId,
  value,
  onChange,
  onBehaviorChange,
  error,
}: InvoiceCustomSectionFieldsProps) => {
  const { translate } = useInternationalization()
  const { data: orgInvoiceCustomSections, loading } = useInvoiceCustomSections()
  const { data: customerInvoiceCustomSections } = useCustomerInvoiceCustomSections(customerId)

  const viewTypeLabel = translate(VIEW_TYPE_TRANSLATION_KEYS[viewType])

  const customerDefaultSections =
    customerInvoiceCustomSections && !customerInvoiceCustomSections.skipInvoiceCustomSections
      ? customerInvoiceCustomSections.configurableInvoiceCustomSections
      : []

  const [behavior, setBehavior] = useState<InvoiceCustomSectionBehavior>(() =>
    deriveInvoiceCustomSectionBehavior(value),
  )
  const [selectedSections, setSelectedSections] = useState<InvoiceCustomSectionBasic[]>(
    () => value?.invoiceCustomSections ?? [],
  )

  const handleBehaviorChange = (next: InvoiceCustomSectionBehavior): void => {
    setBehavior(next)
    onBehaviorChange?.(next)

    if (next === InvoiceCustomSectionBehavior.NONE) {
      onChange({ invoiceCustomSections: [], skipInvoiceCustomSections: true })
    } else if (next === InvoiceCustomSectionBehavior.APPLY) {
      onChange({ invoiceCustomSections: selectedSections, skipInvoiceCustomSections: false })
    } else {
      onChange({ invoiceCustomSections: [], skipInvoiceCustomSections: false })
    }
  }

  const handleComboboxChange = (options: { value: string; label?: string | null }[]): void => {
    const mapped: InvoiceCustomSectionBasic[] = options.map((option) => ({
      id: option.value,
      name: option.label || '',
    }))

    setSelectedSections(mapped)
    onChange({ invoiceCustomSections: mapped, skipInvoiceCustomSections: false })
  }

  const options = (orgInvoiceCustomSections ?? []).map((section) => ({
    label: section.name,
    labelNode: section.name,
    value: section.id,
  }))

  return (
    <div className="flex flex-col gap-4">
      <div data-test={ICS_FIELDS_FALLBACK_RADIO_TEST_ID}>
        <Radio
          name="invoiceCustomSectionBehavior"
          value={InvoiceCustomSectionBehavior.FALLBACK}
          checked={behavior === InvoiceCustomSectionBehavior.FALLBACK}
          onChange={(next) => handleBehaviorChange(next as InvoiceCustomSectionBehavior)}
          label={translate('text_1782738644347svkr94bf4aw')}
          sublabel={translate('text_1782738644347lfuxg0yi21g')}
          labelVariant="body"
        />
        {behavior === InvoiceCustomSectionBehavior.FALLBACK &&
          customerDefaultSections.length > 0 && (
            <div
              className="ml-9 mt-2 flex flex-wrap gap-2"
              data-test={ICS_FIELDS_CUSTOMER_DEFAULT_CHIPS_TEST_ID}
            >
              {customerDefaultSections.map((section) => (
                <Chip key={section.id} label={section.name} />
              ))}
            </div>
          )}
      </div>

      <div data-test={ICS_FIELDS_APPLY_RADIO_TEST_ID}>
        <Radio
          name="invoiceCustomSectionBehavior"
          value={InvoiceCustomSectionBehavior.APPLY}
          checked={behavior === InvoiceCustomSectionBehavior.APPLY}
          onChange={(next) => handleBehaviorChange(next as InvoiceCustomSectionBehavior)}
          label={translate('text_1782738644347qh5s13lol1p')}
          sublabel={translate('text_1782738644347zkakx1t3ee5', { object: viewTypeLabel })}
          labelVariant="body"
        />
        {behavior === InvoiceCustomSectionBehavior.APPLY && (
          <div className="ml-9 mt-4">
            <MultipleComboBox
              hideTags={false}
              forcePopupIcon
              disabled={loading}
              name="invoiceCustomSections"
              data={options}
              onChange={handleComboboxChange}
              value={selectedSections.map((section) => ({
                value: section.id,
                label: section.name,
              }))}
              placeholder={translate('text_17653633183105vrys5z3tvj')}
              emptyText={translate('text_173642092241713ws50zg9v4')}
              error={error}
              // z-dialog (2000) sits above both the dialog (2000) and the
              // drawer (1600) layers this renders inside, so the dropdown is
              // never hidden behind its host overlay.
              PopperProps={{ displayInDialog: true }}
            />
          </div>
        )}
      </div>

      <div data-test={ICS_FIELDS_NONE_RADIO_TEST_ID}>
        <Radio
          name="invoiceCustomSectionBehavior"
          value={InvoiceCustomSectionBehavior.NONE}
          checked={behavior === InvoiceCustomSectionBehavior.NONE}
          onChange={(next) => handleBehaviorChange(next as InvoiceCustomSectionBehavior)}
          label={translate('text_1782738644347z3azl4u1f15')}
          sublabel={translate('text_1782738644347xbb9be2uu2q', { object: viewTypeLabel })}
          labelVariant="body"
        />
      </div>
    </div>
  )
}
