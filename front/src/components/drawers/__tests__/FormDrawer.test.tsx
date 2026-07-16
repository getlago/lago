import NiceModal, { Provider as NiceModalProvider } from '@ebay/nice-modal-react'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import {
  BASE_DRAWER_ACTIONS_TEST_ID,
  BASE_DRAWER_CLOSE_BUTTON_TEST_ID,
  BASE_DRAWER_CONTENT_TEST_ID,
  BASE_DRAWER_HEADER_TEST_ID,
  BASE_DRAWER_TEST_ID,
} from '../BaseDrawer'
import FormDrawer from '../FormDrawer'

jest.mock('../drawerStack')

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

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

const SUBMIT_BUTTON_TEST_ID = 'form-drawer-submit-button'

const showDrawer = async (props: Partial<Parameters<typeof NiceModal.show>[1]> = {}) => {
  const mockSubmit = jest.fn().mockResolvedValue(undefined)

  const result = render(
    <NiceModalProvider>
      <div />
    </NiceModalProvider>,
  )

  const mergedProps = {
    title: 'Form Drawer Title',
    children: <div>Form content</div>,
    form: { id: 'test-form', submit: mockSubmit },
    mainAction: (
      <button type="submit" form="test-form" data-test={SUBMIT_BUTTON_TEST_ID}>
        Save
      </button>
    ),
    ...props,
  }

  await act(async () => {
    NiceModal.show(FormDrawer, mergedProps)
  })

  return { ...result, mockSubmit }
}

describe('FormDrawer', () => {
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

          expect(header).toHaveTextContent('Form Drawer Title')
        })
      })

      it('THEN should display children content', async () => {
        await showDrawer()

        await waitFor(() => {
          const content = screen.getByTestId(BASE_DRAWER_CONTENT_TEST_ID)

          expect(content).toHaveTextContent('Form content')
        })
      })

      it('THEN should display the actions bar with cancel and main action', async () => {
        await showDrawer()

        await waitFor(() => {
          const actions = screen.getByTestId(BASE_DRAWER_ACTIONS_TEST_ID)

          expect(actions).toBeInTheDocument()
          expect(screen.getByTestId(SUBMIT_BUTTON_TEST_ID)).toBeInTheDocument()
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

    describe('WHEN the form is submitted', () => {
      it('THEN should call the form submit handler', async () => {
        const { mockSubmit } = await showDrawer()

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        const form = document.getElementById('test-form') as HTMLFormElement

        await act(async () => {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        })

        await waitFor(() => {
          expect(mockSubmit).toHaveBeenCalled()
        })
      })

      it('THEN should auto-close the drawer once submit settles (default)', async () => {
        const { mockSubmit } = await showDrawer()

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        const form = document.getElementById('test-form') as HTMLFormElement

        await act(async () => {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        })

        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(mockSubmit).toHaveBeenCalled()
          expect(screen.queryByTestId(BASE_DRAWER_TEST_ID)).not.toBeInTheDocument()
        })
      })
    })

    // Guards keep-open-on-error: drawers that own their close (close on success,
    // stay open on a failed mutation) pass closeOnSubmitSuccess=false. The form
    // drawer must then forward the submit raw and never auto-close.
    describe('WHEN closeOnSubmitSuccess is false and the form is submitted', () => {
      it('THEN should call submit but leave the drawer open', async () => {
        const { mockSubmit } = await showDrawer({ closeOnSubmitSuccess: false })

        await waitFor(() => {
          expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
        })

        const form = document.getElementById('test-form') as HTMLFormElement

        await act(async () => {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        })

        act(() => {
          jest.advanceTimersByTime(500)
        })

        await waitFor(() => {
          expect(mockSubmit).toHaveBeenCalled()
        })
        expect(screen.getByTestId(BASE_DRAWER_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN a secondaryAction is provided', () => {
      it('THEN should render it in the actions bar', async () => {
        await showDrawer({
          secondaryAction: <button data-test="form-drawer-secondary-action">Delete</button>,
        })

        await waitFor(() => {
          expect(screen.getByTestId('form-drawer-secondary-action')).toBeInTheDocument()
        })
      })
    })
  })
})
