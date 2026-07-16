import NiceModal from '@ebay/nice-modal-react'
import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
} from '~/components/dialogs/const'
import { MainHeader } from '~/components/MainHeader/MainHeader'
import { CountryCode } from '~/generated/graphql'
import { render } from '~/test-utils'

import LagoTaxManagementIntegration, {
  LAGO_TAX_MANAGEMENT_REMOVE_BUTTON_TEST_ID,
} from '../LagoTaxManagementIntegration'

const mockNavigate = jest.fn()
const mockAddToast = jest.fn()
const mockUpdate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: jest.fn(() => mockNavigate),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: () => true,
  }),
}))

const mockBillingEntitiesCollection = [
  {
    id: 'be-1',
    code: 'billing-entity-1',
    name: 'EU Billing Entity',
    country: CountryCode.Fr,
    euTaxManagement: true,
  },
]

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetBillingEntitiesQuery: jest.fn(() => ({
    data: {
      billingEntities: {
        collection: mockBillingEntitiesCollection,
      },
    },
    loading: false,
  })),
  useGetTaxesForTaxManagementIntegrationDetailsPageQuery: jest.fn(() => ({
    data: {
      taxes: {
        collection: [{ id: 'tax-1', code: 'vat_20', name: 'VAT 20%', rate: 20 }],
      },
    },
    loading: false,
  })),
  useUpdateBillingEntityMutation: jest.fn(() => [mockUpdate]),
}))

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const Page = () => (
  <NiceModal.Provider>
    <MainHeader />
    <LagoTaxManagementIntegration />
  </NiceModal.Provider>
)

describe('LagoTaxManagementIntegration', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(cleanup)

  const renderPage = async () => {
    await act(async () => {
      render(<Page />)
    })
  }

  describe('GIVEN the page is rendered', () => {
    describe('WHEN the user has permissions', () => {
      it('THEN should display the remove connection button', async () => {
        await renderPage()

        // MainHeader renders actions in both mobile and desktop layouts
        expect(
          screen.getAllByTestId(LAGO_TAX_MANAGEMENT_REMOVE_BUTTON_TEST_ID).length,
        ).toBeGreaterThanOrEqual(1)
      })
    })
  })

  describe('GIVEN the user clicks the remove connection button', () => {
    describe('WHEN the warning dialog is confirmed and mutations return errors', () => {
      it('THEN should NOT navigate away', async () => {
        mockUpdate.mockResolvedValue({
          errors: [{ message: 'some_error' }],
        })

        const user = userEvent.setup()

        await renderPage()

        const removeButton = screen.getAllByTestId(LAGO_TAX_MANAGEMENT_REMOVE_BUTTON_TEST_ID)[0]

        await user.click(removeButton)

        const confirmButton = await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        await user.click(confirmButton)

        await waitFor(() => {
          expect(mockUpdate).toHaveBeenCalled()
        })

        expect(mockNavigate).not.toHaveBeenCalled()
      })

      it('THEN should NOT show a success toast', async () => {
        mockUpdate.mockResolvedValue({
          errors: [{ message: 'some_error' }],
        })

        const user = userEvent.setup()

        await renderPage()

        const removeButton = screen.getAllByTestId(LAGO_TAX_MANAGEMENT_REMOVE_BUTTON_TEST_ID)[0]

        await user.click(removeButton)

        const confirmButton = await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        await user.click(confirmButton)

        await waitFor(() => {
          expect(mockUpdate).toHaveBeenCalled()
        })

        expect(mockAddToast).not.toHaveBeenCalled()
      })
    })

    describe('WHEN the warning dialog is confirmed and mutations succeed', () => {
      it('THEN should navigate to the integrations route', async () => {
        mockUpdate.mockResolvedValue({
          data: { updateBillingEntity: { id: 'be-1' } },
        })

        const user = userEvent.setup()

        await renderPage()

        const removeButton = screen.getAllByTestId(LAGO_TAX_MANAGEMENT_REMOVE_BUTTON_TEST_ID)[0]

        await user.click(removeButton)

        const confirmButton = await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        await user.click(confirmButton)

        await waitFor(() => {
          expect(mockNavigate).toHaveBeenCalled()
        })
      })

      it('THEN should show a success toast', async () => {
        mockUpdate.mockResolvedValue({
          data: { updateBillingEntity: { id: 'be-1' } },
        })

        const user = userEvent.setup()

        await renderPage()

        const removeButton = screen.getAllByTestId(LAGO_TAX_MANAGEMENT_REMOVE_BUTTON_TEST_ID)[0]

        await user.click(removeButton)

        const confirmButton = await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID)

        await user.click(confirmButton)

        await waitFor(() => {
          expect(mockAddToast).toHaveBeenCalledWith(
            expect.objectContaining({
              severity: 'success',
            }),
          )
        })
      })
    })
  })
})
