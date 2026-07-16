import { renderHook } from '@testing-library/react'
// eslint-disable-next-line lago/no-direct-rrd-nav-import
import { useLocation as useRRLocation } from 'react-router-dom'

import { useLocation } from '../useLocation'

jest.mock('react-router-dom', () => {
  const actual = jest.requireActual('react-router-dom')
  const mockUseParams = jest.fn(actual.useParams)

  return {
    ...actual,
    useNavigate: () => jest.fn(),
    useParams: mockUseParams,
    useLocation: jest.fn(),
  }
})

const mockUseRRLocation = useRRLocation as jest.Mock
const mockUseParams = jest.requireMock('react-router-dom').useParams as jest.Mock

describe('useLocation', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the user is inside an organization context', () => {
    beforeEach(() => {
      mockUseParams.mockReturnValue({ organizationSlug: 'acme' })
    })

    describe('WHEN the pathname includes the org slug', () => {
      it('THEN should return strippedPathname without the slug prefix', () => {
        mockUseRRLocation.mockReturnValue({
          pathname: '/acme/customers',
          search: '',
          hash: '',
          state: null,
          key: 'default',
        })

        const { result } = renderHook(() => useLocation())

        expect(result.current.strippedPathname).toBe('/customers')
        expect(result.current.pathname).toBe('/acme/customers')
      })
    })

    describe('WHEN the pathname is exactly the org slug', () => {
      it('THEN should return "/" as strippedPathname', () => {
        mockUseRRLocation.mockReturnValue({
          pathname: '/acme',
          search: '',
          hash: '',
          state: null,
          key: 'default',
        })

        const { result } = renderHook(() => useLocation())

        expect(result.current.strippedPathname).toBe('/')
      })
    })

    describe('WHEN the pathname has a deep path under the slug', () => {
      it('THEN should strip only the slug prefix', () => {
        mockUseRRLocation.mockReturnValue({
          pathname: '/acme/settings/taxes',
          search: '?page=2',
          hash: '#section',
          state: { from: '/previous' },
          key: 'abc123',
        })

        const { result } = renderHook(() => useLocation())

        expect(result.current.strippedPathname).toBe('/settings/taxes')
        expect(result.current.search).toBe('?page=2')
        expect(result.current.hash).toBe('#section')
        expect(result.current.state).toEqual({ from: '/previous' })
        expect(result.current.key).toBe('abc123')
      })
    })
  })

  describe('GIVEN the user is outside an organization context', () => {
    beforeEach(() => {
      mockUseParams.mockReturnValue({})
    })

    describe('WHEN the pathname has no org slug', () => {
      it('THEN should return strippedPathname equal to pathname', () => {
        mockUseRRLocation.mockReturnValue({
          pathname: '/login',
          search: '',
          hash: '',
          state: null,
          key: 'default',
        })

        const { result } = renderHook(() => useLocation())

        expect(result.current.strippedPathname).toBe('/login')
        expect(result.current.pathname).toBe('/login')
      })
    })
  })
})
