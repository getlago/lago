import { useStore } from '@tanstack/react-form'

import { getHubspotTargetedObjectTranslationKey } from '~/core/constants/form'
import { HubspotIntegration, HubspotTargetedObjectsEnum } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

type HubspotCrmProviderContentProps = {
  hadInitialHubspotIntegrationCustomer: boolean
  selectedHubspotIntegration?: HubspotIntegration
  isEdition?: boolean
}

const defaultProps: HubspotCrmProviderContentProps = {
  hadInitialHubspotIntegrationCustomer: false,
  selectedHubspotIntegration: undefined,
  isEdition: false,
}

const hubspotExternalIdTypeCopyMap: Record<
  HubspotTargetedObjectsEnum,
  Record<'label' | 'placeholder', string>
> = {
  [HubspotTargetedObjectsEnum.Companies]: {
    label: 'text_1729602057769exfgebgaj4g',
    placeholder: 'text_1729602057769w37ljj318sn',
  },
  [HubspotTargetedObjectsEnum.Contacts]: {
    label: 'text_1729067791880uwec7af9cpq',
    placeholder: 'text_1729067791880y0th6mtz2av',
  },
}

const HubspotCrmProviderContent = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({
    form,
    hadInitialHubspotIntegrationCustomer,
    selectedHubspotIntegration,
    isEdition,
  }) {
    const { translate } = useInternationalization()

    const syncWithProvider = useStore(
      form.store,
      (state) => state.values.crmCustomer?.syncWithProvider,
    )

    const targetedObject = useStore(form.store, (state) => state.values.crmCustomer?.targetedObject)

    const targetedObjectdata = [
      {
        label: translate(
          getHubspotTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Companies],
        ),
        value: HubspotTargetedObjectsEnum.Companies,
      },
      {
        label: translate(
          getHubspotTargetedObjectTranslationKey[HubspotTargetedObjectsEnum.Contacts],
        ),
        value: HubspotTargetedObjectsEnum.Contacts,
      },
    ]

    const handleSyncWithProviderChange = (value: boolean | undefined) => {
      if (!value || isEdition) return

      form.setFieldValue('crmCustomer.crmCustomerId', '')
    }

    return (
      <>
        <form.AppField name="crmCustomer.targetedObject">
          {(field) => (
            <field.ComboBoxField
              disableClearable
              label={translate('text_17290677918809xyyuizjvtk')}
              disabled={hadInitialHubspotIntegrationCustomer}
              data={targetedObjectdata}
              PopperProps={{ displayInDialog: true }}
            />
          )}
        </form.AppField>
        {!!targetedObject && (
          <>
            <form.AppField name="crmCustomer.crmCustomerId">
              {(field) => (
                <field.TextInputField
                  disabled={!!syncWithProvider || hadInitialHubspotIntegrationCustomer}
                  label={translate(hubspotExternalIdTypeCopyMap[targetedObject]['label'])}
                  placeholder={translate(
                    hubspotExternalIdTypeCopyMap[targetedObject]['placeholder'],
                  )}
                />
              )}
            </form.AppField>
            <form.AppField
              name="crmCustomer.syncWithProvider"
              listeners={{
                onChange: ({ value }) => handleSyncWithProviderChange(value),
              }}
            >
              {(field) => (
                <field.CheckboxField
                  disabled={hadInitialHubspotIntegrationCustomer}
                  label={translate('text_66423cad72bbad009f2f569e', {
                    connectionName: selectedHubspotIntegration?.name || 'Hubspot',
                  })}
                />
              )}
            </form.AppField>
          </>
        )}
      </>
    )
  },
})

export default HubspotCrmProviderContent
