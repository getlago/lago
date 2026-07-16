import { FormikProps } from 'formik'

import NetsuiteIntegrationMapItemNonTaxContextForm from './NetsuiteIntegrationMapItemNonTaxContextForm'
import NetsuiteIntegrationMapItemTaxContextForm from './NetsuiteIntegrationMapItemTaxContextForm'
import { FormValuesType } from './types'

export function netsuiteIntegrationMapItemFormWrapperFactory(isTaxContext: boolean) {
  const NetsuiteIntegrationMapItemFormWrapper = ({
    formikProps,
    billingEntityKey,
  }: {
    formikProps: FormikProps<FormValuesType>
    billingEntityKey: string
  }): JSX.Element => {
    if (isTaxContext) {
      return (
        <NetsuiteIntegrationMapItemTaxContextForm
          formikProps={formikProps}
          billingEntityKey={billingEntityKey}
        />
      )
    }

    return (
      <NetsuiteIntegrationMapItemNonTaxContextForm
        formikProps={formikProps}
        billingEntityKey={billingEntityKey}
      />
    )
  }

  return NetsuiteIntegrationMapItemFormWrapper
}
