import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useCreateEditTax } from '~/hooks/useCreateEditTax'
import { render } from '~/test-utils'

import CreateTaxRate, {
  CREATE_TAX_CLOSE_BUTTON_TEST_ID,
  CREATE_TAX_DESCRIPTION_DELETE_TEST_ID,
  CREATE_TAX_FORM_ID,
} from '../CreateTax'

const getNameInput = () => document.querySelector('input[name="name"]') as HTMLInputElement
const getCodeInput = () => document.querySelector('input[name="code"]') as HTMLInputElement
const getRateInput = () => document.querySelector('input[name="rate"]') as HTMLInputElement
const getDescriptionTextarea = () =>
  document.querySelector('textarea[name="description"]') as HTMLTextAreaElement

const mockOnSave = jest.fn()
const mockOnClose = jest.fn()

const mockDefaultUseCreateEditTax = {
  isEdition: false,
  loading: false,
  tax: undefined,
  errorCode: undefined,
  onSave: mockOnSave,
  onClose: mockOnClose,
}

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useCreateEditTax', () => ({
  useCreateEditTax: jest.fn(() => mockDefaultUseCreateEditTax),
}))

jest.mock('~/components/taxes/TaxCodeSnippet', () => ({
  TaxCodeSnippet: jest.fn(() => <div data-test="tax-code-snippet" />),
}))

jest.mock('~/components/designSystem/WarningDialog', () => ({
  WarningDialog: jest.fn(() => null),
  WarningDialogRef: {},
}))

jest.mock('~/core/utils/domUtils', () => ({
  scrollToTop: jest.fn(),
}))

const mockedUseCreateEditTax = useCreateEditTax as jest.Mock

