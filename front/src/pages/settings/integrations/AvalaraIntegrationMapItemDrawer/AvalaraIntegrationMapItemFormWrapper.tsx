import { FormikProps } from 'formik'

import { Typography } from '~/components/designSystem/Typography'
import { TextInputField } from '~/components/form'
import { AVALARA_TAX_CODE_DOCUMENTATION_URL } from '~/core/constants/externalUrls'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { FormValuesType } from './types'

/**
 * Those levels of deep calls are necessary just because of callback order.
 * React needs to have the callback called in the same order and since we are using a new hook in here but were not using one before
 * the element was built
 */

const AvalaraTextInputs = ({
  formikProps,
  billingEntityKey,
}: {
  formikProps: FormikProps<FormValuesType>
  billingEntityKey: string
}) => {
  const { translate } = useInternationalization()

  return (
    <div className="mb-8 flex flex-col gap-6">
      <TextInputField
        label={translate('text_1745416010613eidnh95dbs2')}
        placeholder={translate('text_17454159844152n3rimhvk4b')}
        name={`${billingEntityKey}.externalName`}
        formikProps={formikProps}
      />

      <div className="flex flex-col gap-1">
        <TextInputField
          label={translate('text_17454160106136tkffv4p4c3')}
          placeholder={translate('text_1745415984416mjvvaj4ahgp')}
          name={`${billingEntityKey}.externalId`}
          formikProps={formikProps}
        />

        <Typography
          variant="caption"
          color="grey600"
          html={translate('text_1748266296790rrag2rqt68c', {
            href: AVALARA_TAX_CODE_DOCUMENTATION_URL,
          })}
        />
      </div>
    </div>
  )
}

export const AvalaraIntegrationMapItemFormWrapper = ({
  formikProps,
  billingEntityKey,
}: {
  formikProps: FormikProps<FormValuesType>
  billingEntityKey: string
}): JSX.Element => {
  return <AvalaraTextInputs formikProps={formikProps} billingEntityKey={billingEntityKey} />
}
