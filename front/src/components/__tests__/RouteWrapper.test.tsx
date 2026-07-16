import { render, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'

import { RouteWrapper } from '~/components/RouteWrapper'

const mockNavigate = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockNavigate,
}))

const mockSetMainRouterUrl = jest.fn()
let mockMainRouterUrl = ''

jest.mock('~/hooks/useDeveloperTool', () => ({
  DEVTOOL_TAB_PARAMS: 'devtool-tab',
  useDeveloperTool: () => ({
    mainRouterUrl: mockMainRouterUrl,
    setMainRouterUrl: mockSetMainRouterUrl,
  }),
}))

jest.mock('~/hooks/auth/useIsAuthenticated', () => ({
  useIsAuthenticated: () => ({
    isAuthenticated: true,
  }),
}))

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    onRouteEnter: jest.fn(),
  }),
}))

const TEST_SLUG = 'test-slug'

jest.mock('~/core/router', () => ({
  routes: [],
  useNavigate: () => mockNavigate,
  useLocation: () => ({
    // First segment of `pathname` is treated as the active org slug by
    // RouteWrapper's MemoryRouter→BrowserRouter bridge.
    pathname: `/${TEST_SLUG}/api-keys`,
    strippedPathname: '/api-keys',
    search: '',
    hash: '',
    state: null,
    key: 'default',
  }),
}))

describe('RouteWrapper', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockMainRouterUrl = ''
  })

  describe('mainRouterUrl navigation effect', () => {
    describe('GIVEN mainRouterUrl is empty', () => {
      describe('WHEN RouteWrapper renders', () => {
        it('THEN it should not trigger navigation', () => {
          mockMainRouterUrl = ''

          render(
            <MemoryRouter>
              <RouteWrapper />
            </MemoryRouter>,
          )

          expect(mockNavigate).not.toHaveBeenCalled()
          expect(mockSetMainRouterUrl).not.toHaveBeenCalled()
        })
      })
    })

    describe('GIVEN mainRouterUrl has a value', () => {
      describe('WHEN RouteWrapper renders', () => {
        it('THEN it should navigate to that URL and reset mainRouterUrl', async () => {
          mockMainRouterUrl = '/api-keys/create'

          render(
            <MemoryRouter>
              <RouteWrapper />
            </MemoryRouter>,
          )

          await waitFor(() => {
            expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_SLUG}/api-keys/create`, {
              skipSlugPrepend: true,
            })
            expect(mockSetMainRouterUrl).toHaveBeenCalledWith('')
          })
        })
      })
    })

    describe('GIVEN mainRouterUrl is set to webhook edit route', () => {
      describe('WHEN RouteWrapper renders', () => {
        it('THEN it should navigate to the webhook edit page', async () => {
          mockMainRouterUrl = '/webhook/123/edit'

          render(
            <MemoryRouter>
              <RouteWrapper />
            </MemoryRouter>,
          )

          await waitFor(() => {
            expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_SLUG}/webhook/123/edit`, {
              skipSlugPrepend: true,
            })
            expect(mockSetMainRouterUrl).toHaveBeenCalledWith('')
          })
        })
      })
    })

    describe('GIVEN mainRouterUrl is set to api keys edit route', () => {
      describe('WHEN RouteWrapper renders', () => {
        it('THEN it should navigate to the api keys edit page', async () => {
          mockMainRouterUrl = '/api-keys/456/edit'

          render(
            <MemoryRouter>
              <RouteWrapper />
            </MemoryRouter>,
          )

          await waitFor(() => {
            expect(mockNavigate).toHaveBeenCalledWith(`/${TEST_SLUG}/api-keys/456/edit`, {
              skipSlugPrepend: true,
            })
            expect(mockSetMainRouterUrl).toHaveBeenCalledWith('')
          })
        })
      })
    })
  })

  describe('rendering', () => {
    describe('GIVEN valid router context', () => {
      describe('WHEN RouteWrapper is rendered', () => {
        it('THEN it should render without crashing', () => {
          mockMainRouterUrl = ''

          const { container } = render(
            <MemoryRouter>
              <RouteWrapper />
            </MemoryRouter>,
          )

          expect(container).toBeDefined()
        })
      })
    })
  })
})
