import { render, screen, waitFor } from '@testing-library/react'

import { OrderFormStatusEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemOrderFormStatus } from '../FiltersItemOrderFormStatus'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemOrderFormStatus value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemOrderFormStatus', () => {
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
      ['generated', OrderFormStatusEnum.Generated],
      ['signed', OrderFormStatusEnum.Signed],
      ['expired', OrderFormStatusEnum.Expired],
      ['voided', OrderFormStatusEnum.Voided],
    ])('THEN displays chip for %s', async (_, enumValue) => {
      renderComponent(enumValue)

      await waitFor(() => {
        expect(screen.getByText(enumValue)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple values', () => {
    it('THEN displays all chips', async () => {
      const multipleValues = `${OrderFormStatusEnum.Generated},${OrderFormStatusEnum.Signed}`

      renderComponent(multipleValues)

      await waitFor(() => {
        expect(screen.getByText(OrderFormStatusEnum.Generated)).toBeInTheDocument()
        expect(screen.getByText(OrderFormStatusEnum.Signed)).toBeInTheDocument()
      })
    })
  })
})
