import { renderHook } from '@testing-library/react'

import { currentOrganizationVar } from '~/core/apolloClient/reactiveVars'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

const mockUseGetOrganizationInfosQuery = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => ({}),
}))

jest.mock('~/hooks/auth/useIsAuthenticated', () => ({
  useIsAuthenticated: () => ({ isAuthenticated: true }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetOrganizationInfosQuery: (opts: unknown) => mockUseGetOrganizationInfosQuery(opts),
}))

describe('useOrganizationInfos — skip-on-null-var guard', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseGetOrganizationInfosQuery.mockReturnValue({
      data: undefined,
      loading: false,
      refetch: jest.fn(),
    })
  })

  it('skips the org query when there is no current org id (no header to send)', () => {
    currentOrganizationVar(null)

    renderHook(() => useOrganizationInfos())

    expect(mockUseGetOrganizationInfosQuery).toHaveBeenCalledWith(
      expect.objectContaining({ skip: true }),
    )
  })

  it('runs the org query once the current org id is set', () => {
    currentOrganizationVar('org-1')

    renderHook(() => useOrganizationInfos())

    expect(mockUseGetOrganizationInfosQuery).toHaveBeenCalledWith(
      expect.objectContaining({ skip: false }),
    )

    currentOrganizationVar(null)
  })
})
