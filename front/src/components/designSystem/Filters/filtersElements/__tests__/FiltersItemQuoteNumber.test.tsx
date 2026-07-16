import { render, screen, waitFor } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { FiltersItemQuoteNumber } from '../FiltersItemQuoteNumber'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemQuoteNumber value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemQuoteNumber', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no initial value', () => {
    it('THEN displays the combobox', async () => {
      renderComponent()

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN undefined value', () => {
    it('THEN should not crash and displays the combobox', async () => {
      renderComponent(undefined)

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a single quote number', () => {
    it('THEN displays the number as a chip', async () => {
      renderComponent('QUO-001')

      await waitFor(() => {
        expect(screen.getByText('QUO-001')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple quote numbers', () => {
    it('THEN displays all number chips', async () => {
      renderComponent('QUO-001,QUO-002')

      await waitFor(() => {
        expect(screen.getByText('QUO-001')).toBeInTheDocument()
        expect(screen.getByText('QUO-002')).toBeInTheDocument()
      })
    })
  })
})
