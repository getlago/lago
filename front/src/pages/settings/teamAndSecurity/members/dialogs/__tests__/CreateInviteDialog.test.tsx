import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  DIALOG_TITLE_TEST_ID,
  FORM_DIALOG_CANCEL_BUTTON_TEST_ID,
  FORM_DIALOG_NAME,
} from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { GetRolesListDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import {
  FORM_CREATE_INVITE_ID,
  INVITE_URL_DATA_TEST,
  SUBMIT_INVITE_DATA_TEST,
  useCreateInviteDialog,
} from '../CreateInviteDialog'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

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

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
    currentMembership: { roles: ['Admin'] },
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      id: 'org-123',
      name: 'Test Organization',
    },
  }),
}))

const mockCreateInvite = jest.fn()

jest.mock('../../hooks/useInviteActions', () => ({
  useInviteActions: () => ({
    createInvite: mockCreateInvite,
  }),
}))

// Mock scrollIntoView for jsdom
Element.prototype.scrollIntoView = jest.fn()

const OPEN_DIALOG_TEST_ID = 'open-dialog'

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
      ],
    },
  },
}

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const TestComponent = () => {
  const { openCreateInviteDialog } = useCreateInviteDialog()

  return (
    <button data-test={OPEN_DIALOG_TEST_ID} onClick={openCreateInviteDialog}>
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
    screen.getByTestId(OPEN_DIALOG_TEST_ID).click()
  })

  await waitFor(() => {
    expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
  })
}

