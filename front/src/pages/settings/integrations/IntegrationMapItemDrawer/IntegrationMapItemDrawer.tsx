import Tab from '@mui/material/Tab'
import Tabs from '@mui/material/Tabs'
import { FormikValues, useFormik } from 'formik'
import { useMemo, useState } from 'react'
import { array } from 'yup'

import { Button } from '~/components/designSystem/Button'
import { Drawer } from '~/components/designSystem/Drawer'
import { Typography } from '~/components/designSystem/Typography'
import { addToast } from '~/core/apolloClient'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import {
  DEFAULT_MAPPING_KEY,
  isItemMappingForKeyNotForCurrenciesMapping,
} from '~/pages/settings/integrations/common'
import { CreateUpdateDeleteSuccessAnswer } from '~/pages/settings/integrations/common/types'

import { IntegrationMapItemDrawerProps } from './types'

export function IntegrationMapItemDrawer<FormValues extends FormikValues>({
  type,
  integrationId,
  billingEntities,
  itemMappings,
  title,
  description,
  validationSchema,
  drawerRef,
  formComponent,
  getFormInitialValues,
  validateForm,
  handleDataMutation,
  resetLocalData,
}: IntegrationMapItemDrawerProps<FormValues>) {
  const { translate } = useInternationalization()

  const formikProps = useFormik<FormValues>({
    initialValues: getFormInitialValues(),
    validate(values) {
      return validateForm(values)
    },
    /**
     * This validates the pattern Record<string, Object>
     * More on this: https://github.com/jquense/yup/issues/524#issuecomment-530780947
     */
    validationSchema: array()
      .transform((_key, orig) => Object.values(orig))
      .of(validationSchema),
    validateOnMount: true,
    enableReinitialize: true,
    onSubmit: async (values) => {
      const promises = (billingEntities || []).map(
        async (billingEntity): Promise<CreateUpdateDeleteSuccessAnswer> => {
          if (!itemMappings || !type || !integrationId)
            return {
              success: false,
              reasons: ['Missing required data for mutation'],
            }

          const billingEntityKey = billingEntity.key || DEFAULT_MAPPING_KEY
          const inputValues = values[billingEntityKey]

          /**
           * Using this typeguard just for good measure and typing. This scenario shouldn't really happen
           */
          if (
            !isItemMappingForKeyNotForCurrenciesMapping(
              {
                mappingType: type,
              },
              itemMappings,
              billingEntityKey,
            )
          ) {
            return {
              success: false,
              reasons: ['Mapping type is not applicable for currencies mapping'],
            }
          }

          return await handleDataMutation(
            inputValues,
            itemMappings[billingEntityKey],
            type,
            integrationId,
            billingEntity,
          )
        },
      )

      const answers = await Promise.all(promises)

      const hasErrors = answers.some((answer) => {
        return !answer.success
      })

      if (!hasErrors) {
        addToast({
          message: translate('text_6630e5923500e7015f190643'),
          severity: 'success',
        })
        // Reset local data after successful submission just so we're sure we always start fresh
        resetLocalData()
        drawerRef.current?.closeDrawer()
      }
    },
  })

  const [selectedTabIndex, setSelectedTabIndex] = useState(0)

  const handleTabClick = (_event: React.SyntheticEvent<Element, Event>, newValue: number) =>
    setSelectedTabIndex(newValue)

  const billingEntitiesWithoutDefault = useMemo(() => {
    return (billingEntities || []).filter((be) => be.id !== null) || []
  }, [billingEntities])

  return (
    <Drawer
      ref={drawerRef}
      title={title}
      onClose={() => {
        formikProps.resetForm()
        formikProps.validateForm()
      }}
      stickyBottomBar={
        <div className="flex justify-end gap-3">
          <Button variant="quaternary" onClick={() => drawerRef.current?.closeDrawer()}>
            {translate('text_6244277fe0975300fe3fb94a')}
          </Button>
          <Button
            disabled={!formikProps.isValid || !formikProps.dirty}
            onClick={formikProps.submitForm}
          >
            {translate('text_6630e51df0a194013daea624')}
          </Button>
        </div>
      }
    >
      <div className="flex flex-col gap-12">
        <div className="flex flex-col gap-1">
          <Typography variant="headline">{title}</Typography>
          <Typography>{description}</Typography>
        </div>
        <div className="mb-8 flex flex-col gap-6">
          <div className="flex flex-col gap-2">
            <Typography variant="subhead1">{translate('text_6630e3210c13c500cd398e97')}</Typography>
            <Typography variant="caption">{translate('text_1762159805730gne2kxieeqo')}</Typography>
          </div>
          {formComponent({ formikProps, billingEntityKey: DEFAULT_MAPPING_KEY })}
        </div>
        <div className="flex flex-col gap-6">
          <div className="flex flex-col gap-2">
            <Typography variant="subhead1">{translate('text_1762159805730r5zfutgdloi')}</Typography>
            <Typography variant="caption">{translate('text_1762159805730hqzi614r672')}</Typography>
          </div>
          <div className="flex flex-row overflow-hidden shadow-b">
            <Tabs
              className="min-h-13 w-full flex-1 items-center"
              variant="scrollable"
              role="navigation"
              scrollButtons="auto"
              value={selectedTabIndex}
              onChange={handleTabClick}
            >
              {billingEntitiesWithoutDefault.map((billingEntity, index) => (
                <Tab
                  key={`tab-${billingEntity.id || DEFAULT_MAPPING_KEY}`}
                  disableFocusRipple
                  disableRipple
                  role="tab"
                  className="relative my-2 h-9 justify-between gap-1 rounded-xl p-2 text-grey-600 no-underline [min-height:unset] [min-width:unset] first:-ml-2 last:-mr-2 hover:bg-grey-100 hover:text-grey-700"
                  label={<Typography variant="captionHl">{billingEntity.name}</Typography>}
                  value={index}
                  id={`simple-tab-${index}`}
                  aria-controls={`simple-tabpanel-${index}`}
                />
              ))}
            </Tabs>
          </div>
          {billingEntitiesWithoutDefault.map((billingEntity, index) => {
            const isSelected = selectedTabIndex === index

            if (!isSelected) return null

            return (
              <div
                key={`tabpanel-${billingEntity.id || DEFAULT_MAPPING_KEY}`}
                role="tabpanel"
                hidden={!isSelected}
                id={`simple-tabpanel-${index}`}
                aria-labelledby={`simple-tab-${index}`}
                className="w-full"
              >
                {formComponent({
                  formikProps,
                  billingEntityKey: billingEntity.key || DEFAULT_MAPPING_KEY,
                })}
              </div>
            )
          })}
        </div>
      </div>
    </Drawer>
  )
}

IntegrationMapItemDrawer.displayName = 'IntegrationMapItemDrawer'
