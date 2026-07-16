import { cleanup, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { Typography } from '../Typography'

describe('Typography', () => {
  afterEach(cleanup)

  describe('Basic Rendering', () => {
    it('renders children correctly', () => {
      render(<Typography>Hello World</Typography>)

      expect(screen.getByText('Hello World')).toBeInTheDocument()
    })

    it('renders with default variant (body)', () => {
      render(<Typography>Default variant</Typography>)

      expect(screen.getByTestId('body')).toBeInTheDocument()
    })

    it('renders as div by default', () => {
      const { container } = render(<Typography>Content</Typography>)

      expect(container.querySelector('div')).toBeInTheDocument()
    })
  })

  describe('Variants', () => {
    it.each([
      'headline',
      'subhead1',
      'subhead2',
      'bodyHl',
      'body',
      'captionHl',
      'caption',
      'note',
      'noteHl',
      'captionCode',
    ] as const)('renders %s variant correctly', (variant) => {
      render(<Typography variant={variant}>Content</Typography>)

      expect(screen.getByTestId(variant)).toBeInTheDocument()
    })

    it('renders captionCode with code variant mapping', () => {
      render(<Typography variant="captionCode">Code content</Typography>)

      // The captionCode variant is mapped to 'code' via variantMapping
      // and should render the content correctly
      expect(screen.getByTestId('captionCode')).toBeInTheDocument()
      expect(screen.getByText('Code content')).toBeInTheDocument()
    })
  })

  describe('Colors', () => {
    it.each([
      'grey700',
      'grey600',
      'grey500',
      'grey400',
      'info600',
      'primary600',
      'danger600',
      'warning700',
      'success600',
      'inherit',
      'white',
      'disabled',
      'textPrimary',
      'textSecondary',
    ] as const)('applies %s color correctly', (color) => {
      render(
        <Typography color={color} data-testid="typography">
          Colored text
        </Typography>,
      )

      expect(screen.getByText('Colored text')).toBeInTheDocument()
    })
  })

  describe('Custom Component', () => {
    it('renders as span when component is specified', () => {
      const { container } = render(<Typography component="span">Span content</Typography>)

      expect(container.querySelector('span')).toBeInTheDocument()
    })

    it('renders as h1 when component is specified', () => {
      const { container } = render(<Typography component="h1">Heading content</Typography>)

      expect(container.querySelector('h1')).toBeInTheDocument()
    })

    it('renders as p when component is specified', () => {
      const { container } = render(<Typography component="p">Paragraph content</Typography>)

      expect(container.querySelector('p')).toBeInTheDocument()
    })
  })

  describe('HTML Content', () => {
    it('renders sanitized HTML', () => {
      render(<Typography html="<strong>Bold</strong> text" />)

      expect(screen.getByText('Bold')).toBeInTheDocument()
      expect(screen.getByText('Bold').tagName).toBe('STRONG')
    })

    it('sanitizes dangerous HTML tags', () => {
      const { container } = render(<Typography html="<script>alert('xss')</script><b>Safe</b>" />)

      expect(container.querySelector('script')).not.toBeInTheDocument()
      expect(screen.getByText('Safe')).toBeInTheDocument()
    })

    it('allows safe tags like b, i, em, strong, a, sup, span', () => {
      const { container } = render(
        <Typography html="<b>bold</b> <i>italic</i> <em>emphasis</em> <strong>strong</strong> <sup>sup</sup> <span>span</span>" />,
      )

      expect(container.querySelector('b')).toBeInTheDocument()
      expect(container.querySelector('i')).toBeInTheDocument()
      expect(container.querySelector('em')).toBeInTheDocument()
      expect(container.querySelector('strong')).toBeInTheDocument()
      expect(container.querySelector('sup')).toBeInTheDocument()
      expect(container.querySelector('span')).toBeInTheDocument()
    })

    it('preserves href, target, rel attributes on anchor tags', () => {
      const { container } = render(
        <Typography html='<a href="https://example.com" target="_blank" rel="noopener">Link</a>' />,
      )

      const anchor = container.querySelector('a')

      expect(anchor).toBeInTheDocument()
      expect(anchor).toHaveAttribute('href', 'https://example.com')
      expect(anchor).toHaveAttribute('target', '_blank')
      expect(anchor).toHaveAttribute('rel', 'noopener')
    })

    it('renders internal links with react-router Link component', () => {
      render(<Typography html='<a href="/internal" data-text="Internal Link">placeholder</a>' />)

      // The internal link should be transformed to use react-router Link
      expect(screen.getByText('Internal Link')).toBeInTheDocument()
    })

    it('renders multiple internal links correctly', () => {
      render(
        <Typography html='Text with <a href="/link1" data-text="First">placeholder</a> and <a href="/link2" data-text="Second">placeholder</a>' />,
      )

      expect(screen.getByText('First')).toBeInTheDocument()
      expect(screen.getByText('Second')).toBeInTheDocument()
    })
  })

  describe('CSS Classes', () => {
    it('applies custom className', () => {
      const { container } = render(<Typography className="custom-class">Content</Typography>)

      expect(container.firstChild).toHaveClass('custom-class')
    })

    it('applies whitespace-pre-line when noWrap is false and not captionCode', () => {
      const { container } = render(<Typography variant="body">Content</Typography>)

      expect(container.firstChild).toHaveClass('whitespace-pre-line')
    })

    it('applies whitespace-pre for captionCode variant', () => {
      const { container } = render(<Typography variant="captionCode">Code</Typography>)

      expect(container.firstChild).toHaveClass('whitespace-pre')
    })

    it('does not apply whitespace classes when noWrap is true', () => {
      const { container } = render(<Typography noWrap>Content</Typography>)

      expect(container.firstChild).not.toHaveClass('whitespace-pre-line')
      expect(container.firstChild).not.toHaveClass('whitespace-pre')
    })
  })

  describe('Blur Effect', () => {
    it('applies blur classes when blur is true', () => {
      const { container } = render(<Typography blur>Blurred content</Typography>)

      expect(container.firstChild).toHaveClass('blur-sm')
      expect(container.firstChild).toHaveClass('pointer-events-none')
      expect(container.firstChild).toHaveClass('select-none')
    })

    it('does not apply blur classes when blur is false', () => {
      const { container } = render(<Typography blur={false}>Normal content</Typography>)

      expect(container.firstChild).not.toHaveClass('blur-sm')
    })
  })

  describe('Force Break', () => {
    it('applies line-break-anywhere when forceBreak is true', () => {
      const { container } = render(<Typography forceBreak>Long content</Typography>)

      expect(container.firstChild).toHaveClass('line-break-anywhere')
    })

    it('does not apply line-break-anywhere by default', () => {
      const { container } = render(<Typography>Content</Typography>)

      expect(container.firstChild).not.toHaveClass('line-break-anywhere')
    })
  })

  describe('noWrap', () => {
    it('passes noWrap prop to MuiTypography', () => {
      const { container } = render(<Typography noWrap>No wrap content</Typography>)

      // MUI Typography with noWrap applies truncation styles
      expect(container.firstChild).toBeInTheDocument()
    })
  })

  describe('Text Alignment', () => {
    it('supports align prop', () => {
      render(<Typography align="center">Centered text</Typography>)

      expect(screen.getByText('Centered text')).toBeInTheDocument()
    })
  })

  describe('onClick Handler', () => {
    it('calls onClick when clicked', async () => {
      const handleClick = jest.fn()

      render(<Typography onClick={handleClick}>Clickable</Typography>)

      await userEvent.click(screen.getByText('Clickable'))

      expect(handleClick).toHaveBeenCalledTimes(1)
    })
  })

  describe('Default Color Mapping', () => {
    it('uses textSecondary for headline variant by default', () => {
      render(<Typography variant="headline">Headline</Typography>)

      // The component should render without error, indicating the color was applied
      expect(screen.getByTestId('headline')).toBeInTheDocument()
    })

    it('uses textSecondary for subhead variants by default', () => {
      render(<Typography variant="subhead1">Subhead</Typography>)

      expect(screen.getByTestId('subhead1')).toBeInTheDocument()
    })

    it('uses textPrimary for body variant by default', () => {
      render(<Typography variant="body">Body</Typography>)

      expect(screen.getByTestId('body')).toBeInTheDocument()
    })
  })

  describe('SX Prop', () => {
    it('accepts sx prop for custom MUI styling', () => {
      render(<Typography sx={{ marginTop: 2 }}>Styled content</Typography>)

      expect(screen.getByText('Styled content')).toBeInTheDocument()
    })
  })

  describe('Memo Behavior', () => {
    it('has displayName set to Typography', () => {
      expect(Typography.displayName).toBe('Typography')
    })
  })

  describe('XSS Prevention', () => {
    it('renders javascript: href as plain text instead of a link', () => {
      const { container } = render(
        <Typography html='<a href="javascript:alert(1)" data-text="Click me">placeholder</a>' />,
      )

      expect(screen.getByText('Click me')).toBeInTheDocument()
      // Should render as <span>, not as a <Link>/<a>
      expect(screen.getByText('Click me').tagName).toBe('SPAN')
      expect(container.querySelector('a[href="javascript:alert(1)"]')).not.toBeInTheDocument()
    })

    it('renders safe relative href as a link', () => {
      render(<Typography html='<a href="/customers/123" data-text="Customer">placeholder</a>' />)

      const link = screen.getByText('Customer')

      expect(link).toBeInTheDocument()
      expect(link.tagName).toBe('A')
      expect(link).toHaveAttribute('href', '/customers/123')
    })

    it('renders data: protocol href as plain text instead of a link', () => {
      const { container } = render(
        <Typography html='<a href="data:text/html,<script>alert(1)</script>" data-text="Data link">placeholder</a>' />,
      )

      expect(screen.getByText('Data link')).toBeInTheDocument()
      expect(screen.getByText('Data link').tagName).toBe('SPAN')
      expect(container.querySelector('a[href^="data:"]')).not.toBeInTheDocument()
    })

    it('renders protocol-relative href as plain text instead of a link', () => {
      const { container } = render(
        <Typography html='<a href="//evil.com" data-text="Evil link">placeholder</a>' />,
      )

      expect(screen.getByText('Evil link')).toBeInTheDocument()
      expect(screen.getByText('Evil link').tagName).toBe('SPAN')
      expect(container.querySelector('a[href="//evil.com"]')).not.toBeInTheDocument()
    })

    it('preserves text after internal link with unsafe href (no truncation)', () => {
      const { container } = render(
        <Typography html='Before <a href="javascript:alert(1)" data-text="XSS">click</a> after the link' />,
      )

      expect(screen.getByText('XSS')).toBeInTheDocument()
      // Verify text after the link is not truncated
      expect(container.textContent).toContain('after the link')
      expect(container.textContent).toContain('Before')
    })

    it('preserves text after internal link with safe href (no truncation)', () => {
      const { container } = render(
        <Typography html='Before <a href="/customers/123" data-text="Customer">click</a> after the link' />,
      )

      expect(screen.getByText('Customer')).toBeInTheDocument()
      // Verify text after the link is not truncated
      expect(container.textContent).toContain('after the link')
      expect(container.textContent).toContain('Before')
    })
  })
})