describe('CreateInviteDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
    // NiceModal keeps open modals in module-level state that survives cleanup().
    // Purge them so leaked dialogs from one test don't bleed into the next.
    NiceModal.remove(FORM_DIALOG_NAME)
    NiceModal.remove(CENTRALIZED_DIALOG_NAME)
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
        screen.getByTestId(OPEN_DIALOG_TEST_ID).click()
      })

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('Rendering', () => {
    it('renders the dialog with correct title', async () => {
      await prepare()

      expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
    })

    it('renders the email input field', async () => {
      await prepare()

      expect(screen.getByLabelText(/email/i)).toBeInTheDocument()
    })

    it('renders the role picker', async () => {
      await prepare()

      expect(screen.getByText('Role')).toBeInTheDocument()
    })

    it('renders the submit button', async () => {
      await prepare()

      expect(screen.getByTestId(SUBMIT_INVITE_DATA_TEST)).toBeInTheDocument()
    })

    it('renders the cancel button', async () => {
      await prepare()

      expect(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('Form Validation', () => {
    it('converts email to lowercase', async () => {
      const user = userEvent.setup()

      await prepare()

      const emailInput = screen.getByLabelText(/email/i)

      await user.type(emailInput, 'TEST@EXAMPLE.COM')

      await waitFor(() => {
        expect(emailInput).toHaveValue('test@example.com')
      })
    })
  })

  describe('Dialog Actions', () => {
    it('closes dialog when cancel button is clicked', async () => {
      const user = userEvent.setup()

      await prepare()

      expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()

      const cancelButton = screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)

      await user.click(cancelButton)

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Form ID', () => {
    it('has the correct form ID', async () => {
      await prepare()

      expect(document.getElementById(FORM_CREATE_INVITE_ID)).toBeInTheDocument()
    })
  })

  describe('Email Input', () => {
    it('accepts valid email addresses', async () => {
      const user = userEvent.setup()

      await prepare()

      const emailInput = screen.getByLabelText(/email/i)

      await user.type(emailInput, 'user@example.com')

      expect(emailInput).toHaveValue('user@example.com')
    })

    it('handles special characters in email', async () => {
      const user = userEvent.setup()

      await prepare()

      const emailInput = screen.getByLabelText(/email/i)

      await user.type(emailInput, 'user+test@example.co.uk')

      expect(emailInput).toHaveValue('user+test@example.co.uk')
    })
  })

  describe('Submit Button State', () => {
    it('renders submit button with correct text', async () => {
      await prepare()

      const submitButton = screen.getByTestId(SUBMIT_INVITE_DATA_TEST)

      expect(submitButton).toBeInTheDocument()
      expect(submitButton).toHaveTextContent(/generate invitation/i)
    })

    it('submit button is enabled initially', async () => {
      await prepare()

      const submitButton = screen.getByTestId(SUBMIT_INVITE_DATA_TEST)

      expect(submitButton).not.toBeDisabled()
    })
  })

  describe('Dialog Form', () => {
    it('renders form with correct structure', async () => {
      await prepare()

      expect(document.getElementById(FORM_CREATE_INVITE_ID)).toBeInTheDocument()
      expect(screen.getByLabelText(/email/i)).toBeInTheDocument()
      expect(screen.getByText('Role')).toBeInTheDocument()
    })
  })

  describe('Form Submission', () => {
    async function fillForm(user: ReturnType<typeof userEvent.setup>) {
      const emailInput = screen.getByLabelText(/email/i)

      await user.type(emailInput, 'newuser@example.com')

      // Open the ComboBox dropdown and select Admin role
      const roleInput = screen.getByPlaceholderText(/search and select a role/i)

      await user.click(roleInput)

      // Click the option element (inner ComboboxItem with data-test={value})
      await waitFor(() => {
        expect(screen.getByTestId('admin')).toBeInTheDocument()
      })

      await user.click(screen.getByTestId('admin'))
    }

    it('calls createInvite with correct arguments on successful submission', async () => {
      const user = userEvent.setup()

      mockCreateInvite.mockResolvedValue({
        data: {
          createInvite: {
            id: 'invite-1',
            token: 'test-token-123',
          },
        },
      })

      await prepare({ mocks: [rolesListMock, rolesListMock, rolesListMock] })
      await fillForm(user)

      await user.click(screen.getByTestId(SUBMIT_INVITE_DATA_TEST))

      await waitFor(
        () => {
          expect(mockCreateInvite).toHaveBeenCalledWith({
            variables: {
              input: {
                email: 'newuser@example.com',
                roles: ['admin'],
              },
            },
          })
        },
        { timeout: 5000 },
      )
    })

    it('opens copy invite link dialog after successful submission', async () => {
      const user = userEvent.setup()

      mockCreateInvite.mockResolvedValue({
        data: {
          createInvite: {
            id: 'invite-1',
            token: 'test-token-123',
          },
        },
      })

      await prepare({ mocks: [rolesListMock, rolesListMock, rolesListMock] })
      await fillForm(user)

      await user.click(screen.getByTestId(SUBMIT_INVITE_DATA_TEST))

      // Wait for the full async chain: form submit → FormDialog resolves → CentralizedDialog opens
      await waitFor(
        () => {
          expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 5000 },
      )

      expect(screen.getByTestId(INVITE_URL_DATA_TEST)).toBeInTheDocument()
    })

    it('copies invitation URL and shows toast when copy button is clicked', async () => {
      const user = userEvent.setup()

      mockCreateInvite.mockResolvedValue({
        data: {
          createInvite: {
            id: 'invite-1',
            token: 'test-token-123',
          },
        },
      })

      await prepare({ mocks: [rolesListMock, rolesListMock, rolesListMock] })
      await fillForm(user)

      await user.click(screen.getByTestId(SUBMIT_INVITE_DATA_TEST))

      // Wait for the full async chain: form submit → FormDialog resolves → CentralizedDialog opens
      await waitFor(
        () => {
          expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 5000 },
      )

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(copyToClipboard).toHaveBeenCalled()
        expect(addToast).toHaveBeenCalledWith({
          severity: 'info',
          translateKey: 'text_63208c711ce25db781407536',
        })
      })
    })

    it('keeps dialog open when InviteAlreadyExists error occurs', async () => {
      const user = userEvent.setup()

      mockCreateInvite.mockResolvedValue({
        errors: [
          {
            message: 'Invite already exists',
            extensions: {
              code: 'unprocessable_entity',
              details: { base: ['invite_already_exists'] },
            },
          },
        ],
      })

      await prepare({ mocks: [rolesListMock, rolesListMock, rolesListMock] })
      await fillForm(user)

      await user.click(screen.getByTestId(SUBMIT_INVITE_DATA_TEST))

      // Dialog should stay open (closeOnError: false)
      await waitFor(
        () => {
          expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 5000 },
      )
    })

    it('keeps dialog open when EmailAlreadyUsed error occurs', async () => {
      const user = userEvent.setup()

      mockCreateInvite.mockResolvedValue({
        errors: [
          {
            message: 'Email already used',
            extensions: {
              code: 'unprocessable_entity',
              details: { base: ['email_already_used'] },
            },
          },
        ],
      })

      await prepare({ mocks: [rolesListMock, rolesListMock, rolesListMock] })
      await fillForm(user)

      await user.click(screen.getByTestId(SUBMIT_INVITE_DATA_TEST))

      // Dialog should stay open (closeOnError: false)
      await waitFor(
        () => {
          expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
        },
        { timeout: 5000 },
      )
    })
  })
})
