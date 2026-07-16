import NiceModal from '@ebay/nice-modal-react'
import { cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReactNode, useEffect } from 'react'

import { render } from '~/test-utils'

import { DIALOG_TITLE_TEST_ID, PREMIUM_WARNING_DIALOG_NAME } from '../const'
import PremiumWarningDialog, {
  PremiumWarningDialogProps,
  usePremiumWarningDialog,
} from '../PremiumWarningDialog'

// Register the dialog
NiceModal.register(PREMIUM_WARNING_DIALOG_NAME, PremiumWarningDialog)

// Test component that opens the dialog with given props
const TestComponent = ({
  dialogProps,
  autoOpen = true,
}: {
  dialogProps?: PremiumWarningDialogProps
  autoOpen?: boolean
}) => {
  const premiumWarningDialog = usePremiumWarningDialog()

  useEffect(() => {
    if (autoOpen) {
      premiumWarningDialog.open(dialogProps).catch(() => {
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

describe('PremiumWarningDialog', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('Basic Functionality', () => {
    it('renders with default title from translations', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })
    })

    it('renders with custom title when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              title: 'Custom Premium Feature Title',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Custom Premium Feature Title')).toBeInTheDocument()
      })
    })

    it('renders with custom description when provided', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              description: 'Custom Premium Feature Description',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByText('Custom Premium Feature Description')).toBeInTheDocument()
      })
    })

    it('renders cancel button', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        // Cancel button has text "Close" from translations
        const cancelButton = screen.getByText('Close')

        expect(cancelButton).toBeInTheDocument()
      })
    })

    it('renders contact/mailto button', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const mailtoLink = document.querySelector('a[href^="mailto:"]')

        expect(mailtoLink).toBeInTheDocument()
      })
    })

    it('generates correct mailto link with default subject and body', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const mailtoLink = document.querySelector('a[href^="mailto:"]')

        expect(mailtoLink).toBeInTheDocument()
        expect(mailtoLink?.getAttribute('href')).toContain('hello@getlago.com')
      })
    })

    it('generates correct mailto link with custom subject and body', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              mailtoSubject: 'Custom Subject',
              mailtoBody: 'Custom Body',
            }}
          />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        const mailtoLink = document.querySelector('a[href^="mailto:"]')

        expect(mailtoLink).toBeInTheDocument()
        expect(mailtoLink?.getAttribute('href')).toContain('subject=Custom%20Subject')
        expect(mailtoLink?.getAttribute('href')).toContain('body=Custom%20Body')
      })
    })
  })

  describe('Callbacks', () => {
    it('closes dialog when cancel button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      // Cancel button has text "Close" from translations
      const cancelButton = screen.getByText('Close')

      expect(cancelButton).toBeInTheDocument()

      await user.click(cancelButton)

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('closes dialog when backdrop is clicked', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      const backdrop = document.querySelector('.MuiBackdrop-root')

      expect(backdrop).toBeInTheDocument()

      if (backdrop) {
        await user.click(backdrop)
      }

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('closes dialog when Escape key is pressed', async () => {
      const user = userEvent.setup()

      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      await user.keyboard('{Escape}')

      await waitFor(() => {
        expect(screen.queryByTestId(DIALOG_TITLE_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with default props', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent />
        </NiceModalWrapper>,
      )

      await waitFor(() => {
        expect(screen.getByTestId(DIALOG_TITLE_TEST_ID)).toBeInTheDocument()
      })

      const dialogPaper = document.querySelector('.MuiDialog-paper')

      expect(dialogPaper).toMatchSnapshot()
    })

    it('matches snapshot with custom title and description', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              title: 'Custom Premium Title',
              description: 'Custom Premium Description',
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

    it('matches snapshot with custom mailto props', async () => {
      render(
        <NiceModalWrapper>
          <TestComponent
            dialogProps={{
              mailtoSubject: 'Custom Subject',
              mailtoBody: 'Custom Body',
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
