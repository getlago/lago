import { FeatureFlagEnum } from '~/generated/graphql'

import { CustomRouteObject } from './types'
import { lazyLoad } from './utils'

// ----------- Pages -----------
const Quotes = lazyLoad(() => import('~/pages/quotes/Quotes'))
const QuoteDetails = lazyLoad(() => import('~/pages/quotes/QuoteDetails'))
const CreateQuote = lazyLoad(() => import('~/pages/quotes/CreateQuote'))
const EditQuote = lazyLoad(() => import('~/pages/quotes/EditQuote'))
const VoidQuote = lazyLoad(() => import('~/pages/quotes/VoidQuote'))
const ApproveQuote = lazyLoad(() => import('~/pages/quotes/ApproveQuote'))
const QuoteVersionPreview = lazyLoad(() => import('~/pages/quotes/QuoteVersionPreview'))
const VoidOrderForm = lazyLoad(() => import('~/pages/quotes/VoidOrderForm'))
const SignOrderForm = lazyLoad(() => import('~/pages/quotes/SignOrderForm'))
const OrderFormDetails = lazyLoad(() => import('~/pages/quotes/OrderFormDetails'))
const EditOrder = lazyLoad(() => import('~/pages/quotes/EditOrder'))

// ----------- Routes -----------
export const QUOTES_LIST_ROUTE = '/quotes'
export const QUOTES_TAB_ROUTE = `${QUOTES_LIST_ROUTE}/:tab`
export const QUOTE_DETAILS_ROUTE = '/quote/:quoteId/:tab'
export const CREATE_QUOTE_ROUTE = '/quote/create'
export const EDIT_QUOTE_ROUTE = '/quote/:quoteId/version/:versionId/edit'
export const VOID_QUOTE_ROUTE = '/quote/:quoteId/version/:versionId/void'
export const APPROVE_QUOTE_ROUTE = '/quote/:quoteId/version/:versionId/approve'
export const QUOTE_VERSION_PREVIEW_ROUTE = '/quote/:quoteId/version/:versionId/preview'
export const VOID_ORDER_FORM_ROUTE = '/order-form/:orderFormId/void'
export const SIGN_ORDER_FORM_ROUTE = '/order-form/:orderFormId/sign'
export const ORDER_FORM_DETAILS_ROUTE = '/order-form/:orderFormId'
export const EDIT_ORDER_ROUTE = '/order/:orderId/edit'

export const quotesRoutes: CustomRouteObject[] = [
  {
    path: [QUOTES_LIST_ROUTE, QUOTES_TAB_ROUTE],
    private: true,
    element: <Quotes />,
    permissions: ['quotesView'],
    featureFlag: FeatureFlagEnum.OrderForms,
  },
  {
    path: QUOTE_DETAILS_ROUTE,
    private: true,
    element: <QuoteDetails />,
    permissions: ['quotesView'],
    featureFlag: FeatureFlagEnum.OrderForms,
  },
]

export const quotesModificationRoutes: CustomRouteObject[] = [
  {
    path: CREATE_QUOTE_ROUTE,
    private: true,
    element: <CreateQuote />,
    permissions: ['quotesCreate'],
    featureFlag: FeatureFlagEnum.OrderForms,
  },
  {
    path: EDIT_QUOTE_ROUTE,
    private: true,
    element: <EditQuote />,
    permissions: ['quotesUpdate'],
  },
  {
    path: VOID_QUOTE_ROUTE,
    private: true,
    element: <VoidQuote />,
    permissions: ['quotesVoid'],
  },
  {
    path: APPROVE_QUOTE_ROUTE,
    private: true,
    element: <ApproveQuote />,
    permissions: ['quotesApprove'],
  },
  {
    path: QUOTE_VERSION_PREVIEW_ROUTE,
    private: true,
    element: <QuoteVersionPreview />,
    permissions: ['quotesView'],
  },
]

export const orderFormsModificationRoutes: CustomRouteObject[] = [
  {
    path: VOID_ORDER_FORM_ROUTE,
    private: true,
    element: <VoidOrderForm />,
    permissions: ['quotesVoid'],
  },
  {
    path: SIGN_ORDER_FORM_ROUTE,
    private: true,
    element: <SignOrderForm />,
    permissions: ['orderFormsSign'],
  },
  {
    path: ORDER_FORM_DETAILS_ROUTE,
    private: true,
    element: <OrderFormDetails />,
    permissions: ['orderFormsView'],
  },
]

export const ordersModificationRoutes: CustomRouteObject[] = [
  {
    path: EDIT_ORDER_ROUTE,
    private: true,
    element: <EditOrder />,
    permissions: ['ordersUpdate'],
  },
]
