import NiceModal from '@ebay/nice-modal-react'
import { cleanup, fireEvent, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME, FORM_DIALOG_TEST_ID } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { render } from '~/test-utils'

import { PURCHASE_ORDER_NUMBER_MAX_LENGTH } from '../constants'
import {
  PURCHASE_ORDER_DIALOG_SUBMIT_BUTTON_TEST_ID,
  usePurchaseOrderNumberDialogs,
} from '../usePurchaseOrderNumberDialogs'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

const OPEN_BUTTON_TEST_ID = 'open-purchase-order-dialog'

type HarnessProps = {
  value?: string | null
  description?: ReactNode
  onChange?: (value: string | null) => void | Promise<void>
}

const Harness = ({ value, description, onChange }: HarnessProps) => {
  const { openEditDialog } = usePurchaseOrderNumberDialogs({ value, description, onChange })

  return (
    <button data-test={OPEN_BUTTON_TEST_ID} onClick={openEditDialog}>
      open
    </button>
  )
}

const renderHarness = (props: HarnessProps) =>
  render(
    <NiceModal.Provider>
      <Harness {...props} />
    </NiceModal.Provider>,
  )

const getPurchaseOrderInput = () =>
  document.querySelector('input[name="purchaseOrderNumber"]') as HTMLInputElement

describe('usePurchaseOrderNumberDialogs', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the dialog is opened', () => {
    describe('WHEN openEditDialog is called', () => {
      it('THEN should render the form dialog with the purchase order input', async () => {
        const user = userEvent.setup()

        renderHarness({ value: null })

        await user.click(screen.getByTestId(OPEN_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
        })

        expect(getPurchaseOrderInput()).toBeInTheDocument()
      })

      it('THEN should prefill the input with the current value', async () => {
        const user = userEvent.setup()

        renderHarness({ value: 'PO-INITIAL' })

        await user.click(screen.getByTestId(OPEN_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(getPurchaseOrderInput()).toHaveValue('PO-INITIAL')
        })
      })

      it('THEN should display a custom description when provided', async () => {
        const user = userEvent.setup()

        renderHarness({ value: null, description: 'My custom PO description' })

        await user.click(screen.getByTestId(OPEN_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(screen.getByText('My custom PO description')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN the dialog is submitted', () => {
    describe('WHEN a valid value is entered', () => {
      it('THEN should call onChange with the trimmed value and close the dialog', async () => {
        const onChange = jest.fn()
        const user = userEvent.setup()

        renderHarness({ value: null, onChange })

        await user.click(screen.getByTestId(OPEN_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(getPurchaseOrderInput()).toBeInTheDocument()
        })

        fireEvent.change(getPurchaseOrderInput(), { target: { value: '  PO-NEW  ' } })
        await user.click(screen.getByTestId(PURCHASE_ORDER_DIALOG_SUBMIT_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(onChange).toHaveBeenCalledWith('PO-NEW')
        })

        await waitFor(() => {
          expect(screen.queryByTestId(FORM_DIALOG_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })

    describe('WHEN the value is cleared', () => {
      it('THEN should call onChange with null', async () => {
        const onChange = jest.fn()
        const user = userEvent.setup()

        renderHarness({ value: 'PO-INITIAL', onChange })

        await user.click(screen.getByTestId(OPEN_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(getPurchaseOrderInput()).toHaveValue('PO-INITIAL')
        })

        fireEvent.change(getPurchaseOrderInput(), { target: { value: '' } })
        await user.click(screen.getByTestId(PURCHASE_ORDER_DIALOG_SUBMIT_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(onChange).toHaveBeenCalledWith(null)
        })
      })
    })

    describe('WHEN the value exceeds the max length', () => {
      it('THEN should show a validation error and not call onChange', async () => {
        const onChange = jest.fn()
        const user = userEvent.setup()

        renderHarness({ value: null, onChange })

        await user.click(screen.getByTestId(OPEN_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(getPurchaseOrderInput()).toBeInTheDocument()
        })

        fireEvent.change(getPurchaseOrderInput(), {
          target: { value: 'a'.repeat(PURCHASE_ORDER_NUMBER_MAX_LENGTH + 1) },
        })
        await user.click(screen.getByTestId(PURCHASE_ORDER_DIALOG_SUBMIT_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(screen.getByTestId('text-field-error')).toBeInTheDocument()
        })

        expect(onChange).not.toHaveBeenCalled()
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
