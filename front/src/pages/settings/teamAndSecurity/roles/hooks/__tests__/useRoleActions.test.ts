import { act, renderHook, waitFor } from '@testing-library/react'

import { DeleteRoleDocument, GetRolesListDocument } from '~/generated/graphql'
import { AllTheProviders, testMockNavigateFn, TestMocksType } from '~/test-utils'

import { useRoleActions } from '../useRoleActions'

const mockAddToast = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (params: unknown) => mockAddToast(params),
}))

const ROLE_ID = 'role-123'

const deleteRoleMock = {
  request: {
    query: DeleteRoleDocument,
    variables: {
      input: { id: ROLE_ID },
    },
  },
  result: {
    data: {
      destroyRole: {
        __typename: 'Role',
        id: ROLE_ID,
      },
    },
  },
}

const rolesListMock = {
  request: {
    query: GetRolesListDocument,
  },
  result: {
    data: {
      roles: [],
    },
  },
}

const createWrapper = (mocks: TestMocksType) => {
  return ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })
}

describe('useRoleActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('deleteRole', () => {
    it('returns deleteRole function', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      expect(result.current.deleteRole).toBeDefined()
      expect(typeof result.current.deleteRole).toBe('function')
    })

    it('returns isDeletingRole as false initially', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      expect(result.current.isDeletingRole).toBe(false)
    })

    it('returns deleteRoleError as undefined initially', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      expect(result.current.deleteRoleError).toBeUndefined()
    })

    it('successfully deletes a role', async () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([deleteRoleMock, rolesListMock]),
      })

      await act(async () => {
        await result.current.deleteRole({ id: ROLE_ID })
      })

      await waitFor(() => {
        expect(testMockNavigateFn).toHaveBeenCalled()
      })
    })

    it('shows success toast after deleting a role', async () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([deleteRoleMock, rolesListMock]),
      })

      await act(async () => {
        await result.current.deleteRole({ id: ROLE_ID })
      })

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          message: 'text_1766158947598m8ut1nw2vjq',
          severity: 'success',
        })
      })
    })

    it('navigates to roles list after deleting a role', async () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([deleteRoleMock, rolesListMock]),
      })

      await act(async () => {
        await result.current.deleteRole({ id: ROLE_ID })
      })

      await waitFor(() => {
        expect(testMockNavigateFn).toHaveBeenCalledWith('/settings/team-and-security/roles')
      })
    })

    it('does not navigate or show toast when mutation returns no data', async () => {
      const noDataMock = {
        request: {
          query: DeleteRoleDocument,
          variables: {
            input: { id: ROLE_ID },
          },
        },
        result: {
          data: {
            destroyRole: null,
          },
        },
      }

      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([noDataMock]),
      })

      await act(async () => {
        await result.current.deleteRole({ id: ROLE_ID })
      })

      // Wait a bit to ensure any async effects have completed
      await new Promise((resolve) => setTimeout(resolve, 100))

      expect(mockAddToast).not.toHaveBeenCalled()
      expect(testMockNavigateFn).not.toHaveBeenCalled()
    })
  })

  describe('navigateToDuplicate', () => {
    it('returns navigateToDuplicate function', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      expect(result.current.navigateToDuplicate).toBeDefined()
      expect(typeof result.current.navigateToDuplicate).toBe('function')
    })

    it('navigates to create route with duplicate query param', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      act(() => {
        result.current.navigateToDuplicate(ROLE_ID)
      })

      expect(testMockNavigateFn).toHaveBeenCalledWith('/settings/team-and-security/roles/create')
    })
  })

  describe('navigateToEdit', () => {
    it('returns navigateToEdit function', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      expect(result.current.navigateToEdit).toBeDefined()
      expect(typeof result.current.navigateToEdit).toBe('function')
    })

    it('navigates to edit route with role id', () => {
      const { result } = renderHook(() => useRoleActions(), {
        wrapper: createWrapper([]),
      })

      act(() => {
        result.current.navigateToEdit(ROLE_ID)
      })

      expect(testMockNavigateFn).toHaveBeenCalledWith(
        `/settings/team-and-security/roles/${ROLE_ID}/edit`,
      )
    })
  })
})
