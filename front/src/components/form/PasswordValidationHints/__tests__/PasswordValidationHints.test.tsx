import { act, cleanup, screen } from '@testing-library/react'

import { PASSWORD_VALIDATION_ERRORS } from '~/formValidation/zodCustoms'
import { render } from '~/test-utils'

import {
  PASSWORD_HINTS_TEST_IDS,
  PASSWORD_VALIDATION_KEYS,
  PasswordValidationHints,
} from '../PasswordValidationHints'

type PrepareOptions = {
  password: string
  errors: string[]
  isValid: boolean
  successMessage?: string
  className?: string
}

async function prepare(options: PrepareOptions) {
  await act(() =>
    render(
      <PasswordValidationHints
        password={options.password}
        errors={options.errors}
        isValid={options.isValid}
        successMessage={options.successMessage}
        className={options.className}
      />,
    ),
  )
}

describe('PasswordValidationHints', () => {
  afterEach(cleanup)

  describe('when password is valid', () => {
    it('renders success alert', async () => {
      await prepare({
        password: 'Password1!',
        errors: [],
        isValid: true,
      })

      expect(screen.getByTestId(PASSWORD_HINTS_TEST_IDS.SUCCESS)).toBeInTheDocument()
    })

    it('renders custom success message translation key', async () => {
      await prepare({
        password: 'Password1!',
        errors: [],
        isValid: true,
        successMessage: 'custom_success_key',
      })

      expect(screen.getByTestId(PASSWORD_HINTS_TEST_IDS.SUCCESS)).toBeInTheDocument()
    })
  })

  describe('when password is empty', () => {
    it('renders hidden validation hints', async () => {
      await prepare({
        password: '',
        errors: Object.values(PASSWORD_VALIDATION_ERRORS),
        isValid: false,
      })

      expect(screen.getByTestId(PASSWORD_HINTS_TEST_IDS.HIDDEN)).toBeInTheDocument()
    })
  })

  describe('when password has validation errors', () => {
    it('renders visible validation hints when password is not empty', async () => {
      await prepare({
        password: 'test',
        errors: [
          PASSWORD_VALIDATION_ERRORS.MIN,
          PASSWORD_VALIDATION_ERRORS.UPPERCASE,
          PASSWORD_VALIDATION_ERRORS.NUMBER,
          PASSWORD_VALIDATION_ERRORS.SPECIAL,
        ],
        isValid: false,
      })

      expect(screen.getByTestId(PASSWORD_HINTS_TEST_IDS.VISIBLE)).toBeInTheDocument()
    })

    it('marks errored validation rules with test ids', async () => {
      await prepare({
        password: 'password',
        errors: [
          PASSWORD_VALIDATION_ERRORS.UPPERCASE,
          PASSWORD_VALIDATION_ERRORS.NUMBER,
          PASSWORD_VALIDATION_ERRORS.SPECIAL,
        ],
        isValid: false,
      })

      expect(screen.getByTestId('UPPERCASE')).toBeInTheDocument()
      expect(screen.getByTestId('NUMBER')).toBeInTheDocument()
      expect(screen.getByTestId('SPECIAL')).toBeInTheDocument()
    })

    it('renders all validation keys', async () => {
      await prepare({
        password: 'test',
        errors: Object.values(PASSWORD_VALIDATION_ERRORS),
        isValid: false,
      })

      // Each validation key should render as a hint
      expect(PASSWORD_VALIDATION_KEYS).toHaveLength(5)
    })
  })

  describe('with className prop', () => {
    it('applies className when valid', async () => {
      await prepare({
        password: 'Password1!',
        errors: [],
        isValid: true,
        className: 'custom-class',
      })

      const alert = screen.getByTestId(PASSWORD_HINTS_TEST_IDS.SUCCESS)

      expect(alert).toHaveClass('custom-class')
    })

    it('applies className when invalid', async () => {
      await prepare({
        password: 'test',
        errors: [PASSWORD_VALIDATION_ERRORS.MIN],
        isValid: false,
        className: 'custom-class',
      })

      const hints = screen.getByTestId(PASSWORD_HINTS_TEST_IDS.VISIBLE)

      expect(hints).toHaveClass('custom-class')
    })
  })
})
