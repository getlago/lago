import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import {
  EditCustomerInvoiceGracePeriodDialog,
  EditCustomerInvoiceGracePeriodDialogRef,
} from '~/components/customers/EditCustomerInvoiceGracePeriodDialog'
import { DialogRef } from '~/components/designSystem/Dialog'
import { UpdateCustomerInvoiceGracePeriodDocument } from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

const CUSTOMER_ID = 'customer-123'

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({ customerId: CUSTOMER_ID }),
}))

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (params: unknown) => mockAddToast(params),
}))

async function prepare({
  invoiceGracePeriod = 5,
  mocks = [],
}: {
  invoiceGracePeriod?: number | null
  mocks?: TestMocksType
} = {}) {
  const ref = createRef<EditCustomerInvoiceGracePeriodDialogRef>()

  await act(() =>
    render(
      <EditCustomerInvoiceGracePeriodDialog ref={ref} invoiceGracePeriod={invoiceGracePeriod} />,
      {
        mocks,
      },
    ),
  )

  // Open the dialog
  await act(() => {
    ref.current?.openDialog()
  })

  return { ref }
}

describe('EditCustomerInvoiceGracePeriodDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the dialog is opened', () => {
    describe('WHEN rendered with default props', () => {
      it('THEN should display the dialog title and description', async () => {
        await prepare()

        expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
        expect(screen.getByTestId('dialog-description')).toBeInTheDocument()
      })

      it('THEN should render cancel and submit buttons', async () => {
        await prepare()

        const buttons = screen.getAllByRole('button')

        expect(buttons).toHaveLength(2)
      })
    })

    describe('WHEN invoiceGracePeriod has a value', () => {
      it('THEN should display the grace period value in the input', async () => {
        await prepare({ invoiceGracePeriod: 10 })

        const input = screen.getByRole('textbox')

        expect(input).toHaveValue('10')
      })
    })

    describe('WHEN invoiceGracePeriod is null', () => {
      it('THEN should display an empty input (placeholder shown)', async () => {
        await prepare({ invoiceGracePeriod: null })

        const input = screen.getByRole('textbox')

        expect(input).toHaveValue('')
      })
    })

    describe('WHEN invoiceGracePeriod is undefined', () => {
      it('THEN should display an empty input (placeholder shown)', async () => {
        const ref = createRef<EditCustomerInvoiceGracePeriodDialogRef>()

        await act(() =>
          render(<EditCustomerInvoiceGracePeriodDialog ref={ref} invoiceGracePeriod={undefined} />),
        )

        await act(() => {
          ref.current?.openDialog()
        })

        const input = screen.getByRole('textbox')

        expect(input).toHaveValue('')
      })
    })
  })

  describe('GIVEN the form validation', () => {
    describe('WHEN the form is pristine', () => {
      it('THEN should disable the submit button', async () => {
        await prepare()

        const buttons = screen.getAllByRole('button')
        const submitButton = buttons[1]

        expect(submitButton).toBeDisabled()
      })
    })

    describe('WHEN the user changes the value to a valid number', () => {
      it('THEN should enable the submit button', async () => {
        const user = userEvent.setup()

        await prepare({ invoiceGracePeriod: 5 })

        const input = screen.getByRole('textbox')

        await user.clear(input)
        await user.type(input, '10')

        const buttons = screen.getAllByRole('button')
        const submitButton = buttons[1]

        await waitFor(() => {
          expect(submitButton).not.toBeDisabled()
        })
      })
    })

    describe('WHEN the grace period exceeds 365 days', () => {
      it('THEN should keep the submit button disabled', async () => {
        const user = userEvent.setup()

        await prepare({ invoiceGracePeriod: 5 })

        const input = screen.getByRole('textbox')

        await user.clear(input)
        await user.type(input, '400')

        // Trigger validation by clicking submit
        const buttons = screen.getAllByRole('button')
        const submitButton = buttons[1]

        await user.click(submitButton)

        await waitFor(() => {
          expect(submitButton).toBeDisabled()
        })
      })
    })

    describe('WHEN the field is cleared (empty)', () => {
      it('THEN should disable the submit button due to required validation', async () => {
        const user = userEvent.setup()

        await prepare({ invoiceGracePeriod: 5 })

        const input = screen.getByRole('textbox')

        await user.clear(input)

        // Trigger validation by clicking submit
        const buttons = screen.getAllByRole('button')
        const submitButton = buttons[1]

        await user.click(submitButton)

        await waitFor(() => {
          expect(submitButton).toBeDisabled()
        })
      })
    })
  })

  describe('GIVEN the form submission', () => {
    describe('WHEN the user submits a valid grace period', () => {
      it('THEN should call the mutation with correct variables and show success toast', async () => {
        const user = userEvent.setup()
        const mutationMock = {
          request: {
            query: UpdateCustomerInvoiceGracePeriodDocument,
            variables: {
              input: {
                id: CUSTOMER_ID,
                invoiceGracePeriod: 15,
              },
            },
          },
          result: {
            data: {
              updateCustomerInvoiceGracePeriod: {
                id: CUSTOMER_ID,
                invoiceGracePeriod: 15,
              },
            },
          },
        }

        await prepare({ invoiceGracePeriod: 5, mocks: [mutationMock] })

        const input = screen.getByRole('textbox')

        await user.clear(input)
        await user.type(input, '15')

        const buttons = screen.getAllByRole('button')
        const submitButton = buttons[1]

        await user.click(submitButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(
            expect.objectContaining({ severity: 'success' }),
          )
        })
      })
    })
  })

  describe('GIVEN the dialog actions', () => {
    describe('WHEN the cancel button is clicked', () => {
      it('THEN should close the dialog', async () => {
        const user = userEvent.setup()

        await prepare()

        expect(screen.getByTestId('dialog-title')).toBeInTheDocument()

        const buttons = screen.getAllByRole('button')
        const cancelButton = buttons[0]

        await user.click(cancelButton)

        await waitFor(() => {
          expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
        })
      })
    })

    describe('WHEN the dialog is closed and reopened', () => {
      it('THEN should reset the form to its initial value', async () => {
        const user = userEvent.setup()
        const ref = createRef<DialogRef>()

        await act(() =>
          render(<EditCustomerInvoiceGracePeriodDialog ref={ref} invoiceGracePeriod={5} />),
        )

        // Open dialog
        await act(() => {
          ref.current?.openDialog()
        })

        const input = screen.getByRole('textbox')

        // Change value
        await user.clear(input)
        await user.type(input, '20')
        expect(input).toHaveValue('20')

        // Close dialog
        const buttons = screen.getAllByRole('button')
        const cancelButton = buttons[0]

        await user.click(cancelButton)

        // Reopen dialog
        await act(() => {
          ref.current?.openDialog()
        })

        // Value should be reset to initial
        await waitFor(() => {
          expect(screen.getByRole('textbox')).toHaveValue('5')
        })
      })
    })
  })

  describe('GIVEN the dialog ref API', () => {
    describe('WHEN openDialog is called', () => {
      it('THEN should show the dialog', async () => {
        const ref = createRef<DialogRef>()

        await act(() =>
          render(<EditCustomerInvoiceGracePeriodDialog ref={ref} invoiceGracePeriod={5} />),
        )

        expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()

        await act(() => {
          ref.current?.openDialog()
        })

        await waitFor(() => {
          expect(screen.getByTestId('dialog-title')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN closeDialog is called', () => {
      it('THEN should hide the dialog', async () => {
        const ref = createRef<DialogRef>()

        await act(() =>
          render(<EditCustomerInvoiceGracePeriodDialog ref={ref} invoiceGracePeriod={5} />),
        )

        await act(() => {
          ref.current?.openDialog()
        })

        expect(screen.getByTestId('dialog-title')).toBeInTheDocument()

        await act(() => {
          ref.current?.closeDialog()
        })

        await waitFor(() => {
          expect(screen.queryByTestId('dialog-title')).not.toBeInTheDocument()
        })
      })
    })
  })
})
