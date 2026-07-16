import { Button } from '~/components/designSystem/Button'
import { ComboBox, TextInputField } from '~/components/form'
import { CurrencyEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { NetsuiteAdditionalMappingFormProps } from './types'

const NetsuiteAdditionalMappingForm = ({ formikProps }: NetsuiteAdditionalMappingFormProps) => {
  const { translate } = useInternationalization()
  const maximumNumberOfMappings = Object.keys(CurrencyEnum).length

  const alreadyExistingCurrencies = formikProps.values.default.map(
    (mapping) => mapping.currencyCode,
  )
  const possibleCurrencies = Object.values(CurrencyEnum).map((currency) => {
    return {
      label: currency,
      value: currency,
      disabled: alreadyExistingCurrencies.includes(currency),
    }
  })

  const handleOnChange = (value: string, index: number) => {
    formikProps.setFieldValue(`default.${index}.currencyCode`, value)
  }

  const handleRemoveMapping = (index: number) => {
    const updatedMappings = formikProps.values.default.filter((_, i) => i !== index)

    formikProps.setFieldValue('default', updatedMappings)
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4">
        {formikProps.values.default.map((mapping, index) => (
          <div key={index} className="grid grid-cols-[120px_1fr_40px] gap-4">
            <ComboBox
              name="selectedBillableMetric"
              data={possibleCurrencies}
              onChange={(value) => handleOnChange(value, index)}
              placeholder={translate('text_64352657267c3d916f96275d')}
              value={mapping.currencyCode}
            />
            <TextInputField
              name={`default.${index}.currencyExternalCode`}
              autoComplete="off"
              placeholder={translate('text_1762497490412zk5srhy8fqp')}
              formikProps={formikProps}
              error={undefined}
            />
            <Button
              icon="trash"
              variant="quaternary"
              size="large"
              onClick={() => handleRemoveMapping(index)}
            />
          </div>
        ))}
      </div>
      <Button
        startIcon="plus"
        disabled={formikProps.values.default.length >= maximumNumberOfMappings}
        onClick={() => {
          formikProps.setFieldValue('default', [
            ...formikProps.values.default,
            {
              currencyCode: '',
              currencyExternalCode: '',
            },
          ])
        }}
        variant="inline"
        align="left"
      >
        {translate('text_1762447693332s34s28y76vs')}
      </Button>
    </div>
  )
}

export default NetsuiteAdditionalMappingForm
