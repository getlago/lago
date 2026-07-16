import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'
import { MemoryRouter } from 'react-router-dom'

import {
  DeveloperToolProvider,
  resetDevtoolsNavigation,
  useDeveloperTool,
} from '~/hooks/useDeveloperTool'

// Mock useCurrentUser
jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    currentUser: { id: 'test-user' },
  }),
}))

// Mock usePanel
const mockOpenPanel = jest.fn()
const mockClosePanel = jest.fn()
const mockTogglePanel = jest.fn()

jest.mock('~/hooks/ui/usePanel', () => ({
  usePanel: () => ({
    panelOpen: false,
    openPanel: mockOpenPanel,
    closePanel: mockClosePanel,
    togglePanel: mockTogglePanel,
  }),
}))

const wrapper = ({ children }: { children: ReactNode }) => (
  <MemoryRouter>
    <DeveloperToolProvider>{children}</DeveloperToolProvider>
  </MemoryRouter>
)

describe('useDeveloperTool', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    window.history.replaceState({}, '', '/')
  })

  describe('DeveloperToolProvider', () => {
    describe('GIVEN the hook is used within the provider', () => {
      describe('WHEN the hook is called', () => {
        it('THEN it should provide all context values', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          expect(result.current).toHaveProperty('url')
          expect(result.current).toHaveProperty('setUrl')
          expect(result.current).toHaveProperty('mainRouterUrl')
          expect(result.current).toHaveProperty('setMainRouterUrl')
          expect(result.current).toHaveProperty('openPanel')
          expect(result.current).toHaveProperty('closePanel')
        })

        it('THEN url should be initialized as empty string', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          expect(result.current.url).toBe('')
        })

        it('THEN mainRouterUrl should be initialized as empty string', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          expect(result.current.mainRouterUrl).toBe('')
        })
      })
    })

    describe('GIVEN the hook is used outside the provider', () => {
      describe('WHEN the hook is called', () => {
        it('THEN it should throw an error', () => {
          const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})

          // Note: The hook uses useNavigate() which requires Router context,
          // so Router error is thrown before the DeveloperToolProvider context check
          expect(() => {
            renderHook(() => useDeveloperTool())
          }).toThrow()

          consoleSpy.mockRestore()
        })
      })
    })
  })

  describe('setUrl (MemoryRouter navigation)', () => {
    describe('GIVEN the hook is initialized', () => {
      describe('WHEN setUrl is called with a path', () => {
        it('THEN url state should be updated to that path', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          act(() => {
            result.current.setUrl('/devtool/webhooks')
          })

          expect(result.current.url).toBe('/devtool/webhooks')
        })
      })

      describe('WHEN setUrl is called multiple times', () => {
        it('THEN url state should reflect the latest value', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          act(() => {
            result.current.setUrl('/devtool/webhooks')
          })
          expect(result.current.url).toBe('/devtool/webhooks')

          act(() => {
            result.current.setUrl('/devtool/events')
          })
          expect(result.current.url).toBe('/devtool/events')
        })
      })
    })
  })

  describe('setMainRouterUrl (BrowserRouter navigation)', () => {
    describe('GIVEN the hook is initialized', () => {
      describe('WHEN setMainRouterUrl is called with a path', () => {
        it('THEN mainRouterUrl state should be updated to that path', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          act(() => {
            result.current.setMainRouterUrl('/api-keys/create')
          })

          expect(result.current.mainRouterUrl).toBe('/api-keys/create')
        })
      })

      describe('WHEN setMainRouterUrl is called multiple times', () => {
        it('THEN mainRouterUrl state should reflect the latest value', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          act(() => {
            result.current.setMainRouterUrl('/api-keys/create')
          })
          expect(result.current.mainRouterUrl).toBe('/api-keys/create')

          act(() => {
            result.current.setMainRouterUrl('/webhook/create')
          })
          expect(result.current.mainRouterUrl).toBe('/webhook/create')
        })
      })

      describe('WHEN setMainRouterUrl is called with empty string', () => {
        it('THEN mainRouterUrl should be reset to empty', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          act(() => {
            result.current.setMainRouterUrl('/api-keys/create')
          })
          expect(result.current.mainRouterUrl).toBe('/api-keys/create')

          act(() => {
            result.current.setMainRouterUrl('')
          })
          expect(result.current.mainRouterUrl).toBe('')
        })
      })
    })
  })

  describe('resetDevtoolsNavigation', () => {
    describe('GIVEN the devtools has navigated to a specific tab', () => {
      describe('WHEN resetDevtoolsNavigation is called', () => {
        it('THEN url should be reset to default devtool route and panel should close', () => {
          const { result } = renderHook(() => useDeveloperTool(), { wrapper })

          act(() => {
            result.current.setUrl('/devtool/webhooks')
          })

          act(() => {
            resetDevtoolsNavigation()
          })

          expect(result.current.url).toBe('/devtool')
          expect(mockClosePanel).toHaveBeenCalled()
        })
      })
    })
  })
})
