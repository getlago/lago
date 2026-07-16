import { renderHook } from '@testing-library/react'

import { OrderListItemFragment, OrderStatusEnum } from '~/generated/graphql'
import { buildQuotePreviewProps } from '~/pages/quotes/common/buildQuotePreviewProps'
import { testMockNavigateFn } from '~/test-utils'

import { useOrderActions } from '../useOrderActions'

const mockHasPermissions = jest.fn()
const mockDownload = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/pages/quotes/common/QuotePdfProvider', () => ({
  useDownloadQuotePdf: () => ({ download: mockDownload }),
}))

jest.mock('~/pages/quotes/common/buildQuotePreviewProps', () => ({
  buildQuotePreviewProps: jest.fn(() => ({ content: '# Hello World' })),
}))

const mockedBuildQuotePreviewProps = buildQuotePreviewProps as jest.MockedFunction<
  typeof buildQuotePreviewProps
>

const createMockOrder = (
  overrides: Partial<OrderListItemFragment> = {},
): OrderListItemFragment => ({
  id: 'order-1',
  number: 'OR-2026-0001',
  status: OrderStatusEnum.Created,
  executionMode: null,
  executedAt: null,
  customer: { id: 'customer-001', displayName: 'Acme Corp' },
  orderForm: {
    id: 'of-1',
    number: 'OF-2026-0001',
    quote: {
      id: 'q-1',
      number: 'QT-001',
      images: {},
      currentVersion: { id: 'qv-1', version: 1, content: '# Hello World', mentionVariables: {} },
    },
  },
  ...overrides,
})

describe('useOrderActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    mockDownload.mockResolvedValue(undefined)
  })

  describe('GIVEN a created order with ordersUpdate permission', () => {
    it('THEN returns edit and download actions', () => {
      const { result } = renderHook(() => useOrderActions())
      const actions = result.current.getActions(createMockOrder())

      expect(actions).toHaveLength(2)
      expect(actions[0].icon).toBe('pen')
      expect(actions[1].icon).toBe('download')
    })
  })

  describe('GIVEN an executed order', () => {
    it('THEN returns only the download action', () => {
      const { result } = renderHook(() => useOrderActions())
      const actions = result.current.getActions(
        createMockOrder({ status: OrderStatusEnum.Executed }),
      )

      expect(actions).toHaveLength(1)
      expect(actions[0].icon).toBe('download')
    })
  })

  describe('GIVEN a created order without ordersUpdate permission', () => {
    it('THEN returns only the download action', () => {
      mockHasPermissions.mockReturnValue(false)
      const { result } = renderHook(() => useOrderActions())
      const actions = result.current.getActions(createMockOrder())

      expect(actions).toHaveLength(1)
      expect(actions[0].icon).toBe('download')
    })
  })

  describe('GIVEN the edit action', () => {
    it('THEN navigates to the edit-order route', () => {
      const { result } = renderHook(() => useOrderActions())
      const actions = result.current.getActions(createMockOrder({ id: 'order-42' }))

      actions[0].onAction()

      expect(testMockNavigateFn).toHaveBeenCalledWith('/order/order-42/edit')
    })
  })

  describe('GIVEN an order with no quote version content', () => {
    it('THEN omits the download action', () => {
      const { result } = renderHook(() => useOrderActions())
      const actions = result.current.getActions(
        createMockOrder({
          orderForm: {
            id: 'of-1',
            number: 'OF-2026-0001',
            quote: {
              id: 'q-1',
              number: 'QT-001',
              images: {},
              currentVersion: { id: 'qv-1', version: 1, content: null, mentionVariables: {} },
            },
          },
        }),
      )

      expect(actions.find((a) => a.icon === 'download')).toBeUndefined()
    })
  })

  describe('GIVEN the download action', () => {
    it('THEN downloads with preview props and the Order header', () => {
      const { result } = renderHook(() => useOrderActions())
      const order = createMockOrder()
      const actions = result.current.getActions(order)
      const downloadAction = actions.find((a) => a.icon === 'download')

      downloadAction?.onAction()

      expect(mockedBuildQuotePreviewProps).toHaveBeenCalledWith({
        version: order.orderForm.quote.currentVersion,
        customer: order.customer,
        images: order.orderForm.quote.images,
        header: {
          documentNumber: 'OR-2026-0001',
          rows: ['text_1782723591984l12xpznkwqd'],
        },
      })
      expect(mockDownload).toHaveBeenCalledWith({ content: '# Hello World' })
    })
  })
})
