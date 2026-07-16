import {
  APPROVE_QUOTE_ROUTE,
  QUOTE_DETAILS_ROUTE,
  QUOTES_LIST_ROUTE,
  QUOTES_TAB_ROUTE,
  quotesRoutes,
} from '../QuotesRoutes'

describe('QuotesRoutes', () => {
  describe('route constants', () => {
    it('defines the quotes list route path', () => {
      expect(QUOTES_LIST_ROUTE).toBe('/quotes')
    })

    it('defines the quotes tab route path', () => {
      expect(QUOTES_TAB_ROUTE).toBe('/quotes/:tab')
    })

    it('defines the quote details route path', () => {
      expect(QUOTE_DETAILS_ROUTE).toBe('/quote/:quoteId/:tab')
    })

    it('defines the approve quote route path', () => {
      expect(APPROVE_QUOTE_ROUTE).toBe('/quote/:quoteId/version/:versionId/approve')
    })
  })

  describe('quotesRoutes array', () => {
    it('contains expected number of route definitions', () => {
      expect(quotesRoutes).toHaveLength(2)
    })

    it('all routes are marked as private', () => {
      quotesRoutes.forEach((route) => {
        expect(route.private).toBe(true)
      })
    })

    it('quotes list route supports both list and tab paths', () => {
      const quotesRoute = quotesRoutes[0]

      expect(quotesRoute.path).toContain(QUOTES_LIST_ROUTE)
      expect(quotesRoute.path).toContain(QUOTES_TAB_ROUTE)
    })

    it('quote details route has the correct path', () => {
      const detailsRoute = quotesRoutes[1]

      expect(detailsRoute.path).toBe(QUOTE_DETAILS_ROUTE)
    })

    it('all routes have an element defined', () => {
      quotesRoutes.forEach((route) => {
        expect(route.element).toBeDefined()
      })
    })
  })
})
