import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'

import { slashCommandDefinitions, SlashCommands } from '../SlashCommands'

const mockDestroyPopup = jest.fn()
const mockHidePopup = jest.fn()
const mockSetProps = jest.fn()
const mockDestroyRenderer = jest.fn()
const mockUpdateProps = jest.fn()
const mockRendererElement = document.createElement('div')

jest.mock('tippy.js', () => ({
  __esModule: true,
  default: jest
    .fn()
    .mockImplementation(() => [
      { destroy: mockDestroyPopup, hide: mockHidePopup, setProps: mockSetProps },
    ]),
}))

jest.mock('@tiptap/react', () => ({
  ReactRenderer: jest.fn().mockImplementation(() => ({
    element: mockRendererElement,
    destroy: mockDestroyRenderer,
    updateProps: mockUpdateProps,
    ref: null,
  })),
}))

jest.mock('@tiptap/suggestion', () => {
  const { Plugin, PluginKey } = jest.requireActual('@tiptap/pm/state')

  return {
    __esModule: true,
    default: jest.fn().mockReturnValue(new Plugin({ key: new PluginKey('mockSuggestion') })),
  }
})

const mockTranslate = (key: string): string => {
  const translations: Record<string, string> = {
    text_1774281559656dn2u208gh80: 'Heading 1',
    text_1774281559656pla0xamsvmf: 'Large section heading',
    text_1774281559657ec0exeaqqd3: 'Heading 2',
    text_1774281559657q7h8pu6455p: 'Medium section heading',
    text_1774281559657t0kkn628zdy: 'Heading 3',
    text_1774281559657o48ilt0rq5y: 'Small section heading',
    text_1774281559657cbz20fzcjka: 'Bullet List',
    text_17742815596575m8mqwrg1qy: 'Unordered list',
    text_1774281559657yc3z031hm6x: 'Table',
    text_1774281559657y9saycc2aev: 'Insert a 3x3 table',
    text_1774281559657l4kkx9ws4mz: 'Code Block',
    text_1774281559657qdknwsvn5ka: 'Insert a code block',
    text_1782889379261hdcd0jhzdm6: 'Discount',
    text_178288937926153opd9g5cwg: 'Apply a coupon discount to this quote',
  }

  return translations[key] ?? key
}

const resolveItems = () =>
  slashCommandDefinitions.map((def) => ({
    title: mockTranslate(def.titleKey),
    description: mockTranslate(def.descriptionKey),
    command: def.command,
  }))

const createSlashEditor = () =>
  new Editor({
    extensions: [StarterKit, SlashCommands.configure({ translate: mockTranslate })],
    content: '<p>Hello</p>',
  })

