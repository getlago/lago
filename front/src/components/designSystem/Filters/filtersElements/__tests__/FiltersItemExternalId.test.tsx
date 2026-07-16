import { fireEvent, render, screen, waitFor } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { FiltersItemExternalId } from '../FiltersItemExternalId'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemExternalId value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemExternalId', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no initial value', () => {
    it('THEN displays an empty text input', async () => {
      renderComponent()

      await waitFor(() => {
        expect(screen.getByRole('textbox')).toHaveValue('')
      })
    })
  })

  describe('GIVEN an initial value', () => {
    it('THEN displays the value in the text input', async () => {
      renderComponent('external_id_123')

      await waitFor(() => {
        expect(screen.getByRole('textbox')).toHaveValue('external_id_123')
      })
    })
  })

  describe('WHEN the user types a value', () => {
    it('THEN calls setFilterValue with the typed value', async () => {
      renderComponent()

      fireEvent.change(screen.getByRole('textbox'), { target: { value: 'external_id_123' } })

      await waitFor(() => {
        expect(mockSetFilterValue).toHaveBeenCalledWith('external_id_123')
      })
    })
  })
})
