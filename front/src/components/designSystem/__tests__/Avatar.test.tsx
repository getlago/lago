import { cleanup, screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { Avatar, AvatarBadge } from '../Avatar'

describe('Avatar', () => {
  afterEach(cleanup)

  describe('User Variant', () => {
    it('renders user avatar with identifier', () => {
      const { container } = render(<Avatar variant="user" identifier="John Doe" />)

      expect(container.firstChild).toBeInTheDocument()
      expect(container.firstChild).toHaveAttribute('data-test', 'user/big')
    })

    it('displays initials from identifier', () => {
      render(<Avatar variant="user" identifier="John Doe" />)

      expect(screen.getByText('JO')).toBeInTheDocument()
    })

    it('displays custom initials when provided', () => {
      render(<Avatar variant="user" identifier="John Doe" initials="JD" />)

      expect(screen.getByText('JD')).toBeInTheDocument()
    })

    it('displays single initial for small size', () => {
      render(<Avatar variant="user" identifier="John Doe" size="small" />)

      expect(screen.getByText('J')).toBeInTheDocument()
    })

    it('displays single initial for intermediate size', () => {
      render(<Avatar variant="user" identifier="John Doe" size="intermediate" />)

      expect(screen.getByText('J')).toBeInTheDocument()
    })

    it('renders with rounded-full class for user variant', () => {
      const { container } = render(<Avatar variant="user" identifier="John" />)

      expect(container.firstChild).toHaveClass('rounded-full')
    })

    it('uppercases initials', () => {
      render(<Avatar variant="user" identifier="john doe" />)

      expect(screen.getByText('JO')).toBeInTheDocument()
    })

    it('removes non-alphanumeric characters from initials', () => {
      render(<Avatar variant="user" identifier="@john-doe!" />)

      expect(screen.getByText('JO')).toBeInTheDocument()
    })
  })

  describe('Company Variant', () => {
    it('renders company avatar with identifier', () => {
      const { container } = render(<Avatar variant="company" identifier="Acme Corp" />)

      expect(container.firstChild).toBeInTheDocument()
      expect(container.firstChild).toHaveAttribute('data-test', 'company/big')
    })

    it('does not have rounded-full class for company variant', () => {
      const { container } = render(<Avatar variant="company" identifier="Acme" />)

      expect(container.firstChild).not.toHaveClass('rounded-full')
    })
  })

  describe('Connector Variant', () => {
    it('renders connector avatar with children', () => {
      const { container } = render(
        <Avatar variant="connector" size="big">
          <svg data-testid="connector-icon" />
        </Avatar>,
      )

      expect(container.firstChild).toBeInTheDocument()
      expect(container.firstChild).toHaveAttribute('data-test', 'connector/big')
      expect(container.querySelector('svg')).toBeInTheDocument()
    })

    it('renders connector-full variant with full-size SVG styling', () => {
      const { container } = render(
        <Avatar variant="connector-full" size="big">
          <svg data-testid="connector-icon" />
        </Avatar>,
      )

      expect(container.firstChild).toHaveAttribute('data-test', 'connector-full/big')
    })
  })

  describe('Sizes', () => {
    it.each(['tiny', 'small', 'intermediate', 'medium', 'big', 'large'] as const)(
      'renders %s size correctly',
      (size) => {
        const { container } = render(<Avatar variant="user" identifier="Test" size={size} />)

        expect(container.firstChild).toHaveAttribute('data-test', `user/${size}`)
      },
    )

    it('defaults to big size', () => {
      const { container } = render(<Avatar variant="user" identifier="Test" />)

      expect(container.firstChild).toHaveAttribute('data-test', 'user/big')
    })
  })

  describe('Custom className', () => {
    it('applies custom className to user avatar', () => {
      const { container } = render(
        <Avatar variant="user" identifier="Test" className="custom-class" />,
      )

      expect(container.firstChild).toHaveClass('custom-class')
    })

    it('applies custom className to connector avatar', () => {
      const { container } = render(
        <Avatar variant="connector" className="custom-class">
          <span>Icon</span>
        </Avatar>,
      )

      expect(container.firstChild).toHaveClass('custom-class')
    })
  })

  describe('Background Colors', () => {
    it('applies background color based on identifier', () => {
      const { container } = render(<Avatar variant="user" identifier="Test User" />)

      // Should have one of the avatar background color classes
      const element = container.firstChild as HTMLElement

      expect(element.className).toMatch(/bg-avatar-/)
    })

    it('applies default background when no identifier', () => {
      const { container } = render(<Avatar variant="company" identifier="" />)
      const element = container.firstChild as HTMLElement

      expect(element).toHaveClass('bg-grey-100')
    })

    it('generates consistent color for same identifier', () => {
      const { container: container1, unmount } = render(
        <Avatar variant="user" identifier="consistent" />,
      )
      const element1 = container1.firstChild as HTMLElement
      const bgClass1 = element1.className.match(/bg-avatar-\w+/)?.[0]

      unmount()

      const { container: container2 } = render(<Avatar variant="user" identifier="consistent" />)
      const element2 = container2.firstChild as HTMLElement
      const bgClass2 = element2.className.match(/bg-avatar-\w+/)?.[0]

      expect(bgClass1).toBe(bgClass2)
    })
  })

  describe('Text Color', () => {
    it('applies white text color when identifier is provided', () => {
      const { container } = render(<Avatar variant="user" identifier="Test" />)

      expect(container.firstChild).toHaveClass('text-white')
    })

    it('applies default text color when no identifier', () => {
      const { container } = render(<Avatar variant="company" identifier="" />)

      expect(container.firstChild).toHaveClass('text-grey-600')
    })
  })
})

describe('AvatarBadge', () => {
  afterEach(cleanup)

  it('renders with icon', () => {
    const { container } = render(<AvatarBadge icon="checkmark" />)

    expect(container.firstChild).toBeInTheDocument()
    expect(container.querySelector('svg')).toBeInTheDocument()
  })

  it('renders with big size by default', () => {
    const { container } = render(<AvatarBadge icon="checkmark" />)

    expect(container.firstChild).toHaveClass('size-4')
  })

  it('renders with large size', () => {
    const { container } = render(<AvatarBadge icon="checkmark" size="large" />)

    expect(container.firstChild).toHaveClass('size-6')
  })

  describe('Colors', () => {
    it.each([
      ['primary', 'bg-blue-600'],
      ['success', 'bg-green-600'],
      ['error', 'bg-red-600'],
      ['warning', 'bg-yellow-600'],
      ['info', 'bg-purple-600'],
      ['light', 'bg-white'],
      ['black', 'bg-grey-700'],
      ['dark', 'bg-grey-600'],
      ['input', 'bg-grey-500'],
      ['disabled', 'bg-grey-400'],
      ['skeleton', 'bg-grey-100'],
    ] as const)('applies %s color correctly', (color, expectedClass) => {
      const { container } = render(<AvatarBadge icon="checkmark" color={color} />)

      expect(container.firstChild).toHaveClass(expectedClass)
    })
  })

  it('has rounded-full class', () => {
    const { container } = render(<AvatarBadge icon="checkmark" />)

    expect(container.firstChild).toHaveClass('rounded-full')
  })

  it('is positioned at bottom-right', () => {
    const { container } = render(<AvatarBadge icon="checkmark" />)

    expect(container.firstChild).toHaveClass('absolute', 'bottom-0', 'right-0')
  })
})

describe('Avatar with AvatarBadge', () => {
  afterEach(cleanup)

  it('renders avatar with badge overlay', () => {
    const { container } = render(
      <Avatar variant="connector">
        <AvatarBadge icon="checkmark" color="success" />
      </Avatar>,
    )

    // Avatar should render
    expect(container.firstChild).toBeInTheDocument()
    expect(container).toMatchSnapshot()
  })
})
