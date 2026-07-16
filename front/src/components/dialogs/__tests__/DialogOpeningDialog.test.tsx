import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect } from 'react'

import { render } from '~/test-utils'

import CentralizedDialog from '../CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  DIALOG_OPENING_DIALOG_NAME,
  DIALOG_TITLE_TEST_ID,
} from '../const'
import DialogOpeningDialog, {
  DialogOpeningDialogProps,
  useDialogOpeningDialog,
} from '../DialogOpeningDialog'

// Test IDs for test-specific elements
const DIALOG_CONTENT_TEST_ID = 'dialog-content'

// Register both dialogs
NiceModal.register(DIALOG_OPENING_DIALOG_NAME, DialogOpeningDialog)
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

// Test component that opens the dialog with given props
const TestComponent = ({
  dialogProps,
  autoOpen = true,
}: {
  dialogProps: DialogOpeningDialogProps
  autoOpen?: boolean
}) => {
  const dialogOpeningWarningDialog = useDialogOpeningDialog()

  useEffect(() => {
    if (autoOpen) {
      dialogOpeningWarningDialog.open(dialogProps).catch(() => {
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

const defaultWarningDialogProps = {
  title: 'Warning Title',
  description: 'Warning Description',
  onAction: jest.fn(),
  actionText: 'Confirm Warning',
}

const defaultProps: DialogOpeningDialogProps = {
  title: 'Dialog Opening Title',
  onAction: jest.fn(),
  actionText: 'OK',
  openDialogText: 'Open',
  otherDialogProps: defaultWarningDialogProps,
}

describe('DialogOpeningWarningDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Basic Functionality', () => {
    it('renders with title', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toHaveTextContent('Dialog Opening Title')
      })
    })

    it('renders title as ReactNode when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              title: <div data-test="custom-title">Custom Title Component</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('custom-title')).toBeInTheDocument()
      })
    })

    it('renders description when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              description: 'This is a test description',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('This is a test description')).toBeInTheDocument()
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

    it('renders children content', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              children: <div data-test={DIALOG_CONTENT_TEST_ID}>Test Content</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeInTheDocument()
      })
    })

    it('renders action button with actionText', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('OK')).toBeInTheDocument()
      })
    })
  })

  describe('Warning Dialog Button', () => {
    it('does not render warning button when canOpenDialog is false', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: false,
              openDialogText: 'Open Warning',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.queryByText('Open Warning')).not.toBeInTheDocument()
    })

    it('does not render warning button by default (undefined canOpenDialog)', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              openDialogText: 'Open Warning',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.queryByText('Open Warning')).not.toBeInTheDocument()
    })

    it('renders warning button when canOpenDialog is true', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Open Warning')).toBeInTheDocument()
      })
    })

    it('opens warning dialog when warning button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Open Warning')).toBeInTheDocument()
      })

      await user.click(screen.getByText('Open Warning'))

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
        expect(screen.getByText('Warning Title')).toBeInTheDocument()
      })
    })

    it('closes parent dialog before opening warning dialog', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Dialog Opening Title')).toBeInTheDocument()
      })

      await user.click(screen.getByText('Open Warning'))

      await waitFor(() => {
        expect(screen.queryByText('Dialog Opening Title')).not.toBeInTheDocument()
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('Callbacks', () => {
    it('closes dialog when backdrop is clicked', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              children: <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeInTheDocument()
      })

      const backdrop = document.querySelector('.MuiBackdrop-root')

      expect(backdrop).toBeInTheDocument()

      if (backdrop) {
        await user.click(backdrop)
      }

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('closes dialog when Escape key is pressed', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              children: <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeInTheDocument()
      })

      await user.keyboard('{Escape}')

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
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
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with warning button', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Delete Item',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with all props', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              description: 'This is a description',
              headerContent: <div>Header Content</div>,
              children: <div>Dialog Content</div>,
              canOpenDialog: true,
              openDialogText: 'Delete Item',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })
  })

  describe('Complex Scenarios', () => {
    it('warning dialog receives correct props when opened', async () => {
      const onAction = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
              otherDialogProps: {
                title: 'Custom Warning Title',
                description: 'Custom Warning Description',
                onAction,
                actionText: 'Custom Continue Text',
              },
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Open Warning')).toBeInTheDocument()
      })

      await user.click(screen.getByText('Open Warning'))

      await waitFor(() => {
        expect(screen.getByText('Custom Warning Title')).toBeInTheDocument()
        expect(screen.getByText('Custom Warning Description')).toBeInTheDocument()
        expect(screen.getByText('Custom Continue Text')).toBeInTheDocument()
      })
    })

    it('resolves immediately with other dialog promise when opening another dialog', async () => {
      const user = userEvent.setup()
      let resolvedValue: unknown

      const { rerender } = render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
            }}
            autoOpen={false}
          />
        </NiceModalWrapper>,
      )

      // Create component that captures the promise resolution
      const TestComponentWithPromise = () => {
        const dialogOpeningWarningDialog = useDialogOpeningDialog()

        useEffect(() => {
          dialogOpeningWarningDialog
            .open({
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
            })
            .then((value) => {
              resolvedValue = value
            })
            .catch(() => {
              // Ignore rejection
            })
          // eslint-disable-next-line react-hooks/exhaustive-deps
        }, [])

        return null
      }

      rerender(
        <NiceModalWrapper>
          <TestComponentWithPromise />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Open Warning')).toBeInTheDocument()
      })

      // Click to open other dialog
      await user.click(screen.getByText('Open Warning'))

      // Verify the promise resolved immediately with the right structure
      await waitFor(() => {
        expect(resolvedValue).toHaveProperty('reason', 'open-other-dialog')
        expect(resolvedValue).toHaveProperty('otherDialog')
        expect((resolvedValue as any).otherDialog).toBeInstanceOf(Promise)
      })

      // Parent dialog should be closed and other dialog should be open
      await waitFor(() => {
        expect(screen.queryByText('Dialog Opening Title')).not.toBeInTheDocument()
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    it('allows caller to handle other dialog result via returned promise', async () => {
      const user = userEvent.setup()
      const otherDialogResult = { reason: 'success', data: 'test-data' }
      let finalResult: unknown

      const { rerender } = render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
            }}
            autoOpen={false}
          />
        </NiceModalWrapper>,
      )

      // Create component that captures the promise resolution
      const TestComponentWithPromise = () => {
        const dialogOpeningWarningDialog = useDialogOpeningDialog()

        useEffect(() => {
          dialogOpeningWarningDialog
            .open({
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
              otherDialogProps: {
                ...defaultWarningDialogProps,
                onAction: jest.fn().mockResolvedValue(otherDialogResult),
              },
            })
            .then(async (result: any) => {
              if (result.reason === 'open-other-dialog') {
                // Caller handles the other dialog's promise
                finalResult = await result.otherDialog
              }
            })
            .catch(() => {
              // Ignore rejection
            })
          // eslint-disable-next-line react-hooks/exhaustive-deps
        }, [])

        return null
      }

      rerender(
        <NiceModalWrapper>
          <TestComponentWithPromise />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Open Warning')).toBeInTheDocument()
      })

      await user.click(screen.getByText('Open Warning'))

      await waitFor(() => {
        expect(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      // Click confirm on other dialog
      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      // Verify caller received the other dialog's result
      await waitFor(() => {
        expect(finalResult).toEqual(otherDialogResult)
      })
    })
  })
})
