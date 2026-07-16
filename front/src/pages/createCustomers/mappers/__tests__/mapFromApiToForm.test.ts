import {
  AddCustomerDrawerFragment,
  CountryCode,
  CurrencyEnum,
  CustomerAccountTypeEnum,
  CustomerTypeEnum,
  HubspotTargetedObjectsEnum,
  IntegrationTypeEnum,
  ProviderPaymentMethodsEnum,
  ProviderTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'

import { mapFromApiToForm } from '../mapFromApiToForm'
import { BillingEntityItem } from '../types'

describe('mapFromApiToForm', () => {
  const mockDefaultBillingEntity: BillingEntityItem = {
    label: 'Default Entity',
    value: 'default-entity',
    isDefault: true,
  }

  const baseCustomer: AddCustomerDrawerFragment = {
    __typename: 'Customer',
    id: 'customer-1',
    customerType: CustomerTypeEnum.Individual,
    accountType: CustomerAccountTypeEnum.Customer,
    name: 'John Doe',
    firstname: 'John',
    lastname: 'Doe',
    externalId: 'ext-123',
    externalSalesforceId: 'sf-456',
    legalName: 'John Doe LLC',
    legalNumber: 'LN-789',
    taxIdentificationNumber: 'TIN-012',
    currency: CurrencyEnum.Usd,
    phone: '+1-555-0123',
    email: 'john@example.com',
    addressLine1: '123 Main St',
    addressLine2: 'Suite 100',
    state: 'CA',
    country: CountryCode.Us,
    city: 'San Francisco',
    zipcode: '94105',
    shippingAddress: {
      addressLine1: '456 Oak Ave',
      addressLine2: 'Apt 2B',
      city: 'Oakland',
      state: 'CA',
      zipcode: '94610',
      country: CountryCode.Us,
    },
    timezone: TimezoneEnum.TzAmericaLosAngeles,
    url: 'https://example.com',
    paymentProviderCode: 'stripe_1',
    metadata: [
      { key: 'department', value: 'engineering', displayInInvoice: true, id: 'meta-1' },
      { key: 'priority', value: 'high', displayInInvoice: false, id: 'meta-2' },
    ],
    billingEntity: {
      __typename: 'BillingEntity',
      id: 'billing-entity-1',
      code: 'default-entity',
      name: 'Default Entity',
      euTaxManagement: false,
    },
    canEditAttributes: true,
    applicableTimezone: TimezoneEnum.TzAmericaLosAngeles,
  }

  describe('when customer is undefined', () => {
    it('should return default values with undefined billing entity when no default billing entity', () => {
      const result = mapFromApiToForm(undefined, undefined)

      expect(result).toEqual({
        customerType: undefined,
        isPartner: false,
        name: '',
        firstname: '',
        lastname: '',
        externalId: '',
        externalSalesforceId: '',
        legalName: '',
        legalNumber: '',
        taxIdentificationNumber: '',
        currency: undefined,
        phone: '',
        email: undefined,
        billingAddress: {
          addressLine1: '',
          addressLine2: '',
          state: '',
          country: null,
          city: '',
          zipcode: '',
        },
        isShippingEqualBillingAddress: false,
        shippingAddress: {
          addressLine1: '',
          addressLine2: '',
          city: '',
          state: '',
          zipcode: '',
          country: null,
        },
        timezone: undefined,
        url: undefined,
        accountingProviderCode: '',
        accountingCustomer: {
          accountingCustomerId: '',
          syncWithProvider: false,
          subsidiaryId: undefined,
        },
        crmProviderCode: '',
        crmCustomer: {
          crmCustomerId: '',
          syncWithProvider: false,
        },
        taxProviderCode: '',
        taxCustomer: {
          taxCustomerId: '',
          syncWithProvider: false,
        },
        paymentProviderCode: '',
        paymentProviderCustomer: {
          providerCustomerId: '',
          syncWithProvider: false,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
          },
        },
        metadata: [],
        billingEntityCode: undefined,
      })
    })

    it('should return default values with default billing entity when provided', () => {
      const result = mapFromApiToForm(undefined, mockDefaultBillingEntity)

      expect(result).toEqual(
        expect.objectContaining({
          billingEntityCode: 'default-entity',
        }),
      )
    })
  })

  describe('when customer has basic information', () => {
    const mockCustomer: AddCustomerDrawerFragment = {
      __typename: 'Customer',
      id: 'customer-1',
      customerType: CustomerTypeEnum.Individual,
      accountType: CustomerAccountTypeEnum.Customer,
      name: 'John Doe',
      firstname: 'John',
      lastname: 'Doe',
      externalId: 'ext-123',
      externalSalesforceId: 'sf-456',
      legalName: 'John Doe LLC',
      legalNumber: 'LN-789',
      taxIdentificationNumber: 'TIN-012',
      currency: CurrencyEnum.Usd,
      phone: '+1-555-0123',
      email: 'john@example.com',
      addressLine1: '123 Main St',
      addressLine2: 'Suite 100',
      state: 'CA',
      country: CountryCode.Us,
      city: 'San Francisco',
      zipcode: '94105',
      shippingAddress: {
        addressLine1: '456 Oak Ave',
        addressLine2: 'Apt 2B',
        city: 'Oakland',
        state: 'CA',
        zipcode: '94610',
        country: CountryCode.Us,
      },
      timezone: TimezoneEnum.TzAmericaLosAngeles,
      url: 'https://example.com',
      paymentProviderCode: 'stripe_1',
      metadata: [
        { key: 'department', value: 'engineering', displayInInvoice: true, id: 'meta-1' },
        { key: 'priority', value: 'high', displayInInvoice: false, id: 'meta-2' },
      ],
      billingEntity: {
        __typename: 'BillingEntity',
        id: 'billing-entity-1',
        code: 'default-entity',
        name: 'Default Entity',
        euTaxManagement: false,
      },
      canEditAttributes: true,
      applicableTimezone: TimezoneEnum.TzAmericaLosAngeles,
    }

    it('should map all basic fields correctly', () => {
      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result).toEqual({
        customerType: CustomerTypeEnum.Individual,
        isPartner: false,
        name: 'John Doe',
        firstname: 'John',
        lastname: 'Doe',
        externalId: 'ext-123',
        externalSalesforceId: 'sf-456',
        legalName: 'John Doe LLC',
        legalNumber: 'LN-789',
        taxIdentificationNumber: 'TIN-012',
        currency: CurrencyEnum.Usd,
        phone: '+1-555-0123',
        email: 'john@example.com',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: 'Suite 100',
          state: 'CA',
          country: CountryCode.Us,
          city: 'San Francisco',
          zipcode: '94105',
        },
        isShippingEqualBillingAddress: false,
        shippingAddress: {
          addressLine1: '456 Oak Ave',
          addressLine2: 'Apt 2B',
          city: 'Oakland',
          state: 'CA',
          zipcode: '94610',
          country: CountryCode.Us,
        },
        timezone: TimezoneEnum.TzAmericaLosAngeles,
        url: 'https://example.com',
        accountingProviderCode: '',
        accountingCustomer: {
          accountingCustomerId: '',
          syncWithProvider: false,
          subsidiaryId: undefined,
          providerType: undefined,
        },
        crmProviderCode: '',
        crmCustomer: {
          crmCustomerId: '',
          syncWithProvider: false,
          providerType: undefined,
        },
        taxProviderCode: '',
        taxCustomer: {
          taxCustomerId: '',
          syncWithProvider: false,
          providerType: undefined,
        },
        paymentProviderCode: '',
        paymentProviderCustomer: {
          providerCustomerId: '',
          syncWithProvider: false,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
          },
          providerType: undefined,
        },
        metadata: [
          { key: 'department', value: 'engineering', displayInInvoice: true, id: 'meta-1' },
          { key: 'priority', value: 'high', displayInInvoice: false, id: 'meta-2' },
        ],
        billingEntityCode: 'default-entity',
      })
    })

    it('should set isPartner to true when account type is Partner', () => {
      const partnerCustomer: AddCustomerDrawerFragment = {
        ...mockCustomer,
        accountType: CustomerAccountTypeEnum.Partner,
      }

      const result = mapFromApiToForm(partnerCustomer, mockDefaultBillingEntity)

      expect(result.isPartner).toBe(true)
    })

    it('should use customer billing entity code when available', () => {
      const customerWithBillingEntity: AddCustomerDrawerFragment = {
        ...mockCustomer,
        billingEntity: {
          id: 'billing-entity-1',
          code: 'custom-entity',
          __typename: 'BillingEntity',
          name: 'Custom Entity',
          euTaxManagement: false,
        },
      }

      const result = mapFromApiToForm(customerWithBillingEntity, mockDefaultBillingEntity)

      expect(result.billingEntityCode).toBe('custom-entity')
    })

    it('should set isShippingEqualBillingAddress to true when addresses match', () => {
      const customerWithMatchingAddresses: AddCustomerDrawerFragment = {
        ...mockCustomer,
        shippingAddress: {
          addressLine1: '123 Main St',
          addressLine2: 'Suite 100',
          city: 'San Francisco',
          state: 'CA',
          zipcode: '94105',
          country: CountryCode.Us,
        },
      }

      const result = mapFromApiToForm(customerWithMatchingAddresses, mockDefaultBillingEntity)

      expect(result.isShippingEqualBillingAddress).toBe(true)
    })
  })

  describe('when customer has payment provider information', () => {
    const mockCustomer: AddCustomerDrawerFragment = {
      __typename: 'Customer',
      id: 'customer-1',
      customerType: CustomerTypeEnum.Individual,
      accountType: CustomerAccountTypeEnum.Customer,
      name: 'John Doe',
      firstname: 'John',
      lastname: 'Doe',
      externalId: 'ext-123',
      externalSalesforceId: 'sf-456',
      legalName: 'John Doe LLC',
      legalNumber: 'LN-789',
      taxIdentificationNumber: 'TIN-012',
      currency: CurrencyEnum.Usd,
      phone: '+1-555-0123',
      email: 'john@example.com',
      addressLine1: '123 Main St',
      addressLine2: 'Suite 100',
      state: 'CA',
      country: CountryCode.Us,
      city: 'San Francisco',
      zipcode: '94105',
      shippingAddress: {
        addressLine1: '456 Oak Ave',
        addressLine2: 'Apt 2B',
        city: 'Oakland',
        state: 'CA',
        zipcode: '94610',
        country: CountryCode.Us,
      },
      timezone: TimezoneEnum.TzAmericaLosAngeles,
      url: 'https://example.com',
      paymentProviderCode: 'stripe_1',
      metadata: [
        { key: 'department', value: 'engineering', displayInInvoice: true, id: 'meta-1' },
        { key: 'priority', value: 'high', displayInInvoice: false, id: 'meta-2' },
      ],
      billingEntity: {
        __typename: 'BillingEntity',
        id: 'billing-entity-1',
        code: 'default-entity',
        name: 'Default Entity',
        euTaxManagement: false,
      },
      canEditAttributes: true,
      applicableTimezone: TimezoneEnum.TzAmericaLosAngeles,
    }

    it('should map payment provider customer with payment methods', () => {
      const customerWithPaymentMethods: AddCustomerDrawerFragment = {
        ...mockCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        currency: CurrencyEnum.Usd,
        paymentProvider: ProviderTypeEnum.Stripe,
        paymentProviderCode: 'stripe_1',
        providerCustomer: {
          id: 'cus_12345',
          providerCustomerId: 'cus_12345',
          syncWithProvider: true,
          providerPaymentMethods: [
            ProviderPaymentMethodsEnum.Card,
            ProviderPaymentMethodsEnum.SepaDebit,
          ],
        },
      }

      const result = mapFromApiToForm(customerWithPaymentMethods, mockDefaultBillingEntity)

      expect(result.paymentProviderCode).toBe('stripe_1')
      expect(result.paymentProviderCustomer).toEqual({
        providerCustomerId: 'cus_12345',
        syncWithProvider: true,
        providerPaymentMethods: {
          [ProviderPaymentMethodsEnum.Card]: true,
          [ProviderPaymentMethodsEnum.SepaDebit]: true,
        },
        providerType: ProviderTypeEnum.Stripe,
      })
    })

    it('should default to Card and SepaDebit for EUR currency when no payment methods', () => {
      const customerWithEur: AddCustomerDrawerFragment = {
        ...mockCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        currency: CurrencyEnum.Eur,
        paymentProviderCode: 'stripe_1',
        providerCustomer: undefined,
      }

      const result = mapFromApiToForm(customerWithEur, mockDefaultBillingEntity)

      expect(result.paymentProviderCustomer?.providerPaymentMethods).toEqual({
        [ProviderPaymentMethodsEnum.Card]: true,
        [ProviderPaymentMethodsEnum.SepaDebit]: true,
      })
    })

    it('should default to Card only for non-EUR currency when no payment methods', () => {
      const customerNonEur: AddCustomerDrawerFragment = {
        ...mockCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        currency: CurrencyEnum.Usd,
        paymentProviderCode: 'stripe_1',
        providerCustomer: undefined,
      }

      const result = mapFromApiToForm(customerNonEur, mockDefaultBillingEntity)

      expect(result.paymentProviderCustomer?.providerPaymentMethods).toEqual({
        [ProviderPaymentMethodsEnum.Card]: true,
      })
    })

    it('should handle empty providerPaymentMethods array', () => {
      const customerEmptyProviderPayment: AddCustomerDrawerFragment = {
        ...mockCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        currency: CurrencyEnum.Usd,
        paymentProviderCode: 'stripe_1',
        providerCustomer: {
          id: 'cus_12345',
          providerCustomerId: 'cus_12345',
          syncWithProvider: false,
          providerPaymentMethods: [],
        },
      }

      const result = mapFromApiToForm(customerEmptyProviderPayment, mockDefaultBillingEntity)

      expect(result.paymentProviderCustomer?.providerPaymentMethods).toEqual({
        [ProviderPaymentMethodsEnum.Card]: true,
      })
    })
  })

  describe('when customer has accounting provider information', () => {
    it('should map Xero accounting provider correctly', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        xeroCustomer: {
          __typename: 'XeroCustomer',
          id: 'xero-1',
          integrationCode: 'xero_1',
          externalCustomerId: 'xero-123',
          syncWithProvider: true,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.accountingProviderCode).toBe('xero_1')
      expect(result.accountingCustomer).toEqual({
        id: 'xero-1',
        accountingCustomerId: 'xero-123',
        syncWithProvider: true,
        subsidiaryId: undefined,
      })
    })

    it('should map NetSuite accounting provider with subsidiaryId correctly', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        netsuiteCustomer: {
          __typename: 'NetsuiteCustomer',
          id: 'netsuite-1',
          integrationCode: 'netsuite_1',
          externalCustomerId: 'netsuite-456',
          syncWithProvider: false,
          subsidiaryId: 'subsidiary-789',
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.accountingProviderCode).toBe('netsuite_1')
      expect(result.accountingCustomer).toEqual({
        id: 'netsuite-1',
        accountingCustomerId: 'netsuite-456',
        syncWithProvider: false,
        subsidiaryId: 'subsidiary-789',
      })
    })

    it('should prefer Xero when both Xero and NetSuite are present', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        xeroCustomer: {
          __typename: 'XeroCustomer',
          id: 'xero-1',
          integrationCode: 'xero_1',
          externalCustomerId: 'xero-123',
          syncWithProvider: true,
        },
        netsuiteCustomer: {
          __typename: 'NetsuiteCustomer',
          id: 'netsuite-1',
          integrationCode: 'netsuite_1',
          externalCustomerId: 'netsuite-456',
          syncWithProvider: false,
          subsidiaryId: 'subsidiary-789',
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.accountingProviderCode).toBe('xero_1')
      expect(result.accountingCustomer).toEqual({
        id: 'xero-1',
        accountingCustomerId: 'xero-123',
        syncWithProvider: true,
        subsidiaryId: undefined,
      })
    })
  })

  describe('when customer has CRM provider information', () => {
    it('should map HubSpot CRM provider correctly', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        hubspotCustomer: {
          __typename: 'HubspotCustomer',
          id: 'hubspot-1',
          integrationCode: 'hubspot_1',
          externalCustomerId: 'hubspot-123',
          syncWithProvider: true,
          targetedObject: HubspotTargetedObjectsEnum.Contacts,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.crmProviderCode).toBe('hubspot_1')
      expect(result.crmCustomer).toEqual({
        id: 'hubspot-1',
        crmCustomerId: 'hubspot-123',
        syncWithProvider: true,
        targetedObject: HubspotTargetedObjectsEnum.Contacts,
      })
    })

    it('should map Salesforce CRM provider correctly', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        salesforceCustomer: {
          __typename: 'SalesforceCustomer',
          id: 'salesforce-1',
          integrationCode: 'salesforce_1',
          externalCustomerId: 'salesforce-456',
          syncWithProvider: false,
          integrationType: IntegrationTypeEnum.Salesforce,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.crmProviderCode).toBe('salesforce_1')
      expect(result.crmCustomer).toEqual({
        id: 'salesforce-1',
        crmCustomerId: 'salesforce-456',
        syncWithProvider: false,
        providerType: IntegrationTypeEnum.Salesforce,
      })
    })

    it('should prefer HubSpot when both HubSpot and Salesforce are present', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        hubspotCustomer: {
          __typename: 'HubspotCustomer',
          id: 'hubspot-1',
          integrationCode: 'hubspot_1',
          externalCustomerId: 'hubspot-123',
          syncWithProvider: true,
        },
        salesforceCustomer: {
          __typename: 'SalesforceCustomer',
          id: 'salesforce-1',
          integrationCode: 'salesforce_1',
          externalCustomerId: 'salesforce-456',
          syncWithProvider: false,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.crmProviderCode).toBe('hubspot_1')
      expect(result.crmCustomer).toEqual({
        id: 'hubspot-1',
        crmCustomerId: 'hubspot-123',
        syncWithProvider: true,
      })
    })
  })

  describe('when customer has tax provider information', () => {
    it('should map Anrok tax provider correctly', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        anrokCustomer: {
          __typename: 'AnrokCustomer',
          id: 'anrok-1',
          integrationCode: 'anrok_1',
          externalCustomerId: 'anrok-123',
          syncWithProvider: true,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.taxProviderCode).toBe('anrok_1')
      expect(result.taxCustomer).toEqual({
        id: 'anrok-1',
        taxCustomerId: 'anrok-123',
        syncWithProvider: true,
      })
    })

    it('should map Avalara tax provider correctly', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        avalaraCustomer: {
          __typename: 'AvalaraCustomer',
          id: 'avalara-1',
          integrationCode: 'avalara_1',
          externalCustomerId: 'avalara-456',
          syncWithProvider: false,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.taxProviderCode).toBe('avalara_1')
      expect(result.taxCustomer).toEqual({
        id: 'avalara-1',
        taxCustomerId: 'avalara-456',
        syncWithProvider: false,
      })
    })

    it('should prefer Anrok when both Anrok and Avalara are present', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        anrokCustomer: {
          __typename: 'AnrokCustomer',
          id: 'anrok-1',
          integrationCode: 'anrok_1',
          externalCustomerId: 'anrok-123',
          syncWithProvider: true,
        },
        avalaraCustomer: {
          __typename: 'AvalaraCustomer',
          id: 'avalara-1',
          integrationCode: 'avalara_1',
          externalCustomerId: 'avalara-456',
          syncWithProvider: false,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.taxProviderCode).toBe('anrok_1')
      expect(result.taxCustomer).toEqual({
        id: 'anrok-1',
        taxCustomerId: 'anrok-123',
        syncWithProvider: true,
      })
    })
  })

  describe('when customer has null/undefined shipping address', () => {
    it('should handle undefined shipping address', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        shippingAddress: undefined,
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.shippingAddress).toEqual({
        addressLine1: '',
        addressLine2: '',
        city: '',
        state: '',
        zipcode: '',
        country: null,
      })
    })

    it('should handle null shipping address', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        shippingAddress: null,
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.shippingAddress).toEqual({
        addressLine1: '',
        addressLine2: '',
        city: '',
        state: '',
        zipcode: '',
        country: null,
      })
    })
  })

  describe('when customer has empty metadata', () => {
    it('should handle undefined metadata', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        metadata: undefined,
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.metadata).toEqual([])
    })

    it('should handle null metadata', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        metadata: null,
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.metadata).toEqual([])
    })

    it('should handle empty metadata array', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        metadata: [],
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.metadata).toEqual([])
    })
  })

  describe('edge cases and complex scenarios', () => {
    it('should handle customer with all providers and complete information', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        customerType: CustomerTypeEnum.Company,
        accountType: CustomerAccountTypeEnum.Partner,
        name: 'Complete Customer',
        firstname: 'Complete',
        lastname: 'Customer',
        externalId: 'ext-complete',
        externalSalesforceId: 'sf-complete',
        legalName: 'Complete Customer Inc',
        legalNumber: 'CC-123',
        taxIdentificationNumber: 'TIN-456',
        currency: CurrencyEnum.Eur,
        phone: '+33-1-23-45-67-89',
        email: 'complete@example.com',
        addressLine1: '123 Complete St',
        addressLine2: 'Floor 5',
        state: 'Paris',
        country: CountryCode.Fr,
        city: 'Paris',
        zipcode: '75001',
        shippingAddress: {
          addressLine1: '456 Shipping Ave',
          addressLine2: 'Warehouse B',
          city: 'Lyon',
          state: 'Rhône',
          zipcode: '69001',
          country: CountryCode.Fr,
        },
        timezone: TimezoneEnum.TzEuropeParis,
        url: 'https://complete.example.com',
        paymentProvider: ProviderTypeEnum.Stripe,
        paymentProviderCode: 'stripe_complete',
        providerCustomer: {
          id: 'cus_complete',
          providerCustomerId: 'cus_complete',
          syncWithProvider: true,
          providerPaymentMethods: [
            ProviderPaymentMethodsEnum.Card,
            ProviderPaymentMethodsEnum.SepaDebit,
          ],
        },
        xeroCustomer: {
          __typename: 'XeroCustomer',
          id: 'xero-1',
          integrationCode: 'xero_complete',
          externalCustomerId: 'xero-complete',
          syncWithProvider: true,
        },
        hubspotCustomer: {
          __typename: 'HubspotCustomer',
          id: 'hubspot-1',
          integrationCode: 'hubspot_complete',
          externalCustomerId: 'hubspot-complete',
          syncWithProvider: false,
        },
        anrokCustomer: {
          __typename: 'AnrokCustomer',
          id: 'anrok-1',
          integrationCode: 'anrok_complete',
          externalCustomerId: 'anrok-complete',
          syncWithProvider: true,
        },
        billingEntity: {
          __typename: 'BillingEntity',
          id: 'billing-entity-1',
          code: 'complete-entity',
          name: 'Complete Entity',
          euTaxManagement: false,
        },
        metadata: [
          { key: 'segment', value: 'enterprise', displayInInvoice: true, id: 'meta-1' },
          { key: 'region', value: 'europe', displayInInvoice: false, id: 'meta-2' },
          { key: 'account_manager', value: 'alice.smith', displayInInvoice: false, id: 'meta-3' },
        ],
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result).toEqual({
        customerType: CustomerTypeEnum.Company,
        isPartner: true,
        name: 'Complete Customer',
        firstname: 'Complete',
        lastname: 'Customer',
        externalId: 'ext-complete',
        externalSalesforceId: 'sf-complete',
        legalName: 'Complete Customer Inc',
        legalNumber: 'CC-123',
        taxIdentificationNumber: 'TIN-456',
        currency: CurrencyEnum.Eur,
        phone: '+33-1-23-45-67-89',
        email: 'complete@example.com',
        billingAddress: {
          addressLine1: '123 Complete St',
          addressLine2: 'Floor 5',
          state: 'Paris',
          country: CountryCode.Fr,
          city: 'Paris',
          zipcode: '75001',
        },
        isShippingEqualBillingAddress: false,
        shippingAddress: {
          addressLine1: '456 Shipping Ave',
          addressLine2: 'Warehouse B',
          city: 'Lyon',
          state: 'Rhône',
          zipcode: '69001',
          country: CountryCode.Fr,
        },
        timezone: TimezoneEnum.TzEuropeParis,
        url: 'https://complete.example.com',
        accountingProviderCode: 'xero_complete',
        accountingCustomer: {
          id: 'xero-1',
          accountingCustomerId: 'xero-complete',
          syncWithProvider: true,
          subsidiaryId: undefined,
          providerType: undefined,
        },
        crmProviderCode: 'hubspot_complete',
        crmCustomer: {
          id: 'hubspot-1',
          crmCustomerId: 'hubspot-complete',
          syncWithProvider: false,
          providerType: undefined,
        },
        taxProviderCode: 'anrok_complete',
        taxCustomer: {
          id: 'anrok-1',
          taxCustomerId: 'anrok-complete',
          syncWithProvider: true,
          providerType: undefined,
        },
        paymentProviderCode: 'stripe_complete',
        paymentProviderCustomer: {
          providerCustomerId: 'cus_complete',
          syncWithProvider: true,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
            [ProviderPaymentMethodsEnum.SepaDebit]: true,
          },
          providerType: ProviderTypeEnum.Stripe,
        },
        metadata: [
          { key: 'segment', value: 'enterprise', displayInInvoice: true, id: 'meta-1' },
          { key: 'region', value: 'europe', displayInInvoice: false, id: 'meta-2' },
          { key: 'account_manager', value: 'alice.smith', displayInInvoice: false, id: 'meta-3' },
        ],
        billingEntityCode: 'complete-entity',
      })
    })

    it('should handle NetSuite provider with non-string subsidiaryId', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        netsuiteCustomer: {
          __typename: 'NetsuiteCustomer',
          id: 'netsuite-1',
          integrationCode: 'netsuite_1',
          externalCustomerId: 'netsuite-123',
          syncWithProvider: true,
          // This simulates a case where subsidiaryId might not be a string
          // @ts-expect-error Testing non-string subsidiaryId
          subsidiaryId: 123,
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.accountingCustomer?.subsidiaryId).toBeUndefined()
    })

    it('should handle missing subsidiaryId property on NetSuite provider', () => {
      const mockCustomer: AddCustomerDrawerFragment = {
        ...baseCustomer,
        __typename: 'Customer',
        id: 'customer-1',
        externalId: 'ext-123',
        name: 'Test Customer',
        netsuiteCustomer: {
          __typename: 'NetsuiteCustomer',
          id: 'netsuite-1',
          integrationCode: 'netsuite_1',
          externalCustomerId: 'netsuite-123',
          syncWithProvider: true,
          // subsidiaryId property is not present
        },
      }

      const result = mapFromApiToForm(mockCustomer, mockDefaultBillingEntity)

      expect(result.accountingCustomer?.subsidiaryId).toBeUndefined()
    })
  })
})
