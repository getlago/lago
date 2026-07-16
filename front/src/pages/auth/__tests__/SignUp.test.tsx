import { MockedProvider } from '@apollo/client/testing'
import { act, render, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { PASSWORD_HINTS_TEST_IDS } from '~/components/form/PasswordValidationHints/PasswordValidationHints'

import SignUp from '../SignUp'
import {
  SIGNUP_EMAIL_FIELD_TEST_ID,
  SIGNUP_ORGANIZATION_NAME_FIELD_TEST_ID,
  SIGNUP_PASSWORD_FIELD_TEST_ID,
  SIGNUP_SUBMIT_BUTTON_TEST_ID,
} from '../signUpTestIds'

const getByDataTest = (testId: string) => document.querySelector(`[data-test="${testId}"]`)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/ui/useShortcuts', () => ({
  useShortcuts: jest.fn(),
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
        values: { organizationName: '', email: '', password: '' },
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
        organizationName: 'signup-organization-name-field',
        email: 'signup-email-field',
        password: 'signup-password-field',
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
    SubmitButton: ({ children, dataTest }: { children: React.ReactNode; dataTest?: string }) => (
      <button type="submit" data-test={dataTest}>
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
      values: { organizationName: '', email: '', password },
    }

    return selector(state)
  })
}

const renderSignUp = async (initialEntries: string[] = ['/signup']) => {
  let result

  await act(async () => {
    result = render(
      <MockedProvider mocks={[]} addTypename={false}>
        <MemoryRouter initialEntries={initialEntries}>
          <SignUp />
        </MemoryRouter>
      </MockedProvider>,
    )
  })

  return result
}

describe('SignUp', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupMockUseStore('', true)
    mockPasswordValidation.mockReturnValue({
      isValid: false,
      errors: ['MIN', 'LOWERCASE', 'UPPERCASE', 'NUMBER', 'SPECIAL'],
    })
  })

  describe('when rendering the signup form', () => {
    it('should display the form right fields', async () => {
      await renderSignUp()

      expect(getByDataTest(SIGNUP_ORGANIZATION_NAME_FIELD_TEST_ID)).toBeInTheDocument()
      expect(getByDataTest(SIGNUP_EMAIL_FIELD_TEST_ID)).toBeInTheDocument()
      expect(getByDataTest(SIGNUP_PASSWORD_FIELD_TEST_ID)).toBeInTheDocument()
      expect(getByDataTest(SIGNUP_SUBMIT_BUTTON_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('when typing an invalid password', () => {
    it('should show the password validation checklist', async () => {
      setupMockUseStore('weak', true)
      mockPasswordValidation.mockReturnValue({
        isValid: false,
        errors: ['MIN', 'UPPERCASE', 'NUMBER', 'SPECIAL'],
      })

      await renderSignUp()

      await waitFor(() => {
        expect(getByDataTest(PASSWORD_HINTS_TEST_IDS.VISIBLE)).toBeInTheDocument()
      })
    })
  })

  describe('when typing a valid password', () => {
    it('should show the success alert', async () => {
      setupMockUseStore('ValidPass1!', true)
      mockPasswordValidation.mockReturnValue({ isValid: true, errors: [] })

      await renderSignUp()

      await waitFor(() => {
        expect(getByDataTest(PASSWORD_HINTS_TEST_IDS.SUCCESS)).toBeInTheDocument()
      })
    })
  })
})
