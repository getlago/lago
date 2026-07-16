import { cleanup, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { AiBadge } from '../AiBadge'

describe('AiBadge', () => {
  afterEach(cleanup)

  it('renders without children', () => {
    const { container } = render(<AiBadge />)

    expect(container.querySelector('svg')).toBeInTheDocument()
  })

  it('renders with children', () => {
    render(<AiBadge>AI Powered</AiBadge>)

    expect(screen.getByText('AI Powered')).toBeInTheDocument()
  })

  it('applies custom className', () => {
    const { container } = render(<AiBadge className="custom-class" />)

    expect(container.firstChild).toHaveClass('custom-class')
  })

  it('renders SVG icon with default size', () => {
    const { container } = render(<AiBadge />)

    const svg = container.querySelector('svg')

    expect(svg).toHaveAttribute('width', '16')
    expect(svg).toHaveAttribute('height', '16')
  })

  it('renders SVG icon with custom size', () => {
    const { container } = render(<AiBadge iconSize={24} />)

    const svg = container.querySelector('svg')

    expect(svg).toHaveAttribute('width', '24')
    expect(svg).toHaveAttribute('height', '24')
  })
})
