import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import { Drawer, DrawerRef } from '../Drawer'

// Test IDs
export const DRAWER_OPENER_TEST_ID = 'drawer-opener'
export const DRAWER_CONTENT_TEST_ID = 'drawer-content'
export const DRAWER_STICKY_BAR_TEST_ID = 'drawer-sticky-bar'

describe('Drawer', () => {
  describe('Basic Functionality', () => {
    it('renders the drawer with title', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      expect(screen.getByText('Test Drawer')).toBeInTheDocument()
    })

    it('renders title as ReactNode when provided', () => {
      render(
        <Drawer title={<div data-test="custom-title">Custom Title Component</div>} forceOpen>
          <div>Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId('custom-title')).toBeInTheDocument()
      expect(screen.getByText('Custom Title Component')).toBeInTheDocument()
    })

    it('renders children content', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Test Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeInTheDocument()
      expect(screen.getByText('Test Content')).toBeInTheDocument()
    })

    it('renders children as function with closeDrawer callback', async () => {
      const user = userEvent.setup()

      render(
        <Drawer title="Test Drawer" forceOpen>
          {({ closeDrawer }) => (
            <button data-test="close-button" onClick={closeDrawer}>
              Close
            </button>
          )}
        </Drawer>,
      )

      expect(screen.getByTestId('close-button')).toBeInTheDocument()

      await user.click(screen.getByTestId('close-button'))

      await waitFor(() => {
        expect(screen.queryByTestId('close-button')).not.toBeInTheDocument()
      })
    })
  })

  describe('Opener Functionality', () => {
    it('renders opener button when provided', () => {
      render(
        <Drawer
          title="Test Drawer"
          opener={<button data-test={DRAWER_OPENER_TEST_ID}>Open Drawer</button>}
        >
          <div>Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId(DRAWER_OPENER_TEST_ID)).toBeInTheDocument()
    })

    it('opens drawer when opener is clicked', async () => {
      const user = userEvent.setup()

      render(
        <Drawer
          title="Test Drawer"
          opener={<button data-test={DRAWER_OPENER_TEST_ID}>Open Drawer</button>}
        >
          <div data-test={DRAWER_CONTENT_TEST_ID}>Drawer Content</div>
        </Drawer>,
      )

      await user.click(screen.getByTestId(DRAWER_OPENER_TEST_ID))

      await waitFor(() => {
        expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeVisible()
      })
    })

    it('toggles drawer when opener is clicked multiple times', async () => {
      const user = userEvent.setup()

      render(
        <Drawer
          title="Test Drawer"
          opener={<button data-test={DRAWER_OPENER_TEST_ID}>Open Drawer</button>}
        >
          <div data-test={DRAWER_CONTENT_TEST_ID}>Drawer Content</div>
        </Drawer>,
      )

      // Open drawer
      await user.click(screen.getByTestId(DRAWER_OPENER_TEST_ID))

      await waitFor(() => {
        expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeVisible()
      })

      // Close drawer
      await user.click(screen.getByTestId(DRAWER_OPENER_TEST_ID))

      await waitFor(() => {
        expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('forceOpen Prop', () => {
    it('opens drawer automatically when forceOpen is true', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeVisible()
    })

    it('keeps drawer closed when forceOpen is false', () => {
      render(
        <Drawer title="Test Drawer" forceOpen={false}>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('Close Button', () => {
    it('renders close button in header', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div>Content</div>
        </Drawer>,
      )

      const closeButton = screen.getByTestId('button')

      expect(closeButton).toBeInTheDocument()
    })

    it('closes drawer when close button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <Drawer title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const closeButton = screen.getByTestId('button')

      await user.click(closeButton)

      await waitFor(() => {
        expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Callbacks', () => {
    it('calls onOpen callback when drawer is opened via ref', () => {
      const onOpen = jest.fn()
      const ref = createRef<DrawerRef>()

      render(
        <Drawer ref={ref} title="Test Drawer" onOpen={onOpen}>
          <div>Content</div>
        </Drawer>,
      )

      ref.current?.openDrawer()

      expect(onOpen).toHaveBeenCalledTimes(1)
    })

    it('calls onClose callback when drawer is closed', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Drawer title="Test Drawer" forceOpen onClose={onClose}>
          <div>Content</div>
        </Drawer>,
      )

      const closeButton = screen.getByTestId('button')

      await user.click(closeButton)

      await waitFor(() => {
        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })

    it('calls onClose when clicking backdrop without warning dialog', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Drawer title="Test Drawer" forceOpen onClose={onClose}>
          <div>Content</div>
        </Drawer>,
      )

      // Click on backdrop (MUI Drawer backdrop)
      const backdrop = document.querySelector('.MuiBackdrop-root')

      expect(backdrop).toBeInTheDocument()

      if (backdrop) {
        await user.click(backdrop)
      }

      await waitFor(() => {
        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })
  })

  describe('Drawer Ref', () => {
    it('exposes openDrawer method via ref', async () => {
      const ref = createRef<DrawerRef>()

      render(
        <Drawer ref={ref} title="Test Drawer">
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()

      ref.current?.openDrawer()

      await waitFor(() => {
        expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeInTheDocument()
      })
    })

    it('exposes closeDrawer method via ref', async () => {
      const ref = createRef<DrawerRef>()

      render(
        <Drawer ref={ref} title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeVisible()

      ref.current?.closeDrawer()

      await waitFor(() => {
        expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('Sticky Bottom Bar', () => {
    it('renders sticky bottom bar when provided', () => {
      render(
        <Drawer
          title="Test Drawer"
          forceOpen
          stickyBottomBar={<div data-test={DRAWER_STICKY_BAR_TEST_ID}>Bottom Actions</div>}
        >
          <div>Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId(DRAWER_STICKY_BAR_TEST_ID)).toBeInTheDocument()
      expect(screen.getByText('Bottom Actions')).toBeInTheDocument()
    })

    it('renders sticky bottom bar as function with closeDrawer callback', async () => {
      const user = userEvent.setup()

      render(
        <Drawer
          title="Test Drawer"
          forceOpen
          stickyBottomBar={({ closeDrawer }) => (
            <button data-test="sticky-close-button" onClick={closeDrawer}>
              Cancel
            </button>
          )}
        >
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      expect(screen.getByTestId('sticky-close-button')).toBeInTheDocument()

      await user.click(screen.getByTestId('sticky-close-button'))

      await waitFor(() => {
        expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('does not render sticky bottom bar when not provided', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div>Content</div>
        </Drawer>,
      )

      expect(screen.queryByTestId(DRAWER_STICKY_BAR_TEST_ID)).not.toBeInTheDocument()
    })

    it('applies custom stickyBottomBarClassName', async () => {
      render(
        <Drawer
          title="Test Drawer"
          forceOpen
          stickyBottomBarClassName="custom-sticky-class"
          stickyBottomBar={<div>Bottom Bar</div>}
        >
          <div>Content</div>
        </Drawer>,
      )

      await waitFor(() => {
        const stickyBar = document.querySelector('.custom-sticky-class')

        expect(stickyBar).toBeInTheDocument()
      })
    })
  })

  describe('Anchor Positioning', () => {
    it('renders with default right anchor', async () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div>Content</div>
        </Drawer>,
      )

      await waitFor(() => {
        const drawer = document.querySelector('.MuiDrawer-paperAnchorRight')

        expect(drawer).toBeInTheDocument()
      })
    })

    it('renders with left anchor when specified', async () => {
      render(
        <Drawer title="Test Drawer" forceOpen anchor="left">
          <div>Content</div>
        </Drawer>,
      )

      await waitFor(() => {
        const drawer = document.querySelector('.MuiDrawer-paperAnchorLeft')

        expect(drawer).toBeInTheDocument()
      })
    })

    it('renders with top anchor when specified', async () => {
      render(
        <Drawer title="Test Drawer" forceOpen anchor="top">
          <div>Content</div>
        </Drawer>,
      )

      await waitFor(() => {
        const drawer = document.querySelector('.MuiDrawer-paperAnchorTop')

        expect(drawer).toBeInTheDocument()
      })
    })

    it('renders with bottom anchor when specified', async () => {
      render(
        <Drawer title="Test Drawer" forceOpen anchor="bottom">
          <div>Content</div>
        </Drawer>,
      )

      await waitFor(() => {
        const drawer = document.querySelector('.MuiDrawer-paperAnchorBottom')

        expect(drawer).toBeInTheDocument()
      })
    })
  })

  describe('Content Styling', () => {
    it('applies padding by default', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      // Find the content wrapper by checking parent of content
      const content = screen.getByTestId(DRAWER_CONTENT_TEST_ID)
      const contentWrapper = content.parentElement

      expect(contentWrapper).toHaveClass('px-4', 'pb-20', 'pt-12')
    })

    it('removes padding when withPadding is false', () => {
      render(
        <Drawer title="Test Drawer" forceOpen withPadding={false}>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const content = screen.getByTestId(DRAWER_CONTENT_TEST_ID)
      const contentWrapper = content.parentElement

      expect(contentWrapper).not.toHaveClass('px-4', 'pb-20', 'pt-12')
    })

    it('applies full height when fullContentHeight is true', () => {
      render(
        <Drawer title="Test Drawer" forceOpen fullContentHeight>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const content = screen.getByTestId(DRAWER_CONTENT_TEST_ID)
      const contentWrapper = content.parentElement

      expect(contentWrapper).toHaveClass('h-full')
    })

    it('does not apply full height by default', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const content = screen.getByTestId(DRAWER_CONTENT_TEST_ID)
      const contentWrapper = content.parentElement

      expect(contentWrapper).not.toHaveClass('h-full')
    })
  })

  describe('Close Warning Dialog', () => {
    it('shows warning dialog when showCloseWarningDialog is true', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Drawer title="Test Drawer" forceOpen showCloseWarningDialog onClose={onClose}>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const closeButton = screen.getByTestId('button')

      await user.click(closeButton)

      // Warning dialog should appear - drawer content should still be visible
      await waitFor(() => {
        expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeInTheDocument()
      })

      // onClose should not be called yet
      expect(onClose).not.toHaveBeenCalled()
    })

    it('closes drawer after confirming warning dialog', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Drawer title="Test Drawer" forceOpen showCloseWarningDialog onClose={onClose}>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const closeButton = screen.getByTestId('button')

      await user.click(closeButton)

      // Wait a bit for dialog to appear
      await waitFor(
        () => {
          // Find the continue button (last button in the dialog typically)
          const buttons = screen.getAllByRole('button')

          expect(buttons.length).toBeGreaterThan(1)
        },
        { timeout: 1000 },
      )

      // Find and click the continue/confirm button (usually the last button)
      const buttons = screen.getAllByRole('button')
      const continueButton = buttons.at(-1)

      if (!continueButton) {
        throw new Error('Continue button not found in warning dialog')
      }

      await user.click(continueButton)

      await waitFor(() => {
        expect(onClose).toHaveBeenCalledTimes(1)
        expect(screen.queryByTestId(DRAWER_CONTENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    it('cancels closing when canceling warning dialog', async () => {
      const user = userEvent.setup()
      const onClose = jest.fn()

      render(
        <Drawer title="Test Drawer" forceOpen showCloseWarningDialog onClose={onClose}>
          <div data-test={DRAWER_CONTENT_TEST_ID}>Content</div>
        </Drawer>,
      )

      const closeButton = screen.getByTestId('button')

      await user.click(closeButton)

      // Wait for dialog to appear (multiple buttons means dialog is open)
      await waitFor(
        () => {
          const buttons = screen.getAllByRole('button')

          expect(buttons.length).toBeGreaterThan(1)
        },
        { timeout: 1000 },
      )

      // Find cancel button (typically the first button in the dialog or one with cancel text)
      const buttons = screen.getAllByRole('button')
      // Try to find by text first, otherwise use first non-close button
      const cancelButton =
        buttons.find((btn) => btn.textContent?.toLowerCase().includes('cancel')) || buttons[0]

      await user.click(cancelButton)

      await waitFor(() => {
        // Dialog should close but drawer should remain open
        const currentButtons = screen.getAllByRole('button')

        // Should be back to just the close button
        expect(currentButtons.length).toBe(1)
      })

      // Drawer content should still be in the document
      expect(screen.getByTestId(DRAWER_CONTENT_TEST_ID)).toBeInTheDocument()
      // onClose should not have been called
      expect(onClose).not.toHaveBeenCalled()
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot with drawer open', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          <div>Drawer Content</div>
        </Drawer>,
      )

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })

    it('matches snapshot with sticky bottom bar', () => {
      render(
        <Drawer
          title="Test Drawer"
          forceOpen
          stickyBottomBar={
            <div>
              <button>Cancel</button>
              <button>Save</button>
            </div>
          }
        >
          <div>Drawer Content</div>
        </Drawer>,
      )

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })

    it('matches snapshot with ReactNode title', () => {
      render(
        <Drawer title={<div>Custom Title</div>} forceOpen>
          <div>Drawer Content</div>
        </Drawer>,
      )

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })

    it('matches snapshot with fullContentHeight and no padding', () => {
      render(
        <Drawer title="Test Drawer" forceOpen fullContentHeight withPadding={false}>
          <div>Drawer Content</div>
        </Drawer>,
      )

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })

    it('matches snapshot with children as function', () => {
      render(
        <Drawer title="Test Drawer" forceOpen>
          {({ closeDrawer }) => (
            <div>
              <p>Content</p>
              <button onClick={closeDrawer}>Close</button>
            </div>
          )}
        </Drawer>,
      )

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })

    it('matches snapshot with stickyBottomBar and custom className', () => {
      render(
        <Drawer
          title="Test Drawer"
          forceOpen
          stickyBottomBarClassName="custom-sticky-class"
          stickyBottomBar={({ closeDrawer }) => (
            <div>
              <button onClick={closeDrawer}>Cancel</button>
              <button>Save</button>
            </div>
          )}
        >
          <div>Content</div>
        </Drawer>,
      )

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })
  })
})
