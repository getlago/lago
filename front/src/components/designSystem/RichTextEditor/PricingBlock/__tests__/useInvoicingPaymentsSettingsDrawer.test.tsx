import { act, render, renderHook, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import type { QuoteCustomer } from '~/pages/quotes/hooks/useSubscriptionPricingDrawer'

import {
  INVOICING_PAYMENTS_DRAWER_SAVE_TEST_ID,
  type InvoicingPaymentsSettingsFormValues,
  useInvoicingPaymentsSettingsDrawer,
} from '../useInvoicingPaymentsSettingsDrawer'

const mockDrawerOpen = jest.fn()
const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({ open: mockDrawerOpen, close: mockDrawerClose }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/components/paymentMethodsInvoiceSettings/PaymentMethodsInvoiceSettings', () => ({
  PaymentMethodsInvoiceSettings: () => (
    <div data-test="payment-methods-invoice-settings">PaymentMethodsInvoiceSettings</div>
  ),
}))

const mockOnSave = jest.fn()

const defaultValues: InvoicingPaymentsSettingsFormValues = {
  paymentMethodId: '',
  invoiceCustomFooter: '',
}

const mockCustomer: QuoteCustomer = {
  id: 'customer-123',
  externalId: 'ext-customer-123',
  name: 'Test Customer',
}

describe('useInvoicingPaymentsSettingsDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns openDrawer function', () => {
    const { result } = renderHook(() => useInvoicingPaymentsSettingsDrawer(mockOnSave))

    expect(result.current).toHaveProperty('openDrawer')
    expect(typeof result.current.openDrawer).toBe('function')
  })

  it('opens the drawer when openDrawer is called', () => {
    const { result } = renderHook(() => useInvoicingPaymentsSettingsDrawer(mockOnSave))

    act(() => {
      result.current.openDrawer(defaultValues)
    })
    expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
    expect(mockDrawerOpen).toHaveBeenCalledWith(
      expect.objectContaining({
        title: expect.any(String),
        children: expect.anything(),
        actions: expect.anything(),
      }),
    )
  })

  describe('GIVEN showSection return value', () => {
    it('WHEN customer has id THEN returns showSection true', () => {
      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      expect(result.current.showSection).toBe(true)
    })

    it('WHEN customer is null THEN returns showSection false', () => {
      const { result } = renderHook(() => useInvoicingPaymentsSettingsDrawer(mockOnSave, null))

      expect(result.current.showSection).toBe(false)
    })

    it('WHEN customer is undefined THEN returns showSection false', () => {
      const { result } = renderHook(() => useInvoicingPaymentsSettingsDrawer(mockOnSave, undefined))

      expect(result.current.showSection).toBe(false)
    })

    it('WHEN customer has only externalId THEN returns showSection true', () => {
      const customerWithExternalIdOnly: QuoteCustomer = {
        id: '',
        externalId: 'ext-123',
        name: 'Test',
      }

      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, customerWithExternalIdOnly),
      )

      expect(result.current.showSection).toBe(true)
    })
  })

  describe('GIVEN handleSave callback', () => {
    it('WHEN save is triggered with null paymentMethod THEN calls onSave with empty paymentMethodId', () => {
      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      // Open drawer with empty values (paymentMethod will be null in ref)
      act(() => {
        result.current.openDrawer(defaultValues)
      })

      // Extract actions and render them to click save
      const drawerCallArgs = mockDrawerOpen.mock.calls[0][0]
      const { container } = render(drawerCallArgs.actions)
      const saveButton = container.querySelector(
        `[data-test="${INVOICING_PAYMENTS_DRAWER_SAVE_TEST_ID}"]`,
      ) as HTMLElement

      act(() => {
        saveButton?.click()
      })

      expect(mockOnSave).toHaveBeenCalledWith({
        paymentMethodId: '',
        invoiceCustomFooter: '',
      })
      expect(mockDrawerClose).toHaveBeenCalledTimes(1)
    })

    it('WHEN save is triggered with a paymentMethodId THEN calls onSave with the paymentMethodId', () => {
      const valuesWithPayment: InvoicingPaymentsSettingsFormValues = {
        paymentMethodId: 'pm-456',
        invoiceCustomFooter: '',
      }

      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      act(() => {
        result.current.openDrawer(valuesWithPayment)
      })

      const drawerCallArgs = mockDrawerOpen.mock.calls[0][0]
      const { container } = render(drawerCallArgs.actions)
      const saveButton = container.querySelector(
        `[data-test="${INVOICING_PAYMENTS_DRAWER_SAVE_TEST_ID}"]`,
      ) as HTMLElement

      act(() => {
        saveButton?.click()
      })

      expect(mockOnSave).toHaveBeenCalledWith({
        paymentMethodId: 'pm-456',
        invoiceCustomFooter: '',
      })
      expect(mockDrawerClose).toHaveBeenCalledTimes(1)
    })

    it('WHEN save is triggered with invoiceCustomSection THEN serializes it to JSON', () => {
      const invoiceSection = {
        invoiceCustomSections: [{ id: 'sec-1', name: 'Footer Section' }],
        skipInvoiceCustomSections: false,
      }
      const valuesWithFooter: InvoicingPaymentsSettingsFormValues = {
        paymentMethodId: 'pm-789',
        invoiceCustomFooter: JSON.stringify(invoiceSection),
      }

      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      act(() => {
        result.current.openDrawer(valuesWithFooter)
      })

      const drawerCallArgs = mockDrawerOpen.mock.calls[0][0]
      const { container } = render(drawerCallArgs.actions)
      const saveButton = container.querySelector(
        `[data-test="${INVOICING_PAYMENTS_DRAWER_SAVE_TEST_ID}"]`,
      ) as HTMLElement

      act(() => {
        saveButton?.click()
      })

      expect(mockOnSave).toHaveBeenCalledWith({
        paymentMethodId: 'pm-789',
        invoiceCustomFooter: JSON.stringify(invoiceSection),
      })
      expect(mockDrawerClose).toHaveBeenCalledTimes(1)
    })

    it('WHEN cancel is clicked THEN closes drawer without saving', async () => {
      const user = userEvent.setup()

      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      act(() => {
        result.current.openDrawer(defaultValues)
      })

      const drawerCallArgs = mockDrawerOpen.mock.calls[0][0]

      render(drawerCallArgs.actions)
      // The cancel button is the "quaternary" variant — it's the first button in actions
      const buttons = screen.getAllByRole('button')
      const cancelButton = buttons[0]

      await user.click(cancelButton)

      expect(mockDrawerClose).toHaveBeenCalledTimes(1)
      expect(mockOnSave).not.toHaveBeenCalled()
    })
  })

  describe('GIVEN InvoicingPaymentsDrawerContent rendering', () => {
    it('WHEN customer is provided THEN renders PaymentMethodsInvoiceSettings', () => {
      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      act(() => {
        result.current.openDrawer(defaultValues)
      })

      const drawerCallArgs = mockDrawerOpen.mock.calls[0][0]
      const { container } = render(drawerCallArgs.children)

      expect(
        container.querySelector('[data-test="payment-methods-invoice-settings"]'),
      ).toBeInTheDocument()
    })

    it('WHEN customer is provided with initial paymentMethodId THEN passes it to content', () => {
      const valuesWithPayment: InvoicingPaymentsSettingsFormValues = {
        paymentMethodId: 'pm-initial',
        invoiceCustomFooter: '',
      }

      const { result } = renderHook(() =>
        useInvoicingPaymentsSettingsDrawer(mockOnSave, mockCustomer),
      )

      act(() => {
        result.current.openDrawer(valuesWithPayment)
      })

      const drawerCallArgs = mockDrawerOpen.mock.calls[0][0]
      const { container } = render(drawerCallArgs.children)

      expect(
        container.querySelector('[data-test="payment-methods-invoice-settings"]'),
      ).toBeInTheDocument()
    })
  })
})
