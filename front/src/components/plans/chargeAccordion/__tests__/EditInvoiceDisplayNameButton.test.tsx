import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { EditInvoiceDisplayNameButton } from '../EditInvoiceDisplayNameButton'

const mockOpenEditInvoiceDisplayNameDialog = jest.fn()

jest.mock('~/components/invoices/useEditInvoiceDisplayName', () => ({
  useEditInvoiceDisplayNameDialog: () => ({
    openEditInvoiceDisplayNameDialog: mockOpenEditInvoiceDisplayNameDialog,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

describe('EditInvoiceDisplayNameButton', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the button is rendered', () => {
    describe('WHEN the component mounts', () => {
      it('THEN should render a button', () => {
        render(
          <EditInvoiceDisplayNameButton
            currentInvoiceDisplayName="My invoice"
            onEdit={jest.fn()}
          />,
        )

        expect(screen.getByRole('button')).toBeInTheDocument()
      })
    })

    describe('WHEN the button is clicked', () => {
      it('THEN should open the dialog with the current display name and the onEdit callback', async () => {
        const user = userEvent.setup()
        const onEdit = jest.fn()

        render(
          <EditInvoiceDisplayNameButton currentInvoiceDisplayName="My invoice" onEdit={onEdit} />,
        )

        await user.click(screen.getByRole('button'))

        expect(mockOpenEditInvoiceDisplayNameDialog).toHaveBeenCalledWith({
          invoiceDisplayName: 'My invoice',
          callback: onEdit,
        })
      })
    })
  })
})
