import { CountryCode } from '~/generated/graphql'

import { formatAddress } from '../formatAddress'

describe('formatAddress', () => {
  it('should format the address correctly', () => {
    const address = formatAddress({
      addressLine1: '123 Main St',
      addressLine2: 'Apt 4B',
      city: 'San Francisco',
      country: CountryCode.Us,
      state: 'CA',
      zipcode: '94101',
    })

    expect(address).toBe('123 Main St\nApt 4B\nSan Francisco, CA 94101\nUnited States of America\n')
  })

  it('should return null if no address is provided', () => {
    const addressNull = formatAddress({
      addressLine1: null,
      addressLine2: null,
      city: null,
      country: null,
      state: null,
      zipcode: null,
    })

    const addressUndefined = formatAddress({
      addressLine1: undefined,
      addressLine2: undefined,
      city: undefined,
      country: undefined,
      state: undefined,
      zipcode: undefined,
    })

    const addressEmpty = formatAddress({})

    expect(addressNull).toBeNull()
    expect(addressUndefined).toBeNull()
    expect(addressEmpty).toBeNull()
  })

  it('should format as US address if no country is provided', () => {
    const address = formatAddress({
      addressLine1: '123 Main St',
      addressLine2: 'Apt 4B',
      city: 'London',
      state: 'London',
      zipcode: 'W1A 1AA',
    })

    expect(address).toBe('123 Main St\nApt 4B\nLondon, London W1A 1AA\n')
  })

  describe('when the address is international', () => {
    it('should format a Canadian address correctly', () => {
      const address = formatAddress({
        addressLine1: '123 Main St',
        addressLine2: 'Apt 4B',
        city: 'Toronto',
        country: CountryCode.Ca,
        state: 'CA',
        zipcode: 'M5V 3L9',
      })

      expect(address).toBe('123 Main St\nApt 4B\nToronto, CA M5V 3L9\nCanada\n')
    })

    it('should format a UK address correctly', () => {
      const address = formatAddress({
        addressLine1: '123 Main St',
        addressLine2: 'Apt 4B',
        city: 'London',
        country: CountryCode.Gb,
        state: 'London',
        zipcode: 'W1A 1AA',
      })

      expect(address).toBe(
        '123 Main St\nApt 4B\nLondon\nW1A 1AA\nUnited Kingdom of Great Britain and Northern Ireland\n',
      )
    })

    it('should format a French address correctly', () => {
      const address = formatAddress({
        addressLine1: '4a rue des cols verts',
        addressLine2: 'Apt 19',
        city: 'Annecy',
        country: CountryCode.Fr,
        state: 'Haute-Savoie',
        zipcode: '74940',
      })

      expect(address).toBe('4a rue des cols verts\nApt 19\n74940 Annecy\nFrance\n')
    })

    it('should format a US address correctly', () => {
      const address = formatAddress({
        addressLine1: '123 Main St',
        addressLine2: 'Apt 4B',
        city: 'San Francisco',
        country: CountryCode.Us,
        state: 'CA',
        zipcode: '94101',
      })

      expect(address).toBe(
        '123 Main St\nApt 4B\nSan Francisco, CA 94101\nUnited States of America\n',
      )
    })

    it('should format a US address without zipcode and city correctly', () => {
      const address = formatAddress({
        addressLine1: '123 Main St',
        addressLine2: 'Apt 4B',
        country: CountryCode.Us,
        state: 'CA',
      })

      expect(address).toBe('123 Main St\nApt 4B\nCA\nUnited States of America\n')
    })
  })
})
