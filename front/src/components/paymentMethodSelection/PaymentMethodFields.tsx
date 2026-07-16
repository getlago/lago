import { useState } from 'react'

import { Radio } from '~/components/form/Radio/Radio'
import { PaymentMethodTypeEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { PaymentMethodComboBox } from './PaymentMethodComboBox'
import { deriveBehavior, PaymentMethodBehavior, SelectedPaymentMethod } from './types'

import { VIEW_TYPE_TRANSLATION_KEYS, ViewTypeEnum } from '../paymentMethodsInvoiceSettings/types'

export const PM_FIELDS_FALLBACK_RADIO_TEST_ID = 'payment-method-fields-fallback-radio'
export const PM_FIELDS_SPECIFIC_RADIO_TEST_ID = 'payment-method-fields-specific-radio'
export const PM_FIELDS_MANUAL_RADIO_TEST_ID = 'payment-method-fields-manual-radio'

const toValue = (
  behavior: PaymentMethodBehavior,
  paymentMethodId: string,
): SelectedPaymentMethod => {
  if (behavior === PaymentMethodBehavior.MANUAL) {
    return { paymentMethodId: null, paymentMethodType: PaymentMethodTypeEnum.Manual }
  }
  if (behavior === PaymentMethodBehavior.SPECIFIC) {
    return {
      paymentMethodId: paymentMethodId || undefined,
      paymentMethodType: PaymentMethodTypeEnum.Provider,
    }
  }

  return { paymentMethodId: null, paymentMethodType: PaymentMethodTypeEnum.Provider }
}

interface PaymentMethodFieldsProps {
  viewType: ViewTypeEnum
  externalCustomerId: string
  value?: SelectedPaymentMethod
  onChange: (value: SelectedPaymentMethod) => void
  onBehaviorChange?: (behavior: PaymentMethodBehavior) => void
  error?: string
}

export const PaymentMethodFields = ({
  viewType,
  externalCustomerId,
  value,
  onChange,
  onBehaviorChange,
  error,
}: PaymentMethodFieldsProps) => {
  const { translate } = useInternationalization()
  const viewTypeLabel = translate(VIEW_TYPE_TRANSLATION_KEYS[viewType])

  const [behavior, setBehavior] = useState<PaymentMethodBehavior>(() => deriveBehavior(value))
  const [paymentMethodId, setPaymentMethodId] = useState<string>(() => value?.paymentMethodId || '')

  const handleBehaviorChange = (next: PaymentMethodBehavior): void => {
    setBehavior(next)
    onBehaviorChange?.(next)
    onChange(toValue(next, paymentMethodId))
  }

  const handleComboboxChange = (selected: SelectedPaymentMethod): void => {
    const nextId = selected?.paymentMethodId || ''

    setPaymentMethodId(nextId)
    onChange(toValue(PaymentMethodBehavior.SPECIFIC, nextId))
  }

  return (
    <div className="flex flex-col gap-4">
      <div data-test={PM_FIELDS_FALLBACK_RADIO_TEST_ID}>
        <Radio
          name="paymentMethodBehavior"
          value={PaymentMethodBehavior.FALLBACK}
          checked={behavior === PaymentMethodBehavior.FALLBACK}
          onChange={(next) => handleBehaviorChange(next as PaymentMethodBehavior)}
          label={translate('text_1782801373795rfpcgchgkv2')}
          sublabel={translate('text_1782801373795sa2672fluz7', { object: viewTypeLabel })}
          labelVariant="body"
        />
      </div>

      <div data-test={PM_FIELDS_SPECIFIC_RADIO_TEST_ID}>
        <Radio
          name="paymentMethodBehavior"
          value={PaymentMethodBehavior.SPECIFIC}
          checked={behavior === PaymentMethodBehavior.SPECIFIC}
          onChange={(next) => handleBehaviorChange(next as PaymentMethodBehavior)}
          label={translate('text_1782801373795gxafl6ekcte')}
          sublabel={translate('text_1782801373795xhgdr3uewyu', { object: viewTypeLabel })}
          labelVariant="body"
        />
        {behavior === PaymentMethodBehavior.SPECIFIC && (
          <div className="ml-9 mt-4">
            <PaymentMethodComboBox
              externalCustomerId={externalCustomerId}
              selectedPaymentMethod={{
                paymentMethodId: paymentMethodId || undefined,
                paymentMethodType: PaymentMethodTypeEnum.Provider,
              }}
              setSelectedPaymentMethod={handleComboboxChange}
              error={error}
              PopperProps={{ displayInDialog: true }}
            />
          </div>
        )}
      </div>

      <div data-test={PM_FIELDS_MANUAL_RADIO_TEST_ID}>
        <Radio
          name="paymentMethodBehavior"
          value={PaymentMethodBehavior.MANUAL}
          checked={behavior === PaymentMethodBehavior.MANUAL}
          onChange={(next) => handleBehaviorChange(next as PaymentMethodBehavior)}
          label={translate('text_1782801373795pwkwintj6s8')}
          sublabel={translate('text_1782801373795mbjugce2ya0')}
          labelVariant="body"
        />
      </div>
    </div>
  )
}
