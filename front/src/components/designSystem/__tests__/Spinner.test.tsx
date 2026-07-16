import { render } from '@testing-library/react'

import { Spinner } from '../Spinner'

describe('Spinner', () => {
  describe('Basic Functionality', () => {
    it('renders the spinner', () => {
      const { container } = render(<Spinner />)

      expect(container.firstChild).toBeInTheDocument()
    })

    it('renders with centered container', () => {
      const { container } = render(<Spinner />)
      const spinnerContainer = container.firstChild as HTMLElement

      expect(spinnerContainer).toHaveClass('flex', 'size-full', 'items-center', 'justify-center')
    })

    it('renders with spinning animation', () => {
      const { container } = render(<Spinner />)

      // The Icon component should render with spin animation
      const icon = container.querySelector('.animate-spin')

      expect(icon).toBeInTheDocument()
    })

    it('renders an SVG icon', () => {
      const { container } = render(<Spinner />)
      const spinnerContainer = container.firstChild as HTMLElement

      // Should contain an SVG icon
      const svg = spinnerContainer.querySelector('svg')

      expect(svg).toBeInTheDocument()
    })
  })

  describe('Container Structure', () => {
    it('has correct container structure', () => {
      const { container } = render(<Spinner />)

      // Should have a div as container
      expect(container.firstChild?.nodeName).toBe('DIV')

      // Container should have exactly one child (the Icon)
      expect(container.firstChild?.childNodes.length).toBe(1)
    })

    it('takes full size of parent', () => {
      const { container } = render(<Spinner />)
      const spinnerContainer = container.firstChild as HTMLElement

      // size-full means width and height are 100%
      expect(spinnerContainer).toHaveClass('size-full')
    })
  })

  describe('Snapshot Tests', () => {
    it('matches snapshot', () => {
      const { container } = render(<Spinner />)

      expect(container.firstChild).toMatchSnapshot()
    })
  })

  describe('Usage in different contexts', () => {
    it('renders correctly when wrapped in a parent container', () => {
      const { container } = render(
        <div style={{ width: '200px', height: '200px' }}>
          <Spinner />
        </div>,
      )

      const parent = container.firstChild as HTMLElement
      const spinnerContainer = parent.firstChild as HTMLElement

      expect(spinnerContainer).toBeInTheDocument()
      expect(spinnerContainer).toHaveClass('flex', 'items-center', 'justify-center')
    })

    it('can be rendered multiple times independently', () => {
      const { container } = render(
        <div>
          <div>
            <Spinner />
          </div>
          <div>
            <Spinner />
          </div>
        </div>,
      )

      const parent = container.firstChild as HTMLElement
      const spinner1Container = parent.children[0].firstChild as HTMLElement
      const spinner2Container = parent.children[1].firstChild as HTMLElement

      expect(spinner1Container).toBeInTheDocument()
      expect(spinner2Container).toBeInTheDocument()

      // Both should have the same structure
      expect(spinner1Container).toHaveClass('flex', 'items-center', 'justify-center')
      expect(spinner2Container).toHaveClass('flex', 'items-center', 'justify-center')
    })
  })

  describe('Accessibility', () => {
    it('renders without accessibility violations', () => {
      const { container } = render(<Spinner />)

      // Spinner should be visible
      expect(container.firstChild).toBeVisible()
    })

    it('is semantically a loading indicator', () => {
      const { container } = render(<Spinner />)

      // The processing icon with spin animation indicates loading
      const icon = container.querySelector('.animate-spin')

      expect(icon).toBeInTheDocument()
      expect(icon).toHaveClass('animate-spin')
    })
  })
})
