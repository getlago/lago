import { screen } from '@testing-library/react'
import { NodeViewProps } from '@tiptap/react'

import { render } from '~/test-utils'

import { RichTextEditorProvider } from '../../common/RichTextEditorContext'
import { QUOTE_IMAGE_NODE_VIEW_TEST_ID, QuoteImageNodeView } from '../QuoteImageNodeView'

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  NodeViewWrapper: ({
    children,
    ...props
  }: {
    children: React.ReactNode
    as?: string
    className?: string
    'data-type'?: string
  }) => <div {...props}>{children}</div>,
}))

const nodeWithSrc = (src: unknown, alt?: unknown) =>
  ({
    attrs: { src, alt },
  }) as unknown as NodeViewProps['node']

const defaultProps = {
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

const renderQuoteImageNodeView = ({
  node,
  images = {} as Record<string, string>,
}: {
  node: NodeViewProps['node']
  images?: Record<string, string>
}) => {
  return render(
    <RichTextEditorProvider value={{ mode: 'preview', mentionValues: {}, entities: {}, images }}>
      <QuoteImageNodeView {...defaultProps} node={node} />
    </RichTextEditorProvider>,
  )
}

describe('QuoteImageNodeView', () => {
  describe('GIVEN a src that is a known blob id', () => {
    it('THEN should render an <img> with the resolved signed URL', () => {
      renderQuoteImageNodeView({
        node: nodeWithSrc('blob-1', 'a picture'),
        images: { 'blob-1': 'https://signed/blob-1' },
      })

      const wrapper = screen.getByTestId(QUOTE_IMAGE_NODE_VIEW_TEST_ID)
      const img = wrapper.querySelector('img')

      expect(img).toBeInTheDocument()
      expect(img).toHaveAttribute('src', 'https://signed/blob-1')
      expect(img).toHaveAttribute('alt', 'a picture')
    })
  })

  describe('GIVEN a src that is an unknown blob id', () => {
    it('THEN should render no <img>', () => {
      renderQuoteImageNodeView({
        node: nodeWithSrc('blob-unknown'),
        images: {},
      })

      const wrapper = screen.getByTestId(QUOTE_IMAGE_NODE_VIEW_TEST_ID)

      expect(wrapper.querySelector('img')).not.toBeInTheDocument()
      expect(wrapper).toBeEmptyDOMElement()
    })
  })

  describe('GIVEN a src that is a legacy http(s) URL', () => {
    it('THEN should render the URL verbatim', () => {
      renderQuoteImageNodeView({
        node: nodeWithSrc('https://legacy.example.com/image.png'),
        images: {},
      })

      const wrapper = screen.getByTestId(QUOTE_IMAGE_NODE_VIEW_TEST_ID)
      const img = wrapper.querySelector('img')

      expect(img).toHaveAttribute('src', 'https://legacy.example.com/image.png')
    })
  })

  describe('GIVEN a null/undefined src', () => {
    it('THEN should render no <img>', () => {
      renderQuoteImageNodeView({ node: nodeWithSrc(null) })

      const wrapper = screen.getByTestId(QUOTE_IMAGE_NODE_VIEW_TEST_ID)

      expect(wrapper.querySelector('img')).not.toBeInTheDocument()
    })
  })
})
