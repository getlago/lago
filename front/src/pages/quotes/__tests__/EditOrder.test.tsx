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
import { OrderExecutionModeEnum, OrderStatusEnum, OrderTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import EditOrder, {
  EDIT_ORDER_CANCEL_BUTTON_TEST_ID,
  EDIT_ORDER_CLOSE_BUTTON_TEST_ID,
  EDIT_ORDER_EXECUTION_TYPE_TEST_ID,
  EDIT_ORDER_PREVIEW_TEST_ID,
  EDIT_ORDER_SUBMIT_BUTTON_TEST_ID,
} from '../EditOrder'

NiceModal.register(CENTRALIZED_DIALOG_NAME, CentralizedDialog)

const renderPage = () =>
  render(
    <NiceModal.Provider>
      <EditOrder />
    </NiceModal.Provider>,
  )

jest.mock('~/components/designSystem/RichTextEditor/RichTextEditor', () => ({
  __esModule: true,
  default: (props: Record<string, unknown>) => (
    <div data-test="rich-text-editor" data-mode={props.mode} />
  ),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (date: string) => ({ date }),
  }),
}))

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  buildPreviewEntities: jest.fn(() => ({})),
}))

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

const mockUpdateOrder = jest.fn()
const mockUseGetOrderForEditQuery = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetOrderForEditQuery: (...args: unknown[]) => mockUseGetOrderForEditQuery(...args),
  useUpdateOrderMutation: () => [mockUpdateOrder],
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
}))

const mockOrder = {
  id: 'order-123',
  number: 'OR-2026-0001',
  status: OrderStatusEnum.Created,
  orderType: OrderTypeEnum.SubscriptionCreation,
  executeAt: null,
  executionMode: OrderExecutionModeEnum.ExecuteInLago,
  customer: { id: 'customer-001', name: 'Acme Corp', displayName: 'Acme Corp' },
  orderForm: {
    id: 'of-1',
    number: 'OF-2026-0001',
    quote: {
      id: 'quote-456',
      number: 'QT-2026-0042',
      currentVersion: { id: 'qv-1', version: 1, content: '# Hello World', billingItems: null },
      customer: { id: 'customer-001' },
    },
  },
}

