import { render, screen, waitFor } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { FiltersItemOrderFormNumber } from '../FiltersItemOrderFormNumber'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemOrderFormNumber value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemOrderFormNumber', () => {
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

  describe('GIVEN a single order form number', () => {
    it('THEN displays the number as a chip', async () => {
      renderComponent('OF-001')

      await waitFor(() => {
        expect(screen.getByText('OF-001')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple order form numbers', () => {
    it('THEN displays all number chips', async () => {
      renderComponent('OF-001,OF-002')

      await waitFor(() => {
        expect(screen.getByText('OF-001')).toBeInTheDocument()
        expect(screen.getByText('OF-002')).toBeInTheDocument()
      })
    })
  })
})
