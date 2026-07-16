import { computeCustomerInitials, getInitials } from '~/components/customers/utils'

describe('customerUtils', () => {
  describe('getInitials', () => {
    describe('one word', () => {
      it('should return the first letter of the single word', () => {
        expect(getInitials('First')).toEqual('F')
      })
    })

    describe('multiple words', () => {
      it('should return the first letter of the two words', () => {
        expect(getInitials('First Second')).toEqual('FS')
      })

      it('should return the first letter of all the words', () => {
        expect(getInitials('First Second Third')).toEqual('FST')
      })
    })
  })

  describe('computeCustomerInitials', () => {
    describe('name', () => {
      it('should return the initial of the name', () => {
        expect(computeCustomerInitials({ name: 'Lago' })).toEqual('L')
      })
    })

    describe('name + firstname', () => {
      it('should return the initial of the name', () => {
        expect(computeCustomerInitials({ name: 'Lago', firstname: 'Stefan' })).toEqual('L')
      })
    })

    describe('name + lastname', () => {
      it('should return the initial of the name', () => {
        expect(computeCustomerInitials({ name: 'Lago', lastname: 'World' })).toEqual('L')
      })
    })

    describe('name + firstname + lastname', () => {
      it('should return the initial of the name', () => {
        expect(
          computeCustomerInitials({ name: 'Lago', firstname: 'Stefan', lastname: 'World' }),
        ).toEqual('L')
      })
    })

    describe('firstname', () => {
      it('should return the initial of the firstname', () => {
        expect(computeCustomerInitials({ firstname: 'Stefan' })).toEqual('S')
      })
    })

    describe('firstname + lastname', () => {
      it('should return the initial of both names', () => {
        expect(computeCustomerInitials({ firstname: 'Stefan', lastname: 'World' })).toEqual('SW')
      })
    })

    describe('lastname', () => {
      it('should return the initial of the last name', () => {
        expect(computeCustomerInitials({ lastname: 'World' })).toEqual('W')
      })
    })
  })
})
