import NiceModal from '@ebay/nice-modal-react'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import CentralizedDialog from '~/components/dialogs/CentralizedDialog'
import {
  CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID,
  CENTRALIZED_DIALOG_NAME,
  CENTRALIZED_DIALOG_TEST_ID,
} from '~/components/dialogs/const'
import { addToast } from '~/core/apolloClient'
import { OrderExecutionModeEnum, OrderFormStatusEnum, OrderTypeEnum } from '~/generated/graphql'
import { render, testMockNavigateFn } from '~/test-utils'

import SignOrderForm, {
  SIGN_ORDER_FORM_ALERT_TEST_ID,
  SIGN_ORDER_FORM_CANCEL_BUTTON_TEST_ID,
  SIGN_ORDER_FORM_CLOSE_BUTTON_TEST_ID,
  SIGN_ORDER_FORM_EXECUTION_TYPE_TEST_ID,
  SIGN_ORDER_FORM_PREVIEW_TEST_ID,
  SIGN_ORDER_FORM_SUBMIT_BUTTON_TEST_ID,
} from '../SignOrderForm'

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const renderPage = () =>
  render(
    <NiceModal.Provider>
      <SignOrderForm />
    </NiceModal.Provider>,
  )

jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 56,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, i) => ({
        index: i,
        key: String(i),
        start: i * 56,
        size: 56,
      })),
    scrollToIndex: jest.fn(),
    measureElement: jest.fn(),
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string, vars?: Record<string, unknown>) =>
      vars ? `${key}:${JSON.stringify(vars)}` : key,
  }),
}))

const mockGoBack = jest.fn()

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({ goBack: mockGoBack }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({ date }),
  }),
}))

const mockMarkSigned = jest.fn()
const mockUseGetOrderFormForSignQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetOrderFormForSignQuery: (...args: unknown[]) => mockUseGetOrderFormForSignQuery(...args),
  useMarkOrderFormAsSignedMutation: () => [mockMarkSigned],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

const mockOrderForm = {
  id: 'order-form-123',
  number: 'OF-2026-0001',
  status: OrderFormStatusEnum.Generated,
  createdAt: '2026-04-09T10:00:00Z',
  expiresAt: '2026-12-31T00:00:00Z',
  customer: { id: 'customer-001', name: 'Acme Corp' },
  quote: {
    id: 'quote-456',
    number: 'QT-2026-0042',
    orderType: OrderTypeEnum.SubscriptionCreation,
    currentVersion: { version: 1 },
  },
}

