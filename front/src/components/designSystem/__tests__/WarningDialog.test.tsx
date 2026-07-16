import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { DIALOG_DESCRIPTION_TEST_ID, DIALOG_TITLE_TEST_ID } from '~/components/designSystem/Dialog'
import {
  WARNING_DIALOG_CANCEL_BUTTON_TEST_ID,
  WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID,
  WARNING_DIALOG_TEST_ID,
  WarningDialog,
  WarningDialogMode,
  WarningDialogRef,
} from '~/components/designSystem/WarningDialog'
import { render } from '~/test-utils'

describe('WarningDialog', () => {
  afterEach(cleanup)

  describe('Basic Functionality', () => {
    it('renders with title and description', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Warning Title"
            description="Warning Description"
            continueText="Continue"
          />,
        ),
      )

      expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toHaveTextContent('Warning Title')
      expect(screen.getByTestId(DIALOG_DESCRIPTION_TEST_ID)).toHaveTextContent(
        'Warning Description',
      )
    })

    it('renders with custom continue text', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="Custom Continue"
          />,
        ),
      )

      expect(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)).toHaveTextContent(
        'Custom Continue',
      )
    })

    it('renders cancel button with translated text', async () => {
      await act(() =>
        render(
          <WarningDialog forceOpen title="Title" description="Description" continueText="OK" />,
        ),
      )

      const cancelButton = screen.getByTestId(WARNING_DIALOG_CANCEL_BUTTON_TEST_ID)

      expect(cancelButton).toBeInTheDocument()
      // The cancel button should have translated text
      expect(cancelButton).toHaveTextContent(/cancel/i)
    })

    it('does not render when forceOpen is false', () => {
      render(
        <WarningDialog
          forceOpen={false}
          title="Title"
          description="Description"
          continueText="OK"
        />,
      )

      expect(screen.queryByTestId(WARNING_DIALOG_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders ReactNode as title and description', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title={<div data-test="custom-title">Custom Title</div>}
            description={<div data-test="custom-description">Custom Description</div>}
            continueText="Continue"
          />,
        ),
      )

      expect(screen.getByTestId('custom-title')).toBeInTheDocument()
      expect(screen.getByTestId('custom-description')).toBeInTheDocument()
    })
  })

  describe('Modes', () => {
    it('renders in danger mode by default', async () => {
      await act(() =>
        render(
          <WarningDialog forceOpen title="Title" description="Description" continueText="OK" />,
        ),
      )

      const confirmButton = screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)

      // In danger mode, button should have button-danger class
      expect(confirmButton).toHaveClass('button-danger')
    })

    it('renders in danger mode when explicitly set', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            mode={WarningDialogMode.danger}
          />,
        ),
      )

      const confirmButton = screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)

      expect(confirmButton).toHaveClass('button-danger')
    })

    it('renders in info mode when set', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            mode={WarningDialogMode.info}
          />,
        ),
      )

      const confirmButton = screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)

      // In info mode, button should not have button-danger class
      expect(confirmButton).not.toHaveClass('button-danger')
    })
  })

  describe('Callbacks', () => {
    it('triggers onContinue callback when confirm button is clicked', async () => {
      const onContinue = jest.fn()

      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            onContinue={onContinue}
          />,
        ),
      )

      expect(onContinue).not.toHaveBeenCalled()

      await userEvent.click(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID))

      expect(onContinue).toHaveBeenCalledTimes(1)
    })

    it('closes dialog after onContinue callback', async () => {
      const onContinue = jest.fn()

      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            onContinue={onContinue}
          />,
        ),
      )

      expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeVisible()

      await userEvent.click(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID))

      // Dialog should close after callback
      await waitFor(() => {
        expect(screen.queryByTestId(WARNING_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('handles async onContinue callback', async () => {
      const onContinue = jest.fn().mockResolvedValue(undefined)

      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            onContinue={onContinue}
          />,
        ),
      )

      await userEvent.click(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(onContinue).toHaveBeenCalled()
      })
    })

    it('does not throw when onContinue is not provided', async () => {
      await act(() =>
        render(
          <WarningDialog forceOpen title="Title" description="Description" continueText="OK" />,
        ),
      )

      await expect(async () => {
        await userEvent.click(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID))
      }).resolves.not.toThrow()
    })

    it('closes dialog when cancel button is clicked', async () => {
      await act(() =>
        render(
          <WarningDialog forceOpen title="Title" description="Description" continueText="OK" />,
        ),
      )

      expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeVisible()

      await userEvent.click(screen.getByTestId(WARNING_DIALOG_CANCEL_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.queryByTestId(WARNING_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Ref Methods', () => {
    it('exposes openDialog method via ref', async () => {
      const ref = createRef<WarningDialogRef>()

      render(
        <WarningDialog
          ref={ref}
          title="Title"
          description="Description"
          continueText="OK"
          forceOpen={false}
        />,
      )

      expect(screen.queryByTestId(WARNING_DIALOG_TEST_ID)).not.toBeInTheDocument()

      act(() => {
        ref.current?.openDialog()
      })

      await waitFor(() => {
        expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeInTheDocument()
      })
    })

    it('exposes closeDialog method via ref', async () => {
      const ref = createRef<WarningDialogRef>()

      await act(() =>
        render(
          <WarningDialog
            ref={ref}
            title="Title"
            description="Description"
            continueText="OK"
            forceOpen
          />,
        ),
      )

      expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeVisible()

      act(() => {
        ref.current?.closeDialog()
      })

      await waitFor(() => {
        expect(screen.queryByTestId(WARNING_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('calls onOpen callback when opened via ref', () => {
      const onOpen = jest.fn()
      const ref = createRef<WarningDialogRef>()

      render(
        <WarningDialog
          ref={ref}
          title="Title"
          description="Description"
          continueText="OK"
          onOpen={onOpen}
        />,
      )

      act(() => {
        ref.current?.openDialog()
      })

      expect(onOpen).toHaveBeenCalledTimes(1)
    })

    it('calls onClose callback when closed via ref', async () => {
      const onClose = jest.fn()
      const ref = createRef<WarningDialogRef>()

      await act(() =>
        render(
          <WarningDialog
            ref={ref}
            title="Title"
            description="Description"
            continueText="OK"
            onClose={onClose}
            forceOpen
          />,
        ),
      )

      act(() => {
        ref.current?.closeDialog()
      })

      expect(onClose).toHaveBeenCalledTimes(1)
    })
  })

  describe('Disable State', () => {
    it('disables confirm button when disableOnContinue is true', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            disableOnContinue
          />,
        ),
      )

      const confirmButton = screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)

      expect(confirmButton).toBeDisabled()
    })

    it('enables confirm button when disableOnContinue is false', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            disableOnContinue={false}
          />,
        ),
      )

      const confirmButton = screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)

      expect(confirmButton).not.toBeDisabled()
    })

    it('enables confirm button by default', async () => {
      await act(() =>
        render(
          <WarningDialog forceOpen title="Title" description="Description" continueText="OK" />,
        ),
      )

      const confirmButton = screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID)

      expect(confirmButton).not.toBeDisabled()
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with basic props', async () => {
      await act(() =>
        render(
          <WarningDialog forceOpen title="Title" description="Description" continueText="OK" />,
        ),
      )

      const dialog = screen.getByTestId(WARNING_DIALOG_TEST_ID)

      expect(dialog).toMatchSnapshot()
    })

    it('matches snapshot in danger mode', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="Delete"
            mode={WarningDialogMode.danger}
          />,
        ),
      )

      const dialog = screen.getByTestId(WARNING_DIALOG_TEST_ID)

      expect(dialog).toMatchSnapshot()
    })

    it('matches snapshot in info mode', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="Confirm"
            mode={WarningDialogMode.info}
          />,
        ),
      )

      const dialog = screen.getByTestId(WARNING_DIALOG_TEST_ID)

      expect(dialog).toMatchSnapshot()
    })

    it('matches snapshot with disabled confirm button', async () => {
      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            disableOnContinue
          />,
        ),
      )

      const dialog = screen.getByTestId(WARNING_DIALOG_TEST_ID)

      expect(dialog).toMatchSnapshot()
    })
  })

  describe('Complex Scenarios', () => {
    it('handles multiple open/close cycles via ref', async () => {
      const ref = createRef<WarningDialogRef>()

      render(<WarningDialog ref={ref} title="Title" description="Description" continueText="OK" />)

      // Open
      act(() => ref.current?.openDialog())
      await waitFor(() => {
        expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeVisible()
      })

      // Close
      act(() => ref.current?.closeDialog())
      await waitFor(() => {
        expect(screen.queryByTestId(WARNING_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })

      // Open again
      act(() => ref.current?.openDialog())
      await waitFor(() => {
        expect(screen.getByTestId(WARNING_DIALOG_TEST_ID)).toBeVisible()
      })
    })

    it('handles continue button click with multiple callbacks', async () => {
      const onContinue = jest.fn()
      const onClose = jest.fn()

      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            onContinue={onContinue}
            onClose={onClose}
          />,
        ),
      )

      await userEvent.click(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(onContinue).toHaveBeenCalled()
        expect(onClose).toHaveBeenCalled()
      })
    })

    it('handles async onContinue with delay', async () => {
      const onContinue = jest.fn().mockImplementation(
        () =>
          new Promise((resolve) => {
            setTimeout(resolve, 100)
          }),
      )

      await act(() =>
        render(
          <WarningDialog
            forceOpen
            title="Title"
            description="Description"
            continueText="OK"
            onContinue={onContinue}
          />,
        ),
      )

      await userEvent.click(screen.getByTestId(WARNING_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(
        () => {
          expect(onContinue).toHaveBeenCalled()
        },
        { timeout: 2000 },
      )
    })
  })
})
