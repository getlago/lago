import { usePremiumWarningDialog } from '~/components/dialogs/PremiumWarningDialog'
import { ComboBox } from '~/components/form/ComboBox/ComboBox'
import { LockedPickerBox } from '~/components/form/LockedPickerBox'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useCurrentUser } from '~/hooks/useCurrentUser'

export const MONTH_SELECTOR_COMBO_BOX = 'month-selector-combo-box'

export const AnalyticsPeriodScopeEnum = {
  Year: 'year',
  Quarter: 'quarter',
  Month: 'month',
} as const

export const PeriodScopeTranslationLookup = {
  [AnalyticsPeriodScopeEnum.Year]: 'text_6553885df387fd0097fd7383',
  [AnalyticsPeriodScopeEnum.Quarter]: 'text_65562f85ed468200b9debb48',
  [AnalyticsPeriodScopeEnum.Month]: 'text_65562f85ed468200b9debb49',
}

export type TPeriodScopeTranslationLookupValue =
  (typeof AnalyticsPeriodScopeEnum)[keyof typeof AnalyticsPeriodScopeEnum]

const MonthSelectorDropdown = ({
  periodScope,
  setPeriodScope,
}: {
  periodScope: TPeriodScopeTranslationLookupValue
  setPeriodScope: (periodScope: TPeriodScopeTranslationLookupValue) => void
}) => {
  const { isPremium } = useCurrentUser()
  const { translate } = useInternationalization()
  const { open: openPremiumWarningDialog } = usePremiumWarningDialog()

  if (!isPremium) {
    return (
      <LockedPickerBox
        placeholder={translate(PeriodScopeTranslationLookup[periodScope])}
        onClick={() => openPremiumWarningDialog()}
        containerClassName="w-48"
      />
    )
  }

  const periodOptions = Object.values(AnalyticsPeriodScopeEnum).map((value) => ({
    value,
    label: translate(PeriodScopeTranslationLookup[value]),
    isDefault: false,
  }))

  return (
    <ComboBox
      data-test={MONTH_SELECTOR_COMBO_BOX}
      data={periodOptions}
      value={periodScope}
      onChange={(next) => {
        if (next) {
          setPeriodScope(next as TPeriodScopeTranslationLookupValue)
        }
      }}
      disableClearable
      sortValues={false}
      containerClassName="w-48"
      PopperProps={{ placement: 'bottom-end', displayInDialog: true }}
    />
  )
}

export default MonthSelectorDropdown
