import { useStore } from '@tanstack/react-form'
import { useMemo, useRef } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Selector } from '~/components/designSystem/Selector'
import { deriveBehavior, PaymentMethodBehavior } from '~/components/paymentMethodSelection/types'
import { ViewTypeEnum } from '~/components/paymentMethodsInvoiceSettings/types'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'

import { buildSubscriptionDefaultValues } from './buildSubscriptionDefaultValues'
import { PaymentSettingsDrawer, PaymentSettingsDrawerRef } from './PaymentSettingsDrawer'

const TYPING_PLACEHOLDER_DATE = '2026-01-01'

const SUMMARY_KEY_BY_BEHAVIOR: Record<PaymentMethodBehavior, string> = {
  [PaymentMethodBehavior.FALLBACK]: 'text_1782801373795rfpcgchgkv2',
  [PaymentMethodBehavior.SPECIFIC]: 'text_1782801373795gxafl6ekcte',
  [PaymentMethodBehavior.MANUAL]: 'text_1782801373795pwkwintj6s8',
}

interface PaymentSettingsSectionExtraProps {
  externalCustomerId: string
}

const paymentSettingsSectionDefaultProps: PaymentSettingsSectionExtraProps = {
  externalCustomerId: '',
}

// Entry point for the subscription payment settings: a Selector card previewing
// the current choice that opens the PaymentSettingsDrawer. Keeps the preview,
// the drawer ref and the save wiring in one place (mirrors InvoicingSettingsSection).
export const PaymentSettingsSection = withForm({
  defaultValues: buildSubscriptionDefaultValues(
    undefined,
    FORM_TYPE_ENUM.creation,
    TYPING_PLACEHOLDER_DATE,
  ),
  props: paymentSettingsSectionDefaultProps,
  render: function PaymentSettingsSectionRender({ form, externalCustomerId }) {
    const { translate } = useInternationalization()
    const drawerRef = useRef<PaymentSettingsDrawerRef>(null)

    const paymentMethod = useStore(form.store, (s) => s.values.paymentMethod)

    const summary = useMemo(
      () => translate(SUMMARY_KEY_BY_BEHAVIOR[deriveBehavior(paymentMethod)]),
      [paymentMethod, translate],
    )

    return (
      <>
        <Selector
          icon="coin-dollar"
          title={translate('text_17828013737948943pe3k8nc')}
          subtitle={summary}
          endContent={<Button icon="chevron-right-filled" variant="quaternary" tabIndex={-1} />}
          onClick={() => drawerRef.current?.openDrawer({ paymentMethod })}
          data-test="payment-settings-selector"
        />

        <PaymentSettingsDrawer
          ref={drawerRef}
          viewType={ViewTypeEnum.Subscription}
          externalCustomerId={externalCustomerId}
          onSave={({ paymentMethod: nextPaymentMethod }) => {
            form.setFieldValue('paymentMethod', nextPaymentMethod)
          }}
        />
      </>
    )
  },
})
