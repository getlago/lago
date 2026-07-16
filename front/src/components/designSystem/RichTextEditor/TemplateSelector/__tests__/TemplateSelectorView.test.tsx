import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { NodeViewProps } from '@tiptap/react'

import { render } from '~/test-utils'

import {
  TEMPLATE_SELECTOR_ITEM_TEST_ID,
  TEMPLATE_SELECTOR_VIEW_TEST_ID,
  TemplateSelectorView,
} from '../TemplateSelectorView'
import type { EditorTemplate } from '../types'

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  NodeViewWrapper: ({
    children,
    ...props
  }: {
    children: React.ReactNode
    as?: string
    className?: string
  }) => <div {...props}>{children}</div>,
}))

const mockTemplates: EditorTemplate[] = [
  {
    id: 'invoice-reminder',
    name: 'Invoice Reminder',
    description: 'A polite payment reminder email',
    content: '# Payment Reminder\n\nDear Customer',
  },
  {
    id: 'welcome-email',
    name: 'Welcome Email',
    description: 'Onboarding email for new customers',
    content: '# Welcome!\n\nHi there',
  },
]

const mockRun = jest.fn()
const mockSetContent = jest.fn(() => ({ run: mockRun }))
const mockFocus = jest.fn(() => ({ setContent: mockSetContent }))
const mockChain = jest.fn(() => ({ focus: mockFocus }))

const createNodeProps = (templates: EditorTemplate[] = []): NodeViewProps => {
  return {
    node: {
      attrs: { templates },
    },
    editor: {
      chain: mockChain,
    },
    extension: null as never,
    getPos: () => 0,
    updateAttributes: jest.fn(),
    deleteNode: () => {},
    selected: false,
    decorations: [],
    innerDecorations: null as never,
    HTMLAttributes: {},
    view: null as never,
  } as unknown as NodeViewProps
}

describe('TemplateSelectorView', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered with templates', () => {
    describe('WHEN templates are provided', () => {
      it('THEN should display the template list container', () => {
        render(<TemplateSelectorView {...createNodeProps(mockTemplates)} />)

        expect(screen.getByTestId(TEMPLATE_SELECTOR_VIEW_TEST_ID)).toBeInTheDocument()
      })

      it.each([
        ['Invoice Reminder', 'invoice-reminder'],
        ['Welcome Email', 'welcome-email'],
      ])('THEN should display the %s template button', (name, id) => {
        render(<TemplateSelectorView {...createNodeProps(mockTemplates)} />)

        const button = screen.getByTestId(`${TEMPLATE_SELECTOR_ITEM_TEST_ID}-${id}`)

        expect(button).toBeInTheDocument()
        expect(button).toHaveTextContent(name)
      })
    })

    describe('WHEN no templates are provided', () => {
      it('THEN should render an empty list', () => {
        render(<TemplateSelectorView {...createNodeProps([])} />)

        expect(screen.getByTestId(TEMPLATE_SELECTOR_VIEW_TEST_ID)).toBeInTheDocument()
        expect(
          screen.queryByTestId(`${TEMPLATE_SELECTOR_ITEM_TEST_ID}-invoice-reminder`),
        ).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a user interacts with a template', () => {
    describe('WHEN clicking a template button', () => {
      it('THEN should call editor.chain().focus().setContent() with the template content', async () => {
        const user = userEvent.setup()

        render(<TemplateSelectorView {...createNodeProps(mockTemplates)} />)

        const button = screen.getByTestId(`${TEMPLATE_SELECTOR_ITEM_TEST_ID}-invoice-reminder`)

        await user.click(button)

        expect(mockChain).toHaveBeenCalled()
        expect(mockFocus).toHaveBeenCalled()
        expect(mockSetContent).toHaveBeenCalledWith('# Payment Reminder\n\nDear Customer')
        expect(mockRun).toHaveBeenCalled()
      })
    })

    describe('WHEN clicking a different template button', () => {
      it('THEN should call setContent with that template content', async () => {
        const user = userEvent.setup()

        render(<TemplateSelectorView {...createNodeProps(mockTemplates)} />)

        const button = screen.getByTestId(`${TEMPLATE_SELECTOR_ITEM_TEST_ID}-welcome-email`)

        await user.click(button)

        expect(mockSetContent).toHaveBeenCalledWith('# Welcome!\n\nHi there')
        expect(mockRun).toHaveBeenCalled()
      })
    })
  })
})
