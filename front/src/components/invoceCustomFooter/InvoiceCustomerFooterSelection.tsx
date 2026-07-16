import { useMemo } from 'react'

import { Typography } from '~/components/designSystem/Typography'
import { ComboBox, ComboboxItem } from '~/components/form'
import { useInvoiceCustomSections } from '~/hooks/useInvoiceCustomSections'

import { InvoiceCustomSectionBasic } from './types'

interface InvoiceCustomerFooterSelectionProps {
  onChange?: (item: InvoiceCustomSectionBasic) => void
  label?: string
  placeholder?: string
  emptyText?: string
  className?: string
  disabled?: boolean
  name?: string
  invoiceCustomSelected?: InvoiceCustomSectionBasic[]
}

export const InvoiceCustomerFooterSelection = ({
  label = '',
  placeholder,
  emptyText,
  className,
  disabled: externalDisabled = false,
  name = 'selectPaymentMethod',
  invoiceCustomSelected = [],
  onChange,
}: InvoiceCustomerFooterSelectionProps) => {
  const { data: orgInvoiceCustomSections, loading } = useInvoiceCustomSections()

  const handleChange = (id: string) => {
    const item = orgInvoiceCustomSections?.find((section) => section.id === id)

    if (item) {
      onChange?.(item)
    }
  }

  const options = useMemo(() => {
    if (!orgInvoiceCustomSections) return []

    const selectedSectionIds = new Set(invoiceCustomSelected.map((section) => section.id))

    return orgInvoiceCustomSections.map(({ id, name: itemName }) => {
      const disabled = selectedSectionIds.has(id)

      return {
        label: itemName,
        labelNode: (
          <ComboboxItem>
            <Typography variant="body" color="grey700" noWrap>
              {itemName}
            </Typography>
          </ComboboxItem>
        ),
        value: id,
        disabled,
      }
    })
  }, [orgInvoiceCustomSections, invoiceCustomSelected])

  return (
    <ComboBox
      loading={loading}
      className={className}
      name={name}
      data={options}
      label={label}
      placeholder={placeholder}
      emptyText={emptyText}
      onChange={(item) => handleChange(item)}
      disabled={externalDisabled || loading}
      sortValues={false}
    />
  )
}
