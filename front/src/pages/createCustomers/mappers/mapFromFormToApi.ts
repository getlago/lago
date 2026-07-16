import {
  CreateCustomerInput,
  CustomerAccountTypeEnum,
  GetAccountingIntegrationsForExternalAppsAccordionQuery,
  GetCrmIntegrationsForExternalAppsAccordionQuery,
  GetTaxIntegrationsForExternalAppsAccordionQuery,
  ProviderPaymentMethodsEnum,
  ProviderTypeEnum,
  UpdateCustomerInput,
} from '~/generated/graphql'

import { getIntegrationCustomers } from './getIntegrationCustomers'

import { CreateCustomerDefaultValues } from '../formInitialization/validationSchema'

type AdditionalData = {
  paymentProvider?: ProviderTypeEnum | null
  taxProviders?: GetTaxIntegrationsForExternalAppsAccordionQuery
  crmProviders?: GetCrmIntegrationsForExternalAppsAccordionQuery
  accountingProviders?: GetAccountingIntegrationsForExternalAppsAccordionQuery
}

export const mapFromFormToApi = (
  values: CreateCustomerDefaultValues,
  { paymentProvider, taxProviders, crmProviders, accountingProviders }: AdditionalData,
): CreateCustomerInput | UpdateCustomerInput => {
  const formattedEmail = values.email
    ?.split(',')
    .map((mail) => mail.trim())
    .join(',')

  const getProviderPaymentMethods = (): Array<ProviderPaymentMethodsEnum> => {
    return Object.entries(values.paymentProviderCustomer?.providerPaymentMethods || {}).reduce(
      (acc, [method, isEnabled]) => {
        if (isEnabled) {
          acc.push(method as ProviderPaymentMethodsEnum)
        }
        return acc
      },
      [] as Array<ProviderPaymentMethodsEnum>,
    )
  }

  const integrationCustomers = getIntegrationCustomers({
    taxProviderCode: values.taxProviderCode,
    accountingProviderCode: values.accountingProviderCode,
    crmProviderCode: values.crmProviderCode,
    taxProviders,
    accountingProviders,
    crmProviders,
    accountingCustomer: values.accountingCustomer,
    crmCustomer: values.crmCustomer,
    taxCustomer: values.taxCustomer,
  })

  const providerCustomer =
    values.paymentProviderCustomer?.providerCustomerId ||
    values.paymentProviderCustomer?.syncWithProvider
      ? {
          providerCustomerId: values.paymentProviderCustomer?.providerCustomerId,
          syncWithProvider: values.paymentProviderCustomer?.syncWithProvider,
          providerPaymentMethods: getProviderPaymentMethods(),
        }
      : null

  return {
    email: formattedEmail,
    accountType: values.isPartner
      ? CustomerAccountTypeEnum.Partner
      : CustomerAccountTypeEnum.Customer,
    customerType: values.customerType,
    name: values.name,
    firstname: values.firstname,
    lastname: values.lastname,
    externalId: values.externalId,
    externalSalesforceId: values.externalSalesforceId,
    legalName: values.legalName,
    legalNumber: values.legalNumber,
    currency: values.currency,
    phone: values.phone,
    addressLine1: values.billingAddress?.addressLine1,
    addressLine2: values.billingAddress?.addressLine2,
    city: values.billingAddress?.city,
    state: values.billingAddress?.state,
    zipcode: values.billingAddress?.zipcode,
    country: values.billingAddress?.country ?? null,
    shippingAddress:
      values.shippingAddress && Object.values(values.shippingAddress).some((value) => !!value)
        ? { ...values.shippingAddress, country: values.shippingAddress.country ?? null }
        : null,
    timezone: values.timezone,
    url: values.url,
    paymentProvider,
    paymentProviderCode: values.paymentProviderCode,
    providerCustomer,
    metadata: values.metadata?.map((meta) => ({
      id: meta.id,
      key: meta.key,
      value: meta.value,
      displayInInvoice: meta.displayInInvoice || false,
    })),
    billingEntityCode: values.billingEntityCode,
    integrationCustomers,
    taxIdentificationNumber: values.taxIdentificationNumber,
  }
}
