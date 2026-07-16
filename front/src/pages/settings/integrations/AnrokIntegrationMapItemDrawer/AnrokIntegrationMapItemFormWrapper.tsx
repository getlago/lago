import { FormikProps } from 'formik'

import { TextInputField } from '~/components/form'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FormValuesType } from './types'

/**
 * Those levels of deep calls are necessary just because of callback order.
 * React needs to have the callback called in the same order and since we are using a new hook in here but were not using one before
 * the element was built
 */

const AnrokTextInputs = ({
  formikProps,
  billingEntityKey,
}: {
  formikProps: FormikProps<FormValuesType>
  billingEntityKey: string
}) => {
  const { translate } = useInternationalization()

  return (
    <div className="flex flex-col gap-6">
      <TextInputField
        label={translate('text_6668821d94e4da4dfd8b38a6')}
        placeholder={translate('text_6668821d94e4da4dfd8b38be')}
        name={`${billingEntityKey}.externalName`}
        formikProps={formikProps}
      />
      <TextInputField
        label={translate('text_6668821d94e4da4dfd8b38d3')}
        placeholder={translate('text_6668821d94e4da4dfd8b38e7')}
        name={`${billingEntityKey}.externalId`}
        formikProps={formikProps}
      />
    </div>
  )
}

export const AnrokIntegrationMapItemFormWrapper = ({
  formikProps,
  billingEntityKey,
}: {
  formikProps: FormikProps<FormValuesType>
  billingEntityKey: string
}): JSX.Element => {
  return <AnrokTextInputs formikProps={formikProps} billingEntityKey={billingEntityKey} />
}
