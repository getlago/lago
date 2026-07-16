import { Alert } from '~/components/designSystem/Alert'
import { BasicComboBoxData, ComboBox } from '~/components/form'
import { LocalFixedChargeInput, LocalUsageChargeInput } from '~/components/plans/types'
import { getChargeModelHelpTextTranslationKey } from '~/core/constants/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

export const ChargeModelSelector = ({
  alreadyUsedChargeAlertMessage,
  isInSubscriptionForm,
  disabled,
  localCharge,
  chargeModelComboboxData,
  handleUpdate,
}: {
  alreadyUsedChargeAlertMessage: string | undefined
  isInSubscriptionForm: boolean | undefined
  disabled: boolean | undefined
  localCharge: LocalUsageChargeInput | LocalFixedChargeInput
  chargeModelComboboxData: BasicComboBoxData[]
  handleUpdate: (name: string, value: unknown) => void
}) => {
  const { translate } = useInternationalization()

  return (
    <div data-test="charge-model-wrapper">
      {!!alreadyUsedChargeAlertMessage && (
        <Alert type="warning" className="mb-4">
          {alreadyUsedChargeAlertMessage}
        </Alert>
      )}
      <ComboBox
        disableClearable
        name="chargeModel"
        disabled={isInSubscriptionForm || disabled}
        label={translate('text_65201b8216455901fe273dd5')}
        data={chargeModelComboboxData}
        value={localCharge.chargeModel}
        helperText={translate(getChargeModelHelpTextTranslationKey[localCharge.chargeModel])}
        onChange={(value) => handleUpdate('chargeModel', value)}
      />
    </div>
  )
}
