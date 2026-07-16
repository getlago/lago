import { FormikErrors } from 'formik'
import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { object, string } from 'yup'

import { DrawerRef } from '~/components/designSystem/Drawer'
import { IntegrationTypeEnum, MappableTypeEnum, MappingTypeEnum } from '~/generated/graphql'
import {
  BillingEntityForIntegrationMapping,
  DEFAULT_MAPPING_KEY,
  handleIntegrationMappingCreateUpdateDelete,
  isItemMappingForKeyNotForCurrenciesMapping,
  ItemMappingForMappable,
  ItemMappingForNonTaxMapping,
  ItemMappingForTaxMapping,
} from '~/pages/settings/integrations/common'
import { IntegrationMapItemDrawer } from '~/pages/settings/integrations/IntegrationMapItemDrawer'

import { extractOptionValue } from './extractOptionValue'
import { stringifyOptionValue } from './stringifyOptionValue'
import {
  FormValuesType,
  XeroIntegrationMapItemDrawerProps,
  XeroIntegrationMapItemDrawerRef,
} from './types'
import { useXeroIntegrationMappingCRUD } from './useXeroIntegrationMappingCRUD'
import { useXeroIntegrationTitleAndDescriptionMapping } from './useXeroIntegrationTitleAndDescriptionMapping'
import { xeroIntegrationMapItemFormWrapperFactory } from './XeroIntegrationMapItemFormWrapper'

export const XeroIntegrationMapItemDrawer = forwardRef<XeroIntegrationMapItemDrawerRef>(
  (_, ref) => {
    const drawerRef = useRef<DrawerRef>(null)
    const [localData, setLocalData] = useState<XeroIntegrationMapItemDrawerProps | undefined>(
      undefined,
    )

    const { getTitleAndDescription } = useXeroIntegrationTitleAndDescriptionMapping()

    const { title, description } = getTitleAndDescription(localData, localData?.type)

    const {
      createCollectionMapping,
      createMapping,
      deleteCollectionMapping,
      deleteMapping,
      updateCollectionMapping,
      updateMapping,
    } = useXeroIntegrationMappingCRUD(localData?.type, localData?.integrationId)

    const getFormInitialValues = (): FormValuesType => {
      const emptyValues = {
        selectedElementValue: '',
      }

      if (!localData)
        return {
          default: emptyValues,
        }

      return localData.billingEntities.reduce(
        (acc: FormValuesType, billingEntity: BillingEntityForIntegrationMapping) => {
          const billingEntityKey = billingEntity.key || DEFAULT_MAPPING_KEY

          if (
            !isItemMappingForKeyNotForCurrenciesMapping(
              localData,
              localData.itemMappings,
              billingEntityKey,
            )
          ) {
            return acc
          }

          if (
            !localData.itemMappings[billingEntityKey].itemExternalId ||
            !localData.itemMappings[billingEntityKey].itemExternalName ||
            !localData.itemMappings[billingEntityKey].itemExternalCode
          ) {
            acc[billingEntityKey] = emptyValues
            return acc
          }

          acc[billingEntityKey] = {
            selectedElementValue: stringifyOptionValue({
              externalId: localData.itemMappings[billingEntityKey].itemExternalId || '',
              externalName: localData.itemMappings[billingEntityKey].itemExternalName || '',
              externalAccountCode: localData.itemMappings[billingEntityKey].itemExternalCode || '',
            }),
          }

          return acc
        },
        {},
      )
    }

    const validateForm = (
      values: FormValuesType,
    ): object | Promise<FormikErrors<FormValuesType>> => {
      if (!localData) return {}

      const validationPerBillingEntity = localData.billingEntities.map(
        (
          billingEntity,
        ):
          | {
              success: true
            }
          | { success: false; error: string } => {
          const billingEntityKey = billingEntity.key || DEFAULT_MAPPING_KEY
          const inputValues = values[billingEntityKey]

          const selectedElementValue = inputValues.selectedElementValue

          // Can be empty to clear the mapping
          if (!selectedElementValue) {
            return { success: true }
          }

          const { externalAccountCode, externalId, externalName } =
            extractOptionValue(selectedElementValue)

          if (!externalAccountCode || !externalId || !externalName) {
            return { success: false, error: 'Fill in all inputs' }
          }

          return { success: true }
        },
      )

      const hasOneError = validationPerBillingEntity.some(
        (validation) => validation.success === false,
      )

      if (hasOneError) {
        return { error: 'Fill in all inputs' }
      }

      return {}
    }

    const validationSchema = object().shape({
      selectedElementValue: string(),
    })

    const handleDataMutation = async (
      inputValues: FormValuesType['values'],
      initialMapping:
        ItemMappingForTaxMapping | ItemMappingForNonTaxMapping | ItemMappingForMappable | undefined,
      formType: MappingTypeEnum | MappableTypeEnum,
      integrationId: string,

      billingEntity: BillingEntityForIntegrationMapping,
    ) => {
      return await handleIntegrationMappingCreateUpdateDelete(
        inputValues,
        initialMapping,
        formType,
        integrationId,
        {
          createCollectionMapping,
          createMapping,
          deleteCollectionMapping,
          deleteMapping,
          updateCollectionMapping,
          updateMapping,
        },
        billingEntity,
        IntegrationTypeEnum.Xero,
      )
    }

    const resetLocalData = () => {
      setLocalData(undefined)
    }

    useImperativeHandle(ref, () => ({
      openDrawer: (props) => {
        setLocalData(props)
        drawerRef.current?.openDrawer()
      },
      closeDrawer: () => drawerRef.current?.closeDrawer(),
    }))

    return (
      <IntegrationMapItemDrawer
        type={localData?.type}
        integrationId={localData?.integrationId}
        billingEntities={localData?.billingEntities}
        itemMappings={localData?.itemMappings}
        drawerRef={drawerRef}
        title={title}
        description={description}
        validationSchema={validationSchema}
        formComponent={xeroIntegrationMapItemFormWrapperFactory({
          formType: localData?.type,
          integrationId: localData?.integrationId,
        })}
        getFormInitialValues={getFormInitialValues}
        validateForm={validateForm}
        handleDataMutation={handleDataMutation}
        resetLocalData={resetLocalData}
      />
    )
  },
)

XeroIntegrationMapItemDrawer.displayName = 'XeroIntegrationMapItemDrawer'
