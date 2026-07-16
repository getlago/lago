import { gql } from '@apollo/client'
import { useRef } from 'react'

import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { SectionHeader } from '~/components/plans/details-v2/shared/SectionHeader'
import {
  PaymentSettingsDrawer,
  PaymentSettingsDrawerRef,
} from '~/components/subscriptions/form/PaymentSettingsDrawer'
import { SubscriptionPaymentMethodDetails } from '~/components/subscriptions/SubscriptionPaymentMethodDetails'
import { SubscriptionPaymentSectionFragment } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useUpdateSubscriptionSettings } from '~/hooks/customer/useUpdateSubscriptionSettings'
import { usePermissions } from '~/hooks/usePermissions'

gql`
  fragment SubscriptionPaymentSection on Subscription {
    id
    paymentMethodType
    paymentMethod {
      id
    }
    customer {
      id
      externalId
    }
  }
`

type SubscriptionPaymentSectionProps = {
  subscription: SubscriptionPaymentSectionFragment
}

export const SubscriptionPaymentSection = ({ subscription }: SubscriptionPaymentSectionProps) => {
  const { translate } = useInternationalization()
  const { hasPermissions } = usePermissions()
  const drawerRef = useRef<PaymentSettingsDrawerRef>(null)
  const { savePayment } = useUpdateSubscriptionSettings(subscription.id)

  const selectedPaymentMethod = {
    paymentMethodType: subscription.paymentMethodType,
    paymentMethodId: subscription.paymentMethod?.id,
  }

  return (
    <section className="flex flex-col gap-6">
      <SectionHeader
        title={translate('text_1782825858647rr5zp42t63m')}
        description={translate('text_1782825858647ro8ahgg7uys')}
        action={{
          label: translate('text_63e51ef4985f0ebd75c212fc'),
          startIcon: 'pen',
          onClick: () => drawerRef.current?.openDrawer({ paymentMethod: selectedPaymentMethod }),
          hidden: !hasPermissions(['subscriptionsUpdate']),
        }}
      />

      <SubscriptionPaymentMethodDetails
        selectedPaymentMethod={selectedPaymentMethod}
        externalCustomerId={subscription.customer?.externalId}
      />

      <PaymentSettingsDrawer
        ref={drawerRef}
        viewType={ViewTypeEnum.Subscription}
        externalCustomerId={subscription.customer?.externalId ?? ''}
        onSave={savePayment}
      />
    </section>
  )
}
