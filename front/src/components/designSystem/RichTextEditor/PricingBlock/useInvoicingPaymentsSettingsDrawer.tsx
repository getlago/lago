import { useCallback, useRef, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useDrawer } from '~/components/drawers/useDrawer'
import type { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { CenteredPage } from '~/components/layouts/CenteredPage'
import type { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { PaymentMethodsInvoiceSettings } from '~/components/paymentMethodsInvoiceSettings/PaymentMethodsInvoiceSettings'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import type { QuoteCustomer } from '~/pages/quotes/hooks/useSubscriptionPricingDrawer'

export const INVOICING_PAYMENTS_DRAWER_SAVE_TEST_ID = 'invoicing-payments-drawer-save'

export interface InvoicingPaymentsSettingsFormValues {
  paymentMethodId: string
  invoiceCustomFooter: string
}

/**
 * Bridges the PaymentMethodsInvoiceSettings component (which works with
 * `paymentMethod` objects and `invoiceCustomSection` objects) with the
 * quote serializer (which stores simple `paymentMethodId` and
 * `invoiceCustomFooter` strings).
 *
 * Local state inside the drawer tracks the rich object shapes. On save,
 * we extract the flat string values back for the serializer.
 */
function InvoicingPaymentsDrawerContent({
  customer,
  initialValues,
  initialInvoiceCustomSection,
  valuesRef,
}: Readonly<{
  customer: QuoteCustomer
  initialValues: InvoicingPaymentsSettingsFormValues
  initialInvoiceCustomSection?: InvoiceCustomSectionInput
  valuesRef: React.MutableRefObject<{
    paymentMethod: SelectedPaymentMethod
    invoiceCustomSection: InvoiceCustomSectionInput | undefined
  }>
}>) {
  const [paymentMethod, setPaymentMethod] = useState<SelectedPaymentMethod>(
    initialValues.paymentMethodId ? { paymentMethodId: initialValues.paymentMethodId } : null,
  )
  const [invoiceCustomSection, setInvoiceCustomSection] = useState<
    InvoiceCustomSectionInput | undefined
  >(initialInvoiceCustomSection)

  // Keep valuesRef in sync so the save handler can read current values
  valuesRef.current = { paymentMethod, invoiceCustomSection }

  const formAdapter = {
    values: { paymentMethod, invoiceCustomSection } as Partial<Record<string, unknown>>,
    setFieldValue: (field: string, value: unknown) => {
      if (field === 'paymentMethod') {
        setPaymentMethod(value as SelectedPaymentMethod)
      } else if (field === 'invoiceCustomSection') {
        setInvoiceCustomSection(value as InvoiceCustomSectionInput | undefined)
      }
    },
  }

  return (
    <PaymentMethodsInvoiceSettings
      customer={customer}
      form={formAdapter}
      viewType={ViewTypeEnum.Subscription}
    />
  )
}

export const useInvoicingPaymentsSettingsDrawer = (
  onSave: (values: InvoicingPaymentsSettingsFormValues) => void,
  customer?: QuoteCustomer | null,
) => {
  const { translate } = useInternationalization()
  const drawer = useDrawer()

  const valuesRef = useRef<{
    paymentMethod: SelectedPaymentMethod
    invoiceCustomSection: InvoiceCustomSectionInput | undefined
  }>({
    paymentMethod: null,
    invoiceCustomSection: undefined,
  })

  const handleSave = useCallback(() => {
    const { paymentMethod, invoiceCustomSection } = valuesRef.current

    onSave({
      paymentMethodId: paymentMethod?.paymentMethodId ?? '',
      invoiceCustomFooter: invoiceCustomSection ? JSON.stringify(invoiceCustomSection) : '',
    })
    drawer.close()
  }, [onSave, drawer])

  const showSection = Boolean(customer?.externalId || customer?.id)

  const openDrawer = useCallback(
    (values: InvoicingPaymentsSettingsFormValues) => {
      // Reset valuesRef for new drawer session
      const parsedSection = values.invoiceCustomFooter
        ? (JSON.parse(values.invoiceCustomFooter) as InvoiceCustomSectionInput)
        : undefined

      valuesRef.current = {
        paymentMethod: values.paymentMethodId ? { paymentMethodId: values.paymentMethodId } : null,
        invoiceCustomSection: parsedSection,
      }

      drawer.open({
        title: translate('text_17791987800309g2j0x3t2n0'),
        children: (
          <CenteredPage.SectionWrapper>
            <CenteredPage.PageTitle
              title={translate('text_17791987800309g2j0x3t2n0')}
              description={translate('text_1779198780030brdysjhb54o')}
            />
            {showSection && customer ? (
              <InvoicingPaymentsDrawerContent
                customer={customer}
                initialValues={values}
                initialInvoiceCustomSection={parsedSection}
                valuesRef={valuesRef}
              />
            ) : (
              <Typography variant="caption" color="grey600">
                {translate('text_17440371192355fhimnf6j8x')}
              </Typography>
            )}
          </CenteredPage.SectionWrapper>
        ),
        actions: (
          <div className="flex items-center justify-end gap-3">
            <Button variant="quaternary" onClick={() => drawer.close()}>
              {translate('text_6411e6b530cb47007488b027')}
            </Button>
            <Button data-test={INVOICING_PAYMENTS_DRAWER_SAVE_TEST_ID} onClick={handleSave}>
              {translate('text_17295436903260tlyb1gp1i7')}
            </Button>
          </div>
        ),
      })
    },
    [drawer, translate, handleSave, showSection, customer],
  )

  return { openDrawer, showSection }
}