describe('SlashCommands', () => {
  describe('slashCommandDefinitions', () => {
    describe('GIVEN the slash command definitions are defined', () => {
      it('THEN should contain all expected translation keys', () => {
        const titleKeys = slashCommandDefinitions.map((def) => def.titleKey)

        expect(titleKeys).toEqual([
          'text_1774281559656dn2u208gh80',
          'text_1774281559657ec0exeaqqd3',
          'text_1774281559657t0kkn628zdy',
          'text_1774281559657cbz20fzcjka',
          'text_1774281559657yc3z031hm6x',
          'text_1774281559657l4kkx9ws4mz',
        ])
      })

      it.each(slashCommandDefinitions)(
        'THEN each definition should have a descriptionKey and command',
        (def) => {
          expect(def.descriptionKey).toBeTruthy()
          expect(typeof def.command).toBe('function')
        },
      )
    })

    describe('GIVEN the suggestion config', () => {
      describe('WHEN filtering resolved items with a query', () => {
        const filterItems = (query: string) => {
          const items = resolveItems()

          return items.filter((item) => item.title.toLowerCase().includes(query.toLowerCase()))
        }

        it('THEN should return all items for empty query', () => {
          expect(filterItems('')).toHaveLength(6)
        })

        it('THEN should filter items by title case-insensitively', () => {
          const results = filterItems('head')

          expect(results).toHaveLength(3)
          expect(results.map((r) => r.title)).toEqual(['Heading 1', 'Heading 2', 'Heading 3'])
        })

        it('THEN should return empty array for non-matching query', () => {
          expect(filterItems('nonexistent')).toHaveLength(0)
        })

        it('THEN should find table command', () => {
          const results = filterItems('table')

          expect(results).toHaveLength(1)
          expect(results[0].title).toBe('Table')
        })
      })
    })

    describe('GIVEN a command is executed', () => {
      const createMockEditor = () => {
        const runMock = jest.fn()
        const chainMethods: Record<string, jest.Mock> = {}

        const handler: ProxyHandler<Record<string, jest.Mock>> = {
          get: (_target, prop: string) => {
            if (prop === 'run') return runMock
            if (!chainMethods[prop]) {
              chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
            }

            return chainMethods[prop]
          },
        }

        return {
          chain: jest.fn().mockReturnValue(new Proxy({}, handler)),
          runMock,
        }
      }

      it.each([
        ['Heading 1', 0],
        ['Heading 2', 1],
        ['Heading 3', 2],
        ['Bullet List', 3],
        ['Table', 4],
        ['Code Block', 5],
      ])('WHEN "%s" command is called THEN should invoke editor chain', (_, index) => {
        const mockEditor = createMockEditor()

        slashCommandDefinitions[index].command(
          mockEditor as unknown as Parameters<
            (typeof slashCommandDefinitions)[number]['command']
          >[0],
        )

        expect(mockEditor.chain).toHaveBeenCalled()
        expect(mockEditor.runMock).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the suggestion render lifecycle', () => {
    const tippy = jest.requireMock('tippy.js').default as jest.Mock

    const getRenderCallbacks = () => {
      const options = (
        SlashCommands.config.addOptions as unknown as () => {
          suggestion: {
            render: () => {
              onStart: (props: Record<string, unknown>) => void
              onUpdate: (props: Record<string, unknown>) => void
              onKeyDown: (props: { event: { key: string } }) => boolean
              onExit: () => void
            }
          }
        }
      )()

      return options.suggestion.render()
    }

    const createSuggestionProps = (
      clientRect?: (() => DOMRect) | null,
    ): Record<string, unknown> => ({
      editor: {},
      clientRect,
    })

    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN onStart is called with a valid clientRect', () => {
      it('THEN should pass the clientRect result to tippy', () => {
        const callbacks = getRenderCallbacks()
        const rect = new DOMRect(10, 20, 100, 50)
        const props = createSuggestionProps(() => rect)

        callbacks.onStart(props)

        const tippyCall = tippy.mock.calls[0]
        const getReferenceClientRect = tippyCall[1].getReferenceClientRect as () => DOMRect

        expect(getReferenceClientRect()).toEqual(rect)
      })
    })

    describe('WHEN onStart is called with null clientRect', () => {
      it('THEN should fall back to an empty DOMRect', () => {
        const callbacks = getRenderCallbacks()
        const props = createSuggestionProps(null)

        callbacks.onStart(props)

        const tippyCall = tippy.mock.calls[0]
        const getReferenceClientRect = tippyCall[1].getReferenceClientRect as () => DOMRect
        const result = getReferenceClientRect()

        expect(result).toBeInstanceOf(DOMRect)
        expect(result.x).toBe(0)
        expect(result.y).toBe(0)
        expect(result.width).toBe(0)
        expect(result.height).toBe(0)
      })
    })

    describe('WHEN onStart is called with undefined clientRect', () => {
      it('THEN should fall back to an empty DOMRect', () => {
        const callbacks = getRenderCallbacks()
        const props = createSuggestionProps(undefined)

        callbacks.onStart(props)

        const tippyCall = tippy.mock.calls[0]
        const getReferenceClientRect = tippyCall[1].getReferenceClientRect as () => DOMRect
        const result = getReferenceClientRect()

        expect(result).toBeInstanceOf(DOMRect)
        expect(result.width).toBe(0)
      })
    })

    describe('WHEN onUpdate is called with null clientRect', () => {
      it('THEN should pass a fallback DOMRect to setProps', () => {
        const callbacks = getRenderCallbacks()

        // onStart must be called first to initialize renderer/popup
        callbacks.onStart(createSuggestionProps(() => new DOMRect()))

        callbacks.onUpdate(createSuggestionProps(null))

        const setPropsCall = mockSetProps.mock.calls[0]
        const getReferenceClientRect = setPropsCall[0].getReferenceClientRect as () => DOMRect
        const result = getReferenceClientRect()

        expect(result).toBeInstanceOf(DOMRect)
        expect(result.width).toBe(0)
      })
    })

    describe('WHEN onExit is called', () => {
      it('THEN should destroy popup and renderer', () => {
        const callbacks = getRenderCallbacks()

        callbacks.onStart(createSuggestionProps(() => new DOMRect()))
        callbacks.onExit()

        expect(mockDestroyPopup).toHaveBeenCalled()
        expect(mockDestroyRenderer).toHaveBeenCalled()
      })
    })

    describe('WHEN onKeyDown is called with Escape', () => {
      it('THEN should hide the popup and return true', () => {
        const callbacks = getRenderCallbacks()

        callbacks.onStart(createSuggestionProps(() => new DOMRect()))

        const result = callbacks.onKeyDown({ event: { key: 'Escape' } })

        expect(mockHidePopup).toHaveBeenCalled()
        expect(result).toBe(true)
      })
    })

    describe('WHEN onKeyDown is called with a non-Escape key', () => {
      it('THEN should return false when ref is null', () => {
        const callbacks = getRenderCallbacks()

        callbacks.onStart(createSuggestionProps(() => new DOMRect()))

        const result = callbacks.onKeyDown({ event: { key: 'Enter' } })

        expect(mockHidePopup).not.toHaveBeenCalled()
        expect(result).toBe(false)
      })
    })
  })

  describe('GIVEN the triggerMenu storage API', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN the extension storage is initialized', () => {
      it('THEN should define triggerMenu as null by default', () => {
        const storageInit = SlashCommands.config.addStorage as unknown as () => {
          triggerMenu: null
        }
        const storage = storageInit()

        expect(storage.triggerMenu).toBeNull()
      })
    })

    describe('WHEN the editor is created with SlashCommands', () => {
      it('THEN should populate triggerMenu as a function in storage', () => {
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as Record<string, unknown>

        expect(typeof storage.triggerMenu).toBe('function')

        editor.destroy()
      })
    })

    describe('WHEN triggerMenu is called', () => {
      it('THEN should create a ReactRenderer with resolved items and a command callback', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        expect(ReactRendererMock).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            props: expect.objectContaining({
              items: expect.any(Array),
              command: expect.any(Function),
            }),
            editor,
          }),
        )

        // Clean up
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })

      it('THEN should create a tippy popup with correct options', () => {
        const tippyMock = jest.requireMock('tippy.js').default as jest.Mock
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }
        const clientRect = () => new DOMRect(10, 20, 100, 50)

        tippyMock.mockClear()
        storage.triggerMenu(clientRect)

        expect(tippyMock).toHaveBeenCalledWith(
          'body',
          expect.objectContaining({
            getReferenceClientRect: clientRect,
            showOnCreate: true,
            interactive: true,
            trigger: 'manual',
            placement: 'bottom-start',
          }),
        )

        // Clean up
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN Escape is pressed while the popup is open', () => {
      it('THEN should destroy the popup and renderer', () => {
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        storage.triggerMenu(() => new DOMRect())

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))

        expect(mockDestroyPopup).toHaveBeenCalled()
        expect(mockDestroyRenderer).toHaveBeenCalled()

        editor.destroy()
      })

      it('THEN should prevent default on the Escape event', () => {
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        storage.triggerMenu(() => new DOMRect())

        const escapeEvent = new KeyboardEvent('keydown', {
          key: 'Escape',
          bubbles: true,
          cancelable: true,
        })
        const preventDefaultSpy = jest.spyOn(escapeEvent, 'preventDefault')

        document.dispatchEvent(escapeEvent)

        expect(preventDefaultSpy).toHaveBeenCalled()

        editor.destroy()
      })
    })

    describe('WHEN clicking outside the popup', () => {
      it('THEN should destroy the popup and renderer', () => {
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        storage.triggerMenu(() => new DOMRect())

        document.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))

        expect(mockDestroyPopup).toHaveBeenCalled()
        expect(mockDestroyRenderer).toHaveBeenCalled()

        editor.destroy()
      })
    })

    describe('WHEN clicking inside the popup element', () => {
      it('THEN should not destroy the popup', () => {
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        storage.triggerMenu(() => new DOMRect())

        // Append renderer element to DOM so events propagate through capture phase
        document.body.appendChild(mockRendererElement)
        mockRendererElement.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))
        document.body.removeChild(mockRendererElement)

        expect(mockDestroyPopup).not.toHaveBeenCalled()
        expect(mockDestroyRenderer).not.toHaveBeenCalled()

        // Clean up
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN a command is selected from the menu', () => {
      it('THEN should execute the command with the editor and destroy the popup', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          command: (item: { title: string; description: string; command: jest.Mock }) => void
        }
        const mockCommand = jest.fn()

        rendererProps.command({
          title: 'Test',
          description: 'Test command',
          command: mockCommand,
        })

        expect(mockCommand).toHaveBeenCalledWith(editor)
        expect(mockDestroyPopup).toHaveBeenCalled()
        expect(mockDestroyRenderer).toHaveBeenCalled()

        editor.destroy()
      })
    })

    describe('WHEN destroy is called multiple times', () => {
      it('THEN should only destroy once (idempotent)', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        // Call the command callback twice — second call hits the `if (destroyed) return` guard
        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          command: (item: { title: string; description: string; command: jest.Mock }) => void
        }
        const mockCommand = jest.fn()
        const item = { title: 'Test', description: 'Test', command: mockCommand }

        rendererProps.command(item)
        rendererProps.command(item)

        expect(mockCommand).toHaveBeenCalledTimes(2)
        expect(mockDestroyPopup).toHaveBeenCalledTimes(1)
        expect(mockDestroyRenderer).toHaveBeenCalledTimes(1)

        editor.destroy()
      })
    })

    describe('WHEN a non-Escape key is pressed and ref handles it', () => {
      it('THEN should delegate to renderer ref onKeyDown and prevent default', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnKeyDown = jest.fn().mockReturnValue(true)

        ReactRendererMock.mockImplementationOnce(() => ({
          element: mockRendererElement,
          destroy: mockDestroyRenderer,
          updateProps: mockUpdateProps,
          ref: { onKeyDown: mockOnKeyDown },
        }))

        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        storage.triggerMenu(() => new DOMRect())

        const arrowEvent = new KeyboardEvent('keydown', {
          key: 'ArrowDown',
          bubbles: true,
          cancelable: true,
        })
        const preventDefaultSpy = jest.spyOn(arrowEvent, 'preventDefault')
        const stopPropagationSpy = jest.spyOn(arrowEvent, 'stopPropagation')

        document.dispatchEvent(arrowEvent)

        expect(mockOnKeyDown).toHaveBeenCalled()
        expect(preventDefaultSpy).toHaveBeenCalled()
        expect(stopPropagationSpy).toHaveBeenCalled()

        // Clean up
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN a non-Escape key is pressed and ref does not handle it', () => {
      it('THEN should not prevent default', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnKeyDown = jest.fn().mockReturnValue(false)

        ReactRendererMock.mockImplementationOnce(() => ({
          element: mockRendererElement,
          destroy: mockDestroyRenderer,
          updateProps: mockUpdateProps,
          ref: { onKeyDown: mockOnKeyDown },
        }))

        const editor = createSlashEditor()
        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        storage.triggerMenu(() => new DOMRect())

        const arrowEvent = new KeyboardEvent('keydown', {
          key: 'ArrowDown',
          bubbles: true,
          cancelable: true,
        })
        const preventDefaultSpy = jest.spyOn(arrowEvent, 'preventDefault')

        document.dispatchEvent(arrowEvent)

        expect(mockOnKeyDown).toHaveBeenCalled()
        expect(preventDefaultSpy).not.toHaveBeenCalled()

        // Clean up
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })
  })

  describe('GIVEN onPricingCommand is configured', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN the pricing command is executed via triggerMenu', () => {
      it('THEN should call onPricingCommand with an onSave callback', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
          command: (item: { title: string; command: (editor: Editor) => void }) => void
        }
        const pricingItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        expect(pricingItem).toBeDefined()

        // Execute the pricing command through the menu's command callback
        rendererProps.command(
          pricingItem as { title: string; disabled: boolean; command: jest.Mock },
        )

        expect(mockOnPricingCommand).toHaveBeenCalledWith({ onSave: expect.any(Function) })

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN onSave is invoked from the pricing command callback', () => {
      it('THEN should call editor.chain().focus().insertContent() with the pricingBlock node', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
          command: (item: { title: string; command: (editor: Editor) => void }) => void
        }
        const pricingItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        // Spy on the editor's chain to track calls
        const runMock = jest.fn()
        const chainMethods: Record<string, jest.Mock> = {}
        const handler: ProxyHandler<Record<string, jest.Mock>> = {
          get: (_target, prop: string) => {
            if (prop === 'run') return runMock
            if (!chainMethods[prop]) {
              chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
            }

            return chainMethods[prop]
          },
        }

        const mockEditorForCommand = {
          chain: jest.fn().mockReturnValue(new Proxy({}, handler)),
          commands: { setTextSelection: jest.fn() },
          state: { selection: {} },
        } as unknown as Editor

        // Execute the pricing item's command directly with our mock editor
        ;(pricingItem as { command: (e: Editor) => void }).command(mockEditorForCommand)

        // Capture onSave from the mock
        const capturedParams = mockOnPricingCommand.mock.calls[0][0] as {
          onSave: (...args: unknown[]) => void
        }

        const attrs = { pricingType: 'plan', entityIds: ['plan-1'] }

        capturedParams.onSave(attrs, {})

        expect(mockEditorForCommand.chain).toHaveBeenCalled()
        expect(chainMethods['focus']).toHaveBeenCalled()
        expect(chainMethods['insertContent']).toHaveBeenCalledWith({
          type: 'pricingBlock',
          attrs,
        })
        expect(runMock).toHaveBeenCalled()

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN onSave is invoked and the selection is a NodeSelection', () => {
      it('THEN should move cursor past the inserted node with setTextSelection', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
          command: (item: { title: string; command: (editor: Editor) => void }) => void
        }
        const pricingItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        const runMock = jest.fn()
        const chainMethods: Record<string, jest.Mock> = {}
        const handler: ProxyHandler<Record<string, jest.Mock>> = {
          get: (_target, prop: string) => {
            if (prop === 'run') return runMock
            if (!chainMethods[prop]) {
              chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
            }

            return chainMethods[prop]
          },
        }

        // Create a fake NodeSelection-like object using the actual NodeSelection class
        const { NodeSelection } = jest.requireActual('@tiptap/pm/state') as {
          NodeSelection: { prototype: object }
        }
        const fakeNodeSelection = Object.create(NodeSelection.prototype, {
          from: { value: 5 },
          node: { value: { nodeSize: 3 } },
        })

        const setTextSelectionMock = jest.fn()
        const mockEditorForCommand = {
          chain: jest.fn().mockReturnValue(new Proxy({}, handler)),
          commands: { setTextSelection: setTextSelectionMock },
          state: { selection: fakeNodeSelection },
        } as unknown as Editor

        // Execute the pricing item's command directly with our mock editor
        ;(pricingItem as { command: (e: Editor) => void }).command(mockEditorForCommand)

        const capturedParams = mockOnPricingCommand.mock.calls[0][0] as {
          onSave: (...args: unknown[]) => void
        }

        capturedParams.onSave({ pricingType: 'addOns', entityIds: ['addon-1'] }, {})

        // Should move cursor past the node: from(5) + nodeSize(3) = 8
        expect(setTextSelectionMock).toHaveBeenCalledWith(8)

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })
  })

  describe('GIVEN the suggestion command callback', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN a slash command item is selected from the suggestion dropdown', () => {
      it('THEN should delete the range and execute the item command', () => {
        const options = (
          SlashCommands.config.addOptions as unknown as () => {
            suggestion: {
              command: (params: {
                editor: Editor
                range: { from: number; to: number }
                props: { command: (editor: Editor) => void }
              }) => void
            }
          }
        )()

        const runMock = jest.fn()
        const chainMethods: Record<string, jest.Mock> = {}
        const handler: ProxyHandler<Record<string, jest.Mock>> = {
          get: (_target, prop: string) => {
            if (prop === 'run') return runMock
            if (!chainMethods[prop]) {
              chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
            }

            return chainMethods[prop]
          },
        }

        const mockEditor = {
          chain: jest.fn().mockReturnValue(new Proxy({}, handler)),
        } as unknown as Editor

        const mockItemCommand = jest.fn()
        const range = { from: 0, to: 5 }

        options.suggestion.command({
          editor: mockEditor,
          range,
          props: { command: mockItemCommand } as unknown as { command: (editor: Editor) => void },
        })

        // Should delete the slash command range first
        expect(mockEditor.chain).toHaveBeenCalled()
        expect(chainMethods['focus']).toHaveBeenCalled()
        expect(chainMethods['deleteRange']).toHaveBeenCalledWith(range)
        expect(runMock).toHaveBeenCalled()

        // Then execute the item's command
        expect(mockItemCommand).toHaveBeenCalledWith(mockEditor)
      })
    })
  })

  describe('GIVEN isPricingDisabled is configured for the Suggestion plugin items filter', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN isPricingDisabled returns true', () => {
      it('THEN should mark the pricing item as disabled in the Suggestion items', () => {
        const SuggestionMock = jest.requireMock('@tiptap/suggestion').default as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
              isPricingDisabled: () => true,
            }),
          ],
          content: '<p>Hello</p>',
        })

        // Get the items callback passed to Suggestion
        const lastCallIndex = SuggestionMock.mock.calls.length - 1
        const suggestionConfig = SuggestionMock.mock.calls[lastCallIndex][0] as {
          items: (params: { query: string }) => Array<{ title: string; disabled: boolean }>
        }
        const items = suggestionConfig.items({ query: '' })

        const pricingItem = items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        expect(pricingItem?.disabled).toBe(true)

        // Non-pricing items should not be disabled
        const nonPricingItems = items.filter(
          (item) => item.title !== mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        nonPricingItems.forEach((item) => {
          expect(item.disabled).toBe(false)
        })

        editor.destroy()
      })
    })

    describe('WHEN isPricingDisabled returns false', () => {
      it('THEN should not mark the pricing item as disabled in the Suggestion items', () => {
        const SuggestionMock = jest.requireMock('@tiptap/suggestion').default as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
              isPricingDisabled: () => false,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const lastCallIndex = SuggestionMock.mock.calls.length - 1
        const suggestionConfig = SuggestionMock.mock.calls[lastCallIndex][0] as {
          items: (params: { query: string }) => Array<{ title: string; disabled: boolean }>
        }
        const items = suggestionConfig.items({ query: '' })

        const pricingItem = items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        expect(pricingItem?.disabled).toBe(false)

        editor.destroy()
      })
    })

    describe('WHEN filtering Suggestion items by query with pricing enabled', () => {
      it('THEN should filter items and apply isPricingDisabled to the pricing item', () => {
        const SuggestionMock = jest.requireMock('@tiptap/suggestion').default as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
              isPricingDisabled: () => true,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const lastCallIndex = SuggestionMock.mock.calls.length - 1
        const suggestionConfig = SuggestionMock.mock.calls[lastCallIndex][0] as {
          items: (params: { query: string }) => Array<{ title: string; disabled: boolean }>
        }

        // Filter by a query that matches only pricing
        const pricingTitle = mockTranslate('text_1779802343219a1cl5ckvtrn')
        const items = suggestionConfig.items({ query: pricingTitle })

        expect(items).toHaveLength(1)
        expect(items[0].title).toBe(pricingTitle)
        expect(items[0].disabled).toBe(true)

        editor.destroy()
      })
    })
  })

  describe('GIVEN isPricingDisabled is configured', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN isPricingDisabled returns true', () => {
      it('THEN should mark the pricing item as disabled in triggerMenu', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
              isPricingDisabled: () => true,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; disabled: boolean }>
        }
        const pricingItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        expect(pricingItem?.disabled).toBe(true)

        // Non-pricing items should not be disabled
        const nonPricingItems = rendererProps.items.filter(
          (item) => item.title !== mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        nonPricingItems.forEach((item) => {
          expect(item.disabled).toBe(false)
        })

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN isPricingDisabled returns false', () => {
      it('THEN should not mark the pricing item as disabled', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
              isPricingDisabled: () => false,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; disabled: boolean }>
        }
        const pricingItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        )

        expect(pricingItem?.disabled).toBe(false)

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN a disabled item command is invoked in triggerMenu', () => {
      it('THEN should not execute the command and not destroy the popup', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnPricingCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onPricingCommand: mockOnPricingCommand,
              isPricingDisabled: () => true,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; disabled: boolean; command: jest.Mock }>
          command: (item: { title: string; disabled: boolean; command: jest.Mock }) => void
        }
        const pricingItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1779802343219a1cl5ckvtrn'),
        ) as { title: string; disabled: boolean; command: jest.Mock }

        // Invoking the command callback with a disabled item should be a no-op
        rendererProps.command(pricingItem)

        expect(mockOnPricingCommand).not.toHaveBeenCalled()
        // Popup should not be destroyed (still open)
        expect(mockDestroyPopup).not.toHaveBeenCalled()

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })
  })

  describe('GIVEN onDiscountCommand is configured', () => {
    beforeEach(() => {
      jest.clearAllMocks()
    })

    describe('WHEN onDiscountCommand is provided', () => {
      it('THEN the resolved items should include a discount item', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnDiscountCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onDiscountCommand: mockOnDiscountCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
        }
        const discountItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1782889379261hdcd0jhzdm6'),
        )

        expect(discountItem).toBeDefined()

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN onDiscountCommand is omitted', () => {
      it('THEN the resolved items should not include a discount item', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
        }
        const discountItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1782889379261hdcd0jhzdm6'),
        )

        expect(discountItem).toBeUndefined()

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN the discount command is executed via triggerMenu', () => {
      it('THEN should call onDiscountCommand with an onSave callback', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnDiscountCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onDiscountCommand: mockOnDiscountCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
          command: (item: { title: string; command: (editor: Editor) => void }) => void
        }
        const discountItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1782889379261hdcd0jhzdm6'),
        )

        expect(discountItem).toBeDefined()

        rendererProps.command(
          discountItem as { title: string; disabled: boolean; command: jest.Mock },
        )

        expect(mockOnDiscountCommand).toHaveBeenCalledWith({ onSave: expect.any(Function) })

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN onSave is invoked from the discount command callback', () => {
      it('THEN should call editor.chain().focus().insertContent() with the discountBlock node', () => {
        const ReactRendererMock = jest.requireMock('@tiptap/react').ReactRenderer as jest.Mock
        const mockOnDiscountCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onDiscountCommand: mockOnDiscountCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const storage = (editor.storage as any).slashCommands as {
          triggerMenu: (clientRect: () => DOMRect) => void
        }

        ReactRendererMock.mockClear()
        storage.triggerMenu(() => new DOMRect())

        const rendererProps = ReactRendererMock.mock.calls[0][1].props as {
          items: Array<{ title: string; command: (editor: Editor) => void }>
          command: (item: { title: string; command: (editor: Editor) => void }) => void
        }
        const discountItem = rendererProps.items.find(
          (item) => item.title === mockTranslate('text_1782889379261hdcd0jhzdm6'),
        )

        // Spy on the editor's chain to track calls
        const runMock = jest.fn()
        const chainMethods: Record<string, jest.Mock> = {}
        const handler: ProxyHandler<Record<string, jest.Mock>> = {
          get: (_target, prop: string) => {
            if (prop === 'run') return runMock
            if (!chainMethods[prop]) {
              chainMethods[prop] = jest.fn().mockReturnValue(new Proxy({}, handler))
            }

            return chainMethods[prop]
          },
        }

        const mockEditorForCommand = {
          chain: jest.fn().mockReturnValue(new Proxy({}, handler)),
          commands: { setTextSelection: jest.fn() },
          state: { selection: {} },
        } as unknown as Editor

        // Execute the discount item's command directly with our mock editor
        ;(discountItem as { command: (e: Editor) => void }).command(mockEditorForCommand)

        // Capture the onSave callback
        const capturedParams = mockOnDiscountCommand.mock.calls[0][0] as {
          onSave: (attrs: { couponId: string; localId: string }) => void
        }

        const attrs = { couponId: 'coupon-1', localId: 'local-1' }

        capturedParams.onSave(attrs)

        expect(mockEditorForCommand.chain).toHaveBeenCalled()
        expect(chainMethods['insertContent']).toHaveBeenCalledWith({
          type: 'discountBlock',
          attrs,
        })
        expect(runMock).toHaveBeenCalled()

        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
        editor.destroy()
      })
    })

    describe('WHEN discount item is in the Suggestion items', () => {
      it('THEN should never be disabled (unlimited coupons)', () => {
        const SuggestionMock = jest.requireMock('@tiptap/suggestion').default as jest.Mock
        const mockOnDiscountCommand = jest.fn()
        const editor = new Editor({
          extensions: [
            StarterKit,
            SlashCommands.configure({
              translate: mockTranslate,
              onDiscountCommand: mockOnDiscountCommand,
            }),
          ],
          content: '<p>Hello</p>',
        })

        const suggestionConfig = SuggestionMock.mock.calls[SuggestionMock.mock.calls.length - 1][0]
        const items = suggestionConfig.items({ query: '' })
        const discountItem = items.find(
          (item: { title: string }) =>
            item.title === mockTranslate('text_1782889379261hdcd0jhzdm6'),
        )

        expect(discountItem).toBeDefined()
        expect(discountItem?.disabled).toBe(false)

        editor.destroy()
      })
    })
  })
})
