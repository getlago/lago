import { render, screen, waitFor } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { FiltersItemWebhookEventTypes } from '../FiltersItemWebhookEventTypes'

const mockSetFilterValue = jest.fn()

const mockEventNames = [
  'invoice.created',
  'customer.created',
  'subscription.updated',
  'payment.failed',
]

jest.mock('~/components/designSystem/Filters/context', () => ({
  useFilterContext: () => ({
    displayInDialog: false,
  }),
}))

jest.mock('~/hooks/useWebhookEventTypes', () => ({
  useWebhookEventTypes: () => ({
    allEventNames: mockEventNames,
  }),
}))

const renderComponent = (value?: string) => {
  return render(
    <FiltersItemWebhookEventTypes value={value} setFilterValue={mockSetFilterValue} />,
    {
      wrapper: AllTheProviders,
    },
  )
}

describe('FiltersItemWebhookEventTypes', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN no initial value', () => {
    it('THEN should display the combobox', async () => {
      renderComponent()

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a single value', () => {
    describe('WHEN value is "invoice.created"', () => {
      it('THEN should display the selected chip', async () => {
        renderComponent('invoice.created')

        await waitFor(() => {
          expect(screen.getByText('invoice.created')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN multiple values', () => {
    describe('WHEN two event types are selected', () => {
      it('THEN should display all selected chips', async () => {
        renderComponent('invoice.created,customer.created')

        await waitFor(() => {
          expect(screen.getByText('invoice.created')).toBeInTheDocument()
          expect(screen.getByText('customer.created')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN an empty string value', () => {
    it('THEN should not display any chips', async () => {
      renderComponent('')

      await waitFor(() => {
        expect(screen.getByRole('combobox')).toBeInTheDocument()
      })

      expect(screen.queryByText('invoice.created')).not.toBeInTheDocument()
    })
  })
})
