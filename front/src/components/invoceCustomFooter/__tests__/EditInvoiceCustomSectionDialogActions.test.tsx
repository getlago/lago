import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  EDIT_ICS_DIALOG_CANCEL_BUTTON_TEST_ID,
  EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID,
  EditInvoiceCustomSectionDialogActions,
} from '../EditInvoiceCustomSectionDialogActions'

const mockTranslate = (key: string) => key
const mockCloseDialog = jest.fn()
const mockOnSave = jest.fn()

describe('WHEN EditInvoiceCustomSectionDialogActions is rendered', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('THEN calls onSave when save button is clicked and save is enabled', async () => {
    const user = userEvent.setup()

    render(
      <EditInvoiceCustomSectionDialogActions
        closeDialog={mockCloseDialog}
        onSave={mockOnSave}
        isSaveDisabled={false}
        translate={mockTranslate}
      />,
    )

    const saveButton = screen.getByTestId(EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID)

    expect(saveButton).not.toBeDisabled()

    await user.click(saveButton)

    expect(mockOnSave).toHaveBeenCalledTimes(1)
    expect(mockCloseDialog).not.toHaveBeenCalled()
  })

  it('THEN disables save button when isSaveDisabled is true and calls closeDialog when cancel is clicked', async () => {
    const user = userEvent.setup()

    render(
      <EditInvoiceCustomSectionDialogActions
        closeDialog={mockCloseDialog}
        onSave={mockOnSave}
        isSaveDisabled={true}
        translate={mockTranslate}
      />,
    )

    const saveButton = screen.getByTestId(EDIT_ICS_DIALOG_SAVE_BUTTON_TEST_ID)
    const cancelButton = screen.getByTestId(EDIT_ICS_DIALOG_CANCEL_BUTTON_TEST_ID)

    expect(saveButton).toBeDisabled()

    await user.click(cancelButton)

    expect(mockCloseDialog).toHaveBeenCalledTimes(1)
    expect(mockOnSave).not.toHaveBeenCalled()
  })
})
