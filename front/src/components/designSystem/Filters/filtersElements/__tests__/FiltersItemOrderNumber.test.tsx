import { render, screen, waitFor } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { FiltersItemOrderNumber } from '../FiltersItemOrderNumber'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemOrderNumber value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemOrderNumber', () => {
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

  describe('GIVEN a single order number', () => {
    it('THEN displays the number as a chip', async () => {
      renderComponent('OR-001')

      await waitFor(() => {
        expect(screen.getByText('OR-001')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple order numbers', () => {
    it('THEN displays all number chips', async () => {
      renderComponent('OR-001,OR-002')

      await waitFor(() => {
        expect(screen.getByText('OR-001')).toBeInTheDocument()
        expect(screen.getByText('OR-002')).toBeInTheDocument()
      })
    })
  })
})
