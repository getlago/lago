import {
  CountryCode,
  CurrencyEnum,
  CustomerAccountTypeEnum,
  CustomerTypeEnum,
  HubspotTargetedObjectsEnum,
  ProviderPaymentMethodsEnum,
  ProviderTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'

import {
  CreateCustomerDefaultValues,
  emptyCreateCustomerDefaultValues,
} from '../../formInitialization/validationSchema'
import { mapFromFormToApi } from '../mapFromFormToApi'

// Mock the getIntegrationCustomers function
jest.mock('../getIntegrationCustomers', () => ({
  getIntegrationCustomers: jest.fn((params) => {
    if (!params.taxProviderCode && !params.accountingProviderCode && !params.crmProviderCode) {
      return undefined
    }
    return [
      {
        integrationCode: 'test-integration',
        integrationType: 'anrok',
        syncWithProvider: true,
        externalCustomerId: 'test-external-id',
      },
    ]
  }),
}))

describe('mapFromFormToApi', () => {
  const getIntegrationCustomersMock = jest.requireMock(
    '../getIntegrationCustomers',
  ).getIntegrationCustomers
  const mockTaxProviders = {
    integrations: {
      collection: [
        {
          __typename: 'AnrokIntegration' as const,
          id: 'anrok-1',
          code: 'anrok-test',
          name: 'Anrok Test',
        },
      ],
    },
  }

  const mockCrmProviders = {
    integrations: {
      collection: [
        {
          __typename: 'HubspotIntegration' as const,
          id: 'hubspot-1',
          code: 'hubspot-test',
          name: 'Hubspot Test',
          defaultTargetedObject: HubspotTargetedObjectsEnum.Contacts,
        },
      ],
    },
  }

  const mockAccountingProviders = {
    integrations: {
      collection: [
        {
          __typename: 'NetsuiteIntegration' as const,
          id: 'netsuite-1',
          code: 'netsuite-test',
          name: 'Netsuite Test',
        },
      ],
    },
  }

  describe('Basic customer mapping', () => {
    it('should map basic customer information correctly', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        name: 'John Doe',
        firstname: 'John',
        lastname: 'Doe',
        email: 'john.doe@example.com',
        phone: '+1234567890',
        currency: CurrencyEnum.Usd,
        timezone: TimezoneEnum.TzAmericaNewYork,
        url: 'https://example.com',
        legalName: 'John Doe Inc.',
        legalNumber: '123456789',
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result).toEqual({
        externalId: 'customer-123',
        name: 'John Doe',
        firstname: 'John',
        lastname: 'Doe',
        email: 'john.doe@example.com',
        phone: '+1234567890',
        currency: CurrencyEnum.Usd,
        timezone: TimezoneEnum.TzAmericaNewYork,
        url: 'https://example.com',
        legalName: 'John Doe Inc.',
        legalNumber: '123456789',
        accountType: CustomerAccountTypeEnum.Customer,
        customerType: undefined,
        externalSalesforceId: '',
        addressLine1: '',
        addressLine2: '',
        city: '',
        state: '',
        zipcode: '',
        country: null,
        shippingAddress: null,
        paymentProvider: undefined,
        paymentProviderCode: undefined,
        providerCustomer: null,
        metadata: [],
        billingEntityCode: undefined,
        integrationCustomers: undefined,
        taxIdentificationNumber: '',
      })
    })

    it('should map partner account type correctly when isPartner is true', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'partner-123',
        isPartner: true,
        customerType: CustomerTypeEnum.Company,
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.accountType).toBe(CustomerAccountTypeEnum.Partner)
      expect(result.customerType).toBe(CustomerTypeEnum.Company)
    })

    it('should set account type to customer when isPartner is false', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        isPartner: false,
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.accountType).toBe(CustomerAccountTypeEnum.Customer)
    })
  })

  describe('Email formatting', () => {
    it('should handle single email address', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        email: ' john@example.com ',
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.email).toBe('john@example.com')
    })

    it('should handle undefined email', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        email: undefined,
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.email).toBeUndefined()
    })
  })

  describe('Billing address mapping', () => {
    it('should map complete billing address', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: 'Apt 4B',
          city: 'New York',
          state: 'NY',
          zipcode: '10001',
          country: CountryCode.Us,
        },
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.addressLine1).toBe('123 Main St')
      expect(result.addressLine2).toBe('Apt 4B')
      expect(result.city).toBe('New York')
      expect(result.state).toBe('NY')
      expect(result.zipcode).toBe('10001')
      expect(result.country).toBe(CountryCode.Us)
    })

    it('should handle undefined billing address', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        billingAddress: undefined,
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.addressLine1).toBeUndefined()
      expect(result.addressLine2).toBeUndefined()
      expect(result.city).toBeUndefined()
      expect(result.state).toBeUndefined()
      expect(result.zipcode).toBeUndefined()
      expect(result.country).toBeNull()
    })

    it('should map undefined billing country to null (cleared combobox)', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: '',
          city: 'New York',
          state: 'NY',
          zipcode: '10001',
          country: undefined,
        },
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.country).toBeNull()
    })
  })

  describe('Shipping address mapping', () => {
    it('should map shipping address correctly', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        shippingAddress: {
          addressLine1: '456 Oak Ave',
          addressLine2: 'Suite 200',
          city: 'Los Angeles',
          state: 'CA',
          zipcode: '90210',
          country: CountryCode.Us,
        },
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.shippingAddress).toEqual({
        addressLine1: '456 Oak Ave',
        addressLine2: 'Suite 200',
        city: 'Los Angeles',
        state: 'CA',
        zipcode: '90210',
        country: CountryCode.Us,
      })
    })

    it('should map undefined shipping country to null (cleared combobox)', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        shippingAddress: {
          addressLine1: '456 Oak Ave',
          addressLine2: '',
          city: 'Los Angeles',
          state: 'CA',
          zipcode: '90210',
          country: undefined,
        },
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.shippingAddress?.country).toBeNull()
    })

    it('should return null when shipping address is empty', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        shippingAddress: {
          addressLine1: '',
          addressLine2: '',
          city: '',
          state: '',
          zipcode: '',
          country: null,
        },
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.shippingAddress).toBeNull()
    })
  })

  describe('Payment provider mapping', () => {
    it('should map payment provider information', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        paymentProviderCode: 'stripe_1',
        paymentProviderCustomer: {
          providerCustomerId: 'cus_stripe123',
          syncWithProvider: true,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
            [ProviderPaymentMethodsEnum.SepaDebit]: false,
            [ProviderPaymentMethodsEnum.UsBankAccount]: true,
          },
        },
      }

      const result = mapFromFormToApi(formValues, {
        paymentProvider: ProviderTypeEnum.Stripe,
      })

      expect(result.paymentProvider).toBe(ProviderTypeEnum.Stripe)
      expect(result.paymentProviderCode).toBe('stripe_1')
      expect(result.providerCustomer).toEqual({
        providerCustomerId: 'cus_stripe123',
        syncWithProvider: true,
        providerPaymentMethods: [
          ProviderPaymentMethodsEnum.Card,
          ProviderPaymentMethodsEnum.UsBankAccount,
        ],
      })
    })

    it('should handle empty payment methods', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerCustomerId: 'cus_123',
          syncWithProvider: false,
          providerPaymentMethods: {},
        },
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.providerCustomer?.providerPaymentMethods).toEqual([])
    })

    it('should handle undefined payment provider customer', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        paymentProviderCustomer: undefined,
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.providerCustomer).toBeNull()
    })
  })

  describe('Metadata mapping', () => {
    it('should map metadata correctly', () => {
      const formValues: CreateCustomerDefaultValues = {
        externalId: 'customer-123',
        metadata: [
          { key: 'department', value: 'Engineering', displayInInvoice: true, id: 'meta-1' },
          { key: 'project', value: 'Project X', displayInInvoice: false, id: 'meta-2' },
          { key: 'manager', value: 'John Smith', displayInInvoice: false, id: 'meta-3' }, // displayInInvoice undefined
        ],
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.metadata).toEqual([
        { key: 'department', value: 'Engineering', displayInInvoice: true, id: 'meta-1' },
        { key: 'project', value: 'Project X', displayInInvoice: false, id: 'meta-2' },
        { key: 'manager', value: 'John Smith', displayInInvoice: false, id: 'meta-3' },
      ])
    })

    it('should handle undefined metadata', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        // @ts-expect-error Testing undefined metadata even tho it should be empty array
        metadata: undefined,
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.metadata).toBeUndefined()
    })
  })

  describe('Integration customers mapping', () => {
    it('should call getIntegrationCustomers with correct parameters', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        taxProviderCode: 'anrok-test',
        accountingProviderCode: 'netsuite-test',
        crmProviderCode: 'hubspot-test',
        taxCustomer: {
          taxCustomerId: 'tax-123',
          syncWithProvider: true,
        },
        accountingCustomer: {
          accountingCustomerId: 'accounting-123',
          syncWithProvider: false,
          subsidiaryId: 'subsidiary-1',
        },
        crmCustomer: {
          crmCustomerId: 'crm-123',
          syncWithProvider: true,
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
      }

      mapFromFormToApi(formValues, {
        taxProviders: mockTaxProviders,
        accountingProviders: mockAccountingProviders,
        crmProviders: mockCrmProviders,
      })

      expect(getIntegrationCustomersMock).toHaveBeenCalledWith({
        taxProviderCode: 'anrok-test',
        accountingProviderCode: 'netsuite-test',
        crmProviderCode: 'hubspot-test',
        taxProviders: mockTaxProviders,
        accountingProviders: mockAccountingProviders,
        crmProviders: mockCrmProviders,
        accountingCustomer: {
          accountingCustomerId: 'accounting-123',
          syncWithProvider: false,
          subsidiaryId: 'subsidiary-1',
        },
        crmCustomer: {
          crmCustomerId: 'crm-123',
          syncWithProvider: true,
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
        taxCustomer: {
          taxCustomerId: 'tax-123',
          syncWithProvider: true,
        },
      })
    })

    it('should include integration customers in result when providers are configured', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
        taxProviderCode: 'anrok-test',
      }

      const result = mapFromFormToApi(formValues, {
        taxProviders: mockTaxProviders,
      })

      expect(result.integrationCustomers).toEqual([
        {
          integrationCode: 'test-integration',
          integrationType: 'anrok',
          syncWithProvider: true,
          externalCustomerId: 'test-external-id',
        },
      ])
    })

    it('should set integrationCustomers to undefined when no providers are configured', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'customer-123',
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.integrationCustomers).toBeUndefined()
    })
  })

  describe('Complete customer mapping', () => {
    it('should map a complete customer form correctly', () => {
      const formValues: CreateCustomerDefaultValues = {
        externalId: 'complete-customer-123',
        externalSalesforceId: 'sf-123',
        customerType: CustomerTypeEnum.Company,
        isPartner: true,
        name: 'Acme Corporation',
        firstname: 'John',
        lastname: 'Doe',
        legalName: 'Acme Corporation Inc.',
        legalNumber: '987654321',
        currency: CurrencyEnum.Eur,
        phone: '+33123456789',
        email: 'contact@acme.com, billing@acme.com',
        billingAddress: {
          addressLine1: '123 Business St',
          addressLine2: 'Floor 5',
          city: 'Paris',
          state: 'Île-de-France',
          zipcode: '75001',
          country: CountryCode.Fr,
        },
        shippingAddress: {
          addressLine1: '456 Shipping Ave',
          addressLine2: '',
          city: 'Lyon',
          state: 'Auvergne-Rhône-Alpes',
          zipcode: '69000',
          country: CountryCode.Fr,
        },
        timezone: TimezoneEnum.TzEuropeParis,
        url: 'https://acme.com',
        paymentProviderCode: 'stripe_1',
        paymentProviderCustomer: {
          providerCustomerId: 'cus_acme123',
          syncWithProvider: true,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
            [ProviderPaymentMethodsEnum.SepaDebit]: true,
          },
        },
        metadata: [
          { key: 'industry', value: 'Technology', displayInInvoice: true },
          { key: 'segment', value: 'Enterprise', displayInInvoice: false },
        ],
        billingEntityCode: 'entity-1',
        taxProviderCode: 'anrok-test',
        taxCustomer: {
          taxCustomerId: 'tax-acme-123',
          syncWithProvider: true,
        },
      }

      const result = mapFromFormToApi(formValues, {
        paymentProvider: ProviderTypeEnum.Stripe,
        taxProviders: mockTaxProviders,
      })

      expect(result).toEqual({
        externalId: 'complete-customer-123',
        externalSalesforceId: 'sf-123',
        customerType: CustomerTypeEnum.Company,
        accountType: CustomerAccountTypeEnum.Partner,
        name: 'Acme Corporation',
        firstname: 'John',
        lastname: 'Doe',
        legalName: 'Acme Corporation Inc.',
        legalNumber: '987654321',
        currency: CurrencyEnum.Eur,
        phone: '+33123456789',
        email: 'contact@acme.com,billing@acme.com',
        addressLine1: '123 Business St',
        addressLine2: 'Floor 5',
        city: 'Paris',
        state: 'Île-de-France',
        zipcode: '75001',
        country: CountryCode.Fr,
        shippingAddress: {
          addressLine1: '456 Shipping Ave',
          addressLine2: '',
          city: 'Lyon',
          state: 'Auvergne-Rhône-Alpes',
          zipcode: '69000',
          country: CountryCode.Fr,
        },
        timezone: TimezoneEnum.TzEuropeParis,
        url: 'https://acme.com',
        paymentProvider: ProviderTypeEnum.Stripe,
        paymentProviderCode: 'stripe_1',
        providerCustomer: {
          providerCustomerId: 'cus_acme123',
          syncWithProvider: true,
          providerPaymentMethods: [
            ProviderPaymentMethodsEnum.Card,
            ProviderPaymentMethodsEnum.SepaDebit,
          ],
        },
        metadata: [
          { key: 'industry', value: 'Technology', displayInInvoice: true },
          { key: 'segment', value: 'Enterprise', displayInInvoice: false },
        ],
        billingEntityCode: 'entity-1',
        integrationCustomers: [
          {
            integrationCode: 'test-integration',
            integrationType: 'anrok',
            syncWithProvider: true,
            externalCustomerId: 'test-external-id',
          },
        ],
      })
    })
  })

  describe('Edge cases', () => {
    it('should handle minimal form data', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'minimal-123',
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.externalId).toBe('minimal-123')
      expect(result.accountType).toBe(CustomerAccountTypeEnum.Customer)
      expect(result.providerCustomer).toBeNull()
      expect(result.integrationCustomers).toBeUndefined()
    })

    it('should handle empty strings and null values correctly', () => {
      const formValues: CreateCustomerDefaultValues = {
        ...emptyCreateCustomerDefaultValues,
        externalId: 'empty-test-123',
        name: '',
        email: '',
        phone: '',
        url: '',
      }

      const result = mapFromFormToApi(formValues, {})

      expect(result.name).toBe('')
      expect(result.email).toBe('')
      expect(result.phone).toBe('')
      expect(result.url).toBe('')
    })
  })
})
