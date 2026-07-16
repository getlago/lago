import NiceModal, { Provider as NiceModalProvider } from '@ebay/nice-modal-react'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import NiceModalCentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  CENTRALIZED_DIALOG_TEST_ID,
} from '~/components/dialogs/const'
import { render } from '~/test-utils'

import {
  BASE_DRAWER_CLOSE_BUTTON_TEST_ID,
  BASE_DRAWER_CONTENT_TEST_ID,
  BASE_DRAWER_HEADER_TEST_ID,
  BASE_DRAWER_TEST_ID,
} from '../BaseDrawer'
import CentralizedDrawer from '../CentralizedDrawer'

jest.mock('../drawerStack')

NiceModal.register(CENTRALIZED_DIALOG_NAME, NiceModalCentralizedDialog)

// Mock rAF to fire synchronously so the drawer transitions to 'open' state
beforeEach(() => {
  jest.useFakeTimers()
  jest.spyOn(window, 'requestAnimationFrame').mockImplementation((cb) => {
    cb(0)

    return 0
  })
})

afterEach(() => {
  jest.useRealTimers()
  jest.restoreAllMocks()
})

const showDrawer = async (props: Partial<Parameters<typeof NiceModal.show>[1]> = {}) => {
  const result = render(
    <NiceModalProvider>
      <div />
    </NiceModalProvider>,
  )

  await act(async () => {
    NiceModal.show(CentralizedDrawer, {
      title: 'Test Drawer',
      children: <div>Drawer content</div>,
      ...props,
    })
  })

  return result
}

describe('CentralizedDrawer', () => {
  describe('GIVEN the drawer is shown via NiceModal', () => {
    describe('WHEN rendered with required props', () => {
      it('THEN should display the drawer container', async () => {
        await showDrawer()

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })
      })

      it('THEN should display the title', async () => {
        await showDrawer()

        await waitFor(() => {
          const header = screen.getByTestId(BASE_DRAWER_HEADER_TEST_ID)

          expect(header).toHaveTextContent('Test Drawer')
        })
      })

      it('THEN should display the children content', async () => {
        await showDrawer()

        await waitFor(() => {
          const content = screen.getByTestId(BASE_DRAWER_CONTENT_TEST_ID)

          expect(content).toHaveTextContent('Drawer content')
        })
      })
    })
  })

  describe('GIVEN the drawer is open', () => {
    describe('WHEN the close button is clicked', () => {
      it('THEN should close the drawer', async () => {
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        await showDrawer()

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        await user.click(closeButton)

        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(screen.queryByTestId(BASE_DRAWER_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })

    describe('WHEN the close button is clicked and onClose prop is provided', () => {
      it('THEN should call the onClose callback', async () => {
        const onClose = jest.fn()
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        await showDrawer({ onClose })

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        await user.click(closeButton)

        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN shouldPromptOnClose returns true', () => {
      it('THEN should show a warning dialog instead of closing', async () => {
        const shouldPromptOnClose = jest.fn(() => true)
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        await showDrawer({ shouldPromptOnClose })

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        const closeButton = screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID)

        await user.click(closeButton)

        await waitFor(() => {
          expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
        })

        expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should close the drawer when the warning dialog continue button is clicked', async () => {
        const shouldPromptOnClose = jest.fn(() => true)
        const onClose = jest.fn()
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        await showDrawer({ shouldPromptOnClose, onClose })

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        await user.click(screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID))

        await waitFor(() => {
          expect(screen.getByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
        })

        await user.click(screen.getByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(screen.queryByTestId(BASE_DRAWER_TEST_ID)).not.toBeInTheDocument()
        })

        expect(onClose).toHaveBeenCalledTimes(1)
      })
    })

    describe('WHEN shouldPromptOnClose returns false', () => {
      it('THEN should close the drawer without showing a warning dialog', async () => {
        const shouldPromptOnClose = jest.fn(() => false)
        const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime })

        await showDrawer({ shouldPromptOnClose })

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        await user.click(screen.getByTestId(BASE_DRAWER_CLOSE_BUTTON_TEST_ID))

        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(screen.queryByTestId(BASE_DRAWER_TEST_ID)).not.toBeInTheDocument()
        })

        expect(screen.queryByTestId(CENTRALIZED_DIALOG_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
