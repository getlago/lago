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
import { addToast } from '~/core/apolloClient'
import {
  LagoApiError,
  MemberForEditRoleForDialogFragment,
  PermissionEnum,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import { EDIT_MEMBER_ROLE_FORM_ID, useEditMemberRoleDialog } from '../EditMemberRoleDialog'

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

jest.mock('~/hooks/useRolesList', () => ({
  useRolesList: () => ({
    roles: [
      {
        id: 'role-1',
        name: 'Admin',
        code: 'admin',
        description: 'Administrator role',
        permissions: [],
        admin: true,
        memberships: [],
      },
      {
        id: 'role-2',
        name: 'Finance',
        code: 'finance',
        description: 'Finance role',
        permissions: [],
        admin: false,
        memberships: [],
      },
      {
        id: 'role-3',
        name: 'Manager',
        code: 'manager',
        description: 'Manager role',
        permissions: [],
        admin: false,
        memberships: [],
      },
    ],
    isLoadingRoles: false,
  }),
}))

const mockUpdateMembershipRole = jest.fn()

jest.mock('../../hooks/useMembershipActions', () => ({
  useMembershipActions: () => ({
    updateMembershipRole: mockUpdateMembershipRole,
  }),
}))

// Mock scrollIntoView for jsdom
Element.prototype.scrollIntoView = jest.fn()

const MEMBER_ID = 'member-123'
const MEMBER_EMAIL = 'member@example.com'

// Build a fully-granted permissions fixture from PermissionEnum so new
// permissions are picked up automatically. Enum keys are PascalCase
// (`AddonsCreate`); the Permissions type fields are the camelCase equivalent.
const permissions = {
  __typename: 'Permissions',
  ...Object.fromEntries(
    Object.keys(PermissionEnum).map((key) => [key.charAt(0).toLowerCase() + key.slice(1), true]),
  ),
} as MemberForEditRoleForDialogFragment['permissions']

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const TestComponent = ({
  isEditingLastAdmin = false,
  isEditingMyOwnMembership = false,
}: {
  isEditingLastAdmin?: boolean
  isEditingMyOwnMembership?: boolean
}) => {
  const { openEditMemberRoleDialog } = useEditMemberRoleDialog()

  return (
    <button
      data-test="open-dialog"
      onClick={() =>
        openEditMemberRoleDialog({
          member: {
            __typename: 'Membership',
            id: MEMBER_ID,
            roles: ['Admin'],
            user: {
              __typename: 'User',
              id: 'user-123',
              email: MEMBER_EMAIL,
            },
            permissions,
          },
          isEditingLastAdmin,
          isEditingMyOwnMembership,
        })
      }
    >
      Open Dialog
    </button>
  )
}

async function prepare({
  isEditingLastAdmin = false,
  isEditingMyOwnMembership = false,
}: {
  isEditingLastAdmin?: boolean
  isEditingMyOwnMembership?: boolean
} = {}) {
  await act(() =>
    render(
      <NiceModalWrapper>
        <TestComponent
          isEditingLastAdmin={isEditingLastAdmin}
          isEditingMyOwnMembership={isEditingMyOwnMembership}
        />
      </NiceModalWrapper>,
    ),
  )

  await act(async () => {
    screen.getByTestId('open-dialog').click()
  })

  await waitFor(() => {
    expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
  })
}

describe('EditMemberRoleDialog', () => {
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

    it('renders the member email', async () => {
      await prepare()

      await waitFor(() => {
        expect(screen.getByText(MEMBER_EMAIL)).toBeInTheDocument()
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

      expect(document.getElementById(EDIT_MEMBER_ROLE_FORM_ID)).toBeInTheDocument()
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

  describe('Last Admin Warning', () => {
    it('shows alert when editing the last admin', async () => {
      await prepare({ isEditingLastAdmin: true })

      await waitFor(() => {
        expect(screen.getByTestId('alert-type-danger')).toBeInTheDocument()
      })
    })

    it('does not show alert when not editing the last admin', async () => {
      await prepare({ isEditingLastAdmin: false })

      expect(screen.queryByTestId('alert-type-danger')).not.toBeInTheDocument()
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

    it('calls updateMembershipRole with correct arguments on successful submission', async () => {
      const user = userEvent.setup()

      mockUpdateMembershipRole.mockResolvedValue({
        data: {
          updateMembership: {
            id: MEMBER_ID,
            roles: ['Finance'],
          },
        },
      })

      await prepare()

      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(mockUpdateMembershipRole).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              input: {
                roles: ['finance'],
                id: MEMBER_ID,
              },
            },
          }),
        )
      })
    })

    it('closes the dialog after successful submission', async () => {
      const user = userEvent.setup()

      mockUpdateMembershipRole.mockResolvedValue({
        data: {
          updateMembership: {
            id: MEMBER_ID,
            roles: ['Finance'],
          },
        },
      })

      await prepare()
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('keeps dialog open when submission fails', async () => {
      const user = userEvent.setup()

      mockUpdateMembershipRole.mockResolvedValue({
        data: null,
      })

      await prepare()
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      // Dialog should stay open (closeOnError: false)
      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })

    it('passes silentErrorCodes with LastAdmin to the mutation context', async () => {
      const user = userEvent.setup()

      mockUpdateMembershipRole.mockResolvedValue({
        data: {
          updateMembership: {
            id: MEMBER_ID,
            roles: ['Finance'],
          },
        },
      })

      await prepare()
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(mockUpdateMembershipRole).toHaveBeenCalledWith(
          expect.objectContaining({
            context: { silentErrorCodes: [LagoApiError.LastAdmin] },
          }),
        )
      })
    })

    it('shows a danger toast when the LastAdmin error is returned', async () => {
      const user = userEvent.setup()

      mockUpdateMembershipRole.mockResolvedValue({
        data: null,
        errors: [
          {
            extensions: {
              code: 'last_admin',
            },
            message: 'last_admin',
          },
        ],
      })

      await prepare()
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(addToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'danger',
          }),
        )
      })
    })

    it('keeps the dialog open when the LastAdmin error is returned', async () => {
      const user = userEvent.setup()

      mockUpdateMembershipRole.mockResolvedValue({
        data: null,
        errors: [
          {
            extensions: {
              code: 'last_admin',
            },
            message: 'last_admin',
          },
        ],
      })

      await prepare()
      await selectRole(user, 'finance')

      await user.click(screen.getByText(/edit role/i))

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
