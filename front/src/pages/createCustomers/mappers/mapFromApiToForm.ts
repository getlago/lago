import {
  AddCustomerDrawerFragment,
  CurrencyEnum,
  CustomerAccountTypeEnum,
  ProviderPaymentMethodsEnum,
} from '~/generated/graphql'

import { BillingEntityItem } from './types'

import { CreateCustomerDefaultValues } from '../formInitialization/validationSchema'

export const mapFromApiToForm = (
  customer: AddCustomerDrawerFragment | undefined,
  defaultBillingEntity: BillingEntityItem | undefined,
): CreateCustomerDefaultValues => {
  const getCustomerProviderMethod = () => {
    if (!customer?.providerCustomer?.providerPaymentMethods?.length) {
      return customer?.currency === CurrencyEnum.Eur
        ? { [ProviderPaymentMethodsEnum.Card]: true, [ProviderPaymentMethodsEnum.SepaDebit]: true }
        : { [ProviderPaymentMethodsEnum.Card]: true }
    }
    return customer?.providerCustomer?.providerPaymentMethods.reduce(
      (acc, method) => {
        acc[method] = true
        return acc
      },
      {} as Record<ProviderPaymentMethodsEnum, boolean>,
    )
  }

  const compareBillingAddressWithShippingAddress = () => {
    if (!customer) return false
    const billingAddress = [
      customer.addressLine1,
      customer.addressLine2,
      customer.city,
      customer.state,
      customer.zipcode,
      customer.country,
    ]
    const shippingAddress = [
      customer.shippingAddress?.addressLine1,
      customer.shippingAddress?.addressLine2,
      customer.shippingAddress?.city,
      customer.shippingAddress?.state,
      customer.shippingAddress?.zipcode,
      customer.shippingAddress?.country,
    ]

    return billingAddress.every((value, index) => value === shippingAddress[index])
  }

  // Should only have one between xero and netsuite
  const accountingProvider =
    [customer?.xeroCustomer, customer?.netsuiteCustomer].find(Boolean) || undefined

  // Should only have one between hubspot and salesforce
  const crmProvider =
    [customer?.hubspotCustomer, customer?.salesforceCustomer].find(Boolean) || undefined

  // Should only have one between anrok and avalara
  const taxProvider =
    [customer?.anrokCustomer, customer?.avalaraCustomer].find(Boolean) || undefined

  const getTargetedObject = () => {
    if (!crmProvider) return {}
    if ('targetedObject' in crmProvider) {
      return crmProvider.targetedObject ? { targetedObject: crmProvider.targetedObject } : {}
    }
    return {}
  }

  return {
    customerType: customer?.customerType ?? undefined,
    // is partner is only used for display purpose and should not be sent to API
    isPartner: customer?.accountType === CustomerAccountTypeEnum.Partner,
    name: customer?.name ?? '',
    firstname: customer?.firstname ?? '',
    lastname: customer?.lastname ?? '',
    externalId: customer?.externalId ?? '',
    externalSalesforceId: customer?.externalSalesforceId ?? '',
    legalName: customer?.legalName ?? '',
    legalNumber: customer?.legalNumber ?? '',
    taxIdentificationNumber: customer?.taxIdentificationNumber ?? '',
    currency: customer?.currency ?? undefined,
    phone: customer?.phone ?? '',
    email: customer?.email ?? undefined,
    billingAddress: {
      addressLine1: customer?.addressLine1 ?? '',
      addressLine2: customer?.addressLine2 ?? '',
      state: customer?.state ?? '',
      country: customer?.country ?? null,
      city: customer?.city ?? '',
      zipcode: customer?.zipcode ?? '',
    },
    isShippingEqualBillingAddress: compareBillingAddressWithShippingAddress(),
    shippingAddress: {
      addressLine1: customer?.shippingAddress?.addressLine1 ?? '',
      addressLine2: customer?.shippingAddress?.addressLine2 ?? '',
      city: customer?.shippingAddress?.city ?? '',
      state: customer?.shippingAddress?.state ?? '',
      zipcode: customer?.shippingAddress?.zipcode ?? '',
      country: customer?.shippingAddress?.country ?? null,
    },
    timezone: customer?.timezone ?? undefined,
    url: customer?.url ?? undefined,
    accountingProviderCode: accountingProvider?.integrationCode ?? '',
    accountingCustomer: {
      id: accountingProvider?.id ?? undefined,
      providerType: accountingProvider?.integrationType ?? undefined,
      accountingCustomerId: accountingProvider?.externalCustomerId ?? '',
      syncWithProvider: accountingProvider?.syncWithProvider ?? false,
      subsidiaryId:
        accountingProvider &&
        'subsidiaryId' in accountingProvider &&
        typeof accountingProvider.subsidiaryId === 'string'
          ? accountingProvider.subsidiaryId
          : undefined,
    },
    crmProviderCode: crmProvider?.integrationCode ?? '',
    crmCustomer: {
      id: crmProvider?.id ?? undefined,
      crmCustomerId: crmProvider?.externalCustomerId ?? '',
      syncWithProvider: crmProvider?.syncWithProvider ?? false,
      providerType: crmProvider?.integrationType ?? undefined,
      ...getTargetedObject(),
    },
    taxProviderCode: taxProvider?.integrationCode ?? '',
    taxCustomer: {
      id: taxProvider?.id ?? undefined,
      taxCustomerId: taxProvider?.externalCustomerId ?? '',
      syncWithProvider: taxProvider?.syncWithProvider ?? false,
      providerType: taxProvider?.integrationType ?? undefined,
    },
    paymentProviderCode:
      customer?.paymentProvider && customer?.paymentProviderCode
        ? customer?.paymentProviderCode
        : '',
    paymentProviderCustomer: {
      providerCustomerId: customer?.providerCustomer?.providerCustomerId ?? '',
      syncWithProvider: customer?.providerCustomer?.syncWithProvider ?? false,
      providerPaymentMethods: getCustomerProviderMethod(),
      providerType: customer?.paymentProvider ?? undefined,
    },
    metadata:
      customer?.metadata?.map((meta) => ({
        id: meta.id,
        key: meta.key,
        value: meta.value,
        displayInInvoice: meta.displayInInvoice ?? false,
      })) ?? [],
    billingEntityCode: customer?.billingEntity?.code ?? defaultBillingEntity?.value ?? undefined,
  }
}
