import { FormikProps } from 'formik'

import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  BillingEntityForIntegrationMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common'

export type XeroIntegrationMapItemDrawerProps = {
  type: MappingTypeEnum | MappableTypeEnum
  integrationId: string
  billingEntities: Array<BillingEntityForIntegrationMapping>
  itemMappings: ItemMappingPerBillingEntity
}

export type FormValuesType = Record<
  'default' | string,
  {
    selectedElementValue: string
  }
>

export interface XeroIntegrationMapItemDrawerRef {
  openDrawer: (props: XeroIntegrationMapItemDrawerProps) => unknown
  closeDrawer: () => unknown
}

export type XeroIntegrationMapItemFormWrapperProps = {
  formikProps: FormikProps<FormValuesType>
  billingEntityKey: string
}

export type XeroIntegrationMapItemFormWrapperFactoryProps = {
  formType: MappingTypeEnum | MappableTypeEnum | undefined
  integrationId: string | undefined
}
