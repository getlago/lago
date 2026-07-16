import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { GetRolesListDocument } from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'
import { render, TestMocksType } from '~/test-utils'

import { UpdateInviteSingleRole } from '../../common/inviteTypes'
import RolePicker from '../RolePicker'

// Mock @tanstack/react-virtual for ComboBox virtualization in jsdom
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getVirtualItems: () =>
      Array.from({ length: count }, (_, index) => ({
        key: index,
        index,
        start: index * 56,
        size: 56,
      })),
    getTotalSize: () => count * 56,
    scrollToIndex: () => {},
    measureElement: () => {},
  }),
}))

const mockUseCurrentUser = jest.fn()

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockUseCurrentUser(),
}))

// Mock scrollIntoView for jsdom
Element.prototype.scrollIntoView = jest.fn()

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

// Wrapper component that provides form context
const RolePickerWrapper = ({
  onSubmit,
}: {
  onSubmit?: (values: UpdateInviteSingleRole) => void
}) => {
  const form = useAppForm({
    defaultValues: {
      role: '',
    } as UpdateInviteSingleRole,
    onSubmit: async ({ value }) => {
      onSubmit?.(value)
    },
  })

  return (
    <form.AppForm>
      <form
        onSubmit={(e) => {
          e.preventDefault()
          form.handleSubmit()
        }}
      >
        <RolePicker form={form} fields={{ role: 'role' }} />
        <button type="submit" data-test="submit-button">
          Submit
        </button>
      </form>
    </form.AppForm>
  )
}

async function prepare({ mocks = [rolesListMock] }: { mocks?: TestMocksType } = {}) {
  const onSubmit = jest.fn()

  await act(() =>
    render(<RolePickerWrapper onSubmit={onSubmit} />, {
      mocks,
    }),
  )

  return { onSubmit }
}

async function openDropdown() {
  const user = userEvent.setup()

  await waitFor(() => {
    expect(screen.getByRole('combobox')).toBeInTheDocument()
  })

  const combobox = screen.getByRole('combobox')

  await user.click(combobox)

  await waitFor(() => {
    expect(combobox).toHaveAttribute('aria-expanded', 'true')
  })

  return user
}

describe('RolePicker', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    beforeEach(() => {
      mockUseCurrentUser.mockReturnValue({
        isPremium: true,
        currentMembership: { roles: ['Admin'] },
      })
    })

    it('renders the role label', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('Role')).toBeInTheDocument()
      })
    })

    it('renders the combobox input', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })

    it('renders placeholder text', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByPlaceholderText(/search and select a role/i)).toBeInTheDocument()
      })
    })

    it('does not show premium upsell banner for premium users', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('Role')).toBeInTheDocument()
      })

      // Premium upsell banner should not be visible for premium users
      expect(screen.queryByText(/unlock/i)).not.toBeInTheDocument()
    })
  })

  describe('Role availability based on current user role', () => {
    describe('when the current user is an Admin', () => {
      beforeEach(() => {
        mockUseCurrentUser.mockReturnValue({
          isPremium: true,
          currentMembership: { roles: ['Admin'] },
        })
      })

      it('all roles are enabled', async () => {
        await prepare()
        await openDropdown()

        const adminItem = screen.getByTestId('admin')
        const financeItem = screen.getByTestId('finance')
        const managerItem = screen.getByTestId('manager')

        expect(adminItem).not.toHaveAttribute('aria-disabled', 'true')
        expect(financeItem).not.toHaveAttribute('aria-disabled', 'true')
        expect(managerItem).not.toHaveAttribute('aria-disabled', 'true')
      })
    })

    describe('when the current user is a Manager (non-admin)', () => {
      beforeEach(() => {
        mockUseCurrentUser.mockReturnValue({
          isPremium: true,
          currentMembership: { roles: ['Manager'] },
        })
      })

      it('Admin role is disabled', async () => {
        await prepare()
        await openDropdown()

        const adminItem = screen.getByTestId('admin')

        expect(adminItem).toHaveAttribute('aria-disabled', 'true')
      })

      it('non-admin roles remain enabled', async () => {
        await prepare()
        await openDropdown()

        const financeItem = screen.getByTestId('finance')
        const managerItem = screen.getByTestId('manager')

        expect(financeItem).not.toHaveAttribute('aria-disabled', 'true')
        expect(managerItem).not.toHaveAttribute('aria-disabled', 'true')
      })
    })

    describe('when the current user is a Finance (non-admin)', () => {
      beforeEach(() => {
        mockUseCurrentUser.mockReturnValue({
          isPremium: true,
          currentMembership: { roles: ['Finance'] },
        })
      })

      it('Admin role is disabled', async () => {
        await prepare()
        await openDropdown()

        const adminItem = screen.getByTestId('admin')

        expect(adminItem).toHaveAttribute('aria-disabled', 'true')
      })

      it('non-admin roles remain enabled', async () => {
        await prepare()
        await openDropdown()

        const financeItem = screen.getByTestId('finance')
        const managerItem = screen.getByTestId('manager')

        expect(financeItem).not.toHaveAttribute('aria-disabled', 'true')
        expect(managerItem).not.toHaveAttribute('aria-disabled', 'true')
      })
    })

    describe('when the current user is non-admin and non-premium', () => {
      beforeEach(() => {
        mockUseCurrentUser.mockReturnValue({
          isPremium: false,
          currentMembership: { roles: ['Manager'] },
        })
      })

      it('Admin role is disabled (not admin)', async () => {
        await prepare()
        await openDropdown()

        const adminItem = screen.getByTestId('admin')

        expect(adminItem).toHaveAttribute('aria-disabled', 'true')
      })

      it('non-admin roles are also disabled (not premium)', async () => {
        await prepare()
        await openDropdown()

        const financeItem = screen.getByTestId('finance')
        const managerItem = screen.getByTestId('manager')

        expect(financeItem).toHaveAttribute('aria-disabled', 'true')
        expect(managerItem).toHaveAttribute('aria-disabled', 'true')
      })

      it('shows premium upsell banner', async () => {
        await prepare()

        await waitFor(() => {
          expect(screen.getByText('Role')).toBeInTheDocument()
        })

        expect(screen.getByText(/unlock/i)).toBeInTheDocument()
      })
    })
  })

  describe('Role Selection', () => {
    beforeEach(() => {
      mockUseCurrentUser.mockReturnValue({
        isPremium: true,
        currentMembership: { roles: ['Admin'] },
      })
    })

    it('opens dropdown when clicked', async () => {
      await prepare()
      await openDropdown()

      const combobox = screen.getByRole('combobox')

      expect(combobox).toHaveAttribute('aria-expanded', 'true')
    })
  })

  describe('Loading State', () => {
    beforeEach(() => {
      mockUseCurrentUser.mockReturnValue({
        isPremium: true,
        currentMembership: { roles: ['Admin'] },
      })
    })

    it('renders combobox while roles are loading', async () => {
      const loadingMock = {
        request: {
          query: GetRolesListDocument,
        },
        delay: Infinity,
        result: {
          data: null,
        },
      }

      await act(() =>
        render(<RolePickerWrapper />, {
          mocks: [loadingMock],
        }),
      )

      // Combobox should still render
      expect(screen.getByRole('combobox')).toBeInTheDocument()
    })
  })
})
