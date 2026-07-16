import { render } from '@testing-library/react'

import { CustomerMainInfosFragment } from '~/generated/graphql'

import { createMockCustomerDetails } from './factories/CustomerDetails.factory'

import { CustomerInfoRows } from '../CustomerInfoRows'

jest.mock('~/core/formats/formatAddress', () => ({
  formatAddress: jest.fn(({ addressLine1, addressLine2, city, state, country, zipcode }) =>
    [addressLine1, addressLine2, city, state, country === 'IT' ? 'Italy' : country, zipcode]
      .filter(Boolean)
      .join(', '),
  ),
}))

describe('CustomerInfoRows', () => {
  it('renders customer fields correctly', () => {
    const customer = createMockCustomerDetails()

    const { getByText } = render(<CustomerInfoRows customer={customer} />)

    expect(
      getByText('Via Toledo, Apartment 5B, Napoli, Campania, Italy, 80100'),
    ).toBeInTheDocument()
    expect(
      getByText('Corso Umberto I, Building A, Napoli, Campania, Italy, 80133'),
    ).toBeInTheDocument()
    expect(getByText('Custom Field 1')).toBeInTheDocument()
    expect(getByText('Value 1')).toBeInTheDocument()
    expect(getByText('Custom Field 2')).toBeInTheDocument()
    expect(getByText('Value 2')).toBeInTheDocument()
    expect(getByText('Entity 1')).toBeInTheDocument()
    expect(getByText('John Doe')).toBeInTheDocument() // full name made by firstname + lastname
    expect(getByText('Jonathan Doe')).toBeInTheDocument()
    expect(getByText('EXT123')).toBeInTheDocument()
    expect(getByText('SF123')).toBeInTheDocument()
    expect(getByText('EUR')).toBeInTheDocument()
    expect(getByText('Napoli Legal Name')).toBeInTheDocument()
    expect(getByText('123456789')).toBeInTheDocument()
    expect(getByText('IT123456789')).toBeInTheDocument()
    expect(getByText('john.doe@example.com')).toBeInTheDocument()
    expect(getByText('https://example.com')).toBeInTheDocument()
    expect(getByText('+390812345678')).toBeInTheDocument()
  })

  it('does not render fields when props are missing', () => {
    const customer: CustomerMainInfosFragment = {
      name: undefined,
      firstname: undefined,
      lastname: undefined,
      customerType: undefined,
      addressLine1: undefined,
      city: undefined,
      country: undefined,
      metadata: [],
      billingEntity: undefined,
      externalId: undefined,
      externalSalesforceId: undefined,
      currency: undefined,
      legalName: undefined,
      legalNumber: undefined,
      taxIdentificationNumber: undefined,
      email: undefined,
      url: undefined,
      phone: undefined,
      timezone: undefined,
      addressLine2: undefined,
      state: undefined,
      zipcode: undefined,
      shippingAddress: undefined,
    } as unknown as CustomerMainInfosFragment

    const { queryByText } = render(<CustomerInfoRows customer={customer} />)

    expect(
      queryByText('Via Toledo, Apartment 5B, Napoli, Campania, Italy, 80100'),
    ).not.toBeInTheDocument()
    expect(
      queryByText('Corso Umberto I, Building A, Napoli, Campania, Italy, 80133'),
    ).not.toBeInTheDocument()
    expect(queryByText('Custom Field 1')).not.toBeInTheDocument()
    expect(queryByText('Value 1')).not.toBeInTheDocument()
    expect(queryByText('Custom Field 2')).not.toBeInTheDocument()
    expect(queryByText('Value 2')).not.toBeInTheDocument()
    expect(queryByText('Entity 1')).not.toBeInTheDocument()
    expect(queryByText('John Doe')).not.toBeInTheDocument()
    expect(queryByText('Jonathan Doe')).not.toBeInTheDocument()
    expect(queryByText('EXT123')).not.toBeInTheDocument()
    expect(queryByText('SF123')).not.toBeInTheDocument()
    expect(queryByText('EUR')).not.toBeInTheDocument()
    expect(queryByText('Napoli Legal Name')).not.toBeInTheDocument()
    expect(queryByText('123456789')).not.toBeInTheDocument()
    expect(queryByText('IT123456789')).not.toBeInTheDocument()
    expect(queryByText('john.doe@example.com')).not.toBeInTheDocument()
    expect(queryByText('https://example.com')).not.toBeInTheDocument()
    expect(queryByText('+390812345678')).not.toBeInTheDocument()
  })
})
