import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { DIALOG_TITLE_TEST_ID } from '~/components/designSystem/Dialog'
import { CountryCode, LagoApiError } from '~/generated/graphql'
import { render } from '~/test-utils'

import {
  ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID,
  AddLagoTaxManagementDialog,
  AddLagoTaxManagementDialogRef,
} from '../AddLagoTaxManagementDialog'

const mockNavigate = jest.fn()
const mockAddToast = jest.fn()
const mockUpdate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: jest.fn(() => mockNavigate),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useIntegrations', () => ({
  useIntegrations: () => ({
    hasTaxProvider: false,
    loading: false,
  }),
}))

const mockBillingEntitiesCollection = [
  {
    id: 'be-1',
    code: 'billing-entity-1',
    name: 'EU Billing Entity',
    country: CountryCode.Fr,
    euTaxManagement: true,
  },
  {
    id: 'be-2',
    code: 'billing-entity-2',
    name: 'UK Billing Entity',
    country: CountryCode.Gb,
    euTaxManagement: false,
  },
]

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetBillingEntitiesQuery: jest.fn(() => ({
    data: {
      billingEntities: {
        collection: mockBillingEntitiesCollection,
      },
    },
    loading: false,
  })),
  useUpdateBillingEntityMutation: jest.fn(() => [mockUpdate]),
}))

describe('AddLagoTaxManagementDialog', () => {
  const dialogRef = {
    current: null,
  } as React.MutableRefObject<AddLagoTaxManagementDialogRef | null>

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(cleanup)

  const renderAndOpenDialog = async (isUpdate = true) => {
    await act(async () => {
      render(<AddLagoTaxManagementDialog ref={dialogRef} isUpdate={isUpdate} />)
    })

    await act(async () => {
      dialogRef.current?.openDialog()
    })
  }

  describe('GIVEN the mutation is configured', () => {
    describe('WHEN useUpdateBillingEntityMutation is called', () => {
      it('THEN should pass silentErrorCodes with UnprocessableEntity', async () => {
        const { useUpdateBillingEntityMutation } = jest.requireMock('~/generated/graphql')

        await renderAndOpenDialog()

        expect(useUpdateBillingEntityMutation).toHaveBeenCalledWith(
          expect.objectContaining({
            context: {
              silentErrorCodes: [LagoApiError.UnprocessableEntity],
            },
          }),
        )
      })
    })
  })

  describe('GIVEN the form is submitted and a non-EU eligibility error is returned', () => {
    const nonEuError = {
      errors: [
        {
          message: 'Unprocessable entity',
          extensions: {
            code: 'unprocessable_entity',
            details: { euTaxManagement: ['billing_entity_must_be_in_eu'] },
          },
        },
      ],
    }

    describe('WHEN the submit button is clicked', () => {
      it('THEN should show a danger toast with the EU-specific message', async () => {
        mockUpdate.mockResolvedValue(nonEuError)

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(
            expect.objectContaining({
              severity: 'danger',
              message: 'text_1740672955723utwsgy8vzy2',
            }),
          )
        })
      })

      it('THEN should NOT navigate away', async () => {
        mockUpdate.mockResolvedValue(nonEuError)

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalled()
        })

        expect(mockNavigate).not.toHaveBeenCalled()
      })

      it('THEN should keep the dialog open', async () => {
        mockUpdate.mockResolvedValue(nonEuError)

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalled()
        })

        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the form is submitted and a generic error is returned', () => {
    const genericError = {
      errors: [
        {
          message: 'Internal server error',
          extensions: { code: 'internal_error' },
        },
      ],
    }

    describe('WHEN the submit button is clicked', () => {
      it('THEN should NOT show the EU-specific danger toast', async () => {
        mockUpdate.mockResolvedValue(genericError)

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockUpdate).toHaveBeenCalled()
        })

        expect(mockAddToast).not.toHaveBeenCalled()
      })

      it('THEN should NOT navigate away', async () => {
        mockUpdate.mockResolvedValue(genericError)

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockUpdate).toHaveBeenCalled()
        })

        expect(mockNavigate).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the form is submitted and mutations succeed', () => {
    describe('WHEN the submit button is clicked', () => {
      it('THEN should navigate to the tax management integration route', async () => {
        mockUpdate.mockResolvedValue({
          data: { updateBillingEntity: { id: 'be-1' } },
        })

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalled()
        })
      })

      it('THEN should show a success toast', async () => {
        mockUpdate.mockResolvedValue({
          data: { updateBillingEntity: { id: 'be-1' } },
        })

        const user = userEvent.setup()

        await renderAndOpenDialog()

        const submitButton = screen.getByTestId(ADD_LAGO_TAX_MANAGEMENT_SUBMIT_BUTTON_TEST_ID)

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(
            expect.objectContaining({
              severity: 'success',
            }),
          )
        })
      })
    })
  })
})
