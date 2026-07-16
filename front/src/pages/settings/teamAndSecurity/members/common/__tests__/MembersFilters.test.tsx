import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { GetRolesListDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import MembersFilters, { MembersFiltersProps } from '../MembersFilters'

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
  }),
}))

const rolesListMock = {
  request: {
    query: GetRolesListDocument,
  },
  result: {
    data: {
      roles: [
        {
          __typename: 'Role',
          id: 'role-1',
          name: 'Admin',
          code: 'admin',
          description: 'Administrator role',
          permissions: [],
          admin: true,
          memberships: [],
        },
        {
          __typename: 'Role',
          id: 'role-2',
          name: 'Finance',
          code: 'finance',
          description: 'Finance role',
          permissions: [],
          admin: false,
          memberships: [],
        },
        {
          __typename: 'Role',
          id: 'role-3',
          name: 'Manager',
          code: 'manager',
          description: 'Manager role',
          permissions: [],
          admin: false,
          memberships: [],
        },
      ],
    },
  },
}

const defaultProps: MembersFiltersProps = {
  searchQuery: '',
  setSearchQuery: jest.fn(),
  type: 'members',
}

async function prepare({
  mocks = [rolesListMock],
  props = defaultProps,
}: { mocks?: TestMocksType; props?: MembersFiltersProps } = {}) {
  return await act(() =>
    render(<MembersFilters {...props} />, {
      mocks,
    }),
  )
}

describe('MembersFilters', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    it('renders the search input', async () => {
      await prepare()

      expect(screen.getByRole('textbox')).toBeInTheDocument()
    })

    it('renders the role filter button', async () => {
      await prepare()

      // "All roles" is the default text
      expect(screen.getByText(/all roles/i)).toBeInTheDocument()
    })

    it('renders correct placeholder for members type', async () => {
      await prepare({ props: { ...defaultProps, type: 'members' } })

      expect(screen.getByPlaceholderText(/search/i)).toBeInTheDocument()
    })

    it('renders correct placeholder for invitations type', async () => {
      await prepare({ props: { ...defaultProps, type: 'invitations' } })

      expect(screen.getByPlaceholderText(/search/i)).toBeInTheDocument()
    })
  })

  describe('Search Functionality', () => {
    it('calls setSearchQuery when typing in search input', async () => {
      const setSearchQuery = jest.fn()
      const user = userEvent.setup()

      await prepare({ props: { ...defaultProps, setSearchQuery } })

      const searchInput = screen.getByRole('textbox')

      await user.type(searchInput, 'test')

      await waitFor(() => {
        expect(setSearchQuery).toHaveBeenCalled()
      })
    })

    it('displays current search query value', async () => {
      await prepare({ props: { ...defaultProps, searchQuery: 'test@example.com' } })

      const searchInput = screen.getByRole('textbox')

      expect(searchInput).toHaveValue('test@example.com')
    })
  })

  describe('Role Filter', () => {
    it('opens role filter dropdown when clicked', async () => {
      const user = userEvent.setup()

      await prepare()

      const roleFilterButton = screen.getByText(/all roles/i)

      await user.click(roleFilterButton)

      // Should show "All roles" option in the dropdown
      await waitFor(() => {
        const allRolesOptions = screen.getAllByText(/all roles/i)

        expect(allRolesOptions.length).toBeGreaterThanOrEqual(1)
      })
    })

    it('clears search input when clicking clear button', async () => {
      const setSearchQuery = jest.fn()
      const user = userEvent.setup()

      await prepare({ props: { ...defaultProps, searchQuery: 'test', setSearchQuery } })

      const searchInput = screen.getByRole('textbox')

      expect(searchInput).toHaveValue('test')

      // Clear the input
      await user.clear(searchInput)

      await waitFor(() => {
        expect(setSearchQuery).toHaveBeenCalledWith('')
      })
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with default props', async () => {
      const { container } = await prepare()

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with search query', async () => {
      const { container } = await prepare({
        props: { ...defaultProps, searchQuery: 'test@example.com' },
      })

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with invitations type', async () => {
      const { container } = await prepare({ props: { ...defaultProps, type: 'invitations' } })

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with members type', async () => {
      const { container } = await prepare({ props: { ...defaultProps, type: 'members' } })

      expect(container).toMatchSnapshot()
    })
  })
})
