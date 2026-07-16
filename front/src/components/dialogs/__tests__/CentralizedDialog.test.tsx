import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect } from 'react'

import { render } from '~/test-utils'

import CentralizedDialog, {
  CentralizedDialogProps,
  useCentralizedDialog,
} from '../CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
} from '../const'

// Register the dialog
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

// Test component that opens the dialog with given props
const TestComponent = ({
  dialogProps,
  autoOpen = true,
}: {
  dialogProps: CentralizedDialogProps
  autoOpen?: boolean
}) => {
  const warningDialog = useCentralizedDialog()

  useEffect(() => {
    if (autoOpen) {
      warningDialog.open(dialogProps).catch(() => {
        // Ignore rejection - dialog was cancelled
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoOpen])

  return null
}

// Wrapper that includes NiceModal.Provider
const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const defaultProps: CentralizedDialogProps = {
  title: 'Warning Title',
  description: 'Warning Description',
  onAction: jest.fn(),
  actionText: 'Continue',
}

describe('CentralizedDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Basic Functionality', () => {
    it('renders with title and description', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
        expect(screen.getByText('Warning Title')).toBeInTheDocument()
        expect(screen.getByText('Warning Description')).toBeInTheDocument()
      })
    })

    it('renders with custom continue text', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              actionText: 'Custom Continue',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toHaveTextContent(
          'Custom Continue',
        )
      })
    })

    it('renders close button with translated text by default', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const cancelButton = screen.getByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID)

        expect(cancelButton).toBeInTheDocument()
        expect(cancelButton).toHaveTextContent(/close/i)
      })
    })

    it('renders cancel button when cancelOrCloseText is cancel', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              cancelOrCloseText: 'cancel',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const cancelButton = screen.getByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID)

        expect(cancelButton).toBeInTheDocument()
        expect(cancelButton).toHaveTextContent(/cancel/i)
      })
    })

    it('renders ReactNode as description', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              description: <div data-test="custom-description">Custom Description</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('custom-description')).toBeInTheDocument()
      })
    })

    it('renders headerContent when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              headerContent: <div data-test="header-content">Header Content</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('header-content')).toBeInTheDocument()
      })
    })

    it('renders children when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              children: <div data-test="dialog-children">Children Content</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('dialog-children')).toBeInTheDocument()
      })
    })
  })

  describe('Modes', () => {
    it('renders in info colorVariant by default', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        expect(confirmButton).not.toHaveClass('button-danger')
      })
    })

    it('renders in danger colorVariant when explicitly set', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              colorVariant: 'danger',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        expect(confirmButton).toHaveClass('button-danger')
      })
    })

    it('renders in info colorVariant when set', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              colorVariant: 'info',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        expect(confirmButton).not.toHaveClass('button-danger')
      })
    })
  })

  describe('Callbacks', () => {
    it('calls onAction when confirm button is clicked', async () => {
      const onAction = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              onAction,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(onAction).toHaveBeenCalledTimes(1)
      })
    })

    it('closes dialog after onAction callback', async () => {
      const onAction = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              onAction,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeVisible()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(
          screen.queryByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })

    it('handles async onAction callback', async () => {
      const onAction = jest.fn().mockResolvedValue(undefined)
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              onAction,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(onAction).toHaveBeenCalled()
      })
    })

    it('closes dialog when cancel button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeVisible()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(
          screen.queryByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('Disable State', () => {
    it('disables confirm button when disableOnContinue is true', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              disableOnContinue: true,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        expect(confirmButton).toBeDisabled()
      })
    })

    it('enables confirm button when disableOnContinue is false', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              disableOnContinue: false,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        expect(confirmButton).not.toBeDisabled()
      })
    })

    it('enables confirm button by default', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const confirmButton = screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        expect(confirmButton).not.toBeDisabled()
      })
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with basic props', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot in danger colorVariant', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              colorVariant: 'danger',
              actionText: 'Delete',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot in info colorVariant', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              colorVariant: 'info',
              actionText: 'Confirm',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with disabled confirm button', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              disableOnContinue: true,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })
  })

  describe('Complex Scenarios', () => {
    it('handles async onAction with delay', async () => {
      const onAction = jest.fn().mockImplementation(
        () =>
          new Promise((resolve) => {
            setTimeout(resolve, 100)
          }),
      )
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              onAction,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(
        () => {
          expect(onAction).toHaveBeenCalled()
        },
        { timeout: 2000 },
      )
    })
  })
})
