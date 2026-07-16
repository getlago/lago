import { render, screen, waitFor } from '@testing-library/react'

import { OrderStatusEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemOrderStatus } from '../FiltersItemOrderStatus'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemOrderStatus value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemOrderStatus', () => {
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
      ['created', OrderStatusEnum.Created],
      ['executed', OrderStatusEnum.Executed],
    ])('THEN displays chip for %s', async (_, enumValue) => {
      renderComponent(enumValue)

      await waitFor(() => {
        expect(screen.getByText(enumValue)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple values', () => {
    it('THEN displays all chips', async () => {
      const multipleValues = `${OrderStatusEnum.Created},${OrderStatusEnum.Executed}`

      renderComponent(multipleValues)

      await waitFor(() => {
        expect(screen.getByText(OrderStatusEnum.Created)).toBeInTheDocument()
        expect(screen.getByText(OrderStatusEnum.Executed)).toBeInTheDocument()
      })
    })
  })
})
