import {
  CountryCode,
  CurrencyEnum,
  CustomerTypeEnum,
  HubspotTargetedObjectsEnum,
  IntegrationTypeEnum,
  ProviderPaymentMethodsEnum,
  ProviderTypeEnum,
  TimezoneEnum,
} from '~/generated/graphql'

import { validationSchema } from '../validationSchema'

describe('validationSchema', () => {
  describe('basic fields', () => {
    it('validates a minimal valid customer', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires externalId to be non-empty', () => {
      const result = validationSchema.safeParse({
        externalId: '',
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].path).toEqual(['externalId'])
        expect(result.error.issues[0].message).toBe('text_1763633700902rull0etxlje')
      }
    })

    it('validates optional string fields', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        name: 'Acme Corp',
        firstname: 'John',
        lastname: 'Doe',
        legalName: 'Acme Corporation Ltd',
        legalNumber: '12345678',
        taxIdentificationNumber: 'TAX123456',
        phone: '+1234567890',
        externalSalesforceId: 'SF-123',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates customerType enum', () => {
      const validResult = validationSchema.safeParse({
        externalId: 'customer-123',
        customerType: CustomerTypeEnum.Company,
        metadata: [],
      })

      expect(validResult.success).toBe(true)

      const invalidResult = validationSchema.safeParse({
        externalId: 'customer-123',
        customerType: 'INVALID_TYPE',
      })

      expect(invalidResult.success).toBe(false)
    })

    it('validates currency enum', () => {
      const validResult = validationSchema.safeParse({
        externalId: 'customer-123',
        currency: CurrencyEnum.Usd,
        metadata: [],
      })

      expect(validResult.success).toBe(true)

      const invalidResult = validationSchema.safeParse({
        externalId: 'customer-123',
        currency: 'INVALID_CURRENCY',
        metadata: [],
      })

      expect(invalidResult.success).toBe(false)
    })

    it('validates timezone enum', () => {
      const validResult = validationSchema.safeParse({
        externalId: 'customer-123',
        timezone: TimezoneEnum.TzUtc,
        metadata: [],
      })

      expect(validResult.success).toBe(true)
    })

    it('validates isPartner boolean', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        isPartner: true,
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('email validation', () => {
    it('accepts a valid single email', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        email: 'john@example.com',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('accepts multiple comma-separated valid emails', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        email: 'john@example.com, jane@example.com, bob@test.org',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('rejects invalid email format', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        email: 'not-an-email',
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('text_620bc4d4269a55014d493fc3')
      }
    })

    it('rejects when one email in comma-separated list is invalid', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        email: 'john@example.com, invalid-email, jane@test.org',
        metadata: [],
      })

      expect(result.success).toBe(false)
    })
  })

  describe('url validation', () => {
    it('accepts a valid URL', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        url: 'https://example.com',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('rejects an invalid URL', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        url: 'not-a-url',
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('text_1764239804026ca61hwr3pp9')
      }
    })
  })

  describe('address validation', () => {
    it('validates billingAddress with all fields', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: 'Apt 4B',
          city: 'New York',
          state: 'NY',
          zipcode: '10001',
          country: CountryCode.Us,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates shippingAddress with all fields', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        shippingAddress: {
          addressLine1: '456 Oak Ave',
          addressLine2: 'Suite 100',
          city: 'Los Angeles',
          state: 'CA',
          zipcode: '90001',
          country: CountryCode.Us,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('accepts null country in address', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: '',
          city: 'City',
          state: 'State',
          zipcode: '12345',
          country: null,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('accepts undefined country in address (cleared combobox)', () => {
      const billingResult = validationSchema.safeParse({
        externalId: 'customer-123',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: '',
          city: 'City',
          state: 'State',
          zipcode: '12345',
          country: undefined,
        },
        metadata: [],
      })

      expect(billingResult.success).toBe(true)

      const shippingResult = validationSchema.safeParse({
        externalId: 'customer-123',
        shippingAddress: {
          addressLine1: '456 Oak Ave',
          addressLine2: '',
          city: 'City',
          state: 'State',
          zipcode: '12345',
          country: undefined,
        },
        metadata: [],
      })

      expect(shippingResult.success).toBe(true)
    })

    it('validates isShippingEqualBillingAddress flag', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        isShippingEqualBillingAddress: true,
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('accountingCustomer validation', () => {
    it('validates when no provider is selected', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          providerType: undefined,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates when syncWithProvider is true', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          providerType: IntegrationTypeEnum.Netsuite,
          syncWithProvider: true,
          subsidiaryId: 'SUB-123',
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires accountingCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          providerType: IntegrationTypeEnum.Anrok,
          syncWithProvider: false,
          accountingCustomerId: '',
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.at(-1) === 'accountingCustomerId')

        expect(issue?.message).toBe('text_1764236242615sfcc7546vv8')
      }
    })

    it('accepts accountingCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          providerType: IntegrationTypeEnum.Anrok,
          syncWithProvider: false,
          accountingCustomerId: 'ACC-123',
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires subsidiaryId for NetSuite', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          providerType: IntegrationTypeEnum.Netsuite,
          syncWithProvider: true,
          subsidiaryId: '',
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.at(-1) === 'subsidiaryId')

        expect(issue?.message).toBe('text_1764249459826j3tkbn7s5ca')
      }
    })

    it('does not require subsidiaryId for non-NetSuite providers', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          providerType: IntegrationTypeEnum.Anrok,
          syncWithProvider: true,
          subsidiaryId: '',
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('taxCustomer validation', () => {
    it('validates when no provider is selected', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        taxCustomer: {
          providerType: undefined,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates when syncWithProvider is true', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        taxCustomer: {
          providerType: IntegrationTypeEnum.Anrok,
          syncWithProvider: true,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires taxCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        taxCustomer: {
          providerType: IntegrationTypeEnum.Anrok,
          syncWithProvider: false,
          taxCustomerId: '',
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.at(-1) === 'taxCustomerId')

        expect(issue?.message).toBe('text_1764236242615sfcc7546vv8')
      }
    })

    it('accepts taxCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        taxCustomer: {
          providerType: IntegrationTypeEnum.Anrok,
          syncWithProvider: false,
          taxCustomerId: 'TAX-123',
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('crmCustomer validation', () => {
    it('validates when no provider is selected', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: undefined,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates when syncWithProvider is true', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: true,
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires crmCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: false,
          crmCustomerId: '',
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.at(-1) === 'crmCustomerId')

        expect(issue?.message).toBe('text_1764236242615sfcc7546vv8')
      }
    })

    it('accepts crmCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: false,
          crmCustomerId: 'CRM-123',
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires targetedObject for Hubspot', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: true,
          targetedObject: undefined,
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.at(-1) === 'targetedObject')

        expect(issue?.message).toBe('text_1764249563018adc7qy057at')
      }
    })

    it('accepts valid targetedObject for Hubspot', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: IntegrationTypeEnum.Hubspot,
          syncWithProvider: true,
          targetedObject: HubspotTargetedObjectsEnum.Contacts,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('does not require targetedObject for non-Hubspot providers', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmCustomer: {
          providerType: IntegrationTypeEnum.Salesforce,
          syncWithProvider: true,
          targetedObject: undefined,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('paymentProviderCustomer validation', () => {
    it('validates when no provider is selected', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: undefined,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates Cashfree without providerCustomerId', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Cashfree,
          syncWithProvider: false,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates Flutterwave without providerCustomerId', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Flutterwave,
          syncWithProvider: false,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires providerCustomerId for non-Cashfree/Flutterwave when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Stripe,
          syncWithProvider: false,
          providerCustomerId: '',
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
          },
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.at(-1) === 'providerCustomerId')

        expect(issue?.message).toBe('text_1764236242615sfcc7546vv8')
      }
    })

    it('accepts providerCustomerId when syncWithProvider is false', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Adyen,
          syncWithProvider: false,
          providerCustomerId: 'PROV-123',
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates when syncWithProvider is true', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Stripe,
          syncWithProvider: true,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
          },
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('requires at least one payment method for Stripe', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Stripe,
          syncWithProvider: true,
          providerPaymentMethods: {},
        },
        metadata: [],
      })

      expect(result.success).toBe(false)
      if (!result.success) {
        const issue = result.error.issues.find((i) => {
          const path = i.path as (string | number)[]

          return path[0] === 'paymentProviderCustomer' && path[1] === 'providerPaymentMethods'
        })

        expect(issue?.message).toBe('text_1764259518524a0hr3z00m7r')
      }
    })

    it('accepts Stripe with at least one payment method enabled', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Stripe,
          syncWithProvider: true,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
            [ProviderPaymentMethodsEnum.SepaDebit]: false,
          },
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('does not require payment methods for non-Stripe providers', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCustomer: {
          providerType: ProviderTypeEnum.Adyen,
          syncWithProvider: true,
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('metadata validation', () => {
    it('accepts valid metadata', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        metadata: [
          { key: 'department', value: 'Engineering', displayInInvoice: true },
          { key: 'region', value: 'US-West' },
        ],
      })

      expect(result.success).toBe(true)
    })

    it('accepts empty metadata array', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('rejects metadata with duplicate keys', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        metadata: [
          { key: 'department', value: 'Engineering' },
          { key: 'department', value: 'Sales' },
        ],
      })

      expect(result.success).toBe(false)
    })

    it('rejects metadata with empty key', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        metadata: [{ key: '', value: 'some value' }],
      })

      expect(result.success).toBe(false)
    })

    it('rejects metadata with empty value', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        metadata: [{ key: 'somekey', value: '' }],
      })

      expect(result.success).toBe(false)
    })
  })

  describe('provider codes', () => {
    it('validates accountingProviderCode', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingProviderCode: 'ACC-PROVIDER-001',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates taxProviderCode', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        taxProviderCode: 'TAX-PROVIDER-001',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates crmProviderCode', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        crmProviderCode: 'CRM-PROVIDER-001',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates paymentProviderCode', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        paymentProviderCode: 'PAY-PROVIDER-001',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })

    it('validates billingEntityCode', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        billingEntityCode: 'BILLING-ENTITY-001',
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })

  describe('complex customer scenarios', () => {
    it('validates a fully populated customer', () => {
      const result = validationSchema.safeParse({
        customerType: CustomerTypeEnum.Company,
        isPartner: false,
        name: 'Acme Corporation',
        firstname: 'John',
        lastname: 'Doe',
        externalId: 'acme-corp-001',
        externalSalesforceId: 'SF-ACME-001',
        legalName: 'Acme Corporation Ltd',
        legalNumber: '12345678',
        taxIdentificationNumber: 'TAX-12345678',
        currency: CurrencyEnum.Usd,
        phone: '+1234567890',
        email: 'john@acme.com, jane@acme.com',
        billingAddress: {
          addressLine1: '123 Main St',
          addressLine2: 'Suite 100',
          city: 'New York',
          state: 'NY',
          zipcode: '10001',
          country: CountryCode.Us,
        },
        isShippingEqualBillingAddress: false,
        shippingAddress: {
          addressLine1: '456 Oak Ave',
          addressLine2: 'Building B',
          city: 'Los Angeles',
          state: 'CA',
          zipcode: '90001',
          country: CountryCode.Us,
        },
        timezone: TimezoneEnum.TzUtc,
        url: 'https://acme.com',
        accountingProviderCode: 'ACC-001',
        accountingCustomer: {
          accountingCustomerId: 'ACC-CUST-001',
          syncWithProvider: false,
          providerType: IntegrationTypeEnum.Netsuite,
          subsidiaryId: 'SUB-001',
        },
        taxProviderCode: 'TAX-001',
        taxCustomer: {
          taxCustomerId: 'TAX-CUST-001',
          syncWithProvider: false,
          providerType: IntegrationTypeEnum.Anrok,
        },
        crmProviderCode: 'CRM-001',
        crmCustomer: {
          crmCustomerId: 'CRM-CUST-001',
          syncWithProvider: false,
          providerType: IntegrationTypeEnum.Hubspot,
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
        paymentProviderCode: 'PAY-001',
        paymentProviderCustomer: {
          providerCustomerId: 'PAY-CUST-001',
          syncWithProvider: false,
          providerType: ProviderTypeEnum.Stripe,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
            [ProviderPaymentMethodsEnum.SepaDebit]: true,
            [ProviderPaymentMethodsEnum.UsBankAccount]: false,
          },
        },
        metadata: [
          { key: 'department', value: 'Engineering', displayInInvoice: true },
          { key: 'region', value: 'US-West', displayInInvoice: false },
        ],
        billingEntityCode: 'BILLING-001',
      })

      expect(result.success).toBe(true)
    })

    it('validates a customer with sync enabled for all integrations', () => {
      const result = validationSchema.safeParse({
        externalId: 'customer-123',
        accountingCustomer: {
          syncWithProvider: true,
          providerType: IntegrationTypeEnum.Netsuite,
          subsidiaryId: 'SUB-001',
        },
        taxCustomer: {
          syncWithProvider: true,
          providerType: IntegrationTypeEnum.Anrok,
        },
        crmCustomer: {
          syncWithProvider: true,
          providerType: IntegrationTypeEnum.Hubspot,
          targetedObject: HubspotTargetedObjectsEnum.Companies,
        },
        paymentProviderCustomer: {
          syncWithProvider: true,
          providerType: ProviderTypeEnum.Stripe,
          providerPaymentMethods: {
            [ProviderPaymentMethodsEnum.Card]: true,
          },
        },
        metadata: [],
      })

      expect(result.success).toBe(true)
    })
  })
})
