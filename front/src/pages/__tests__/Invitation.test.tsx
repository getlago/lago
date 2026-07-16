import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'

import { PASSWORD_HINTS_TEST_IDS } from '~/components/form/PasswordValidationHints/PasswordValidationHints'
import { GetinviteDocument } from '~/generated/graphql'

import Invitation, { INVITATION_SUBMIT_BUTTON_TEST_ID } from '../Invitation'

const getByDataTest = (testId: string) => document.querySelector(`[data-test="${testId}"]`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockIsAuthenticated = jest.fn()

jest.mock('~/hooks/auth/useIsAuthenticated', () => ({
  useIsAuthenticated: () => mockIsAuthenticated(),
}))

jest.mock('~/components/auth/GoogleAuthButton', () => ({
  __esModule: true,
  default: ({ label }: { label: string }) => (
    <button data-testid="google-auth-button">{label}</button>
  ),
}))

const mockPasswordValidation = jest.fn()

jest.mock('~/hooks/forms/usePasswordValidation', () => ({
  usePasswordValidation: (password: string) => mockPasswordValidation(password),
}))

const mockHandleSubmit = jest.fn()

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: () => ({
    store: {
      subscribe: jest.fn(() => jest.fn()),
      getState: () => ({
        values: { password: '' },
        canSubmit: true,
      }),
    },
    handleSubmit: mockHandleSubmit,
    AppField: ({
      name,
      children,
    }: {
      name: string
      children: (field: unknown) => React.ReactNode
    }) => {
      const testIdMap: Record<string, string> = {
        password: 'invitation-password-field',
      }

      const fieldProps = {
        TextInputField: ({
          label,
          password,
        }: {
          label?: string
          placeholder?: string
          password?: boolean
          showOnlyErrors?: string[]
        }) => (
          <div>
            {label && <label>{label}</label>}
            <input type={password ? 'password' : 'text'} data-test={testIdMap[name]} />
          </div>
        ),
      }

      return <>{children(fieldProps)}</>
    },
    AppForm: ({ children }: { children: React.ReactNode }) => <>{children}</>,
    SubmitButton: ({
      children,
      dataTest,
      loading,
    }: {
      children: React.ReactNode
      dataTest?: string
      loading?: boolean
    }) => (
      <button type="submit" data-test={dataTest} disabled={loading}>
        {children}
      </button>
    ),
  }),
}))

const mockUseStore = jest.fn()

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: jest.fn(() => ({})),
  useStore: (...args: unknown[]) => mockUseStore(...args),
}))

const setupMockUseStore = (password = '', canSubmit = true) => {
  mockUseStore.mockImplementation((_store, selector) => {
    const state = {
      canSubmit,
      values: { password },
    }

    return selector(state)
  })
}

const createInviteMock = (
  overrides: {
    token?: string
    email?: string
    organizationName?: string
    error?: boolean
  } = {},
): MockedResponse => {
  const {
    token = 'test-token',
    email = 'test@example.com',
    organizationName = 'Test Org',
    error = false,
  } = overrides

  if (error) {
    return {
      request: {
        query: GetinviteDocument,
        variables: { token },
      },
      error: new Error('Invite not found'),
    }
  }

  return {
    request: {
      query: GetinviteDocument,
      variables: { token },
    },
    result: {
      data: {
        invite: {
          id: 'invite-1',
          email,
          organization: {
            id: 'org-1',
            name: organizationName,
          },
        },
      },
    },
  }
}

const renderInvitation = async (
  mocks: MockedResponse[] = [createInviteMock()],
  token = 'test-token',
) => {
  let result

  await act(async () => {
    result = render(
      <MockedProvider mocks={mocks}>
        <MemoryRouter initialEntries={[`/invitation/${token}`]}>
          <Routes>
            <Route path="/invitation/:token" element={<Invitation />} />
          </Routes>
        </MemoryRouter>
      </MockedProvider>,
    )
  })

  return result
}

