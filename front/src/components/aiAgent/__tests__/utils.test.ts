import { CustomRouteObject } from '~/core/router/types'

import { getHiddenAiAgentPaths } from '../utils'

jest.mock('~/core/router/ObjectsRoutes', () => ({
  objectCreationRoutes: [
    {
      path: ['/create/plans', '/update/plan/:planId'],
      private: true,
    },
    {
      path: '/create/invoice',
      private: true,
    },
    {
      path: undefined,
      private: true,
    },
  ] as CustomRouteObject[],
}))

jest.mock('~/core/router/CustomerRoutes', () => ({
  customerObjectCreationRoutes: [
    {
      path: '/customer/:customerId/request-overdue-payment',
      private: true,
    },
    {
      path: ['/customer/:customerId/invoice/:invoiceId/create/credit-notes'],
      private: true,
    },
  ] as CustomRouteObject[],
  customerVoidRoutes: [
    {
      path: '/customer/:customerId/invoice/void/:invoiceId',
      private: true,
    },
    {
      path: '/customer/:customerId/invoice/regenerate/:invoiceId',
      private: true,
    },
  ] as CustomRouteObject[],
}))

jest.mock('~/core/router/SettingRoutes', () => ({
  settingsObjectCreationRoutes: [
    {
      path: ['/settings/dunnings/create', '/settings/dunnings/:campaignId/edit'],
      private: true,
    },
    {
      path: ['/settings/custom-section/create', '/settings/custom-section/:sectionId/edit'],
      private: true,
    },
    {
      path: ['/settings/billing-entity/create', '/settings/billing-entity/:entityId/edit'],
      private: true,
    },
    {
      path: ['/settings/pricing-unit/create', '/settings/pricing-unit/:unitId/edit'],
      private: true,
    },
  ] as CustomRouteObject[],
}))

jest.mock('~/core/router/QuotesRoutes', () => ({
  quotesModificationRoutes: [
    {
      path: '/quote/create',
      private: true,
    },
    {
      path: '/quote/:quoteId/version/:versionId/edit',
      private: true,
    },
    {
      path: '/quote/:quoteId/version/:versionId/void',
      private: true,
    },
    {
      path: '/quote/:quoteId/version/:versionId/approve',
      private: true,
    },
  ] as CustomRouteObject[],
}))

jest.mock('~/core/router/index', () => ({
  ERROR_404_ROUTE: '/404',
  FORBIDDEN_ROUTE: '/forbidden',
}))

describe('getHiddenAiAgentPaths', () => {
  it('should transform all routes into path objects', () => {
    const result = getHiddenAiAgentPaths()

    expect(result).toHaveLength(25)
    expect(result).toEqual([
      { path: '/create/plans' },
      { path: '/update/plan/:planId' },
      { path: '/create/invoice' },
      { path: '/customer/:customerId/request-overdue-payment' },
      { path: '/customer/:customerId/invoice/:invoiceId/create/credit-notes' },
      { path: '/customer/:customerId/invoice/void/:invoiceId' },
      { path: '/customer/:customerId/invoice/regenerate/:invoiceId' },
      { path: '/settings/dunnings/create' },
      { path: '/settings/dunnings/:campaignId/edit' },
      { path: '/settings/custom-section/create' },
      { path: '/settings/custom-section/:sectionId/edit' },
      { path: '/settings/billing-entity/create' },
      { path: '/settings/billing-entity/:entityId/edit' },
      { path: '/settings/pricing-unit/create' },
      { path: '/settings/pricing-unit/:unitId/edit' },
      { path: '/customer-portal/:token' },
      { path: '/customer-portal/:token/usage/:itemId' },
      { path: '/customer-portal/:token/wallet/:walletId' },
      { path: '/customer-portal/:token/customer-edit-information' },
      { path: '/quote/create' },
      { path: '/quote/:quoteId/version/:versionId/edit' },
      { path: '/quote/:quoteId/version/:versionId/void' },
      { path: '/quote/:quoteId/version/:versionId/approve' },
      { path: '/404' },
      { path: '/forbidden' },
    ])
  })

  it('should handle routes with array paths', () => {
    const result = getHiddenAiAgentPaths()

    // Should flatten array paths into individual path objects
    const planPaths = result.filter((p) => p.path.includes('/plan'))

    expect(planPaths).toHaveLength(2)
    expect(planPaths).toContainEqual({ path: '/create/plans' })
    expect(planPaths).toContainEqual({ path: '/update/plan/:planId' })
  })

  it('should handle routes with single string paths', () => {
    const result = getHiddenAiAgentPaths()

    const invoicePath = result.find((p) => p.path === '/create/invoice')

    expect(invoicePath).toEqual({ path: '/create/invoice' })
  })

  it('should skip routes without path property', () => {
    const result = getHiddenAiAgentPaths()

    // Should not include routes with undefined path
    expect(result.every((p) => p.path !== undefined)).toBe(true)
  })

  it('should include paths from objectCreationRoutes, customerObjectCreationRoutes, customerVoidRoutes, and settingsObjectCreationRoutes', () => {
    const result = getHiddenAiAgentPaths()

    // Check objectCreationRoutes paths
    expect(result.some((p) => p.path === '/create/plans')).toBe(true)
    expect(result.some((p) => p.path === '/create/invoice')).toBe(true)

    // Check customerObjectCreationRoutes paths
    expect(result.some((p) => p.path === '/customer/:customerId/request-overdue-payment')).toBe(
      true,
    )
    expect(
      result.some((p) => p.path === '/customer/:customerId/invoice/:invoiceId/create/credit-notes'),
    ).toBe(true)

    // Check customerVoidRoutes paths
    expect(result.some((p) => p.path === '/customer/:customerId/invoice/void/:invoiceId')).toBe(
      true,
    )
    expect(
      result.some((p) => p.path === '/customer/:customerId/invoice/regenerate/:invoiceId'),
    ).toBe(true)

    // Check settingsObjectCreationRoutes paths
    expect(result.some((p) => p.path === '/settings/dunnings/create')).toBe(true)
    expect(result.some((p) => p.path === '/settings/billing-entity/create')).toBe(true)
  })

  it('should include error routes (404 and forbidden)', () => {
    const result = getHiddenAiAgentPaths()

    expect(result.some((p) => p.path === '/404')).toBe(true)
    expect(result.some((p) => p.path === '/forbidden')).toBe(true)
  })
})
