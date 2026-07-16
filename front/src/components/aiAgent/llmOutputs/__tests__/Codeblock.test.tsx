import { act, cleanup, render, screen, waitFor } from '@testing-library/react'

// ---------------------------------------------------------------------------
// Component under test — imported AFTER mocks are installed.
// ---------------------------------------------------------------------------

import { Codeblock } from '../Codeblock'

// ---------------------------------------------------------------------------
// Mocks — these run before any module code thanks to Jest hoisting.
//
// The codeToHtml / loadLanguage jest.fn() instances must be created INSIDE
// the factory to avoid temporal dead zone issues with `const` + jest.mock
// hoisting. They are exposed via `__*` keys for test manipulation.
// ---------------------------------------------------------------------------

jest.mock('shiki/bundle/web', () => {
  const codeToHtmlMock = jest.fn()
  const loadLanguageMock = jest.fn(() => Promise.resolve())

  return {
    bundledLanguages: { javascript: jest.fn(), typescript: jest.fn(), css: jest.fn() },
    createHighlighter: jest.fn(() =>
      Promise.resolve({
        codeToHtml: codeToHtmlMock,
        loadLanguage: loadLanguageMock,
      }),
    ),
    __codeToHtmlMock: codeToHtmlMock,
    __loadLanguageMock: loadLanguageMock,
  }
})

jest.mock('shiki/bundle/full', () => ({
  // 'go' is in the full bundle (can be lazy-loaded), 'brainfuck' is not.
  bundledLanguages: { go: jest.fn(), ruby: jest.fn() },
}))

jest.mock('shiki/themes/catppuccin-latte.mjs', () => ({}), { virtual: true })

