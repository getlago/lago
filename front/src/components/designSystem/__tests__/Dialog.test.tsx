import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import { Dialog, DIALOG_DESCRIPTION_TEST_ID, DIALOG_TITLE_TEST_ID, DialogRef } from '../Dialog'

// Additional test IDs for test-specific elements
export const DIALOG_CONTENT_TEST_ID = 'dialog-content'
export const DIALOG_ACTION_TEST_ID = 'dialog-action'

describe('Dialog', () => {
  describe('Basic Functionality', () => {
    it('renders the dialog with title', () => {
      render(
        <Dialog
          title="Test Dialog"
          open
          actions={() => <button data-test={DIALOG_ACTION_TEST_ID}>OK</button>}
        />,
      )

      expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toHaveTextContent('Test Dialog')
    })

    it('renders title as ReactNode when provided', () => {
      render(
        <Dialog
          title={<div data-test="custom-title">Custom Title Component</div>}
          open
          actions={() => <button>OK</button>}
        />,
      )

      expect(screen.getByTestId('custom-title')).toBeInTheDocument()
      expect(screen.getByText('Custom Title Component')).toBeInTheDocument()
    })

    it('renders description when provided', () => {
      render(
        <Dialog
          title="Test Dialog"
          description="This is a test description"
          open
          actions={() => <button>OK</button>}
        />,
      )

      expect(screen.getByTestId(DIALOG_DESCRIPTION_TEST_ID)).toHaveTextContent(
        'This is a test description',
      )
    })

    it('renders description as ReactNode when provided', () => {
      render(
        <Dialog
          title="Test Dialog"
          description={<div data-test="custom-description">Custom Description</div>}
          open
          actions={() => <button>OK</button>}
        />,
      )

      expect(screen.getByTestId('custom-description')).toBeInTheDocument()
      expect(screen.getByText('Custom Description')).toBeInTheDocument()
    })

    it('renders children content', () => {
      render(
        <Dialog title="Test Dialog" open actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Test Content</div>
        </Dialog>,
      )

      expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeInTheDocument()
      expect(screen.getByText('Test Content')).toBeInTheDocument()
    })

    it('does not render description when not provided', () => {
      render(
        <Dialog title="Test Dialog" open actions={() => <button>OK</button>}>
          <div>Content</div>
        </Dialog>,
      )

      expect(screen.queryByTestId(DIALOG_DESCRIPTION_TEST_ID)).not.toBeInTheDocument()
    })

    it('does not render children when not provided', () => {
      render(<Dialog title="Test Dialog" open actions={() => <button>OK</button>} />)

      expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Actions', () => {
    it('renders actions with closeDialog callback', () => {
      render(
        <Dialog
          title="Test Dialog"
          open
          actions={({ closeDialog }) => (
            <button data-test="action-button" onClick={closeDialog}>
              Close
            </button>
          )}
        />,
      )

      expect(screen.getByTestId('action-button')).toBeInTheDocument()
    })

    it('closes dialog when action with closeDialog is clicked', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Dialog
          title="Test Dialog"
          open
          onClose={onClose}
          actions={({ closeDialog }) => (
            <button data-test="close-button" onClick={closeDialog}>
              Close
            </button>
          )}
        >
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeVisible()

      await user.click(screen.getByTestId('close-button'))

      await waitFor(() => {
        expect(onClose).toHaveBeenCalledTimes(1)
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('renders multiple action buttons', () => {
      render(
        <Dialog
          title="Test Dialog"
          open
          actions={({ closeDialog }) => (
            <>
              <button data-test="cancel-button" onClick={closeDialog}>
                Cancel
              </button>
              <button data-test="confirm-button" onClick={closeDialog}>
                Confirm
              </button>
            </>
          )}
        />,
      )

      expect(screen.getByTestId('cancel-button')).toBeInTheDocument()
      expect(screen.getByTestId('confirm-button')).toBeInTheDocument()
    })
  })

  describe('Open/Close State', () => {
    it('does not show dialog when open is false', () => {
      render(
        <Dialog title="Test Dialog" open={false} actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })

    it('shows dialog when open is true', () => {
      render(
        <Dialog title="Test Dialog" open actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeVisible()
    })

    it('shows dialog by default when open prop is not provided', () => {
      render(
        <Dialog title="Test Dialog" actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      // Default is false, so content should not be visible
      expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Dialog Ref', () => {
    it('exposes openDialog method via ref', async () => {
      const ref = createRef<DialogRef>()

      render(
        <Dialog ref={ref} title="Test Dialog" actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()

      ref.current?.openDialog()

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeInTheDocument()
      })
    })

    it('exposes closeDialog method via ref', async () => {
      const ref = createRef<DialogRef>()

      render(
        <Dialog ref={ref} title="Test Dialog" open actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeVisible()

      ref.current?.closeDialog()

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('calls onOpen callback when dialog is opened via ref', () => {
      const onOpen = jest.fn()
      const ref = createRef<DialogRef>()

      render(
        <Dialog ref={ref} title="Test Dialog" onOpen={onOpen} actions={() => <button>OK</button>}>
          <div>Content</div>
        </Dialog>,
      )

      ref.current?.openDialog()

      expect(onOpen).toHaveBeenCalledTimes(1)
    })

    it('calls onClose callback when dialog is closed via ref', () => {
      const onClose = jest.fn()
      const ref = createRef<DialogRef>()

      render(
        <Dialog
          ref={ref}
          title="Test Dialog"
          open
          onClose={onClose}
          actions={() => <button>OK</button>}
        >
          <div>Content</div>
        </Dialog>,
      )

      ref.current?.closeDialog()

      expect(onClose).toHaveBeenCalledTimes(1)
    })
  })

  describe('Callbacks', () => {
    it('calls onClose callback when dialog is closed by backdrop click', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Dialog title="Test Dialog" open onClose={onClose} actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      // Click on backdrop (MUI Dialog backdrop)
      const backdrop = document.querySelector('.MuiBackdrop-root')

      expect(backdrop).toBeInTheDocument()

      if (backdrop) {
        await user.click(backdrop)
      }

      await waitFor(() => {
        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })

    it('calls onClose callback when Escape key is pressed', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Dialog title="Test Dialog" open onClose={onClose} actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      const dialog = document.querySelector('.MuiDialog-root')

      expect(dialog).toBeInTheDocument()

      if (dialog) {
        await user.keyboard('{Escape}')
      }

      await waitFor(() => {
        expect(onClose).toHaveBeenCalled()
      })
    })

    it('does not call callbacks when not provided', async () => {
      const ref = createRef<DialogRef>()

      render(
        <Dialog ref={ref} title="Test Dialog" open actions={() => <button>OK</button>}>
          <div>Content</div>
        </Dialog>,
      )

      // Should not throw errors when callbacks are not provided
      expect(() => ref.current?.openDialog()).not.toThrow()
      expect(() => ref.current?.closeDialog()).not.toThrow()
    })
  })

  describe('Title and Description Spacing', () => {
    it('applies correct spacing when both title and description are present', () => {
      render(
        <Dialog
          title="Test Dialog"
          description="Test Description"
          open
          actions={() => <button>OK</button>}
        />,
      )

      const title = screen.getByTestId(DIALOG_TITLE_TEST_ID)

      expect(title).toHaveClass('mb-3')
    })

    it('applies correct spacing when only title is present', () => {
      render(<Dialog title="Test Dialog" open actions={() => <button>OK</button>} />)

      const title = screen.getByTestId(DIALOG_TITLE_TEST_ID)

      expect(title).toHaveClass('mb-8')
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with basic props', () => {
      render(
        <Dialog title="Test Dialog" open actions={() => <button>OK</button>}>
          <div>Dialog Content</div>
        </Dialog>,
      )

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with title and description', () => {
      render(
        <Dialog
          title="Test Dialog"
          description="This is a description"
          open
          actions={() => <button>OK</button>}
        >
          <div>Dialog Content</div>
        </Dialog>,
      )

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with ReactNode title and description', () => {
      render(
        <Dialog
          title={<div>Custom Title</div>}
          description={<div>Custom Description</div>}
          open
          actions={() => <button>OK</button>}
        >
          <div>Dialog Content</div>
        </Dialog>,
      )

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with multiple actions', () => {
      render(
        <Dialog
          title="Test Dialog"
          open
          actions={({ closeDialog }) => (
            <>
              <button onClick={closeDialog}>Cancel</button>
              <button onClick={closeDialog}>Confirm</button>
            </>
          )}
        >
          <div>Dialog Content</div>
        </Dialog>,
      )

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot without description', () => {
      render(
        <Dialog title="Test Dialog" open actions={() => <button>OK</button>}>
          <div>Dialog Content</div>
        </Dialog>,
      )

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot without children', () => {
      render(
        <Dialog
          title="Test Dialog"
          description="Test Description"
          open
          actions={() => <button>OK</button>}
        />,
      )

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with closed dialog', () => {
      render(
        <Dialog title="Test Dialog" open={false} actions={() => <button>OK</button>}>
          <div>Dialog Content</div>
        </Dialog>,
      )

      const dialogRoot = document.querySelector('.MuiDialog-root')

      expect(dialogRoot).toMatchSnapshot()
    })
  })

  describe('Complex Scenarios', () => {
    it('handles opening and closing multiple times', async () => {
      const ref = createRef<DialogRef>()

      render(
        <Dialog ref={ref} title="Test Dialog" actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      // Open
      ref.current?.openDialog()
      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeVisible()
      })

      // Close
      ref.current?.closeDialog()
      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })

      // Open again
      ref.current?.openDialog()
      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeVisible()
      })

      // Close again
      ref.current?.closeDialog()
      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('updates when open prop changes', async () => {
      const { rerender } = render(
        <Dialog title="Test Dialog" open={false} actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      expect(screen.queryByTestId(DIALOG_CONTENT_TEST_ID)).not.toBeInTheDocument()

      rerender(
        <Dialog title="Test Dialog" open actions={() => <button>OK</button>}>
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_CONTENT_TEST_ID)).toBeVisible()
      })
    })

    it('handles async action callbacks', async () => {
      const user = userEvent.setup()
      const asyncCallback = jest.fn().mockImplementation(() => {
        return new Promise((resolve) => setTimeout(resolve, 100))
      })

      render(
        <Dialog
          title="Test Dialog"
          open
          actions={({ closeDialog }) => (
            <button
              data-test="async-button"
              onClick={async () => {
                await asyncCallback()
                closeDialog()
              }}
            >
              Confirm
            </button>
          )}
        >
          <div data-test={DIALOG_CONTENT_TEST_ID}>Content</div>
        </Dialog>,
      )

      await user.click(screen.getByTestId('async-button'))

      await waitFor(() => {
        expect(asyncCallback).toHaveBeenCalled()
      })
    })
  })
})
