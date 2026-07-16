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

import { isMappingInTaxContext } from './isMappingInTaxContext'
import { netsuiteIntegrationMapItemFormWrapperFactory } from './NetsuiteIntegrationMapItemFormWrapper'
import type {
  FormValuesType,
  NetsuiteIntegrationMapItemDrawerProps,
  NetsuiteIntegrationMapItemDrawerRef,
} from './types'
import { useNetsuiteIntegrationMappingCUD } from './useNetsuiteIntegrationMappingCUD'
import { useNetsuiteIntegrationTitleAndDescriptionMapping } from './useNetsuiteIntegrationTitleAndDescriptionMapping'

export const NetsuiteIntegrationMapItemDrawer = forwardRef<NetsuiteIntegrationMapItemDrawerRef>(
  (_, ref) => {
    const drawerRef = useRef<DrawerRef>(null)
    const [localData, setLocalData] = useState<NetsuiteIntegrationMapItemDrawerProps | undefined>(
      undefined,
    )
    const isTaxContext = localData?.type === MappingTypeEnum.Tax

    const { getTitleAndDescription } = useNetsuiteIntegrationTitleAndDescriptionMapping()

    const {
      createCollectionMapping,
      createMapping,
      deleteCollectionMapping,
      deleteMapping,
      updateCollectionMapping,
      updateMapping,
    } = useNetsuiteIntegrationMappingCUD(localData?.type)

    const getFormInitialValues = (): FormValuesType => {
      const emptyValues = {
        taxCode: '',
        taxNexus: '',
        taxType: '',
        externalId: '',
        externalName: '',
        externalAccountCode: '',
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

          acc[billingEntityKey] = {
            taxCode: isMappingInTaxContext(localData, billingEntityKey)
              ? localData.itemMappings[billingEntityKey].taxCode || ''
              : '',
            taxNexus: isMappingInTaxContext(localData, billingEntityKey)
              ? localData.itemMappings[billingEntityKey].taxNexus || ''
              : '',
            taxType: isMappingInTaxContext(localData, billingEntityKey)
              ? localData.itemMappings[billingEntityKey].taxType || ''
              : '',
            externalId: localData.itemMappings[billingEntityKey].itemExternalId || '',
            externalName: localData.itemMappings[billingEntityKey].itemExternalName || '',
            externalAccountCode: localData.itemMappings[billingEntityKey].itemExternalCode || '',
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

          const hasOneValueFilled = Object.values(inputValues).some((v) => !!v)

          // For delete action, form needs to be empty but valid
          if (!hasOneValueFilled) {
            return {
              success: true,
            }
          }

          if (hasOneValueFilled) {
            if (
              isTaxContext &&
              (!values[billingEntityKey].taxCode ||
                !values[billingEntityKey].taxNexus ||
                !values[billingEntityKey].taxType)
            ) {
              return { success: false, error: 'Fill in all inputs' }
            }

            if (
              !isTaxContext &&
              (!values[billingEntityKey].externalId ||
                !values[billingEntityKey].externalName ||
                !values[billingEntityKey].externalAccountCode)
            ) {
              return { success: false, error: 'Fill in all inputs' }
            }
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
      taxCode: string(),
      taxNexus: string(),
      taxType: string(),
      externalId: string(),
      externalName: string(),
      externalAccountCode: string(),
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
        IntegrationTypeEnum.Netsuite,
      )
    }

    const { title, description } = getTitleAndDescription(localData, localData?.type)

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
        formComponent={netsuiteIntegrationMapItemFormWrapperFactory(isTaxContext)}
        getFormInitialValues={getFormInitialValues}
        validateForm={validateForm}
        handleDataMutation={handleDataMutation}
        resetLocalData={resetLocalData}
      />
    )
  },
)

NetsuiteIntegrationMapItemDrawer.displayName = 'NetsuiteIntegrationMapItemDrawer'
