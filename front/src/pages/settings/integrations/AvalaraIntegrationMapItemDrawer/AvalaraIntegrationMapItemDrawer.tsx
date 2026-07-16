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

import { AvalaraIntegrationMapItemFormWrapper } from './AvalaraIntegrationMapItemFormWrapper'
import {
  AvalaraIntegrationMapItemDrawerProps,
  AvalaraIntegrationMapItemDrawerRef,
  FormValuesType,
} from './types'
import { useAvalaraIntegrationMappingCUD } from './useAvalaraIntegrationMappingCUD'
import { useAvalaraIntegrationTitleAndDescriptionMapping } from './useAvalaraIntegrationTitleAndDescriptionMapping'

export const AvalaraIntegrationMapItemDrawer = forwardRef<AvalaraIntegrationMapItemDrawerRef>(
  (_, ref) => {
    const drawerRef = useRef<DrawerRef>(null)
    const [localData, setLocalData] = useState<AvalaraIntegrationMapItemDrawerProps | undefined>(
      undefined,
    )

    const { getTitleAndDescription } = useAvalaraIntegrationTitleAndDescriptionMapping()

    const { title, description } = getTitleAndDescription(localData, localData?.type)

    const {
      createCollectionMapping,
      createMapping,
      deleteCollectionMapping,
      deleteMapping,
      updateCollectionMapping,
      updateMapping,
    } = useAvalaraIntegrationMappingCUD(localData?.type)

    const getFormInitialValues = (): FormValuesType => {
      const emptyValues = {
        externalId: '',
        externalName: '',
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
            externalId: localData.itemMappings[billingEntityKey].itemExternalId || '',
            externalName: localData.itemMappings[billingEntityKey].itemExternalName || '',
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
            if (!values[billingEntityKey].externalId || !values[billingEntityKey].externalName) {
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
      externalId: string(),
      externalName: string(),
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
        IntegrationTypeEnum.Avalara,
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
        formComponent={AvalaraIntegrationMapItemFormWrapper}
        getFormInitialValues={getFormInitialValues}
        validateForm={validateForm}
        handleDataMutation={handleDataMutation}
        resetLocalData={resetLocalData}
      />
    )
  },
)

AvalaraIntegrationMapItemDrawer.displayName = 'AvalaraIntegrationMapItemDrawer'