describe('CreateTaxRate', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockedUseCreateEditTax.mockReturnValue(mockDefaultUseCreateEditTax)
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the form is loading', () => {
    describe('WHEN tax data has not loaded', () => {
      it('THEN should not display form inputs', () => {
        mockedUseCreateEditTax.mockReturnValue({
          ...mockDefaultUseCreateEditTax,
          loading: true,
        })

        render(<CreateTaxRate />)

        expect(getNameInput()).not.toBeInTheDocument()
        expect(getCodeInput()).not.toBeInTheDocument()
        expect(getRateInput()).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the component renders in create mode', () => {
    describe('WHEN the page loads', () => {
      it('THEN should display the form element', () => {
        render(<CreateTaxRate />)

        expect(document.getElementById(CREATE_TAX_FORM_ID)).toBeInTheDocument()
      })

      it('THEN should display the tax code snippet', () => {
        render(<CreateTaxRate />)

        expect(screen.getByTestId('tax-code-snippet')).toBeInTheDocument()
      })

      it.each([
        ['name input', getNameInput],
        ['code input', getCodeInput],
        ['rate input', getRateInput],
      ])('THEN should display the %s', (_, getInput) => {
        render(<CreateTaxRate />)

        expect(getInput()).toBeInTheDocument()
      })

      it('THEN should display the submit button', () => {
        render(<CreateTaxRate />)

        expect(screen.getByTestId('submit')).toBeInTheDocument()
      })

      it('THEN should not display the description textarea by default', () => {
        render(<CreateTaxRate />)

        expect(getDescriptionTextarea()).not.toBeInTheDocument()
      })
    })

    describe('WHEN close button is clicked and form is not dirty', () => {
      it('THEN should call onClose directly', async () => {
        const user = userEvent.setup()

        render(<CreateTaxRate />)

        await user.click(screen.getByTestId(CREATE_TAX_CLOSE_BUTTON_TEST_ID))

        expect(mockOnClose).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN show description button is clicked', () => {
      it('THEN should display the description textarea', async () => {
        const user = userEvent.setup()

        render(<CreateTaxRate />)

        await user.click(screen.getByTestId('show-description'))

        expect(getDescriptionTextarea()).toBeInTheDocument()
      })
    })

    describe('WHEN description is displayed and delete button is clicked', () => {
      it('THEN should hide the description textarea', async () => {
        const user = userEvent.setup()

        render(<CreateTaxRate />)

        await user.click(screen.getByTestId('show-description'))
        expect(getDescriptionTextarea()).toBeInTheDocument()

        await user.click(screen.getByTestId(CREATE_TAX_DESCRIPTION_DELETE_TEST_ID))

        expect(getDescriptionTextarea()).not.toBeInTheDocument()
      })
    })

    describe('WHEN form is filled with valid values and submitted', () => {
      it('THEN should call onSave with the form values', async () => {
        const user = userEvent.setup()

        render(<CreateTaxRate />)

        await user.type(getNameInput(), 'My Tax')
        await user.type(getRateInput(), '15')

        await user.click(screen.getByTestId('submit'))

        await waitFor(() => {
          expect(mockOnSave).toHaveBeenCalledWith(
            expect.objectContaining({
              name: 'My Tax',
              rate: '15',
            }),
          )
        })
      })
    })

    describe('WHEN Enter key is pressed while an input is focused', () => {
      it('THEN should submit the form and call onSave', async () => {
        const user = userEvent.setup()

        render(<CreateTaxRate />)

        await user.type(getNameInput(), 'Enter Tax')
        await user.type(getRateInput(), '20')

        getNameInput().focus()
        await user.keyboard('{Enter}')

        await waitFor(() => {
          expect(mockOnSave).toHaveBeenCalledWith(
            expect.objectContaining({
              name: 'Enter Tax',
              rate: '20',
            }),
          )
        })
      })
    })

    describe('WHEN form is submitted with an invalid rate', () => {
      it('THEN should show a validation error and not call onSave', async () => {
        const user = userEvent.setup()

        render(<CreateTaxRate />)

        await user.type(getNameInput(), 'Tax Name')
        await user.type(getRateInput(), '101')

        await user.click(screen.getByTestId('submit'))

        await waitFor(() => {
          expect(screen.getByTestId('text-field-error')).toBeInTheDocument()
        })
        expect(mockOnSave).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the component renders in edit mode', () => {
    const mockTax = {
      id: 'tax-1',
      name: 'Existing Tax',
      code: 'EXISTING_TAX',
      rate: 20,
      description: '',
      customersCount: 0,
      autoGenerated: false,
    }

    beforeEach(() => {
      mockedUseCreateEditTax.mockReturnValue({
        ...mockDefaultUseCreateEditTax,
        isEdition: true,
        tax: mockTax,
      })
    })

    describe('WHEN the page loads with existing tax data', () => {
      it.each([
        ['name', getNameInput, 'Existing Tax'],
        ['code', getCodeInput, 'EXISTING_TAX'],
        ['rate', getRateInput, '20'],
      ])('THEN should populate the %s input with tax value', (_, getInput, expectedValue) => {
        render(<CreateTaxRate />)

        expect(getInput()).toHaveValue(expectedValue)
      })

      it('THEN should disable the submit button when form is not dirty', () => {
        render(<CreateTaxRate />)

        expect(screen.getByTestId('submit')).toBeDisabled()
      })
    })

    describe('WHEN tax is autoGenerated', () => {
      it('THEN should disable the rate input', () => {
        mockedUseCreateEditTax.mockReturnValue({
          ...mockDefaultUseCreateEditTax,
          isEdition: true,
          tax: { ...mockTax, autoGenerated: true },
        })

        render(<CreateTaxRate />)

        expect(getRateInput()).toBeDisabled()
      })
    })

    describe('WHEN tax has an existing description', () => {
      it('THEN should display the description textarea on load', () => {
        mockedUseCreateEditTax.mockReturnValue({
          ...mockDefaultUseCreateEditTax,
          isEdition: true,
          tax: { ...mockTax, description: 'Existing description' },
        })

        render(<CreateTaxRate />)

        expect(getDescriptionTextarea()).toBeInTheDocument()
      })
    })
  })
})
