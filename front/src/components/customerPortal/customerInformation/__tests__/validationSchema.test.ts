import { CountryCode, CustomerTypeEnum } from '~/generated/graphql'

import {
  editCustomerBillingDefaultValues,
  editCustomerBillingValidationSchema,
  mapCustomerToFormValues,
} from '../validationSchema'

describe('validationSchema', () => {
  describe('mapCustomerToFormValues', () => {
    describe('WHEN customer is null or undefined', () => {
      it('THEN should return default values for null', () => {
        expect(mapCustomerToFormValues(null)).toEqual(editCustomerBillingDefaultValues)
      })

      it('THEN should return default values for undefined', () => {
        expect(mapCustomerToFormValues(undefined)).toEqual(editCustomerBillingDefaultValues)
      })
    })

    describe('WHEN customer has data', () => {
      it('THEN should map all fields correctly', () => {
        const customer = {
          customerType: CustomerTypeEnum.Company,
          name: 'Acme Inc',
          firstname: 'John',
          lastname: 'Doe',
          legalName: 'Acme Inc Legal',
          taxIdentificationNumber: 'TAX123',
          email: 'john@acme.com',
          addressLine1: '123 Main St',
          addressLine2: 'Suite 100',
          zipcode: '12345',
          city: 'Springfield',
          state: 'IL',
          country: CountryCode.Us,
          shippingAddress: {
            addressLine1: '456 Ship St',
            addressLine2: undefined,
            city: 'Shelbyville',
            country: CountryCode.Us,
            state: 'IL',
            zipcode: '67890',
          },
        }

        const result = mapCustomerToFormValues(customer)

        expect(result).toEqual({
          customerType: CustomerTypeEnum.Company,
          name: 'Acme Inc',
          firstname: 'John',
          lastname: 'Doe',
          legalName: 'Acme Inc Legal',
          taxIdentificationNumber: 'TAX123',
          email: 'john@acme.com',
          addressLine1: '123 Main St',
          addressLine2: 'Suite 100',
          zipcode: '12345',
          city: 'Springfield',
          state: 'IL',
          country: CountryCode.Us,
          shippingAddress: {
            addressLine1: '456 Ship St',
            addressLine2: undefined,
            city: 'Shelbyville',
            country: CountryCode.Us,
            state: 'IL',
            zipcode: '67890',
          },
        })
      })
    })

    describe('WHEN customer has null fields', () => {
      it('THEN should coerce nulls to undefined or defaults', () => {
        const customer = {
          customerType: null,
          name: null,
          firstname: null,
          lastname: null,
          legalName: null,
          taxIdentificationNumber: null,
          email: null,
          addressLine1: null,
          addressLine2: null,
          zipcode: null,
          city: null,
          state: null,
          country: null,
          shippingAddress: null,
        }

        const result = mapCustomerToFormValues(customer)

        expect(result.customerType).toBeNull()
        expect(result.name).toBe('')
        expect(result.firstname).toBe('')
        expect(result.lastname).toBe('')
        expect(result.legalName).toBeUndefined()
        expect(result.email).toBeUndefined()
        expect(result.shippingAddress).toEqual({
          addressLine1: undefined,
          addressLine2: undefined,
          city: undefined,
          country: undefined,
          state: undefined,
          zipcode: undefined,
        })
      })
    })

    describe('WHEN customer has shipping address with null fields', () => {
      it('THEN should coerce shipping address nulls to undefined', () => {
        const customer = {
          shippingAddress: {
            addressLine1: null,
            addressLine2: null,
            city: null,
            country: null,
            state: null,
            zipcode: null,
          },
        }

        const result = mapCustomerToFormValues(customer)

        expect(result.shippingAddress).toEqual({
          addressLine1: undefined,
          addressLine2: undefined,
          city: undefined,
          country: undefined,
          state: undefined,
          zipcode: undefined,
        })
      })
    })
  })

  describe('editCustomerBillingValidationSchema', () => {
    const validBase = { shippingAddress: {} }

    describe('WHEN email is valid', () => {
      it('THEN should pass validation', () => {
        const result = editCustomerBillingValidationSchema.safeParse({
          ...validBase,
          email: 'test@example.com',
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN email is empty string', () => {
      it('THEN should pass validation', () => {
        const result = editCustomerBillingValidationSchema.safeParse({
          ...validBase,
          email: '',
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN email is invalid', () => {
      it('THEN should fail validation with correct error message', () => {
        const result = editCustomerBillingValidationSchema.safeParse({
          ...validBase,
          email: 'not-an-email',
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const emailError = result.error.issues.find((issue) => issue.path.includes('email'))

          expect(emailError?.message).toBe('text_620bc4d4269a55014d493fc3')
        }
      })
    })

    describe('WHEN customerType is a valid enum value', () => {
      it('THEN should pass validation', () => {
        const result = editCustomerBillingValidationSchema.safeParse({
          ...validBase,
          customerType: CustomerTypeEnum.Company,
        })

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN all optional fields are omitted', () => {
      it('THEN should pass validation with only shippingAddress', () => {
        const result = editCustomerBillingValidationSchema.safeParse(validBase)

        expect(result.success).toBe(true)
      })
    })

    describe('WHEN shippingAddress is missing', () => {
      it('THEN should fail validation', () => {
        const result = editCustomerBillingValidationSchema.safeParse({})

        expect(result.success).toBe(false)
      })
    })
  })
})
