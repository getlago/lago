import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Editor } from '@tiptap/react'

import { serializeUrl } from '~/core/serializers/serializeUrl'
import { render } from '~/test-utils'

import LinkPopperForm, {
  TOOLBAR_LINK_APPLY_BUTTON_TEST_ID,
  TOOLBAR_LINK_INPUT_TEST_ID,
  TOOLBAR_LINK_REMOVE_BUTTON_TEST_ID,
} from '../LinkPopperForm'

jest.mock('~/core/serializers/serializeUrl', () => ({
  serializeUrl: jest.fn().mockImplementation((url: string) => {
    try {
      return new URL(url).href
    } catch {
      return null
    }
  }),
}))

const createMockChain = () => {
  const chainMethods: Record<string, jest.Mock> = {}
  const runMock = jest.fn()

  const handler: ProxyHandler<Record<string, jest.Mock>> = {
    get: (_target, prop: string) => {
      if (prop === 'run') return runMock
      if (!chainMethods[prop]) {
        chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
      }

      return chainMethods[prop]
    },
  }

  return { proxy: new Proxy({}, handler), runMock, chainMethods }
}

const createMockEditor = (
  overrides: Record<string, boolean> = {},
  attributes: Record<string, Record<string, string>> = {},
) => {
  const { proxy, runMock, chainMethods } = createMockChain()

  return {
    editor: {
      isActive: jest.fn((type: string) => overrides[type] ?? false),
      getAttributes: jest.fn((type: string) => attributes[type] ?? {}),
      chain: jest.fn().mockReturnValue(proxy),
    } as unknown as Editor,
    runMock,
    chainMethods,
  }
}

describe('LinkPopperForm', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  it('should render the URL input and Apply button', async () => {
    const { editor } = createMockEditor()
    const closePopper = jest.fn()

    await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

    expect(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID)).toBeInTheDocument()
  })

  describe('WHEN entering a URL with http and clicking Apply', () => {
    it('should call editor chain with the URL', async () => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.type(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID), 'https://example.com')
      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(editor.chain).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
        expect(closePopper).toHaveBeenCalled()
      })
    })
  })

  describe('WHEN entering an invalid URL and clicking Apply', () => {
    it('should not call setLink', async () => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.type(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID), 'example.com')
      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(runMock).not.toHaveBeenCalled()
        expect(closePopper).not.toHaveBeenCalled()
      })
    })

    it('should display a validation error message', async () => {
      const user = userEvent.setup()
      const { editor } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.type(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID), 'example.com')
      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.getByTestId('text-field-error')).toBeInTheDocument()
      })
    })
  })

  describe('WHEN entering a valid URL after an error', () => {
    it('should clear the error message', async () => {
      const user = userEvent.setup()
      const { editor } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      const input = screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID)

      await user.type(input, 'example.com')
      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.getByTestId('text-field-error')).toBeInTheDocument()
      })

      await user.clear(input)
      await user.type(input, 'https://example.com')

      await waitFor(() => {
        expect(screen.queryByTestId('text-field-error')).not.toBeInTheDocument()
      })
    })
  })

  describe('WHEN clicking Apply with empty input', () => {
    it('should call unsetLink and close popper', async () => {
      const user = userEvent.setup()
      const { editor, runMock, chainMethods } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(chainMethods.unsetLink).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
        expect(closePopper).toHaveBeenCalled()
      })
    })
  })

  describe('WHEN pressing Enter in the input', () => {
    it('should submit the form', async () => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.type(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID), 'https://test.com{Enter}')

      await waitFor(() => {
        expect(editor.chain).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
      })
    })
  })

  describe('WHEN serializeUrl returns null for a URL that passes validation', () => {
    it('should display an error and not call setLink', async () => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor()
      const closePopper = jest.fn()

      jest.mocked(serializeUrl).mockReturnValueOnce(null)

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.type(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID), 'https://example.com')
      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(screen.getByTestId('text-field-error')).toBeInTheDocument()
      })

      expect(runMock).not.toHaveBeenCalled()
      expect(closePopper).not.toHaveBeenCalled()
    })
  })

  describe('WHEN link is active', () => {
    it('should show the Remove button', async () => {
      const { editor } = createMockEditor({ link: true })
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      expect(screen.getByTestId(TOOLBAR_LINK_REMOVE_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('should call unsetLink and closePopper when Remove is clicked', async () => {
      const user = userEvent.setup()
      const { editor, runMock } = createMockEditor({ link: true })
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      await user.click(screen.getByTestId(TOOLBAR_LINK_REMOVE_BUTTON_TEST_ID))

      expect(editor.chain).toHaveBeenCalled()
      expect(runMock).toHaveBeenCalled()
      expect(closePopper).toHaveBeenCalled()
    })

    it('should pre-fill the URL input with the current link href', async () => {
      const { editor } = createMockEditor(
        { link: true },
        { link: { href: 'https://existing-link.com' } },
      )
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      expect(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID)).toHaveValue(
        'https://existing-link.com',
      )
    })

    it('should allow editing the existing link URL and submitting', async () => {
      const user = userEvent.setup()
      const { editor, runMock, chainMethods } = createMockEditor(
        { link: true },
        { link: { href: 'https://old-url.com' } },
      )
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      const input = screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID)

      await user.clear(input)
      await user.type(input, 'https://new-url.com')
      await user.click(screen.getByTestId(TOOLBAR_LINK_APPLY_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(chainMethods.setLink).toHaveBeenCalled()
        expect(runMock).toHaveBeenCalled()
        expect(closePopper).toHaveBeenCalled()
      })
    })
  })

  describe('WHEN link is not active', () => {
    it('should not show the Remove button', async () => {
      const { editor } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      expect(screen.queryByTestId(TOOLBAR_LINK_REMOVE_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('should have empty URL input when no link is active', async () => {
      const { editor } = createMockEditor()
      const closePopper = jest.fn()

      await act(() => render(<LinkPopperForm editor={editor} closePopper={closePopper} />))

      expect(screen.getByTestId(TOOLBAR_LINK_INPUT_TEST_ID)).toHaveValue('')
    })
  })
})