jest.mock('@llm-ui/code', () => ({
  loadHighlighter: (highlighterPromise: Promise<unknown>) => {
    let instance: unknown

    return {
      getHighlighter: () => instance,
      highlighterPromise: highlighterPromise.then((h) => {
        instance = h
        return h
      }),
    }
  },

  // Minimal reimplementation — extracts language & code from a fenced block.
  parseCompleteMarkdownCodeBlock: (codeBlock: string) => {
    const lines = codeBlock.split('\n')
    const match = lines[0]?.match(/^`{3}([a-zA-Z0-9_-]*)/)
    const language = match?.[1] || undefined

    return {
      language: language || undefined,
      code: lines.slice(1, -1).join('\n'),
      metaString: undefined,
    }
  },
}))

jest.mock('html-react-parser', () => ({
  __esModule: true,
  default: (html: string) => <div dangerouslySetInnerHTML={{ __html: html }} />,
}))

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

interface WebBundleMocks {
  __codeToHtmlMock: jest.Mock
  __loadLanguageMock: jest.Mock
}

function getWebBundleMocks(): WebBundleMocks {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  return require('shiki/bundle/web') as WebBundleMocks
}

function renderCodeblock(markdownCodeBlock: string) {
  return render(
    <Codeblock
      // Only `output` is used by the component — the other BlockMatch fields
      // are irrelevant for these tests so we cast to avoid boilerplate.
      blockMatch={{ output: markdownCodeBlock } as Parameters<typeof Codeblock>[0]['blockMatch']}
    />,
  )
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Codeblock', () => {
  let mockCodeToHtml: jest.Mock
  let mockLoadLanguage: jest.Mock

  beforeEach(() => {
    const mocks = getWebBundleMocks()

    mockCodeToHtml = mocks.__codeToHtmlMock
    mockLoadLanguage = mocks.__loadLanguageMock
  })

  afterEach(() => {
    cleanup()
    mockCodeToHtml.mockReset()
    mockLoadLanguage.mockReset()
  })

  describe('when Shiki throws "Language not found" (original bug)', () => {
    it('catches the error and falls back to text instead of crashing', async () => {
      // Reproduce the exact Shiki error users were hitting.
      // Use a language NOT in bundledLanguages (full bundle) so no lazy-load
      // is attempted — this isolates the try-catch fallback behavior.
      //
      // Before the fix, useCodeBlockToHtml from @llm-ui/code called
      // codeToHtml without a try-catch, so this error crashed the
      // entire React component tree.
      mockCodeToHtml.mockImplementation((_code: string, options: { lang: string }) => {
        if (options.lang === 'brainfuck') {
          throw new Error('Language `brainfuck` not found, you may need to load it first')
        }

        return `<pre class="shiki"><code>${_code}</code></pre>`
      })

      await act(async () => {
        renderCodeblock('```brainfuck\n++++[>++++++++<-]\n```')
      })

      await waitFor(() => {
        expect(mockCodeToHtml).toHaveBeenCalled()
      })

      // First call attempted the original language…
      expect(mockCodeToHtml).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ lang: 'brainfuck' }),
      )

      // …then the catch block retried with text.
      expect(mockCodeToHtml).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ lang: 'text' }),
      )

      // No lazy-load attempted because 'brainfuck' isn't in the full bundle.
      expect(mockLoadLanguage).not.toHaveBeenCalled()

      // The component rendered successfully — no crash.
      expect(screen.getByText('++++[>++++++++<-]')).toBeInTheDocument()
    })

    it('lazy-loads a language from the full bundle then re-renders with highlighting', async () => {
      // 'go' is in the full bundle but NOT in the web bundle.
      // First render: codeToHtml('go') throws → shows text + triggers lazy-load.
      // After loadLanguage resolves: re-render → codeToHtml('go') succeeds.
      let goLoaded = false

      mockCodeToHtml.mockImplementation((_code: string, options: { lang: string }) => {
        if (options.lang === 'go' && !goLoaded) {
          throw new Error('Language `go` not found, you may need to load it first')
        }

        return `<pre class="shiki"><code>${_code}</code></pre>`
      })

      mockLoadLanguage.mockImplementation(() => {
        goLoaded = true
        return Promise.resolve()
      })

      await act(async () => {
        renderCodeblock('```go\npackage main\n```')
      })

      // loadLanguage was called for the missing 'go' grammar.
      expect(mockLoadLanguage).toHaveBeenCalled()

      // After the lazy-load resolves, the component re-renders with 'go'.
      await waitFor(() => {
        expect(mockCodeToHtml).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({ lang: 'go' }),
        )
      })

      expect(screen.getByText('package main')).toBeInTheDocument()
    })

    it('retries lazy-loading after a transient failure', async () => {
      // Simulate a network error on the first lazy-load attempt (e.g. chunk
      // failed to fetch). The .catch() handler should remove the language from
      // lazyLoadRequested so the next render can retry.
      let rubyLoaded = false

      mockCodeToHtml.mockImplementation((_code: string, options: { lang: string }) => {
        if (options.lang === 'ruby' && !rubyLoaded) {
          throw new Error('Language `ruby` not found, you may need to load it first')
        }

        return `<pre class="shiki"><code>${_code}</code></pre>`
      })

      // First attempt: reject (transient network failure).
      mockLoadLanguage.mockRejectedValueOnce(new Error('Failed to fetch chunk'))

      const { rerender } = await act(async () => renderCodeblock('```ruby\nputs "hello"\n```'))

      // The lazy-load was attempted and failed.
      await waitFor(() => {
        expect(mockLoadLanguage).toHaveBeenCalledTimes(1)
      })

      // Component shows text fallback — no crash.
      expect(screen.getByText('puts "hello"')).toBeInTheDocument()

      // Second attempt: succeed now that the "network" is back.
      mockLoadLanguage.mockImplementation(() => {
        rubyLoaded = true
        return Promise.resolve()
      })

      // Trigger a re-render (e.g. parent streams a new token).
      await act(async () => {
        rerender(
          <Codeblock
            blockMatch={
              { output: '```ruby\nputs "hello"\n```' } as Parameters<
                typeof Codeblock
              >[0]['blockMatch']
            }
          />,
        )
      })

      // The retry succeeded — loadLanguage called a second time.
      await waitFor(() => {
        expect(mockLoadLanguage).toHaveBeenCalledTimes(2)
      })

      expect(screen.getByText('puts "hello"')).toBeInTheDocument()
    })
  })

  describe('when the language is already loaded (web bundle)', () => {
    it('renders highlighted code on the first attempt without lazy-loading', async () => {
      mockCodeToHtml.mockReturnValue('<pre class="shiki"><code>const x = 1</code></pre>')

      await act(async () => {
        renderCodeblock('```javascript\nconst x = 1\n```')
      })

      await waitFor(() => {
        expect(mockCodeToHtml).toHaveBeenCalled()
      })

      // Only one call — no fallback needed.
      expect(mockCodeToHtml).toHaveBeenCalledTimes(1)
      expect(mockCodeToHtml).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ lang: 'javascript' }),
      )

      // No lazy-loading triggered.
      expect(mockLoadLanguage).not.toHaveBeenCalled()

      expect(screen.getByText('const x = 1')).toBeInTheDocument()
    })
  })

  describe('when no language is specified in the code block', () => {
    it('defaults to text', async () => {
      mockCodeToHtml.mockReturnValue('<pre class="shiki"><code>some code</code></pre>')

      await act(async () => {
        renderCodeblock('```\nsome code\n```')
      })

      await waitFor(() => {
        expect(mockCodeToHtml).toHaveBeenCalled()
      })

      expect(mockCodeToHtml).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ lang: 'text' }),
      )

      expect(screen.getByText('some code')).toBeInTheDocument()
    })
  })
})
