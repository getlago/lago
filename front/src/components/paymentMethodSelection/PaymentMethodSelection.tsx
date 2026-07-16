import { useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Typography } from '~/components/designSystem/Typography'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { usePaymentMethodsList } from '~/hooks/customer/usePaymentMethodsList'

import { EditPaymentMethodDialog } from './EditPaymentMethodDialog'
import { PaymentMethodDisplay } from './PaymentMethodDisplay'
import { PaymentMethodSelectionProps } from './types'
import { useDisplayedPaymentMethod } from './useDisplayedPaymentMethod'

import { VIEW_TYPE_TRANSLATION_KEYS } from '../paymentMethodsInvoiceSettings/types'

export const EDIT_PAYMENT_METHOD_BUTTON_TEST_ID = 'edit-payment-method-button'

export const PaymentMethodSelection = ({
  externalCustomerId,
  selectedPaymentMethod,
  setSelectedPaymentMethod,
  viewType,
  className,
  disabled = false,
}: PaymentMethodSelectionProps) => {
  const { translate } = useInternationalization()
  const [isDialogOpen, setIsDialogOpen] = useState(false)

  const {
    data: paymentMethodsList,
    loading: paymentMethodsLoading,
    error: paymentMethodsError,
  } = usePaymentMethodsList({
    externalCustomerId: externalCustomerId || '',
    withDeleted: false,
  })

  const displayedPaymentMethod = useDisplayedPaymentMethod(
    selectedPaymentMethod,
    paymentMethodsList,
  )

  const isLoading = paymentMethodsLoading || !!paymentMethodsError
  const isDisabled = disabled || isLoading

  return (
    <div className={className}>
      <Typography variant="captionHl" color="textSecondary">
        {translate('text_17440371192353kif37ol194')}
      </Typography>

      <Typography variant="caption" className="mb-3">
        {translate('text_1762862363071z59xqjpg844', {
          object: translate(VIEW_TYPE_TRANSLATION_KEYS[viewType]),
        })}
      </Typography>

      <div className="flex flex-col gap-3">
        <PaymentMethodDisplay displayedPaymentMethod={displayedPaymentMethod} />

        <div className="flex items-start">
          <Button
            variant="inline"
            startIcon="pen"
            onClick={() => setIsDialogOpen(true)}
            disabled={isDisabled}
            data-test={EDIT_PAYMENT_METHOD_BUTTON_TEST_ID}
          >
            {translate('text_1764327933607oenowqiqwht')}
          </Button>
        </div>
      </div>

      <EditPaymentMethodDialog
        open={isDialogOpen}
        onClose={() => setIsDialogOpen(false)}
        selectedPaymentMethod={selectedPaymentMethod}
        setSelectedPaymentMethod={setSelectedPaymentMethod}
        externalCustomerId={externalCustomerId}
        viewType={viewType}
      />
    </div>
  )
}
