import { TextInputField } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { NetsuiteIntegrationMapItemFormProps } from './types'

const NetsuiteIntegrationMapItemNonTaxContextForm = ({
  formikProps,
  billingEntityKey,
}: NetsuiteIntegrationMapItemFormProps) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-col gap-6">
      <TextInputField
        name={`${billingEntityKey}.externalName`}
        autoComplete="off"
        label={translate('text_1730738987881evzsfqnn1tr')}
        placeholder={translate('text_1730738987882hhl5gijws0m')}
        formikProps={formikProps}
        error={undefined}
      />

      <TextInputField
        name={`${billingEntityKey}.externalId`}
        autoComplete="off"
        label={translate('text_17307389878820u8ldpctozo')}
        placeholder={translate('text_173073898788226ev6fudddk')}
        formikProps={formikProps}
        error={undefined}
      />

      <TextInputField
        name={`${billingEntityKey}.externalAccountCode`}
        autoComplete="off"
        label={translate('text_1730738987882c15jo2dyc9f')}
        placeholder={translate('text_1730738987882h2yy21a82k2')}
        formikProps={formikProps}
        error={undefined}
      />
    </div>
  )
}

export default NetsuiteIntegrationMapItemNonTaxContextForm
