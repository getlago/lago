import { renderHook } from '@testing-library/react'

import { useNavigate } from '../useNavigate'

const { mockNavigate } = (
  globalThis as unknown as { __testRouterMocks: { mockNavigate: jest.Mock } }
).__testRouterMocks

jest.mock('../utils/prependOrgSlug', () => ({
  prependOrgSlug: jest.fn((path: string, slug: string | undefined) => {
    if (!slug || !path.startsWith('/') || path === '/') return path
    if (path.startsWith(`/${slug}/`) || path === `/${slug}`) return path
    return `/${slug}${path}`
  }),
}))

const mockUseParams = jest.requireMock('react-router-dom').useParams as jest.Mock

describe('useNavigate', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseParams.mockReturnValue({ organizationSlug: 'acme' })
  })

  describe('GIVEN the user is inside an organization context', () => {
    describe('WHEN navigating with a number (history delta)', () => {
      it('THEN should call react-router navigate with the number directly', () => {
        const { result } = renderHook(() => useNavigate())

        result.current(-1)

        expect(mockNavigate).toHaveBeenCalledWith(-1)
      })
    })

    describe('WHEN navigating with an absolute string path', () => {
      it('THEN should prepend the org slug', () => {
        const { result } = renderHook(() => useNavigate())

        result.current('/customers')

        expect(mockNavigate).toHaveBeenCalledWith('/acme/customers')
      })
    })

    describe('WHEN navigating with the root path "/"', () => {
      it('THEN should not prepend the slug', () => {
        const { result } = renderHook(() => useNavigate())

        result.current('/')

        expect(mockNavigate).toHaveBeenCalledWith('/')
      })
    })

    describe('WHEN navigating with an already-prefixed path', () => {
      it('THEN should not double-prepend the slug', () => {
        const { result } = renderHook(() => useNavigate())

        result.current('/acme/customers')

        expect(mockNavigate).toHaveBeenCalledWith('/acme/customers')
      })
    })

    describe('WHEN navigating with skipSlugPrepend option', () => {
      it('THEN should pass the path unchanged', () => {
        const { result } = renderHook(() => useNavigate())

        result.current('/other-org/customers', { skipSlugPrepend: true })

        expect(mockNavigate).toHaveBeenCalledWith('/other-org/customers', {})
      })
    })

    describe('WHEN navigating with options (replace, state)', () => {
      it('THEN should forward the options to react-router navigate', () => {
        const { result } = renderHook(() => useNavigate())
        const state = { from: '/previous' }

        result.current('/customers', { replace: true, state })

        expect(mockNavigate).toHaveBeenCalledWith('/acme/customers', {
          replace: true,
          state,
        })
      })
    })

    describe('WHEN navigating with an object To', () => {
      it('THEN should pass the object through without slug prepend', () => {
        const { result } = renderHook(() => useNavigate())
        const to = { pathname: '/customers', search: '?page=2' }

        result.current(to)

        expect(mockNavigate).toHaveBeenCalledWith(to)
      })
    })
  })

  describe('GIVEN the user is outside an organization context', () => {
    beforeEach(() => {
      mockUseParams.mockReturnValue({})
    })

    describe('WHEN navigating with an absolute string path', () => {
      it('THEN should not prepend any slug', () => {
        const { result } = renderHook(() => useNavigate())

        result.current('/login')

        expect(mockNavigate).toHaveBeenCalledWith('/login')
      })
    })
  })

  describe('GIVEN no options are provided', () => {
    describe('WHEN navigating with only a path', () => {
      it('THEN should call react-router navigate with only the path (no empty options object)', () => {
        const { result } = renderHook(() => useNavigate())

        result.current('/customers')

        expect(mockNavigate).toHaveBeenCalledTimes(1)
        expect(mockNavigate).toHaveBeenCalledWith('/acme/customers')
      })
    })
  })
})
