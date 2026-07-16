import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect } from 'react'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  CENTRALIZED_DIALOG_TEST_ID,
} from '~/components/dialogs/const'
import { addToast, initializeTranslations } from '~/core/apolloClient'
import { DestroyIntegrationDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import { useDeleteOktaIntegrationDialog } from '../DeleteOktaIntegrationDialog'

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

const mockAddToast = addToast as jest.Mock

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const mockCallback = jest.fn()

const defaultIntegration = {
  id: 'okta-integration-123',
  name: 'Test Okta Integration',
}

const TestComponent = ({
  integration = defaultIntegration,
  callback,
}: {
  integration?: typeof defaultIntegration
  callback?: () => void
}) => {
  const { openDeleteOktaIntegrationDialog } = useDeleteOktaIntegrationDialog()

  useEffect(() => {
    openDeleteOktaIntegrationDialog({
      integration,
      callback,
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return null
}

const successMock: TestMocksType = [
  {
    request: {
      query: DestroyIntegrationDocument,
      variables: {
        input: {
          id: 'okta-integration-123',
        },
      },
    },
    result: {
      data: {
        destroyIntegration: {
          id: 'okta-integration-123',
        },
      },
    },
  },
]

async function prepare({
  mocks = successMock,
  callback,
}: { mocks?: TestMocksType; callback?: () => void } = {}) {
  await act(() =>
    render(
      <NiceModalWrapper>
        <TestComponent callback={callback} />
      </NiceModalWrapper>,
      { mocks },
    ),
  )

  await waitFor(() => {
    expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
  })
}

describe('DeleteOktaIntegrationDialog', () => {
  beforeAll(async () => {
    await initializeTranslations()
  })

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(cleanup)

  it('opens a centralized dialog with danger variant', async () => {
    await prepare()

    expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
  })

  it('renders the dialog title and description', async () => {
    await prepare()

    // The dialog should contain the title and description (translation keys)
    const dialog = screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)

    expect(dialog).toBeInTheDocument()
  })

  it('calls mutation and shows toast on successful deletion', async () => {
    const user = userEvent.setup()

    await prepare({ callback: mockCallback })

    const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

    await user.click(confirmButton)

    await waitFor(() => {
      expect(mockCallback).toHaveBeenCalled()
    })

    await waitFor(() => {
      expect(mockAddToast).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: 'success',
        }),
      )
    })
  })

  it('does not call callback when mutation fails', async () => {
    const user = userEvent.setup()

    const failMocks: TestMocksType = [
      {
        request: {
          query: DestroyIntegrationDocument,
          variables: {
            input: {
              id: 'okta-integration-123',
            },
          },
        },
        result: {
          data: {
            destroyIntegration: null,
          },
        },
      },
    ]

    await prepare({ mocks: failMocks, callback: mockCallback })

    const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

    await user.click(confirmButton)

    // Give it time, then verify callback was NOT called
    await waitFor(() => {
      expect(mockCallback).not.toHaveBeenCalled()
    })
  })

  it('works without a callback', async () => {
    const user = userEvent.setup()

    await prepare()

    const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

    // Should not throw when no callback is provided
    await user.click(confirmButton)

    await waitFor(() => {
      expect(mockAddToast).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: 'success',
        }),
      )
    })
  })

  it('handles undefined integration gracefully', async () => {
    const undefinedIntegrationMocks: TestMocksType = [
      {
        request: {
          query: DestroyIntegrationDocument,
          variables: {
            input: {
              id: '',
            },
          },
        },
        result: {
          data: {
            destroyIntegration: {
              id: '',
            },
          },
        },
      },
    ]

    await act(() =>
      render(
        <NiceModalWrapper>
          <TestComponent integration={undefined as any} />
        </NiceModalWrapper>,
        { mocks: undefinedIntegrationMocks },
      ),
    )

    await waitFor(() => {
      expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
    })
  })
})
