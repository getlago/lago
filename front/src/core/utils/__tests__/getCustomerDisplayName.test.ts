import { getCustomerDisplayName } from '../getCustomerDisplayName'

describe('getCustomerDisplayName', () => {
  describe('GIVEN a nullish customer', () => {
    describe('WHEN customer is null and no fallback', () => {
      it('THEN should return an empty string', () => {
        expect(getCustomerDisplayName({ customer: null })).toBe('')
      })
    })

    describe('WHEN customer is undefined and no fallback', () => {
      it('THEN should return an empty string', () => {
        expect(getCustomerDisplayName({ customer: undefined })).toBe('')
      })
    })

    describe('WHEN customer is null with a fallback', () => {
      it('THEN should return the fallback', () => {
        expect(getCustomerDisplayName({ customer: null, fallback: 'ext-1' })).toBe('ext-1')
      })
    })
  })

  describe('GIVEN a customer with a name', () => {
    describe('WHEN name is present alongside firstname and lastname', () => {
      it('THEN should prefer the name', () => {
        expect(
          getCustomerDisplayName({
            customer: { name: 'Acme Inc', firstname: 'John', lastname: 'Doe' },
          }),
        ).toBe('Acme Inc')
      })
    })
  })

  describe('GIVEN a customer without a name', () => {
    describe('WHEN firstname and lastname are present', () => {
      it('THEN should join firstname and lastname', () => {
        expect(
          getCustomerDisplayName({
            customer: { name: null, firstname: 'John', lastname: 'Doe' },
          }),
        ).toBe('John Doe')
      })
    })

    describe('WHEN only firstname is present', () => {
      it('THEN should return the firstname', () => {
        expect(
          getCustomerDisplayName({
            customer: { name: null, firstname: 'John', lastname: null },
          }),
        ).toBe('John')
      })
    })

    describe('WHEN only lastname is present', () => {
      it('THEN should return the lastname', () => {
        expect(
          getCustomerDisplayName({
            customer: { name: null, firstname: null, lastname: 'Doe' },
          }),
        ).toBe('Doe')
      })
    })

    describe('WHEN neither name nor firstname/lastname are present', () => {
      it('THEN should return the fallback', () => {
        expect(
          getCustomerDisplayName({
            customer: { name: null, firstname: null, lastname: null },
            fallback: 'ext-1',
          }),
        ).toBe('ext-1')
      })

      it('THEN should return an empty string when no fallback is provided', () => {
        expect(
          getCustomerDisplayName({
            customer: { name: null, firstname: null, lastname: null },
          }),
        ).toBe('')
      })
    })
  })
})
