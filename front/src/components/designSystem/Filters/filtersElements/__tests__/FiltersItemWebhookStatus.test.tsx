import { render, screen, waitFor } from '@testing-library/react'

import { WebhookStatusEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { FiltersItemWebhookStatus } from '../FiltersItemWebhookStatus'

const mockSetFilterValue = jest.fn()

jest.mock('~/components/designSystem/Filters/context', () => ({
  useFilterContext: () => ({
    displayInDialog: false,
  }),
}))

const renderComponent = (value?: string) => {
  return render(<FiltersItemWebhookStatus value={value} setFilterValue={mockSetFilterValue} />, {
    wrapper: AllTheProviders,
  })
}

describe('FiltersItemWebhookStatus', () => {
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
    describe('WHEN value is "succeeded"', () => {
      it('THEN should display the succeeded chip', async () => {
        renderComponent(WebhookStatusEnum.Succeeded)

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "failed"', () => {
      it('THEN should display the failed chip', async () => {
        renderComponent(WebhookStatusEnum.Failed)

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "pending"', () => {
      it('THEN should display the pending chip', async () => {
        renderComponent(WebhookStatusEnum.Pending)

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN value is "retrying"', () => {
      it('THEN should display the retrying chip', async () => {
        renderComponent(WebhookStatusEnum.Retrying)

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN multiple values', () => {
    describe('WHEN two statuses are selected', () => {
      it('THEN should display all selected chips', async () => {
        renderComponent(`${WebhookStatusEnum.Succeeded},${WebhookStatusEnum.Failed}`)

        await waitFor(() => {
          expect(screen.getByRole('combobox')).toBeInTheDocument()
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
    })
  })
})
