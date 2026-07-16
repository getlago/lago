import { render, screen, waitFor } from '@testing-library/react'

import { GetAllMembersForFilterDocument } from '~/generated/graphql'
import { AllTheProviders, TestMocksType } from '~/test-utils'

import { filterDataInlineSeparator } from '../../types'
import { FiltersItemUserIds } from '../FiltersItemUserIds'

jest.mock('~/components/designSystem/Filters/useFilters', () => ({
  useFilters: () => ({
    displayInDialog: false,
  }),
}))

const mockSetFilterValue = jest.fn()

const membersMock: TestMocksType = [
  {
    request: {
      query: GetAllMembersForFilterDocument,
      variables: { limit: 500 },
    },
    result: {
      data: {
        memberships: {
          __typename: 'MembershipCollection',
          collection: [
            {
              __typename: 'Membership',
              id: 'membership-1',
              user: {
                __typename: 'User',
                id: 'user-1',
                email: 'alice@example.com',
              },
            },
            {
              __typename: 'Membership',
              id: 'membership-2',
              user: {
                __typename: 'User',
                id: 'user-2',
                email: 'bob@example.com',
              },
            },
          ],
        },
      },
    },
  },
]

const renderComponent = (value?: string, mocks: TestMocksType = membersMock) => {
  return render(<FiltersItemUserIds value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: (props) => <AllTheProviders {...props} mocks={mocks} />,
  })
}

describe('FiltersItemUserIds', () => {
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

  describe('GIVEN a value with user id and email', () => {
    describe('WHEN a single user is selected', () => {
      it('THEN displays the user email as a chip', async () => {
        const value = `user-1${filterDataInlineSeparator}alice@example.com`

        renderComponent(value)

        await waitFor(() => {
          expect(screen.getByText('alice@example.com')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN multiple users are selected', () => {
      it('THEN displays all user email chips', async () => {
        const value = `user-1${filterDataInlineSeparator}alice@example.com,user-2${filterDataInlineSeparator}bob@example.com`

        renderComponent(value)

        await waitFor(() => {
          expect(screen.getByText('alice@example.com')).toBeInTheDocument()
          expect(screen.getByText('bob@example.com')).toBeInTheDocument()
        })
      })
    })
  })
})
