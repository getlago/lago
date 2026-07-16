import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import CustomerPortal, {
  CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID,
  CUSTOMER_PORTAL_ERROR_STATE_TEST_ID,
  CUSTOMER_PORTAL_LOADING_STATE_TEST_ID,
} from '../CustomerPortal'

const mockUseCustomerPortalTranslate = jest.fn()
const mockUseCustomerPortalData = jest.fn()
const mockHasDefinedGQLError = jest.fn()

jest.mock('~/components/customerPortal/common/useCustomerPortalTranslate', () => ({
  __esModule: true,
  default: () => mockUseCustomerPortalTranslate(),
}))

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalNavigation', () => ({
  __esModule: true,
  default: () => ({ pathname: '/test' }),
}))

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalData', () => ({
  useCustomerPortalData: () => mockUseCustomerPortalData(),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  hasDefinedGQLError: (...args: unknown[]) => mockHasDefinedGQLError(...args),
}))

jest.mock('~/components/customerPortal/common/CustomerPortalLoading', () => ({
  __esModule: true,
  default: () => <div data-test="mock-portal-loading">Loading Content</div>,
}))

jest.mock('~/components/customerPortal/common/CustomerPortalSidebar', () => ({
  __esModule: true,
  default: () => <div data-test="mock-portal-sidebar">Sidebar</div>,
}))

jest.mock('~/components/customerPortal/common/SectionError', () => ({
  __esModule: true,
  default: () => <div data-test="mock-section-error">Error</div>,
}))

jest.mock('~/components/customerPortal/common/SectionTitle', () => ({
  __esModule: true,
  default: () => <div data-test="mock-section-title">Title</div>,
}))

jest.mock('~/components/customerPortal/common/SectionLoading', () => ({
  LoaderCustomerInformationSection: () => <div>Loader</div>,
  LoaderInvoicesListSection: () => <div>Loader</div>,
  LoaderUsageSection: () => <div>Loader</div>,
  LoaderWalletSection: () => <div>Loader</div>,
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  Outlet: () => <div data-test="mock-outlet">Outlet Content</div>,
  useNavigate: () => jest.fn(),
  useParams: () => ({ token: 'test-token' }),
}))

const setupDefaultMocks = () => {
  mockUseCustomerPortalTranslate.mockReturnValue({
    translate: jest.fn((key: string) => key),
    documentLocale: 'en',
    error: undefined,
    loading: false,
    isUnauthenticated: false,
  })

  mockUseCustomerPortalData.mockReturnValue({
    data: {
      customerPortalOrganization: {
        id: 'org-1',
        name: 'Test Org',
        logoUrl: null,
        premiumIntegrations: [],
      },
    },
    loading: false,
    error: undefined,
  })

  mockHasDefinedGQLError.mockReturnValue(false)
}

describe('CustomerPortal', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  describe('GIVEN the portal is in error state', () => {
    describe('WHEN isUnauthenticated is true', () => {
      it('THEN should render the error state', () => {
        mockUseCustomerPortalTranslate.mockReturnValue({
          translate: jest.fn((key: string) => key),
          documentLocale: 'en',
          error: undefined,
          loading: false,
          isUnauthenticated: true,
        })

        render(<CustomerPortal />)

        expect(screen.getByTestId(CUSTOMER_PORTAL_ERROR_STATE_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the GQL error is Unauthorized', () => {
      it('THEN should render the error state', () => {
        mockUseCustomerPortalTranslate.mockReturnValue({
          translate: jest.fn((key: string) => key),
          documentLocale: 'en',
          error: { message: 'Unauthorized' },
          loading: false,
          isUnauthenticated: false,
        })
        mockHasDefinedGQLError.mockReturnValue(true)

        render(<CustomerPortal />)

        expect(screen.getByTestId(CUSTOMER_PORTAL_ERROR_STATE_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN both isUnauthenticated and GQL error are present', () => {
      it('THEN should render the error state', () => {
        mockUseCustomerPortalTranslate.mockReturnValue({
          translate: jest.fn((key: string) => key),
          documentLocale: 'en',
          error: { message: 'Unauthorized' },
          loading: false,
          isUnauthenticated: true,
        })
        mockHasDefinedGQLError.mockReturnValue(true)

        render(<CustomerPortal />)

        expect(screen.getByTestId(CUSTOMER_PORTAL_ERROR_STATE_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the portal is loading', () => {
    describe('WHEN portalIsLoading is true', () => {
      it('THEN should render the loading state', () => {
        mockUseCustomerPortalTranslate.mockReturnValue({
          translate: jest.fn((key: string) => key),
          documentLocale: 'en',
          error: undefined,
          loading: true,
          isUnauthenticated: false,
        })

        render(<CustomerPortal />)

        expect(screen.getByTestId(CUSTOMER_PORTAL_LOADING_STATE_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the portal has loaded successfully', () => {
    describe('WHEN data is available and no errors', () => {
      it('THEN should render the content state', () => {
        render(<CustomerPortal />)

        expect(screen.getByTestId(CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID)).toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_PORTAL_ERROR_STATE_TEST_ID)).not.toBeInTheDocument()
        expect(screen.queryByTestId(CUSTOMER_PORTAL_LOADING_STATE_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN a non-Unauthorized GQL error occurs', () => {
      it('THEN should still render the content state', () => {
        mockUseCustomerPortalTranslate.mockReturnValue({
          translate: jest.fn((key: string) => key),
          documentLocale: 'en',
          error: { message: 'Some other error' },
          loading: false,
          isUnauthenticated: false,
        })
        mockHasDefinedGQLError.mockReturnValue(false)

        render(<CustomerPortal />)

        expect(screen.getByTestId(CUSTOMER_PORTAL_CONTENT_STATE_TEST_ID)).toBeInTheDocument()
      })
    })
  })
})
