import { gql } from '@apollo/client'

import { JsonEditor } from '~/components/form'
import { useChargeFormContext, usePropertyValues } from '~/contexts/ChargeFormContext'
import { PropertiesInput } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

gql`
  fragment CustomCharge on Properties {
    customProperties
  }
`

export const CUSTOM_CHARGE_JSON_EDITOR_TEST_ID = 'custom-charge-json-editor'

interface CustomChargeProps {
  onExpandCustomCharge?: (currentValue: string | undefined) => void
}

export const CustomCharge = ({ onExpandCustomCharge }: CustomChargeProps) => {
  const { form, propertyCursor, disabled } = useChargeFormContext()
  const { translate } = useInternationalization()
  const valuePointer = usePropertyValues(form, propertyCursor)

  const propertyInput: keyof PropertiesInput = 'customProperties'

  return (
    <div data-test={CUSTOM_CHARGE_JSON_EDITOR_TEST_ID}>
      <JsonEditor
        name={`${propertyCursor}.${propertyInput}`}
        label={translate('text_663dea5702b60301d8d06502')}
        value={valuePointer?.customProperties}
        disabled={disabled}
        onExpand={
          onExpandCustomCharge
            ? () => onExpandCustomCharge(valuePointer?.customProperties)
            : undefined
        }
      />
    </div>
  )
}
