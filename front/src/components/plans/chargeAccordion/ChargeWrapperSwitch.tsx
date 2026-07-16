import { type AnyFormApi } from '@tanstack/react-form'
import { memo } from 'react'

import { ChargePercentage } from '~/components/plans/ChargePercentage'
import { CustomCharge } from '~/components/plans/CustomCharge'
import { DynamicCharge } from '~/components/plans/DynamicCharge'
import { GraduatedChargeTable } from '~/components/plans/GraduatedChargeTable'
import { GraduatedPercentageChargeTable } from '~/components/plans/GraduatedPercentageChargeTable'
import { PackageCharge } from '~/components/plans/PackageCharge'
import PresentationGroupKeys from '~/components/plans/PresentationGroupKeys'
import PricingGroupKeys from '~/components/plans/PricingGroupKeys'
import { StandardCharge } from '~/components/plans/StandardCharge'
import { LocalFixedChargeInput, LocalUsageChargeInput } from '~/components/plans/types'
import { VolumeChargeTable } from '~/components/plans/VolumeChargeTable'
import { ChargeFormProvider } from '~/contexts/ChargeFormContext'
import { ALL_CHARGE_MODELS } from '~/core/constants/form'
import { CurrencyEnum } from '~/generated/graphql'

interface ChargeWrapperSwitchProps {
  chargeType: 'fixed' | 'usage'
  chargePricingUnitShortName: string | undefined
  currency: CurrencyEnum
  disabled?: boolean
  form: AnyFormApi
  isEdition: boolean
  localCharge: LocalFixedChargeInput | LocalUsageChargeInput
  propertyCursor: string
  onExpandCustomCharge?: (currentValue: string | undefined) => void
  // When rendered for a charge filter sub-form, we hide PresentationGroupKeys —
  // filters inherit them from the parent charge automatically.
  isFilterForm?: boolean
}

export const ChargeWrapperSwitch = memo(
  ({
    chargeType,
    chargePricingUnitShortName,
    currency,
    disabled,
    form,
    localCharge,
    propertyCursor,
    onExpandCustomCharge,
    isFilterForm,
  }: ChargeWrapperSwitchProps) => {
    const isUsageCharge = chargeType === 'usage'

    return (
      <ChargeFormProvider
        form={form}
        propertyCursor={propertyCursor}
        currency={currency}
        disabled={disabled}
        chargePricingUnitShortName={chargePricingUnitShortName}
      >
        <div className="flex flex-col gap-6">
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Standard && <StandardCharge />}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Package && <PackageCharge />}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Graduated && <GraduatedChargeTable />}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.GraduatedPercentage && (
            <GraduatedPercentageChargeTable />
          )}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Percentage && <ChargePercentage />}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Volume && <VolumeChargeTable />}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Custom && (
            <CustomCharge onExpandCustomCharge={onExpandCustomCharge} />
          )}
          {localCharge?.chargeModel === ALL_CHARGE_MODELS.Dynamic && <DynamicCharge />}

          {isUsageCharge && (
            <>
              <PricingGroupKeys />
              {!isFilterForm && <PresentationGroupKeys />}
            </>
          )}
        </div>
      </ChargeFormProvider>
    )
  },
)

ChargeWrapperSwitch.displayName = 'ChargeWrapperSwitch'
