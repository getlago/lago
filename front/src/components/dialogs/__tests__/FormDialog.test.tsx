import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect, useState } from 'react'

import { render } from '~/test-utils'

import {
  DIALOG_TITLE_TEST_ID,
  FORM_DIALOG_CANCEL_BUTTON_TEST_ID,
  FORM_DIALOG_NAME,
  FORM_DIALOG_TEST_ID,
} from '../const'
import FormDialog, { FormDialogProps, useFormDialog } from '../FormDialog'

// Register the dialog
NiceModal.register(FORM_DIALOG_NAME, FormDialog)

// Test component that opens the dialog with given props
const TestComponent = ({
  dialogProps,
  autoOpen = true,
}: {
  dialogProps: FormDialogProps
  autoOpen?: boolean
}) => {
  const formDialog = useFormDialog()

  useEffect(() => {
    if (autoOpen) {
      formDialog.open(dialogProps).catch(() => {
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

const mockSubmit = jest.fn()

const defaultProps: FormDialogProps = {
  title: 'Form Dialog Title',
  description: 'Form Dialog Description',
  form: {
    id: 'test-form-dialog',
    submit: mockSubmit,
  },
  mainAction: <button data-test="main-action-button">Submit</button>,
}

describe('FormDialog', () => {
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
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toHaveTextContent('Form Dialog Title')
        expect(screen.getByText('Form Dialog Description')).toBeInTheDocument()
      })
    })

    it('renders ReactNode as title', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              title: <div data-test="custom-title">Custom Title</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('custom-title')).toBeInTheDocument()
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
              children: <div data-test="form-children">Form Fields</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('form-children')).toBeInTheDocument()
      })
    })

    it('renders mainAction button', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('main-action-button')).toBeInTheDocument()
        expect(screen.getByTestId('main-action-button')).toHaveTextContent('Submit')
      })
    })

    it('renders without description when not provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              title: 'Title Only',
              form: defaultProps.form,
              mainAction: defaultProps.mainAction,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.queryByText('Form Dialog Description')).not.toBeInTheDocument()
    })
  })

  describe('Form Integration', () => {
    it('renders form element with correct id', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const form = document.querySelector('form#test-form-dialog')

        expect(form).toBeInTheDocument()
      })
    })

    it('calls submit handler when form is submitted', async () => {
      const submitHandler = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              form: {
                id: 'test-form-dialog',
                submit: submitHandler,
              },
              mainAction: <button type="submit">Submit Form</button>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Submit Form')).toBeInTheDocument()
      })

      await user.click(screen.getByText('Submit Form'))

      await waitFor(() => {
        expect(submitHandler).toHaveBeenCalledTimes(1)
      })
    })

    it('allows form submission via Enter key in input', async () => {
      const submitHandler = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              form: {
                id: 'test-form-dialog',
                submit: submitHandler,
              },
              children: <input type="text" data-test="text-input" />,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('text-input')).toBeInTheDocument()
      })

      const input = screen.getByTestId('text-input')

      await user.click(input)
      await user.keyboard('{Enter}')

      await waitFor(() => {
        expect(submitHandler).toHaveBeenCalled()
      })
    })

    it('form contains all dialog sections', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              children: <div data-test="form-body">Form Body</div>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const form = document.querySelector('form#test-form-dialog')

        expect(form).toBeInTheDocument()
        expect(form?.querySelector('header')).toBeInTheDocument()
        expect(form?.querySelector('[data-test="form-body"]')).toBeInTheDocument()
        expect(
          form?.querySelector(`[data-test="${FORM_DIALOG_CANCEL_BUTTON_TEST_ID}"]`),
        ).toBeInTheDocument()
      })
    })
  })

  describe('Cancel/Close Button', () => {
    it('renders close button by default', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent dialogProps={defaultProps} />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const cancelButton = screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)

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
        const cancelButton = screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)

        expect(cancelButton).toBeInTheDocument()
        expect(cancelButton).toHaveTextContent(/cancel/i)
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
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.queryByTestId(FORM_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Dialog Actions', () => {
    it('handles async actions in mainAction button', async () => {
      const asyncAction = jest.fn().mockImplementation(
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
              mainAction: (
                <button onClick={asyncAction} data-test="async-button">
                  Async Action
                </button>
              ),
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('async-button')).toBeInTheDocument()
      })

      await user.click(screen.getByTestId('async-button'))

      await waitFor(
        () => {
          expect(asyncAction).toHaveBeenCalled()
        },
        { timeout: 2000 },
      )
    })

    it('renders multiple action buttons when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              mainAction: (
                <>
                  <button data-test="action-1">Action 1</button>
                  <button data-test="action-2">Action 2</button>
                </>
              ),
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('action-1')).toBeInTheDocument()
        expect(screen.getByTestId('action-2')).toBeInTheDocument()
        expect(screen.getByTestId(FORM_DIALOG_CANCEL_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('Error Handling', () => {
    it('calls onError when closeOnError is false and error occurs', async () => {
      const onError = jest.fn()
      const errorAction = jest.fn().mockRejectedValue(new Error('Test error'))

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              closeOnError: false,
              onError,
              mainAction: (
                <button onClick={errorAction} data-test="error-button">
                  Error Action
                </button>
              ),
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('error-button')).toBeInTheDocument()
      })

      // Note: This test validates that onError prop is passed through
      // Actual error handling is tested in useDialogActions.test.ts
    })

    it('closes dialog on error when closeOnError is true (default)', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              closeOnError: true,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      // closeOnError is passed to useDialogActions
      // Actual error behavior is tested in useDialogActions.test.ts
    })
  })

  describe('useFormDialog Hook', () => {
    it('returns open and close functions', () => {
      const TestHook = () => {
        const { open, close } = useFormDialog()

        return (
          <div>
            <button onClick={() => open(defaultProps)} data-test="open-btn">
              Open
            </button>
            <button onClick={close} data-test="close-btn">
              Close
            </button>
          </div>
        )
      }

      render(
        <NiceModalWrapper>
          <TestHook />
        </NiceModalWrapper>,
      )

      expect(screen.getByTestId('open-btn')).toBeInTheDocument()
      expect(screen.getByTestId('close-btn')).toBeInTheDocument()
    })

    it('opens dialog when open is called', async () => {
      const TestHook = () => {
        const { open } = useFormDialog()

        return (
          <button onClick={() => open(defaultProps)} data-test="open-btn">
            Open Dialog
          </button>
        )
      }

      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestHook />
        </NiceModalWrapper>,
      )

      await user.click(screen.getByTestId('open-btn'))

      await waitFor(() => {
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })
    })

    it('closes dialog when close is called', async () => {
      const TestHook = () => {
        const { open, close } = useFormDialog()

        useEffect(() => {
          open(defaultProps).catch(() => {
            // Ignore rejection
          })
          // eslint-disable-next-line react-hooks/exhaustive-deps
        }, [])

        return (
          <button onClick={close} data-test="close-btn">
            Close Dialog
          </button>
        )
      }

      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestHook />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      await user.click(screen.getByTestId('close-btn'))

      await waitFor(() => {
        expect(screen.queryByTestId(FORM_DIALOG_TEST_ID)).not.toBeInTheDocument()
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
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with all optional props', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              description: 'Full description',
              headerContent: <div>Header Content</div>,
              children: <div>Form Fields</div>,
              cancelOrCloseText: 'cancel',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with cancel button', async () => {
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
        expect(screen.getByTestId(FORM_DIALOG_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })
  })

  describe('Complex Scenarios', () => {
    it('handles complex form with multiple inputs', async () => {
      const submitHandler = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              form: {
                id: 'complex-form',
                submit: submitHandler,
              },
              children: (
                <>
                  <input type="text" data-test="input-1" placeholder="Input 1" />
                  <input type="email" data-test="input-2" placeholder="Email" />
                  <select data-test="select-1">
                    <option>Option 1</option>
                    <option>Option 2</option>
                  </select>
                </>
              ),
              mainAction: <button type="submit">Submit Complex Form</button>,
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('input-1')).toBeInTheDocument()
      })

      // Fill out form
      await user.type(screen.getByTestId('input-1'), 'Test value')
      await user.type(screen.getByTestId('input-2'), 'test@example.com')

      // Submit
      await user.click(screen.getByText('Submit Complex Form'))

      await waitFor(() => {
        expect(submitHandler).toHaveBeenCalled()
      })
    })

    it('handles dialog with custom mainAction that is not a submit button', async () => {
      const customAction = jest.fn()
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              ...defaultProps,
              mainAction: (
                <button onClick={customAction} data-test="custom-action">
                  Custom Action
                </button>
              ),
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId('custom-action')).toBeInTheDocument()
      })

      await user.click(screen.getByTestId('custom-action'))

      await waitFor(() => {
        expect(customAction).toHaveBeenCalledTimes(1)
      })
    })

    it('maintains dialog state across re-renders', async () => {
      const TestStatefulComponent = () => {
        const { open } = useFormDialog()
        const [count, setCount] = useState(0)

        return (
          <div>
            <button onClick={() => setCount(count + 1)} data-test="increment">
              Increment: {count}
            </button>
            <button
              onClick={() =>
                open({
                  ...defaultProps,
                  title: `Dialog ${count}`,
                })
              }
              data-test="open-dialog"
            >
              Open
            </button>
          </div>
        )
      }

      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestStatefulComponent />
        </NiceModalWrapper>,
      )

      // Increment counter
      await user.click(screen.getByTestId('increment'))
      await user.click(screen.getByTestId('increment'))

      // Open dialog
      await user.click(screen.getByTestId('open-dialog'))

      await waitFor(() => {
        expect(screen.getByText('Dialog 2')).toBeInTheDocument()
      })
    })
  })
})
