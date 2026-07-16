import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  CENTRALIZED_DIALOG_TEST_ID,
  DIALOG_TITLE_TEST_ID,
} from '~/components/dialogs/const'
import { RevokeInviteDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import { useRevokeInviteDialog } from '../RevokeInviteDialog'

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (params: unknown) => mockAddToast(params),
}))

const INVITE_ID = 'invite-123'
const INVITE_EMAIL = 'test@example.com'
const ORGANIZATION_NAME = 'Test Organization'

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const TestComponent = () => {
  const { openRevokeInviteDialog } = useRevokeInviteDialog()

  return (
    <button
      data-test="open-dialog"
      onClick={() =>
        openRevokeInviteDialog({
          id: INVITE_ID,
          email: INVITE_EMAIL,
          organizationName: ORGANIZATION_NAME,
        })
      }
    >
      Open Dialog
    </button>
  )
}

async function prepare({ mocks = [] }: { mocks?: TestMocksType } = {}) {
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

describe('RevokeInviteDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Rendering', () => {
    it('renders the dialog with correct title', async () => {
      await prepare()

      expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
    })

    it('renders cancel and confirm buttons', async () => {
      await prepare()

      expect(screen.getByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
    })
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

      expect(screen.queryByTestId(CENTRALIZED_DIALOG_TEST_ID)).not.toBeInTheDocument()

      await act(async () => {
        screen.getByTestId('open-dialog').click()
      })

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('Dialog Actions', () => {
    it('closes dialog when cancel button is clicked', async () => {
      const user = userEvent.setup()

      await prepare()

      expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.queryByTestId(CENTRALIZED_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('calls revokeInvite mutation when confirm button is clicked', async () => {
      const user = userEvent.setup()
      const mutationMock = {
        request: {
          query: RevokeInviteDocument,
          variables: {
            input: {
              id: INVITE_ID,
            },
          },
        },
        result: {
          data: {
            revokeInvite: {
              id: INVITE_ID,
            },
          },
        },
      }

      await prepare({ mocks: [mutationMock] })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          translateKey: 'text_63208c711ce25db781407523',
          severity: 'success',
        })
      })
    })
  })
})
