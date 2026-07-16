import { gql } from '@apollo/client'
import { useRef } from 'react'

import { DetailsPage } from '~/components/layouts/DetailsPage'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { SectionHeader } from '~/components/plans/details-v2/shared/SectionHeader'
import {
  InvoicingSettingsDrawer,
  InvoicingSettingsDrawerRef,
} from '~/components/subscriptions/form/InvoicingSettingsDrawer'
import { SubscriptionInvoiceCustomSectionDetails } from '~/components/subscriptions/SubscriptionInvoiceCustomSectionDetails'
import { SubscriptionInvoiceSectionFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useUpdateSubscriptionSettings } from '~/hooks/customer/useUpdateSubscriptionSettings'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment SubscriptionInvoiceSection on Subscription {
    id
    consolidateInvoice
    skipInvoiceCustomSections
    selectedInvoiceCustomSections {
      id
      name
    }
    customer {
      id
      externalId
    }
  }
`

type SubscriptionInvoiceSectionProps = {
  subscription: SubscriptionInvoiceSectionFragment
}

export const SubscriptionInvoiceSection = ({ subscription }: SubscriptionInvoiceSectionProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const drawerRef = useRef<InvoicingSettingsDrawerRef>(null)
  const { saveInvoicing } = useUpdateSubscriptionSettings(subscription.id)

  const showCustomSection = !!subscription.customer?.id

  return (
    <section className="flex flex-col gap-6">
      <SectionHeader
        title={translate('text_17423672025282dl7iozy1ru')}
        description={translate('text_1782825858647mvpxt3d6et4')}
        action={{
          label: translate('text_63e51ef4985f0ebd75c212fc'),
          startIcon: 'pen',
          onClick: () =>
            drawerRef.current?.openDrawer({
              consolidateInvoice: subscription.consolidateInvoice,
              invoiceCustomSection: {
                invoiceCustomSections: subscription.selectedInvoiceCustomSections ?? [],
                skipInvoiceCustomSections: subscription.skipInvoiceCustomSections ?? false,
              },
            }),
          hidden: !hasPermissions(['subscriptionsUpdate']),
        }}
      />

      {/* Invoice consolidation */}
      <DetailsPage.InfoGridItem
        label={translate('text_177874535109128tmqdq682k')}
        value={translate(
          subscription.consolidateInvoice
            ? 'text_1778745351091h7z5baw0ta6'
            : 'text_1778745351091fxaqr5dwok8',
        )}
      />

      {/* Invoice custom sections */}
      {showCustomSection && (
        <SubscriptionInvoiceCustomSectionDetails
          customerId={subscription.customer?.id}
          selectedInvoiceCustomSections={subscription.selectedInvoiceCustomSections}
          skipInvoiceCustomSections={subscription.skipInvoiceCustomSections}
        />
      )}

      <InvoicingSettingsDrawer
        ref={drawerRef}
        viewType={ViewTypeEnum.Subscription}
        customerId={subscription.customer?.id}
        showCustomSection={showCustomSection}
        onSave={saveInvoicing}
      />
    </section>
  )
}