describe('EditOrder', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({ orderId: 'order-123' })
    mockUseGetOrderForEditQuery.mockReturnValue({
      data: { order: mockOrder },
      loading: false,
      error: undefined,
    })
  })

  it('renders the document preview card', () => {
    renderPage()

    expect(screen.getByTestId(EDIT_ORDER_PREVIEW_TEST_ID)).toBeInTheDocument()
  })

  it('renders the order number in the preview header', () => {
    renderPage()

    expect(screen.getByTestId(EDIT_ORDER_PREVIEW_TEST_ID)).toHaveTextContent('OR-2026-0001')
  })

  it("submits the order's existing values when unchanged (form is pre-populated)", async () => {
    mockUpdateOrder.mockResolvedValueOnce({
      data: { updateOrder: { id: 'order-123' } },
    })

    const user = userEvent.setup()

    renderPage()

    await user.click(screen.getByTestId(EDIT_ORDER_SUBMIT_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(mockUpdateOrder).toHaveBeenCalledWith({
        variables: {
          input: expect.objectContaining({
            id: 'order-123',
            executionMode: OrderExecutionModeEnum.ExecuteInLago,
          }),
        },
      })
    })

    await waitFor(() => {
      expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'success' }))
    })
    expect(mockGoBack).toHaveBeenCalled()
  })

  it('pre-fills the execution type and date inputs once the order finishes loading', async () => {
    // First paint: query still loading, no data yet (the real-app sequence)
    mockUseGetOrderForEditQuery.mockReturnValue({
      data: undefined,
      loading: true,
      error: undefined,
    })

    const { rerender } = renderPage()

    // Then the order arrives
    mockUseGetOrderForEditQuery.mockReturnValue({
      data: {
        order: {
          ...mockOrder,
          executionMode: OrderExecutionModeEnum.ExecuteInLago,
          // Noon UTC keeps the same calendar date across all realistic test timezones
          executeAt: '2030-12-25T12:00:00.000Z',
        },
      },
      loading: false,
      error: undefined,
    })

    rerender(
      <NiceModal.Provider>
        <EditOrder />
      </NiceModal.Provider>,
    )

    // The execution-type combobox input shows the selected option's label
    await waitFor(() => {
      const comboboxContainer = screen.getByTestId(EDIT_ORDER_EXECUTION_TYPE_TEST_ID)
      const comboboxInput = comboboxContainer.querySelector('input') as HTMLInputElement

      expect(comboboxInput).toHaveValue('text_1781686594125wc395bj9cul')
    })

    // The execution-date input shows the order's executeAt date
    expect(screen.getByPlaceholderText('text_17816865941253r8yqeoibh1')).toHaveValue('12/25/2030')
  })

  it('shows a validation error and does not call the mutation when executionMode is empty', async () => {
    mockUseGetOrderForEditQuery.mockReturnValue({
      data: { order: { ...mockOrder, executionMode: null } },
      loading: false,
      error: undefined,
    })

    const user = userEvent.setup()

    renderPage()

    await user.click(screen.getByTestId(EDIT_ORDER_SUBMIT_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(screen.getByText('text_17816865941254uzl22ixohk')).toBeInTheDocument()
    })
    expect(mockUpdateOrder).not.toHaveBeenCalled()
  })

  it('updates and navigates back when the execution type is changed', async () => {
    mockUpdateOrder.mockResolvedValueOnce({
      data: { updateOrder: { id: 'order-123' } },
    })

    const user = userEvent.setup()

    renderPage()

    const comboboxContainer = screen.getByTestId(EDIT_ORDER_EXECUTION_TYPE_TEST_ID)
    const comboboxInputBase = comboboxContainer.querySelector('.MuiInputBase-root') as HTMLElement

    await user.click(comboboxInputBase)

    const optionWrapper = await screen.findByTestId('combobox-item-text_1781686594125ibfjmzae7cy')
    const option = optionWrapper.querySelector('.MuiAutocomplete-option') as HTMLElement

    await user.click(option)

    await user.click(screen.getByTestId(EDIT_ORDER_SUBMIT_BUTTON_TEST_ID))

    await waitFor(() => {
      expect(mockUpdateOrder).toHaveBeenCalledWith({
        variables: {
          input: expect.objectContaining({
            id: 'order-123',
            executionMode: OrderExecutionModeEnum.OrderOnly,
          }),
        },
      })
    })
    expect(mockGoBack).toHaveBeenCalled()
  })

  describe('unsaved-changes guard', () => {
    const changeExecutionMode = async (user: ReturnType<typeof userEvent.setup>) => {
      const comboboxContainer = screen.getByTestId(EDIT_ORDER_EXECUTION_TYPE_TEST_ID)
      const comboboxInputBase = comboboxContainer.querySelector('.MuiInputBase-root') as HTMLElement

      await user.click(comboboxInputBase)

      const optionWrapper = await screen.findByTestId('combobox-item-text_1781686594125ibfjmzae7cy')
      const option = optionWrapper.querySelector('.MuiAutocomplete-option') as HTMLElement

      await user.click(option)
    }

    it('navigates back immediately when closing a pristine form', async () => {
      const user = userEvent.setup()

      renderPage()

      await user.click(screen.getByTestId(EDIT_ORDER_CLOSE_BUTTON_TEST_ID))

      expect(screen.queryByTestId(CENTRALIZED_DIALOG_TEST_ID)).not.toBeInTheDocument()
      expect(mockGoBack).toHaveBeenCalled()
    })

    it('opens the warning dialog instead of navigating when the form is dirty', async () => {
      const user = userEvent.setup()

      renderPage()

      await changeExecutionMode(user)

      await user.click(screen.getByTestId(EDIT_ORDER_CANCEL_BUTTON_TEST_ID))

      expect(await screen.findByTestId(CENTRALIZED_DIALOG_TEST_ID)).toBeInTheDocument()
      expect(mockGoBack).not.toHaveBeenCalled()
    })

    it('navigates back when confirming the warning dialog', async () => {
      const user = userEvent.setup()

      renderPage()

      await changeExecutionMode(user)
      await user.click(screen.getByTestId(EDIT_ORDER_CANCEL_BUTTON_TEST_ID))

      await user.click(await screen.findByTestId(CENTRALIZED_DIALOG_CONFIRM_BUTTON_TEST_ID))

      await waitFor(() => {
        expect(mockGoBack).toHaveBeenCalled()
      })
    })

    it('stays on the page when cancelling the warning dialog', async () => {
      const user = userEvent.setup()

      renderPage()

      await changeExecutionMode(user)
      await user.click(screen.getByTestId(EDIT_ORDER_CANCEL_BUTTON_TEST_ID))

      await user.click(await screen.findByTestId(CENTRALIZED_DIALOG_CANCEL_BUTTON_TEST_ID))

      expect(mockGoBack).not.toHaveBeenCalled()
    })
  })
})
