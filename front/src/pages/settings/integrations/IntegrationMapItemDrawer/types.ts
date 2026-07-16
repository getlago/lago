import type { FormikErrors, FormikProps, FormikValues } from 'formik'
import { AnyObject, Maybe, ObjectSchema } from 'yup'

import { DrawerRef } from '~/components/designSystem/Drawer'
import type { MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import type {
  BillingEntityForIntegrationMapping,
  CreateUpdateDeleteSuccessAnswer,
  ItemMappingForMappable,
  ItemMappingForNonTaxMapping,
  ItemMappingForTaxMapping,
  ItemMappingPerBillingEntity,
} from '~/pages/settings/integrations/common/types'

export interface IntegrationMapItemDrawerRef extends DrawerRef {
  openDrawer: (props?: unknown) => unknown
  closeDrawer: () => unknown
}

export type IntegrationMapItemDrawerProps<FormValues extends FormikValues> = {
  type: MappingTypeEnum | MappableTypeEnum | undefined
  integrationId: string | undefined
  billingEntities: Array<BillingEntityForIntegrationMapping> | undefined
  itemMappings: ItemMappingPerBillingEntity | undefined
  title: string | undefined
  description: string | undefined
  // Return type of object().shape() from yup
  validationSchema: ObjectSchema<Maybe<AnyObject>, AnyObject, unknown, ''>
  drawerRef: React.RefObject<IntegrationMapItemDrawerRef>
  formComponent: ({
    formikProps,
    billingEntityKey,
  }: {
    formikProps: FormikProps<FormValues>
    billingEntityKey: string
  }) => JSX.Element
  validateForm: (values: FormValues) => object | Promise<FormikErrors<FormValues>>
  getFormInitialValues: () => FormValues
  handleDataMutation: (
    inputValues: FormValues['values'],
    initialMapping:
      ItemMappingForTaxMapping | ItemMappingForNonTaxMapping | ItemMappingForMappable | undefined,
    formType: MappingTypeEnum | MappableTypeEnum,
    integrationId: string,
    billingEntity: BillingEntityForIntegrationMapping,
  ) => Promise<CreateUpdateDeleteSuccessAnswer>
  resetLocalData: () => void
}
