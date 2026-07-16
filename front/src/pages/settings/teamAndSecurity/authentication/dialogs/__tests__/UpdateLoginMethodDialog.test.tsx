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
import {
  AuthenticationMethodsEnum,
  UpdateOrganizationAuthenticationMethodsDocument,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import { useUpdateLoginMethodDialog } from '../UpdateLoginMethodDialog'

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

const mockRefetch = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: {
      authenticationMethods: ['email_password'],
    },
    refetchOrganizationInfos: mockRefetch,
  }),
}))

const mockAddToast = addToast as jest.Mock

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const TestComponent = ({
  method,
  type,
}: {
  method: AuthenticationMethodsEnum
  type: 'enable' | 'disable'
}) => {
  const { openUpdateLoginMethodDialog } = useUpdateLoginMethodDialog()

  useEffect(() => {
    openUpdateLoginMethodDialog({ method, type })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return null
}

describe('UpdateLoginMethodDialog', () => {
  beforeAll(async () => {
    await initializeTranslations()
  })

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(cleanup)

  describe('Enable method', () => {
    const enableMocks: TestMocksType = [
      {
        request: {
          query: UpdateOrganizationAuthenticationMethodsDocument,
          variables: {
            input: {
              authenticationMethods: [
                AuthenticationMethodsEnum.EmailPassword,
                AuthenticationMethodsEnum.GoogleOauth,
              ],
            },
          },
        },
        result: {
          data: {
            updateOrganization: {
              id: 'org-123',
              authenticationMethods: [
                AuthenticationMethodsEnum.EmailPassword,
                AuthenticationMethodsEnum.GoogleOauth,
              ],
            },
          },
        },
      },
    ]

    it('opens a centralized dialog for enabling', async () => {
      await act(() =>
        render(
          <NiceModalWrapper>
            <TestComponent method={AuthenticationMethodsEnum.GoogleOauth} type="enable" />
          </NiceModalWrapper>,
          { mocks: enableMocks },
        ),
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('calls mutation and shows success toast on enable', async () => {
      const user = userEvent.setup()

      await act(() =>
        render(
          <NiceModalWrapper>
            <TestComponent method={AuthenticationMethodsEnum.GoogleOauth} type="enable" />
          </NiceModalWrapper>,
          { mocks: enableMocks },
        ),
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'success',
          }),
        )
      })

      await waitFor(() => {
        expect(mockRefetch).toHaveBeenCalled()
      })
    })
  })

  describe('Disable method', () => {
    const disableMocks: TestMocksType = [
      {
        request: {
          query: UpdateOrganizationAuthenticationMethodsDocument,
          variables: {
            input: {
              authenticationMethods: [],
            },
          },
        },
        result: {
          data: {
            updateOrganization: {
              id: 'org-123',
              authenticationMethods: [],
            },
          },
        },
      },
    ]

    it('opens a centralized dialog for disabling', async () => {
      await act(() =>
        render(
          <NiceModalWrapper>
            <TestComponent method={AuthenticationMethodsEnum.EmailPassword} type="disable" />
          </NiceModalWrapper>,
          { mocks: disableMocks },
        ),
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
      })
    })

    it('calls mutation and shows success toast on disable', async () => {
      const user = userEvent.setup()

      await act(() =>
        render(
          <NiceModalWrapper>
            <TestComponent method={AuthenticationMethodsEnum.EmailPassword} type="disable" />
          </NiceModalWrapper>,
          { mocks: disableMocks },
        ),
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith(
          expect.objectContaining({
            severity: 'success',
          }),
        )
      })

      await waitFor(() => {
        expect(mockRefetch).toHaveBeenCalled()
      })
    })
  })

  describe('Mutation failure', () => {
    const failMocks: TestMocksType = [
      {
        request: {
          query: UpdateOrganizationAuthenticationMethodsDocument,
          variables: {
            input: {
              authenticationMethods: [
                AuthenticationMethodsEnum.EmailPassword,
                AuthenticationMethodsEnum.GoogleOauth,
              ],
            },
          },
        },
        result: {
          data: {
            updateOrganization: null,
          },
        },
      },
    ]

    it('does not show toast or refetch when mutation returns null', async () => {
      const user = userEvent.setup()

      await act(() =>
        render(
          <NiceModalWrapper>
            <TestComponent method={AuthenticationMethodsEnum.GoogleOauth} type="enable" />
          </NiceModalWrapper>,
          { mocks: failMocks },
        ),
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      // Wait for mutation to complete, then verify no toast
      await waitFor(() => {
        expect(mockAddToast).not.toHaveBeenCalled()
      })

      expect(mockRefetch).not.toHaveBeenCalled()
    })
  })
})
