import type { FormikProps } from 'formik'

import type { DrawerRef } from '~/components/designSystem/Drawer'
import type {
  CurrencyEnum,
  CurrencyMappingItem,
  MappableTypeEnum,
  MappingTypeEnum,
} from '~/generated/graphql'

export type NetsuiteAdditionalMappingsProps = {
  integrationId: string
}

export type NetsuiteAdditionalMappingDrawerProps = {
  type: MappingTypeEnum | MappableTypeEnum
  integrationId: string
  itemId?: string | undefined
  mappings?: Array<CurrencyMappingItem>
}

export interface NetsuiteAdditionalMappingDrawerRef extends DrawerRef {
  openDrawer: (props?: NetsuiteAdditionalMappingDrawerProps) => void
  closeDrawer: () => void
}

export type FormValuesType = {
  default: Array<{
    currencyCode: CurrencyEnum
    currencyExternalCode: string
  }>
}

export type NetsuiteAdditionalMappingFormProps = {
  formikProps: FormikProps<FormValuesType>
}
