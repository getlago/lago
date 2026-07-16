import { render, screen, waitFor } from '@testing-library/react'

import { StatusEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemQuoteStatus } from '../FiltersItemQuoteStatus'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemQuoteStatus value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemQuoteStatus', () => {
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
    it.each([
      ['draft', StatusEnum.Draft],
      ['approved', StatusEnum.Approved],
      ['voided', StatusEnum.Voided],
    ])('THEN displays chip for %s', async (_, enumValue) => {
      renderComponent(enumValue)

      await waitFor(() => {
        expect(screen.getByText(enumValue)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple values', () => {
    it('THEN displays all chips', async () => {
      const multipleValues = `${StatusEnum.Draft},${StatusEnum.Approved}`

      renderComponent(multipleValues)

      await waitFor(() => {
        expect(screen.getByText(StatusEnum.Draft)).toBeInTheDocument()
        expect(screen.getByText(StatusEnum.Approved)).toBeInTheDocument()
      })
    })
  })
})
