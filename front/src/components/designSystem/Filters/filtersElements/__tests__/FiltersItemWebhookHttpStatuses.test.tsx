import { render, screen, waitFor } from '@testing-library/react'

import { AllTheProviders } from '~/test-utils'

import { FiltersItemWebhookHttpStatuses } from '../FiltersItemWebhookHttpStatuses'

const mockSetFilterValue = jest.fn()

jest.mock('~/components/designSystem/Filters/context', () => ({
  useFilterContext: () => ({
    displayInDialog: false,
  }),
}))

const renderComponent = (value?: string) => {
  return render(
    <FiltersItemWebhookHttpStatuses value={value} setFilterValue={mockSetFilterValue} />,
    {
      wrapper: AllTheProviders,
    },
  )
}

describe('FiltersItemWebhookHttpStatuses', () => {
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
    describe('WHEN value is "2xx"', () => {
      it('THEN should display the "2xx" chip', async () => {
        renderComponent('2xx')

        await waitFor(() => {
          expect(screen.getByText('2xx')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "5xx"', () => {
      it('THEN should display the "5xx" chip', async () => {
        renderComponent('5xx')

        await waitFor(() => {
          expect(screen.getByText('5xx')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "timeout"', () => {
      it('THEN should render the combobox with timeout selected', async () => {
        renderComponent('timeout')

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN multiple values', () => {
    describe('WHEN two statuses are selected', () => {
      it('THEN should display all selected chips', async () => {
        renderComponent('2xx,5xx')

        await waitFor(() => {
          expect(screen.getByText('2xx')).toBeInTheDocument()
          expect(screen.getByText('5xx')).toBeInTheDocument()
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

      expect(screen.queryByText('2xx')).not.toBeInTheDocument()
    })
  })
})
