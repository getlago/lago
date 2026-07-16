import { screen } from '@testing-library/react'
import { NodeViewProps } from '@tiptap/react'

import { RichTextEditorMode } from '~/components/designSystem/RichTextEditor/RichTextEditor'
import { render } from '~/test-utils'

import { RichTextEditorProvider } from '../../common/RichTextEditorContext'
import { MENTION_NODE_VIEW_TEST_ID, MentionNodeView } from '../MentionNodeView'

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  NodeViewWrapper: ({
    children,
    ...props
  }: {
    children: React.ReactNode
    as?: string
    className?: string
    'data-test'?: string
  }) => <span {...props}>{children}</span>,
}))

const defaultNode = {
  attrs: { id: 'customerName', label: 'Customer Name' },
} as unknown as NodeViewProps['node']

const nodeWithoutLabel = {
  attrs: { id: 'customerName' },
} as unknown as NodeViewProps['node']

const nodeWithNullAttrs = {
  attrs: { id: null, label: null },
} as unknown as NodeViewProps['node']

const nodeWithUndefinedLabel = {
  attrs: { id: 'testId', label: undefined },
} as unknown as NodeViewProps['node']

const defaultProps = {
  node: defaultNode,
  editor: null as never,
  extension: null as never,
  getPos: () => 0,
  updateAttributes: () => {},
  deleteNode: () => {},
  selected: false,
  decorations: [],
  innerDecorations: null as never,
  HTMLAttributes: {},
  view: null as never,
} as unknown as NodeViewProps

const renderMentionNodeView = ({
  node = defaultNode,
  mode = 'edit' as RichTextEditorMode,
  mentionValues = {} as Record<string, string>,
} = {}) => {
  return render(
    <RichTextEditorProvider value={{ mode, mentionValues, entities: {}, images: {} }}>
      <MentionNodeView {...defaultProps} node={node} />
    </RichTextEditorProvider>,
  )
}

describe('MentionNodeView', () => {
  describe('GIVEN the component is in edit mode', () => {
    describe('WHEN rendered with a label', () => {
      it('THEN should display @label text', () => {
        renderMentionNodeView()

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toBeInTheDocument()
        expect(element).toHaveTextContent('@Customer Name')
      })
    })

    describe('WHEN rendered without a label', () => {
      it('THEN should fallback to @id text', () => {
        renderMentionNodeView({ node: nodeWithoutLabel })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toHaveTextContent('@customerName')
      })
    })

    describe('WHEN rendered with null attrs', () => {
      it('THEN should safely convert null values using String()', () => {
        renderMentionNodeView({ node: nodeWithNullAttrs })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toHaveTextContent('@')
      })
    })

    describe('WHEN rendered with undefined label', () => {
      it('THEN should fallback to id via String()', () => {
        renderMentionNodeView({ node: nodeWithUndefinedLabel })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toHaveTextContent('@testId')
      })
    })

    describe('WHEN mentionValues are provided', () => {
      it('THEN should still display @label in edit mode', () => {
        renderMentionNodeView({
          mentionValues: { customerName: 'Acme Corp' },
        })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toHaveTextContent('@Customer Name')
      })
    })
  })

  describe('GIVEN the component is in preview mode', () => {
    describe('WHEN mentionValues has a value for the id', () => {
      it('THEN should display the resolved value instead of @label', () => {
        renderMentionNodeView({
          mode: 'preview',
          mentionValues: { customerName: 'Acme Corp' },
        })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toHaveTextContent('Acme Corp')
        expect(element).not.toHaveTextContent('@Customer Name')
        expect(element).toHaveClass('variable-mention--resolved')
      })
    })

    describe('WHEN mentionValues has no value for the id', () => {
      it('THEN should fall back to @label', () => {
        renderMentionNodeView({
          mode: 'preview',
          mentionValues: {},
        })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).toHaveTextContent('@Customer Name')
      })
    })

    describe('WHEN the resolved value is an empty string', () => {
      it('THEN should render nothing instead of the @label', () => {
        renderMentionNodeView({
          mode: 'preview',
          mentionValues: { customerName: '' },
        })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).not.toHaveTextContent('@Customer Name')
        expect(element).toBeEmptyDOMElement()
      })
    })

    describe('WHEN the resolved value is null', () => {
      it('THEN should render nothing instead of the @label', () => {
        renderMentionNodeView({
          mode: 'preview',
          mentionValues: { customerName: null as unknown as string },
        })

        const element = screen.getByTestId(MENTION_NODE_VIEW_TEST_ID)

        expect(element).not.toHaveTextContent('@Customer Name')
        expect(element).toBeEmptyDOMElement()
      })
    })
  })
})
