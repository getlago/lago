import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { SectionAccordion } from '../SectionAccordion'

describe('SectionAccordion', () => {
  it('renders the summary content', () => {
    render(
      <SectionAccordion title="Charge A" subtitle="USD">
        <div>body</div>
      </SectionAccordion>,
    )

    expect(screen.getByText('Charge A')).toBeInTheDocument()
    expect(screen.getByText('USD')).toBeInTheDocument()
  })

  it('renders no action menu when actions array is empty', () => {
    render(
      <SectionAccordion title="X" actions={[]}>
        <div>body</div>
      </SectionAccordion>,
    )

    expect(screen.queryByLabelText('actions')).not.toBeInTheDocument()
  })

  it('renders no action menu when every action is hidden', () => {
    render(
      <SectionAccordion
        title="X"
        actions={[
          { label: 'Edit', onClick: jest.fn(), hidden: true },
          { label: 'Delete', onClick: jest.fn(), hidden: true },
        ]}
      >
        <div>body</div>
      </SectionAccordion>,
    )

    expect(screen.queryByLabelText('actions')).not.toBeInTheDocument()
  })

  it('renders the body when initiallyOpen and hides it when collapsed', () => {
    const open = render(
      <SectionAccordion title="X" initiallyOpen>
        <div>body-content</div>
      </SectionAccordion>,
    )

    expect(open.getByText('body-content')).toBeInTheDocument()

    const collapsed = render(
      <SectionAccordion title="Y">
        <div>hidden-body</div>
      </SectionAccordion>,
    )

    expect(collapsed.queryByText('hidden-body')).not.toBeInTheDocument()
  })

  it('fires onToggle with the open state when expanded then collapsed', async () => {
    const onToggle = jest.fn()

    render(
      <SectionAccordion title="Charge A" onToggle={onToggle}>
        <div>body</div>
      </SectionAccordion>,
    )

    await userEvent.click(screen.getByText('Charge A'))
    expect(onToggle).toHaveBeenLastCalledWith(true)

    await userEvent.click(screen.getByText('Charge A'))
    expect(onToggle).toHaveBeenLastCalledWith(false)
  })

  it('applies the off-screen content-visibility class by default', () => {
    const { container } = render(
      <SectionAccordion title="X">
        <div>body</div>
      </SectionAccordion>,
    )

    expect(container.querySelector('[class*="content-visibility"]')).not.toBeNull()
  })

  it('drops the content-visibility class when disableContentVisibility is set', () => {
    const { container } = render(
      <SectionAccordion title="X" disableContentVisibility>
        <div>body</div>
      </SectionAccordion>,
    )

    expect(container.querySelector('[class*="content-visibility"]')).toBeNull()
  })

  it('filters hidden actions from the menu and fires onClick of visible ones', async () => {
    const handleEdit = jest.fn()
    const handleDelete = jest.fn()

    render(
      <SectionAccordion
        title="X"
        actions={[
          { label: 'Edit', onClick: handleEdit },
          { label: 'Delete', onClick: handleDelete, hidden: true },
        ]}
      >
        <div>body</div>
      </SectionAccordion>,
    )

    await userEvent.click(screen.getByLabelText('actions'))

    expect(screen.getByText('Edit')).toBeInTheDocument()
    expect(screen.queryByText('Delete')).not.toBeInTheDocument()

    await userEvent.click(screen.getByText('Edit'))

    expect(handleEdit).toHaveBeenCalledTimes(1)
    expect(handleDelete).not.toHaveBeenCalled()
  })
})
