import { useStore } from '@tanstack/react-form'
import { Dispatch, SetStateAction, useMemo } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { ComboboxDataGrouped } from '~/components/form'
import { ADD_CUSTOMER_CRM_PROVIDER_ACCORDION } from '~/core/constants/form'
import {
  AddCustomerDrawerFragment,
  HubspotIntegration,
  IntegrationTypeEnum,
  SalesforceIntegration,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { integrationTypeToTypename } from '~/pages/createCustomers/common/customerIntegrationConst'
import { useCrmProviders } from '~/pages/createCustomers/common/useCrmProviders'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import Hubspot from '~/public/images/hubspot.svg'
import Salesforce from '~/public/images/salesforce.svg'

import HubspotCrmProviderContent from './HubspotCrmProviderContent'
import SalesforceCrmProviderContent from './SalesforceCrmProviderContent'

import { ExternalAppsAccordionLayout } from '../common/ExternalAppsAccordionLayout'
import { getIntegration } from '../common/getIntegration'

type CrmProvidersAccordionProps = {
  setShowCrmSection: Dispatch<SetStateAction<boolean>>
  isEdition: boolean
  customer: AddCustomerDrawerFragment | null | undefined
}

const defaultProps: CrmProvidersAccordionProps = {
  setShowCrmSection: () => {},
  isEdition: false,
  customer: null,
}

const CrmProvidersAccordion = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({ form, setShowCrmSection, isEdition, customer }) {
    const { translate } = useInternationalization()

    const { crmProviders, isLoadingCrmProviders, getCrmProviderFromCode } = useCrmProviders()

    const crmProviderCode = useStore(form.store, (state) => state.values.crmProviderCode)
    const syncWithProvider = useStore(
      form.store,
      (state) => state.values.crmCustomer?.syncWithProvider,
    )

    const crmCustomers = [customer?.hubspotCustomer, customer?.salesforceCustomer].filter(Boolean)

    const {
      hadInitialIntegrationCustomer: hadInitialHubspotIntegrationCustomer,
      allIntegrations: allHubspotIntegrations,
    } = getIntegration<HubspotIntegration>({
      integrationType: IntegrationTypeEnum.Hubspot,
      allIntegrationsData: crmProviders,
      integrationCustomers: crmCustomers,
    })

    const {
      hadInitialIntegrationCustomer: hadInitialSalesforceIntegrationCustomer,
      allIntegrations: allSalesforceIntegrations,
    } = getIntegration<SalesforceIntegration>({
      integrationType: IntegrationTypeEnum.Salesforce,
      allIntegrationsData: crmProviders,
      integrationCustomers: crmCustomers,
    })

    const getSelectedIntegration = () => {
      if (hadInitialHubspotIntegrationCustomer) {
        return allHubspotIntegrations?.find((integration) => integration.code === crmProviderCode)
      }

      if (hadInitialSalesforceIntegrationCustomer) {
        return allSalesforceIntegrations?.find(
          (integration) => integration.code === crmProviderCode,
        )
      }

      return (
        [...(allHubspotIntegrations || []), ...(allSalesforceIntegrations || [])].find(
          (integration) => integration.code === crmProviderCode,
        ) || undefined
      )
    }

    const selectedIntegration = getSelectedIntegration()

    const selectedHubspotIntegration = useMemo(() => {
      if (
        selectedIntegration &&
        selectedIntegration.__typename === integrationTypeToTypename[IntegrationTypeEnum.Hubspot]
      ) {
        return selectedIntegration as HubspotIntegration
      }
    }, [selectedIntegration])

    const selectedSalesforceIntegration = useMemo(() => {
      if (
        selectedIntegration &&
        selectedIntegration.__typename === integrationTypeToTypename[IntegrationTypeEnum.Salesforce]
      ) {
        return selectedIntegration as SalesforceIntegration
      }
    }, [selectedIntegration])

    const allAccountingIntegrationsData = useMemo(() => {
      return [...(allHubspotIntegrations || []), ...(allSalesforceIntegrations || [])]
    }, [allHubspotIntegrations, allSalesforceIntegrations])

    const connectedCrmIntegrationsData: ComboboxDataGrouped[] | [] = useMemo(() => {
      if (!allAccountingIntegrationsData?.length) return []

      return allAccountingIntegrationsData?.map((integration) => ({
        value: integration.code,
        label: integration.name,
        group: integration?.__typename?.replace('Integration', '') || '',
        labelNode: (
          <ExternalAppsAccordionLayout.ComboboxItem
            label={integration.name}
            subLabel={integration.code}
          />
        ),
      }))
    }, [allAccountingIntegrationsData])

    const getAccordionSummaryAvatar = () => {
      if (!selectedIntegration) return null

      return (
        <Avatar size="big" variant="connector-full">
          {selectedIntegration.__typename ===
            integrationTypeToTypename[IntegrationTypeEnum.Hubspot] && <Hubspot />}
          {selectedIntegration.__typename ===
            integrationTypeToTypename[IntegrationTypeEnum.Salesforce] && <Salesforce />}
        </Avatar>
      )
    }

    const handleDeleteCrmProvider = () => {
      form.setFieldValue('crmProviderCode', '')
      form.setFieldValue('crmCustomer.crmCustomerId', '')
      form.setFieldValue('crmCustomer.providerType', undefined)
      form.setFieldValue('crmCustomer.syncWithProvider', false)
      setShowCrmSection(false)
    }

    const handleChangeCrmProviderCode = (value: string | undefined) => {
      const providerType = getCrmProviderFromCode(value)

      form.setFieldValue('crmCustomer.providerType', providerType)
      form.setFieldValue('crmCustomer.id', undefined)
    }

    return (
      <div>
        <Typography variant="captionHl" color="grey700" className="mb-1">
          {translate('text_1728658962985xpfdvl5ru8a')}
        </Typography>
        <Accordion
          noContentMargin
          className={ADD_CUSTOMER_CRM_PROVIDER_ACCORDION}
          summary={
            <ExternalAppsAccordionLayout.Summary
              loading={isLoadingCrmProviders}
              avatar={getAccordionSummaryAvatar()}
              label={selectedIntegration?.name}
              subLabel={selectedIntegration?.code}
              onDelete={handleDeleteCrmProvider}
            />
          }
        >
          <div className="flex flex-col gap-6 p-4">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_65e1f90471bc198c0c934d6c')}
            </Typography>

            {/* Select connected account */}
            <form.AppField
              name="crmProviderCode"
              listeners={{
                onChange: ({ value }) => handleChangeCrmProviderCode(value),
              }}
            >
              {(field) => (
                <field.ComboBoxField
                  disabled={
                    hadInitialHubspotIntegrationCustomer || hadInitialSalesforceIntegrationCustomer
                  }
                  data={connectedCrmIntegrationsData}
                  label={translate('text_66423cad72bbad009f2f5695')}
                  placeholder={translate('text_66423cad72bbad009f2f5697')}
                  emptyText={translate('text_6645daa0468420011304aded')}
                  PopperProps={{ displayInDialog: true }}
                />
              )}
            </form.AppField>

            {!!selectedHubspotIntegration && (
              <HubspotCrmProviderContent
                form={form}
                hadInitialHubspotIntegrationCustomer={hadInitialHubspotIntegrationCustomer}
                selectedHubspotIntegration={selectedHubspotIntegration}
                isEdition={isEdition}
              />
            )}

            {!!selectedSalesforceIntegration && (
              <SalesforceCrmProviderContent
                form={form}
                hadInitialSalesforceIntegrationCustomer={hadInitialSalesforceIntegrationCustomer}
                selectedSalesforceIntegration={selectedSalesforceIntegration}
                isEdition={isEdition}
              />
            )}

            {isEdition &&
              !!selectedHubspotIntegration &&
              syncWithProvider &&
              !hadInitialHubspotIntegrationCustomer && (
                <Alert type="info">{translate('text_1729067791880abj1lzd7dn9')}</Alert>
              )}
          </div>
        </Accordion>
      </div>
    )
  },
})

export default CrmProvidersAccordion
