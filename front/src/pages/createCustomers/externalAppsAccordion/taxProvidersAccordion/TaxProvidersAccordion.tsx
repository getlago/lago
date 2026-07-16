import { useStore } from '@tanstack/react-form'
import { Dispatch, SetStateAction, useMemo } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { ComboboxDataGrouped } from '~/components/form'
import { ADD_CUSTOMER_TAX_PROVIDER_ACCORDION } from '~/core/constants/form'
import {
  AddCustomerDrawerFragment,
  AnrokIntegration,
  AvalaraIntegration,
  IntegrationTypeEnum,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { integrationTypeToTypename } from '~/pages/createCustomers/common/customerIntegrationConst'
import { useTaxProviders } from '~/pages/createCustomers/common/useTaxProviders'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import Anrok from '~/public/images/anrok.svg'
import Avalara from '~/public/images/avalara.svg'

import AnrokTaxProviderContent from './AnrokTaxProviderContent'
import AvalaraTaxProviderContent from './AvalaraTaxProviderContent'

import { ExternalAppsAccordionLayout } from '../common/ExternalAppsAccordionLayout'
import { getIntegration } from '../common/getIntegration'

type TaxProvidersAccordionProps = {
  setShowTaxSection: Dispatch<SetStateAction<boolean>>
  isEdition: boolean
  customer: AddCustomerDrawerFragment | null | undefined
}

const defaultProps: TaxProvidersAccordionProps = {
  setShowTaxSection: () => {},
  isEdition: false,
  customer: null,
}

const TaxProvidersAccordion = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({ form, setShowTaxSection, isEdition, customer }) {
    const { translate } = useInternationalization()

    const { taxProviders, isLoadingTaxProviders, getTaxProviderFromCode } = useTaxProviders()

    const taxProviderCode = useStore(form.store, (state) => state.values.taxProviderCode)

    const taxCustomers = [customer?.anrokCustomer, customer?.avalaraCustomer].filter(Boolean)

    const {
      hadInitialIntegrationCustomer: hadInitialAnrokIntegrationCustomer,
      allIntegrations: allAnrokIntegrations,
    } = getIntegration<AnrokIntegration>({
      integrationType: IntegrationTypeEnum.Anrok,
      allIntegrationsData: taxProviders,
      integrationCustomers: taxCustomers,
    })

    const {
      hadInitialIntegrationCustomer: hadInitialAvalaraIntegrationCustomer,
      allIntegrations: allAvalaraIntegrations,
    } = getIntegration<AvalaraIntegration>({
      integrationType: IntegrationTypeEnum.Avalara,
      allIntegrationsData: taxProviders,
      integrationCustomers: taxCustomers,
    })

    const getSelectedIntegration = () => {
      if (hadInitialAnrokIntegrationCustomer) {
        return allAnrokIntegrations?.find((integration) => integration.code === taxProviderCode)
      }

      if (hadInitialAvalaraIntegrationCustomer) {
        return allAvalaraIntegrations?.find((integration) => integration.code === taxProviderCode)
      }

      return (
        [...(allAnrokIntegrations || []), ...(allAvalaraIntegrations || [])].find(
          (integration) => integration.code === taxProviderCode,
        ) || undefined
      )
    }

    const selectedIntegration = getSelectedIntegration()

    const selectedAnrokIntegration = useMemo(() => {
      if (
        selectedIntegration &&
        selectedIntegration.__typename === integrationTypeToTypename[IntegrationTypeEnum.Anrok]
      ) {
        return selectedIntegration as AnrokIntegration
      }
    }, [selectedIntegration])

    const selectedAvalaraIntegration = useMemo(() => {
      if (
        selectedIntegration &&
        selectedIntegration.__typename === integrationTypeToTypename[IntegrationTypeEnum.Avalara]
      ) {
        return selectedIntegration as AvalaraIntegration
      }
    }, [selectedIntegration])

    const allAccountingIntegrationsData = useMemo(() => {
      return [...(allAnrokIntegrations || []), ...(allAvalaraIntegrations || [])]
    }, [allAnrokIntegrations, allAvalaraIntegrations])

    const connectedTaxIntegrationsData: ComboboxDataGrouped[] | [] = useMemo(() => {
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
            integrationTypeToTypename[IntegrationTypeEnum.Anrok] && <Anrok />}
          {selectedIntegration.__typename ===
            integrationTypeToTypename[IntegrationTypeEnum.Avalara] && <Avalara />}
        </Avatar>
      )
    }

    const handleDeleteTaxProvider = () => {
      form.setFieldValue('taxProviderCode', '')
      form.setFieldValue('taxCustomer.taxCustomerId', '')
      form.setFieldValue('taxCustomer.providerType', undefined)
      form.setFieldValue('taxCustomer.syncWithProvider', false)
      setShowTaxSection(false)
    }

    const handleChangeTaxProviderCode = (value: string | undefined) => {
      const providerType = getTaxProviderFromCode(value)

      form.setFieldValue('taxCustomer.providerType', providerType)
      form.setFieldValue('taxCustomer.id', undefined)
    }

    return (
      <div>
        <Typography variant="captionHl" color="grey700" className="mb-1">
          {translate('text_6668821d94e4da4dfd8b3840')}
        </Typography>
        <Accordion
          noContentMargin
          className={ADD_CUSTOMER_TAX_PROVIDER_ACCORDION}
          summary={
            <ExternalAppsAccordionLayout.Summary
              loading={isLoadingTaxProviders}
              avatar={getAccordionSummaryAvatar()}
              label={selectedIntegration?.name}
              subLabel={selectedIntegration?.code}
              onDelete={handleDeleteTaxProvider}
            />
          }
        >
          <div className="flex flex-col gap-6 p-4">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_65e1f90471bc198c0c934d6c')}
            </Typography>

            {/* Select connected account */}
            <form.AppField
              name="taxProviderCode"
              listeners={{
                onChange: ({ value }) => handleChangeTaxProviderCode(value),
              }}
            >
              {(field) => (
                <field.ComboBoxField
                  disabled={
                    hadInitialAnrokIntegrationCustomer || hadInitialAvalaraIntegrationCustomer
                  }
                  data={connectedTaxIntegrationsData}
                  label={translate('text_66423cad72bbad009f2f5695')}
                  placeholder={translate('text_66423cad72bbad009f2f5697')}
                  emptyText={translate('text_6645daa0468420011304aded')}
                  PopperProps={{ displayInDialog: true }}
                />
              )}
            </form.AppField>

            {!!selectedAnrokIntegration && (
              <AnrokTaxProviderContent
                form={form}
                hadInitialAnrokIntegrationCustomer={hadInitialAnrokIntegrationCustomer}
                selectedAnrokIntegration={selectedAnrokIntegration}
                isEdition={isEdition}
              />
            )}

            {!!selectedAvalaraIntegration && (
              <AvalaraTaxProviderContent
                form={form}
                hadInitialAvalaraIntegrationCustomer={hadInitialAvalaraIntegrationCustomer}
                selectedAvalaraIntegration={selectedAvalaraIntegration}
                isEdition={isEdition}
              />
            )}
          </div>
        </Accordion>
      </div>
    )
  },
})

export default TaxProvidersAccordion
