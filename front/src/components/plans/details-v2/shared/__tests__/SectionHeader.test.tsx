import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { SectionHeader } from '../SectionHeader'

describe('SectionHeader', () => {
  it('renders title and description', () => {
    render(<SectionHeader title="Plan settings" description="Configure the plan" />)

    expect(screen.getByText('Plan settings')).toBeInTheDocument()
    expect(screen.getByText('Configure the plan')).toBeInTheDocument()
  })

  it('renders no action when none provided', () => {
    render(<SectionHeader title="Plan settings" />)

    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })

  it('renders the action button and fires onClick', async () => {
    const handleClick = jest.fn()

    render(<SectionHeader title="Charges" action={{ label: 'Add charge', onClick: handleClick }} />)

    await userEvent.click(screen.getByRole('button', { name: /add charge/i }))

    expect(handleClick).toHaveBeenCalledTimes(1)
  })

  it('hides the action when hidden=true', () => {
    render(
      <SectionHeader
        title="Charges"
        action={{ label: 'Add charge', onClick: jest.fn(), hidden: true }}
      />,
    )

    expect(screen.queryByRole('button', { name: /add charge/i })).not.toBeInTheDocument()
  })

  it('disables the action when disabled=true', () => {
    render(
      <SectionHeader
        title="Charges"
        action={{ label: 'Add charge', onClick: jest.fn(), disabled: true }}
      />,
    )

    expect(screen.getByRole('button', { name: /add charge/i })).toBeDisabled()
  })

  it('renders no icon by default (e.g. an Edit link)', () => {
    render(
      <SectionHeader
        title="Subscription information"
        action={{ label: 'Edit', onClick: jest.fn() }}
      />,
    )

    expect(
      screen.getByRole('button', { name: /edit/i }).querySelector('svg'),
    ).not.toBeInTheDocument()
  })

  it('renders the provided startIcon (e.g. plus for an Add CTA)', () => {
    render(
      <SectionHeader
        title="Charges"
        action={{ label: 'Add charge', onClick: jest.fn(), startIcon: 'plus' }}
      />,
    )

    expect(
      screen.getByRole('button', { name: /add charge/i }).querySelector('svg'),
    ).toBeInTheDocument()
  })
})
