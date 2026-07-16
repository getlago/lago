import { useStore } from '@tanstack/react-form'
import { Dispatch, SetStateAction, useMemo } from 'react'

import { Accordion } from '~/components/designSystem/Accordion'
import { Alert } from '~/components/designSystem/Alert'
import { Avatar } from '~/components/designSystem/Avatar'
import { Typography } from '~/components/designSystem/Typography'
import { ComboboxDataGrouped } from '~/components/form'
import { ADD_CUSTOMER_ACCOUNTING_PROVIDER_ACCORDION } from '~/core/constants/form'
import {
  AddCustomerDrawerFragment,
  IntegrationTypeEnum,
  NetsuiteIntegration,
  XeroIntegration,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { integrationTypeToTypename } from '~/pages/createCustomers/common/customerIntegrationConst'
import { useAccountingProviders } from '~/pages/createCustomers/common/useAccountingProviders'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'
import Netsuite from '~/public/images/netsuite.svg'
import Xero from '~/public/images/xero.svg'

import NetsuiteAccountingProviderContent from './NetsuiteAccountingProviderContent'
import XeroAccountingProviderContent from './XeroAccountingProviderContent'

import { ExternalAppsAccordionLayout } from '../common/ExternalAppsAccordionLayout'
import { getIntegration } from '../common/getIntegration'

type AccountingProvidersAccordionProps = {
  isEdition: boolean
  setShowAccountingSection: Dispatch<SetStateAction<boolean>>
  customer: AddCustomerDrawerFragment | null | undefined
}

const defaultProps: AccountingProvidersAccordionProps = {
  isEdition: false,
  setShowAccountingSection: () => {},
  customer: null,
}

const AccountingProvidersAccordion = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({ form, isEdition, setShowAccountingSection, customer }) {
    const { translate } = useInternationalization()

    const { accountingProviders, isLoadingAccountProviders, getAccountingProviderFromCode } =
      useAccountingProviders()

    const accountingProviderCode = useStore(
      form.store,
      (state) => state.values.accountingProviderCode,
    )

    const accountingCustomer = useStore(form.store, (state) => state.values.accountingCustomer)

    const accountingCustomers = [customer?.xeroCustomer, customer?.netsuiteCustomer].filter(Boolean)

    const {
      hadInitialIntegrationCustomer: hadInitialNetsuiteIntegrationCustomer,
      allIntegrations: allNetsuiteIntegrations,
    } = getIntegration<NetsuiteIntegration>({
      integrationType: IntegrationTypeEnum.Netsuite,
      allIntegrationsData: accountingProviders,
      integrationCustomers: accountingCustomers,
    })

    const {
      hadInitialIntegrationCustomer: hadInitialXeroIntegrationCustomer,
      allIntegrations: allXeroIntegrations,
    } = getIntegration<XeroIntegration>({
      integrationType: IntegrationTypeEnum.Xero,
      allIntegrationsData: accountingProviders,
      integrationCustomers: accountingCustomers,
    })

    const getSelectedIntegration = () => {
      const netsuite = allNetsuiteIntegrations || []
      const xero = allXeroIntegrations || []

      if (hadInitialNetsuiteIntegrationCustomer) {
        return netsuite.find((integration) => integration.code === accountingProviderCode)
      }

      if (hadInitialXeroIntegrationCustomer) {
        return xero.find((integration) => integration.code === accountingProviderCode)
      }

      return (
        [...netsuite, ...xero].find((integration) => integration.code === accountingProviderCode) ||
        undefined
      )
    }

    const selectedIntegration = getSelectedIntegration()

    const selectedNetsuiteIntegration = useMemo(() => {
      if (
        selectedIntegration &&
        selectedIntegration.__typename === integrationTypeToTypename[IntegrationTypeEnum.Netsuite]
      ) {
        return selectedIntegration as NetsuiteIntegration
      }
    }, [selectedIntegration])

    const selectedXeroIntegration = useMemo(() => {
      if (
        selectedIntegration &&
        selectedIntegration.__typename === integrationTypeToTypename[IntegrationTypeEnum.Xero]
      ) {
        return selectedIntegration as XeroIntegration
      }
    }, [selectedIntegration])

    const allAccountingIntegrationsData = useMemo(() => {
      return [...(allNetsuiteIntegrations || []), ...(allXeroIntegrations || [])]
    }, [allNetsuiteIntegrations, allXeroIntegrations])

    const connectedAccountingIntegrationsData: ComboboxDataGrouped[] | [] = useMemo(() => {
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
            integrationTypeToTypename[IntegrationTypeEnum.Netsuite] && <Netsuite />}
          {selectedIntegration.__typename ===
            integrationTypeToTypename[IntegrationTypeEnum.Xero] && <Xero />}
        </Avatar>
      )
    }

    const handleDeleteAccountingProvider = () => {
      form.setFieldValue('accountingProviderCode', '')
      form.setFieldValue('accountingCustomer.accountingCustomerId', '')
      form.setFieldValue('accountingCustomer.providerType', undefined)
      form.setFieldValue('accountingCustomer.syncWithProvider', false)
      setShowAccountingSection(false)
    }

    const handleChangeAccountingProviderCode = (value: string | undefined) => {
      const providerType = getAccountingProviderFromCode(value)

      form.setFieldValue('accountingCustomer.providerType', providerType)
      // Clear the integration customer id when switching integrations
      // so the backend creates a new link instead of trying to update a stale one
      form.setFieldValue('accountingCustomer.id', undefined)
    }

    return (
      <div>
        <Typography variant="captionHl" color="grey700" className="mb-1">
          {translate('text_66423cad72bbad009f2f568f')}
        </Typography>
        <Accordion
          noContentMargin
          className={ADD_CUSTOMER_ACCOUNTING_PROVIDER_ACCORDION}
          summary={
            <ExternalAppsAccordionLayout.Summary
              loading={isLoadingAccountProviders}
              avatar={getAccordionSummaryAvatar()}
              label={selectedIntegration?.name}
              subLabel={selectedIntegration?.code}
              onDelete={handleDeleteAccountingProvider}
            />
          }
        >
          <div className="flex flex-col gap-6 p-4">
            <Typography variant="bodyHl" color="grey700">
              {translate('text_65e1f90471bc198c0c934d6c')}
            </Typography>

            {/* Select Integration account */}
            <form.AppField
              name="accountingProviderCode"
              listeners={{
                onChange: ({ value }) => handleChangeAccountingProviderCode(value),
              }}
            >
              {(field) => (
                <field.ComboBoxField
                  disabled={
                    hadInitialNetsuiteIntegrationCustomer || hadInitialXeroIntegrationCustomer
                  }
                  data={connectedAccountingIntegrationsData}
                  label={translate('text_66423cad72bbad009f2f5695')}
                  placeholder={translate('text_66423cad72bbad009f2f5697')}
                  emptyText={translate('text_6645daa0468420011304aded')}
                  PopperProps={{ displayInDialog: true }}
                />
              )}
            </form.AppField>

            {!!selectedNetsuiteIntegration && (
              <NetsuiteAccountingProviderContent
                form={form}
                hadInitialNetsuiteIntegrationCustomer={hadInitialNetsuiteIntegrationCustomer}
                selectedNetsuiteIntegration={selectedNetsuiteIntegration}
                isEdition={isEdition}
              />
            )}

            {!!selectedXeroIntegration && (
              <XeroAccountingProviderContent
                form={form}
                hadInitialXeroIntegrationCustomer={hadInitialXeroIntegrationCustomer}
                selectedXeroIntegration={selectedXeroIntegration}
                isEdition={isEdition}
              />
            )}

            {/* // If we are editing and have a Xero integration selected, show this info alert  */}
            {isEdition &&
              !!selectedXeroIntegration &&
              accountingCustomer?.syncWithProvider &&
              !hadInitialXeroIntegrationCustomer && (
                <Alert type="info">{translate('text_667d39dc1a765800d28d0607')}</Alert>
              )}
          </div>
        </Accordion>
      </div>
    )
  },
})

export default AccountingProvidersAccordion
