import addressFormatter from '@fragaria/address-formatter'

import { CountryCodes } from '~/core/constants/countryCodes'
import { CountryCode } from '~/generated/graphql'

type FormatAddressInput = {
  addressLine1?: string | null | undefined
  addressLine2?: string | null | undefined
  city?: string | null | undefined
  country?: CountryCode | null | undefined
  state?: string | null | undefined
  zipcode?: string | null | undefined
}

export const formatAddress = (address: FormatAddressInput): string | null => {
  const hasAnyValue = Object.values(address).some((value) => !!value)

  if (!hasAnyValue) return null

  const road = [address.addressLine1, address.addressLine2].filter(Boolean).join('\n')

  return addressFormatter.format(
    {
      city: address.city || undefined,
      country: !!address.country ? CountryCodes[address.country] : undefined,
      countryCode: address.country || undefined,
      postcode: address.zipcode || undefined,
      road: road || undefined,
      state: address.state || undefined,
    },
    {
      fallbackCountryCode: 'US',
    },
  )
}
