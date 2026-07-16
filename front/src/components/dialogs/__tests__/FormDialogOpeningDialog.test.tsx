import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect } from 'react'

import { render } from '~/test-utils'

import CentralizedDialog from '../CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  DIALOG_TITLE_TEST_ID,
  FORM_DIALOG_CANCEL_BUTTON_TEST_ID,
  FORM_DIALOG_OPENING_DIALOG_NAME,
  FORM_DIALOG_OPENING_DIALOG_TEST_ID,
} from '../const'
import FormDialogOpeningDialog, {
  FormDialogOpeningDialogProps,
  useFormDialogOpeningDialog,
} from '../FormDialogOpeningDialog'

const DIALOG_CONTENT_TEST_ID = 'dialog-content'
const MAIN_ACTION_TEST_ID = 'main-action'

NiceModal.register(FORM_DIALOG_OPENING_DIALOG_NAME, FormDialogOpeningDialog)
NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const TestComponent = ({
  dialogProps,
  autoOpen = true,
}: {
  dialogProps: FormDialogOpeningDialogProps
  autoOpen?: boolean
}) => {
  const formDialogOpeningDialog = useFormDialogOpeningDialog()

  useEffect(() => {
    if (autoOpen) {
      formDialogOpeningDialog.open(dialogProps).catch(() => {
        // Ignore rejection - dialog was cancelled
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoOpen])

  return null
}

const NiceModalWrapper = ({ children }: { children: ReactNode }) => {
  return <NiceModal.Provider>{children}</NiceModal.Provider>
}

const defaultOtherDialogProps = {
  title: 'Warning Title',
  description: 'Warning Description',
  onAction: jest.fn(),
  actionText: 'Confirm Warning',
}

const defaultProps: FormDialogOpeningDialogProps = {
  title: 'Form Dialog Title',
  form: {
    id: 'test-form',
    submit: jest.fn(),
  },
  mainAction: (
    <button type="submit" data-test={MAIN_ACTION_TEST_ID}>
      Submit
    </button>
  ),
  openDialogText: 'Open Other',
  otherDialogProps: defaultOtherDialogProps,
}

describe('FormDialogOpeningDialog', () => {
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
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toHaveTextContent('Form Dialog Title')
      })
    })

    it('renders with data-test attribute', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(FORM_DIALOG_OPENING_DIALOG_TEST_ID)).toBeInTheDocument()
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

    it('renders mainAction', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(MAIN_ACTION_TEST_ID)).toBeInTheDocument()
      })
    })

    it('renders cancel button', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('Form Wrapping', () => {
    it('wraps content in a form element with the correct id', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              children: <div data-test={DIALOG_CONTENT_TEST_ID}>Form Content</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeInTheDocument()
      })

      const formElement = document.querySelector('form#test-form')

      expect(formElement).toBeInTheDocument()
    })

    it('calls form.submit when form is submitted', async () => {
      const submitFn = jest.fn()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              form: { id: 'submit-test-form', submit: submitFn },
              mainAction: <button type="submit">Submit</button>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Submit')).toBeInTheDocument()
      })

      const formElement = document.querySelector('form#submit-test-form') as HTMLFormElement

      expect(formElement).toBeInTheDocument()

      formElement.requestSubmit()

      await waitFor(() => {
        expect(submitFn).toHaveBeenCalled()
      })
    })
  })

  describe('Open Other Dialog Button', () => {
    it('does not render open dialog button when canOpenDialog is false', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: false,
              openDialogText: 'Delete',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.queryByText('Delete')).not.toBeInTheDocument()
    })

    it('does not render open dialog button by default (undefined canOpenDialog)', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              openDialogText: 'Delete',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.queryByText('Delete')).not.toBeInTheDocument()
    })

    it('renders open dialog button when canOpenDialog is true', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Delete',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Delete')).toBeInTheDocument()
      })
    })

    it('opens centralized dialog when open dialog button is clicked', async () => {
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

    it('closes parent dialog before opening the other dialog', async () => {
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
        expect(screen.getByText('Form Dialog Title')).toBeInTheDocument()
      })

      await user.click(screen.getByText('Open Warning'))

      await waitFor(() => {
        expect(screen.queryByText('Form Dialog Title')).not.toBeInTheDocument()
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

    it('closes dialog when cancel button is clicked', async () => {
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

      await user.click(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Complex Scenarios', () => {
    it('other dialog receives correct props when opened', async () => {
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

      const TestComponentWithPromise = () => {
        const formDialogOpeningDialog = useFormDialogOpeningDialog()

        useEffect(() => {
          formDialogOpeningDialog
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

      await user.click(screen.getByText('Open Warning'))

      await waitFor(() => {
        expect(resolvedValue).toHaveProperty('reason', 'open-other-dialog')
        expect(resolvedValue).toHaveProperty('otherDialog')
        expect((resolvedValue as any).otherDialog).toBeInstanceOf(Promise)
      })

      await waitFor(() => {
        expect(screen.queryByText('Form Dialog Title')).not.toBeInTheDocument()
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

      const TestComponentWithPromise = () => {
        const formDialogOpeningDialog = useFormDialogOpeningDialog()

        useEffect(() => {
          formDialogOpeningDialog
            .open({
              ...defaultProps,
              canOpenDialog: true,
              openDialogText: 'Open Warning',
              otherDialogProps: {
                ...defaultOtherDialogProps,
                onAction: jest.fn().mockResolvedValue(otherDialogResult),
              },
            })
            .then(async (result: any) => {
              if (result.reason === 'open-other-dialog') {
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

      await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(finalResult).toEqual(otherDialogResult)
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

    it('matches snapshot with open dialog button', async () => {
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
})
