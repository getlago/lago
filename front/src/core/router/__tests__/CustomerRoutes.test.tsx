import {
  CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_DETAILS_TAB_ROUTE,
  CUSTOMER_DRAFT_INVOICES_LIST_ROUTE,
  CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE,
  CUSTOMER_INVOICE_DETAILS_ROUTE,
  CUSTOMER_INVOICE_REGENERATE_ROUTE,
  CUSTOMER_INVOICE_VOID_ROUTE,
  CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
  customerObjectCreationRoutes,
  customerRoutes,
  CUSTOMERS_LIST_ROUTE,
  customerVoidRoutes,
} from '../CustomerRoutes'

describe('CustomerRoutes', () => {
  describe('route constants', () => {
    it('defines all expected route paths', () => {
      expect(CUSTOMERS_LIST_ROUTE).toBe('/customers')
      expect(CUSTOMER_DETAILS_ROUTE).toBe('/customer/:customerId')
      expect(CUSTOMER_DETAILS_TAB_ROUTE).toBe('/customer/:customerId/:tab')
      expect(CUSTOMER_DRAFT_INVOICES_LIST_ROUTE).toBe('/customer/:customerId/draft-invoices')
      expect(CUSTOMER_INVOICE_DETAILS_ROUTE).toBe('/customer/:customerId/invoice/:invoiceId/:tab')
      expect(CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE).toBe(
        '/customer/:customerId/request-overdue-payment',
      )
      expect(CUSTOMER_INVOICE_VOID_ROUTE).toBe('/customer/:customerId/invoice/void/:invoiceId')
      expect(CUSTOMER_INVOICE_REGENERATE_ROUTE).toBe(
        '/customer/:customerId/invoice/regenerate/:invoiceId',
      )
    })

    it('defines credit note related routes', () => {
      expect(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE).toBe(
        '/customer/:customerId/invoice/:invoiceId/credit-notes/:creditNoteId',
      )
      expect(CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE).toBe(
        '/customer/:customerId/credit-notes/:creditNoteId',
      )
      expect(CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE).toBe(
        '/customer/:customerId/invoice/:invoiceId/create/credit-notes',
      )
      expect(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE).toBe(
        '/customer/:customerId/invoice/:invoiceId/credit-notes/:creditNoteId/:tab',
      )
    })
  })

  describe('customerRoutes array', () => {
    it('contains expected number of route definitions', () => {
      expect(customerRoutes).toHaveLength(5)
    })

    it('all routes are marked as private', () => {
      customerRoutes.forEach((route) => {
        expect(route.private).toBe(true)
      })
    })

    it('customers list route has correct permissions', () => {
      const customersListRoute = customerRoutes.find((r) => r.path === CUSTOMERS_LIST_ROUTE)

      expect(customersListRoute).toBeDefined()
      expect(customersListRoute?.permissions).toEqual(['customersView'])
    })

    it('customer details routes have correct permissions', () => {
      const customerDetailsRoute = customerRoutes.find(
        (r) => Array.isArray(r.path) && r.path.includes(CUSTOMER_DETAILS_ROUTE),
      )

      expect(customerDetailsRoute).toBeDefined()
      expect(customerDetailsRoute?.permissions).toEqual(['customersView'])
      expect(customerDetailsRoute?.path).toContain(CUSTOMER_DETAILS_ROUTE)
      expect(customerDetailsRoute?.path).toContain(CUSTOMER_DETAILS_TAB_ROUTE)
    })

    it('invoice details route has correct permissions', () => {
      const invoiceDetailsRoute = customerRoutes.find(
        (r) => Array.isArray(r.path) && r.path.includes(CUSTOMER_INVOICE_DETAILS_ROUTE),
      )

      expect(invoiceDetailsRoute).toBeDefined()
      expect(invoiceDetailsRoute?.permissions).toEqual(['invoicesView'])
    })

    it('draft invoices route has correct permissions', () => {
      const draftInvoicesRoute = customerRoutes.find(
        (r) => r.path === CUSTOMER_DRAFT_INVOICES_LIST_ROUTE,
      )

      expect(draftInvoicesRoute).toBeDefined()
      expect(draftInvoicesRoute?.permissions).toEqual(['invoicesView'])
    })

    it('credit note routes have correct permissions', () => {
      const creditNoteRoute = customerRoutes.find(
        (r) => Array.isArray(r.path) && r.path.includes(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE),
      )

      expect(creditNoteRoute).toBeDefined()
      expect(creditNoteRoute?.permissions).toEqual(['creditNotesView'])
      expect(creditNoteRoute?.path).toContain(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_ROUTE)
      expect(creditNoteRoute?.path).toContain(CUSTOMER_INVOICE_CREDIT_NOTE_DETAILS_TAB_ROUTE)
      expect(creditNoteRoute?.path).toContain(CUSTOMER_CREDIT_NOTE_DETAILS_ROUTE)
    })

    it('all routes have an element defined', () => {
      customerRoutes.forEach((route) => {
        expect(route.element).toBeDefined()
      })
    })
  })

  describe('customerVoidRoutes array', () => {
    it('contains expected number of route definitions', () => {
      expect(customerVoidRoutes).toHaveLength(2)
    })

    it('all routes are marked as private', () => {
      customerVoidRoutes.forEach((route) => {
        expect(route.private).toBe(true)
      })
    })

    it('void invoice route has correct permissions', () => {
      const voidRoute = customerVoidRoutes.find(
        (r) => Array.isArray(r.path) && r.path.includes(CUSTOMER_INVOICE_VOID_ROUTE),
      )

      expect(voidRoute).toBeDefined()
      expect(voidRoute?.permissions).toEqual(['invoicesVoid'])
    })

    it('regenerate invoice route has correct permissions', () => {
      const regenerateRoute = customerVoidRoutes.find(
        (r) => Array.isArray(r.path) && r.path.includes(CUSTOMER_INVOICE_REGENERATE_ROUTE),
      )

      expect(regenerateRoute).toBeDefined()
      expect(regenerateRoute?.permissions).toEqual(['invoicesVoid'])
    })
  })

  describe('customerObjectCreationRoutes array', () => {
    it('contains expected number of route definitions', () => {
      expect(customerObjectCreationRoutes).toHaveLength(2)
    })

    it('all routes are marked as private', () => {
      customerObjectCreationRoutes.forEach((route) => {
        expect(route.private).toBe(true)
      })
    })

    it('create credit note route has correct permissions', () => {
      const createCreditNoteRoute = customerObjectCreationRoutes.find(
        (r) => r.path === CUSTOMER_INVOICE_CREATE_CREDIT_NOTE_ROUTE,
      )

      expect(createCreditNoteRoute).toBeDefined()
      expect(createCreditNoteRoute?.permissions).toEqual(['creditNotesCreate'])
    })

    it('request overdue payment route has correct permissions', () => {
      const overduePaymentRoute = customerObjectCreationRoutes.find(
        (r) => r.path === CUSTOMER_REQUEST_OVERDUE_PAYMENT_ROUTE,
      )

      expect(overduePaymentRoute).toBeDefined()
      expect(overduePaymentRoute?.permissions).toEqual(['analyticsView'])
    })
  })

  describe('route structure validation', () => {
    it('all route arrays export valid CustomRouteObject structures', () => {
      const allRoutes = [...customerRoutes, ...customerVoidRoutes, ...customerObjectCreationRoutes]

      allRoutes.forEach((route) => {
        expect(route).toHaveProperty('path')
        expect(route).toHaveProperty('private')
        expect(route).toHaveProperty('element')
        expect(route).toHaveProperty('permissions')
        expect(Array.isArray(route.permissions)).toBe(true)
      })
    })
  })
})
