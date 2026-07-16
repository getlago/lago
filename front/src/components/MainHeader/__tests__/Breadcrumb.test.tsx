import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import { Breadcrumb, BREADCRUMB_NAV_TEST_ID } from '../Breadcrumb'
import { BreadcrumbItem } from '../types'

describe('Breadcrumb', () => {
  describe('GIVEN an empty items array', () => {
    describe('WHEN the component renders', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<Breadcrumb items={[]} />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN a single breadcrumb item', () => {
    const items: BreadcrumbItem[] = [{ label: 'Home', path: '/home' }]

    describe('WHEN the component renders', () => {
      it('THEN should display the breadcrumb nav', () => {
        render(<Breadcrumb items={items} />)

        expect(screen.getByTestId(BREADCRUMB_NAV_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the link with correct href', () => {
        render(<Breadcrumb items={items} />)

        const link = screen.getByRole('link', { name: 'Home' })

        expect(link).toHaveAttribute('href', '/home')
      })

      it('THEN should not render any separator', () => {
        render(<Breadcrumb items={items} />)

        expect(screen.queryByText('/')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple breadcrumb items', () => {
    const items: BreadcrumbItem[] = [
      { label: 'Customers', path: '/customers' },
      { label: 'Acme Corp', path: '/customers/1' },
      { label: 'Invoices', path: '/customers/1/invoices' },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render all links', () => {
        render(<Breadcrumb items={items} />)

        const links = screen.getAllByRole('link')

        expect(links).toHaveLength(3)
      })

      it('THEN should render separators between items', () => {
        render(<Breadcrumb items={items} />)

        const separators = screen.getAllByText('/')

        expect(separators).toHaveLength(2)
      })

      it.each([
        ['Customers', '/customers'],
        ['Acme Corp', '/customers/1'],
        ['Invoices', '/customers/1/invoices'],
      ])('THEN should render link "%s" pointing to "%s"', (label, path) => {
        render(<Breadcrumb items={items} />)

        const link = screen.getByRole('link', { name: label })

        expect(link).toHaveAttribute('href', path)
      })
    })
  })

  describe('GIVEN a loading breadcrumb item', () => {
    const items: BreadcrumbItem[] = [
      { label: 'Customers', path: '/customers' },
      { label: '', path: '/customers/1', loading: true },
    ]

    describe('WHEN the component renders', () => {
      it('THEN should render a skeleton instead of the link for the loading item', () => {
        render(<Breadcrumb items={items} />)

        // Only the non-loading item is rendered as a link
        expect(screen.getAllByRole('link')).toHaveLength(1)
        expect(screen.queryByRole('link', { name: '/customers/1' })).not.toBeInTheDocument()
      })
    })
  })
})
