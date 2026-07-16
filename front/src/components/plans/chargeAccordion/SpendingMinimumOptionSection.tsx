import InputAdornment from '@mui/material/InputAdornment'
import { useEffect, useState } from 'react'

import { Button } from '~/components/designSystem/Button'
import { Tooltip } from '~/components/designSystem/Tooltip'
import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { AmountInput } from '~/components/form'
import { LocalUsageChargeInput } from '~/components/plans/types'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { getCurrencySymbol } from '~/core/formats/intlFormatNumber'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const SpendingMinimumOptionSection = ({
  initialLocalCharge,
  subscriptionFormType,
  disabled,
  localCharge,
  chargePricingUnitShortName,
  currency,
  isPremium,
  chargeIndex,
  handleUpdate,
  handleRemoveSpendingMinimum,
}: {
  initialLocalCharge: LocalUsageChargeInput
  subscriptionFormType: (typeof FORM_TYPE_ENUM)[keyof typeof FORM_TYPE_ENUM] | undefined
  disabled: boolean | undefined
  localCharge: LocalUsageChargeInput
  chargePricingUnitShortName: string | undefined
  currency: CurrencyEnum
  isPremium: boolean
  chargeIndex: number
  handleUpdate: (name: string, value: unknown) => void
  handleRemoveSpendingMinimum: () => void
}) => {
  const { translate } = useInternationalization()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()
  const [showSpendingMinimum, setShowSpendingMinimum] = useState(
    !!initialLocalCharge?.minAmountCents && Number(initialLocalCharge?.minAmountCents) > 0,
  )

  useEffect(() => {
    setShowSpendingMinimum(
      !!initialLocalCharge?.minAmountCents && Number(initialLocalCharge?.minAmountCents) > 0,
    )
  }, [initialLocalCharge?.minAmountCents])

  return (
    <>
      {!showSpendingMinimum ? (
        <Button
          fitContent
          variant="inline"
          startIcon="plus"
          disabled={subscriptionFormType === FORM_TYPE_ENUM.edition || disabled}
          endIcon={isPremium ? undefined : 'sparkles'}
          onClick={() => {
            if (isPremium) {
              setShowSpendingMinimum(true)
              setTimeout(() => {
                document.getElementById(`spending-minimum-input-${chargeIndex}`)?.focus()
              }, 0)
            } else {
              openPremiumWarningDialog()
            }
          }}
        >
          {translate('text_643e592657fc1ba5ce110b9e')}
        </Button>
      ) : (
        <div className="flex items-center gap-3">
          <AmountInput
            className="flex-1"
            id={`spending-minimum-input-${chargeIndex}`}
            beforeChangeFormatter={['positiveNumber', 'chargeDecimal']}
            currency={currency}
            placeholder={translate('text_643e592657fc1ba5ce110c80')}
            disabled={subscriptionFormType === FORM_TYPE_ENUM.edition || disabled}
            value={localCharge?.minAmountCents || ''}
            onChange={(value) => handleUpdate('minAmountCents', value)}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  {chargePricingUnitShortName || getCurrencySymbol(currency)}
                </InputAdornment>
              ),
            }}
          />
          <Tooltip placement="top-end" title={translate('text_63aa085d28b8510cd46443ff')}>
            <Button
              icon="trash"
              variant="quaternary"
              disabled={disabled}
              onClick={() => {
                handleRemoveSpendingMinimum()
                setShowSpendingMinimum(false)
              }}
            />
          </Tooltip>
        </div>
      )}
    </>
  )
}
