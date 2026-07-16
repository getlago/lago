import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import {
  DIALOG_TITLE_TEST_ID,
  FORM_DIALOG_CANCEL_BUTTON_TEST_ID,
  FORM_DIALOG_NAME,
} from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { GetRolesListDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import { EDIT_INVITE_ROLE_FORM_ID, useEditInviteRoleDialog } from '../EditInviteRoleDialog'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

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

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
    currentMembership: { roles: ['Admin'] },
  }),
}))

const mockUpdateInviteRole = jest.fn()

jest.mock('../../hooks/useInviteActions', () => ({
  useInviteActions: () => ({
    updateInviteRole: mockUpdateInviteRole,
  }),
}))

// Mock scrollIntoView for jsdom
Element.prototype.scrollIntoView = jest.fn()

const INVITE_ID = 'invite-123'
const INVITE_EMAIL = 'test@example.com'
const INITIAL_ROLE = 'admin'

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

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

const TestComponent = () => {
  const { openEditInviteRoleDialog } = useEditInviteRoleDialog()

  return (
    <button
      data-test="open-dialog"
      onClick={() =>
        openEditInviteRoleDialog({
          __typename: 'Invite',
          id: INVITE_ID,
          email: INVITE_EMAIL,
          roles: [INITIAL_ROLE],
        })
      }
    >
      Open Dialog
    </button>
  )
}

async function prepare({ mocks = [rolesListMock] }: { mocks?: TestMocksType } = {}) {
  await act(() =>
    render(
      <NiceModalWrapper>
        <TestComponent />
      </NiceModalWrapper>,
      { mocks },
    ),
  )

  await act(async () => {
    screen.getByTestId('open-dialog').click()
  })

  await waitFor(() => {
    expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
  })
}

describe('EditInviteRoleDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Opening', () => {
    it('opens the dialog when the hook function is called', async () => {
      await act(() =>
        render(
          <NiceModalWrapper>
            <TestComponent />
          </NiceModalWrapper>,
          { mocks: [rolesListMock] },
        ),
      )

      expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()

      await act(async () => {
        screen.getByTestId('open-dialog').click()
      })

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })

    it('renders the invite email', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText(INVITE_EMAIL)).toBeInTheDocument()
      })
    })

    it('renders the role picker', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText('Role')).toBeInTheDocument()
      })
    })
  })

  describe('Rendering', () => {
    it('has the correct form ID', async () => {
      await prepare()

      expect(document.getElementById(EDIT_INVITE_ROLE_FORM_ID)).toBeInTheDocument()
    })

    it('renders the cancel button', async () => {
      await prepare()

      expect(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Dialog Actions', () => {
    it('closes dialog when cancel button is clicked', async () => {
      const user = userEvent.setup()

      await prepare()

      await user.click(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Form Submission', () => {
    async function selectRole(user: ReturnType<typeof userEvent.setup>, roleValue: string) {
      const roleInput = screen.getByPlaceholderText(/search and select a role/i)

      await user.click(roleInput)

      await waitFor(() => {
        expect(screen.getByTestId(roleValue)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(roleValue))
    }

    it('calls updateInviteRole with correct arguments on successful submission', async () => {
      const user = userEvent.setup()

      mockUpdateInviteRole.mockResolvedValue({
        data: {
          updateInvite: {
            id: INVITE_ID,
            roles: ['finance'],
            email: INVITE_EMAIL,
          },
        },
      })

      await prepare({ mocks: [rolesListMock, rolesListMock] })

      // Change role from admin to finance
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(mockUpdateInviteRole).toHaveBeenCalledWith({
          variables: {
            input: {
              roles: ['finance'],
              id: INVITE_ID,
            },
          },
        })
      })
    })

    it('closes the dialog after successful submission', async () => {
      const user = userEvent.setup()

      mockUpdateInviteRole.mockResolvedValue({
        data: {
          updateInvite: {
            id: INVITE_ID,
            roles: ['finance'],
            email: INVITE_EMAIL,
          },
        },
      })

      await prepare({ mocks: [rolesListMock, rolesListMock] })
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('keeps dialog open when submission fails', async () => {
      const user = userEvent.setup()

      mockUpdateInviteRole.mockResolvedValue({
        data: null,
      })

      await prepare({ mocks: [rolesListMock, rolesListMock] })
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      // Dialog should stay open (closeOnError: false)
      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