describe('Invitation', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupMockUseStore('', true)
    mockIsAuthenticated.mockReturnValue({ isAuthenticated: false })
    mockPasswordValidation.mockReturnValue({
      isValid: false,
      errors: ['MIN', 'LOWERCASE', 'UPPERCASE', 'NUMBER', 'SPECIAL'],
    })
  })

  describe('when invite is loaded successfully', () => {
    it('should display the organization name in the title', async () => {
      await renderInvitation([createInviteMock({ organizationName: 'Acme Corp' })])

      await waitFor(() => {
        expect(screen.getByText('text_664c90c9b2b6c2012aa50bcd')).toBeInTheDocument()
      })
    })

    it('should show Google auth button', async () => {
      await renderInvitation()

      await waitFor(() => {
        expect(screen.getByTestId('google-auth-button')).toBeInTheDocument()
      })
    })

    it('should show Okta button', async () => {
      await renderInvitation()

      await waitFor(() => {
        expect(screen.getByText('text_664c90c9b2b6c2012aa50bd5')).toBeInTheDocument()
      })
    })

    it('should have submit button', async () => {
      await renderInvitation()

      await waitFor(() => {
        const submitButton = getByDataTest(INVITATION_SUBMIT_BUTTON_TEST_ID)

        expect(submitButton).toBeInTheDocument()
        expect(submitButton?.textContent).toBe('text_63246f875e2228ab7b63dd1c')
      })
    })
  })

  describe('when invite is not found', () => {
    it('should show error state with login button', async () => {
      const errorMock = createInviteMock({ error: true })

      await renderInvitation([errorMock])

      await waitFor(() => {
        expect(screen.getByText('text_63246f875e2228ab7b63dcf4')).toBeInTheDocument()
        expect(screen.getByText('text_620bc4d4269a55014d493f6d')).toBeInTheDocument()
      })
    })
  })

  describe('password validation', () => {
    it('should show hidden validation hints when password is empty', async () => {
      setupMockUseStore('', true)
      mockPasswordValidation.mockReturnValue({
        isValid: false,
        errors: ['MIN', 'LOWERCASE', 'UPPERCASE', 'NUMBER', 'SPECIAL'],
      })

      await renderInvitation()

      await waitFor(() => {
        expect(getByDataTest(PASSWORD_HINTS_TEST_IDS.HIDDEN)).toBeInTheDocument()
      })
    })

    it('should show visible validation hints when typing invalid password', async () => {
      setupMockUseStore('weak', true)
      mockPasswordValidation.mockReturnValue({
        isValid: false,
        errors: ['MIN', 'UPPERCASE', 'NUMBER', 'SPECIAL'],
      })

      await renderInvitation()

      await waitFor(() => {
        expect(getByDataTest(PASSWORD_HINTS_TEST_IDS.VISIBLE)).toBeInTheDocument()
      })
    })

    it('should show success alert when password is valid', async () => {
      setupMockUseStore('ValidPass1!', true)
      mockPasswordValidation.mockReturnValue({ isValid: true, errors: [] })

      await renderInvitation()

      await waitFor(() => {
        expect(getByDataTest(PASSWORD_HINTS_TEST_IDS.SUCCESS)).toBeInTheDocument()
      })
    })
  })

  describe('email field', () => {
    it('should display email field as disabled', async () => {
      await renderInvitation()

      await waitFor(() => {
        const emailInput = document.querySelector('input[name="email"]')

        expect(emailInput).toBeInTheDocument()
        expect(emailInput).toBeDisabled()
      })
    })
  })

  describe('when user is authenticated', () => {
    it('should render nothing', async () => {
      mockIsAuthenticated.mockReturnValue({ isAuthenticated: true })

      const { container } = (await renderInvitation()) as unknown as { container: HTMLElement }

      expect(container).toBeEmptyDOMElement()
    })
  })
})
