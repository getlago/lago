import { FormikProps } from 'formik'

import { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import type {
  BillingEntityForIntegrationMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common'

export type NetsuiteIntegrationMapItemDrawerProps = {
  type: MappingTypeEnum | MappableTypeEnum
  integrationId: string
  billingEntities: Array<BillingEntityForIntegrationMapping>
  itemMappings: ItemMappingPerBillingEntity
}

export type FormValuesType = Record<
  'default' | string,
  {
    taxCode: string
    taxNexus: string
    taxType: string
    externalId: string
    externalName: string
    externalAccountCode: string
  }
>

export type NetsuiteIntegrationMapItemFormProps = {
  formikProps: FormikProps<FormValuesType>
  billingEntityKey: 'default' | string
}

export interface NetsuiteIntegrationMapItemDrawerRef {
  openDrawer: (props: NetsuiteIntegrationMapItemDrawerProps) => unknown
  closeDrawer: () => unknown
}