describe('SignOrderForm', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ orderFormId: 'order-form-123' })
    mockUseGetOrderFormForSignQuery.mockReturnValue({
      data: { orderForm: mockOrderForm },
      loading: false,
      error: undefined,
    })
  })

  it('renders the info alert', () => {
    renderPage()

    expect(screen.getByTestId(SIGN_ORDER_FORM_ALERT_TEST_ID)).toBeInTheDocument()
  })

  it('renders the document preview card', () => {
    renderPage()

    expect(screen.getByTestId(SIGN_ORDER_FORM_PREVIEW_TEST_ID)).toBeInTheDocument()
  })

  it('renders the valid-until date in the preview header', () => {
    renderPage()

    expect(screen.getByTestId(SIGN_ORDER_FORM_PREVIEW_TEST_ID)).toHaveTextContent('2026-12-31')
  })

  it('does not call the mutation and shows an error when submitting empty', async () => {
    const user = userEvent.setup()

    renderPage()

    await user.click(screen.getByTestId(SIGN_ORDER_FORM_SUBMIT_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(screen.getByText('text_17816865941254uzl22ixohk')).toBeInTheDocument()
    })
    expect(mockMarkSigned).not.toHaveBeenCalled()
  })

  it('signs and navigates when execution type and date are set', async () => {
    mockMarkSigned.mockResolvedValueOnce({
      data: { markOrderFormAsSigned: { id: 'order-form-123', status: OrderFormStatusEnum.Signed } },
    })

    const user = userEvent.setup()

    renderPage()

    // Open the execution-type ComboBox by clicking the MUI input base
    const comboboxContainer = screen.getByTestId(SIGN_ORDER_FORM_EXECUTION_TYPE_TEST_ID)
    const comboboxInputBase = comboboxContainer.querySelector('.MuiInputBase-root') as HTMLElement

    await user.click(comboboxInputBase)

    // Pick "Execute in Lago" from the dropdown
    const optionWrapper = await screen.findByTestId('combobox-item-text_1781686594125wc395bj9cul')
    const option = optionWrapper.querySelector('.MuiAutocomplete-option') as HTMLElement

    await user.click(option)

    // Set the execution date by typing into the date input
    await user.type(screen.getByPlaceholderText('text_17816865941253r8yqeoibh1'), '12/25/2030')

    await user.click(screen.getByTestId(SIGN_ORDER_FORM_SUBMIT_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(mockMarkSigned).toHaveBeenCalledWith({
        variables: {
          input: expect.objectContaining({
            id: 'order-form-123',
            executionMode: OrderExecutionModeEnum.ExecuteInLago,
          }),
        },
      })
    })

    await waitFor(() => {
      expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
    })
    expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-456/order-forms')
  })

  it('signs without an execution date (executeAt is optional)', async () => {
    mockMarkSigned.mockResolvedValueOnce({
      data: { markOrderFormAsSigned: { id: 'order-form-123', status: OrderFormStatusEnum.Signed } },
    })

    const user = userEvent.setup()

    renderPage()

    const comboboxContainer = screen.getByTestId(SIGN_ORDER_FORM_EXECUTION_TYPE_TEST_ID)
    const comboboxInputBase = comboboxContainer.querySelector('.MuiInputBase-root') as HTMLElement

    await user.click(comboboxInputBase)

    const optionWrapper = await screen.findByTestId('combobox-item-text_1781686594125wc395bj9cul')
    const option = optionWrapper.querySelector('.MuiAutocomplete-option') as HTMLElement

    await user.click(option)

    // No execute-at date set.
    await user.click(screen.getByTestId(SIGN_ORDER_FORM_SUBMIT_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(mockMarkSigned).toHaveBeenCalledWith({
        variables: {
          input: expect.objectContaining({
            id: 'order-form-123',
            executionMode: OrderExecutionModeEnum.ExecuteInLago,
            executeAt: undefined,
          }),
        },
      })
    })

    await waitFor(() => {
      expect(testMockNavigateFn).toHaveBeenCalledWith('/quote/quote-456/order-forms')
    })
  })

  describe('unsaved-changes guard', () => {
    const selectExecutionMode = async (user: ReturnType<typeof userEvent.setup>) => {
      const comboboxContainer = screen.getByTestId(SIGN_ORDER_FORM_EXECUTION_TYPE_TEST_ID)
      const comboboxInputBase = comboboxContainer.querySelector('.MuiInputBase-root') as HTMLElement

      await user.click(comboboxInputBase)

      const optionWrapper = await screen.findByTestId('combobox-item-text_1781686594125wc395bj9cul')
      const option = optionWrapper.querySelector('.MuiAutocomplete-option') as HTMLElement

      await user.click(option)
    }

    it('navigates back immediately when closing a pristine form', async () => {
      const user = userEvent.setup()

      renderPage()

      await user.click(screen.getByTestId(SIGN_ORDER_FORM_CLOSE_BUTTON_TEST_ID))

      expect(screen.queryByTestId(CENTRALIZED_DIALOG_TEST_ID)).not.toBeInTheDocument()
      expect(mockGoBack).toHaveBeenCalled()
    })

    it('opens the warning dialog instead of navigating when the form is dirty', async () => {
      const user = userEvent.setup()

      renderPage()

      await selectExecutionMode(user)

      await user.click(screen.getByTestId(SIGN_ORDER_FORM_CANCEL_BUTTON_TEST_ID))

      expect(await screen.findByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
      expect(mockGoBack).not.toHaveBeenCalled()
    })

    it('navigates back when confirming the warning dialog', async () => {
      const user = userEvent.setup()

      renderPage()

      await selectExecutionMode(user)
      await user.click(screen.getByTestId(SIGN_ORDER_FORM_CANCEL_BUTTON_TEST_ID))

      await user.click(await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(mockGoBack).toHaveBeenCalled()
      })
    })

    it('stays on the page when cancelling the warning dialog', async () => {
      const user = userEvent.setup()

      renderPage()

      await selectExecutionMode(user)
      await user.click(screen.getByTestId(SIGN_ORDER_FORM_CANCEL_BUTTON_TEST_ID))

      await user.click(await screen.findByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID))

      expect(mockGoBack).not.toHaveBeenCalled()
    })
  })
})
