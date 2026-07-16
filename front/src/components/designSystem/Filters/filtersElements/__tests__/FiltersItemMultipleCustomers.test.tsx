import { render, screen, waitFor } from '@testing-library/react'

import { GetCustomersForFilterItemMultipleCustomersDocument } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { filterDataInlineSeparator } from '../../types'
import { FiltersItemMultipleCustomers } from '../FiltersItemMultipleCustomers'

jest.mock('~/components/designSystem/Filters/useFilters', () => ({
  useFilters: () => ({
    displayInDialog: false,
  }),
}))

const mockSetFilterValue = jest.fn()

const customersMock: TestMocksType = [
  {
    request: {
      query: GetCustomersForFilterItemMultipleCustomersDocument,
      variables: { page: 1, limit: 500 },
    },
    result: {
      data: {
        customers: {
          __typename: 'CustomerCollection',
          metadata: {
            __typename: 'CollectionMetadata',
            currentPage: 1,
            totalPages: 1,
          },
          collection: [
            {
              __typename: 'Customer',
              id: 'customer-1',
              displayName: 'Acme Corp',
              externalId: 'ext-1',
              deletedAt: null,
            },
            {
              __typename: 'Customer',
              id: 'customer-2',
              displayName: 'Beta Inc',
              externalId: 'ext-2',
              deletedAt: null,
            },
            {
              __typename: 'Customer',
              id: 'customer-3',
              displayName: '',
              externalId: 'ext-3',
              deletedAt: '2026-01-01T00:00:00Z',
            },
          ],
        },
      },
    },
  },
]

const renderComponent = (value?: string, mocks: TestMocksType = customersMock) => {
  return render(
    <FiltersItemMultipleCustomers value={value} setFilterValue={mockSetFilterValue} />,
    {
      wrapper: (props) => <AllTheProviders {...props} mocks={mocks} />,
    },
  )
}

describe('FiltersItemMultipleCustomers', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no initial value', () => {
    it('THEN displays the combobox', async () => {
      renderComponent()

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN undefined value', () => {
    it('THEN should not crash and displays the combobox', async () => {
      renderComponent(undefined)

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a value with id and customer name', () => {
    describe('WHEN a single customer is selected', () => {
      it('THEN displays the customer name as a chip', async () => {
        const value = `customer-1${filterDataInlineSeparator}Acme Corp`

        renderComponent(value)

        await waitFor(() => {
          expect(screen.getByText('Acme Corp')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN multiple customers are selected', () => {
      it('THEN displays all customer name chips', async () => {
        const value = `customer-1${filterDataInlineSeparator}Acme Corp,customer-2${filterDataInlineSeparator}Beta Inc`

        renderComponent(value)

        await waitFor(() => {
          expect(screen.getByText('Acme Corp')).toBeInTheDocument()
          expect(screen.getByText('Beta Inc')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value has no inline separator name', () => {
      it('THEN falls back to displaying the id', async () => {
        const value = 'customer-1'

        renderComponent(value)

        await waitFor(() => {
          expect(screen.getByText('customer-1')).toBeInTheDocument()
        })
      })
    })
  })
})
