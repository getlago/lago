import { render, screen, waitFor } from '@testing-library/react'

import { InvoiceSettlementTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemSettlementType } from '../FiltersItemSettlementType'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemSettlementType value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemSettlementType', () => {
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

  describe('GIVEN a single value', () => {
    describe('WHEN value is "credit_note"', () => {
      it('THEN displays "Credit note" chip with correct label', async () => {
        renderComponent(InvoiceSettlementTypeEnum.CreditNote)

        await waitFor(() => {
          expect(screen.getByText('Credit note')).toBeInTheDocument()
        })
      })
    })
  })
})
