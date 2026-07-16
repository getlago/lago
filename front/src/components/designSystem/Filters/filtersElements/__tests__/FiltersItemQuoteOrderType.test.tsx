import { render, screen, waitFor } from '@testing-library/react'

import { OrderTypeEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemQuoteOrderType } from '../FiltersItemQuoteOrderType'

const mockSetFilterValue = jest.fn()

const renderComponent = (value?: string) => {
  return render(<FiltersItemQuoteOrderType value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemQuoteOrderType', () => {
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
      ['one_off', OrderTypeEnum.OneOff],
      ['subscription_amendment', OrderTypeEnum.SubscriptionAmendment],
      ['subscription_creation', OrderTypeEnum.SubscriptionCreation],
    ])('THEN displays chip for %s', async (_, enumValue) => {
      renderComponent(enumValue)

      await waitFor(() => {
        expect(screen.getByText(enumValue)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN multiple values', () => {
    it('THEN displays all chips', async () => {
      const multipleValues = `${OrderTypeEnum.OneOff},${OrderTypeEnum.SubscriptionCreation}`

      renderComponent(multipleValues)

      await waitFor(() => {
        expect(screen.getByText(OrderTypeEnum.OneOff)).toBeInTheDocument()
        expect(screen.getByText(OrderTypeEnum.SubscriptionCreation)).toBeInTheDocument()
      })
    })
  })
})
