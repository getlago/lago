import { render, screen, waitFor } from '@testing-library/react'

import { CreditNoteTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemCreditNoteType } from '../FiltersItemCreditNoteType'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemCreditNoteType value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemCreditNoteType', () => {
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
    describe('WHEN value is "credit"', () => {
      it('THEN displays "Credit" chip with capitalized label', async () => {
        renderComponent(CreditNoteTypeEnum.Credit)

        await waitFor(() => {
          expect(screen.getByText('Credit')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "refund"', () => {
      it('THEN displays "Refund" chip with capitalized label', async () => {
        renderComponent(CreditNoteTypeEnum.Refund)

        await waitFor(() => {
          expect(screen.getByText('Refund')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "offset"', () => {
      it('THEN displays "Offset" chip with capitalized label', async () => {
        renderComponent(CreditNoteTypeEnum.Offset)

        await waitFor(() => {
          expect(screen.getByText('Offset')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN multiple values', () => {
    describe('WHEN two types are selected', () => {
      it('THEN displays all chips with capitalized labels', async () => {
        const multipleValues = `${CreditNoteTypeEnum.Credit},${CreditNoteTypeEnum.Refund}`

        renderComponent(multipleValues)

        await waitFor(() => {
          expect(screen.getByText('Credit')).toBeInTheDocument()
          expect(screen.getByText('Refund')).toBeInTheDocument()
        })
      })
    })
  })
})
