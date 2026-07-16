import { act, renderHook, waitFor } from '@testing-library/react'

import { CreateRoleInput, LagoApiError, PermissionEnum } from '~/generated/graphql'

import { useRoleCreateEdit } from '../useRoleCreateEdit'

const mockRefetchQueries = jest.fn()

jest.mock('@apollo/client', () => ({
  ...jest.requireActual('@apollo/client'),
  useApolloClient: () => ({
    refetchQueries: mockRefetchQueries,
  }),
}))

const mockUseParams = jest.fn()
const mockUseLocation = jest.fn()
const mockNavigate = jest.fn()

const mockCreateRoleMutation = jest.fn()
const mockEditRoleMutation = jest.fn()
const mockAddToast = jest.fn()
const mockHasPermissions = jest.fn()

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: () => mockUseParams(),
  useLocation: () => mockUseLocation(),
  useNavigate: () => mockNavigate,
  generatePath: (path: string, params?: Record<string, string>) => {
    if (params) {
      return Object.entries(params).reduce(
        (acc, [key, value]) => acc.replace(`:${key}`, value),
        path,
      )
    }
    return path
  },
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  addToast: (params: unknown) => mockAddToast(params),
  envGlobalVar: () => ({ disableSignUp: false }),
}))

jest.mock('~/core/router', () => ({
  ROLE_DETAILS_ROUTE: '/settings/roles/:roleId',
  HOME_ROUTE: '/',
  useNavigate: () => mockNavigate,
  useLocation: () => mockUseLocation(),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useCreateRoleMutation: () => [mockCreateRoleMutation],
  useEditRoleMutation: () => [mockEditRoleMutation],
}))

describe('useRoleCreateEdit', () => {
  beforeEach(() => {
    mockUseParams.mockReturnValue({})
    mockUseLocation.mockReturnValue({ search: '' })
    mockCreateRoleMutation.mockResolvedValue({ data: { createRole: { id: 'new-role-id' } } })
    mockEditRoleMutation.mockResolvedValue({ data: { updateRole: { id: 'edit-role-123' } } })
    mockHasPermissions.mockReturnValue(true)
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  describe('roleId detection', () => {
    it('returns undefined roleId when no params or query', () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.roleId).toBeUndefined()
    })

    it('returns roleId from URL params when editing', () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })

      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.roleId).toBe('edit-role-123')
    })

    it('returns roleId from query param when duplicating', () => {
      mockUseLocation.mockReturnValue({ search: '?duplicate-from=duplicate-role-456' })

      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.roleId).toBe('duplicate-role-456')
    })

    it('prioritizes URL param over query param', () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })
      mockUseLocation.mockReturnValue({ search: '?duplicate-from=duplicate-role-456' })

      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.roleId).toBe('edit-role-123')
    })
  })

  describe('isEdition flag', () => {
    it('returns false when creating new role', () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.isEdition).toBe(false)
    })

    it('returns true when editing existing role', () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })

      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.isEdition).toBe(true)
    })

    it('returns false when duplicating a role', () => {
      mockUseLocation.mockReturnValue({ search: '?duplicate-from=duplicate-role-456' })

      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.isEdition).toBe(false)
    })
  })

  describe('handleSave function', () => {
    it('returns handleSave function', () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      expect(result.current.handleSave).toBeDefined()
      expect(typeof result.current.handleSave).toBe('function')
    })

    it('calls createRoleMutation when creating a new role', async () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'New Role',
        code: 'new_role',
        description: 'A new role description',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      expect(mockCreateRoleMutation).toHaveBeenCalled()
      expect(mockEditRoleMutation).not.toHaveBeenCalled()
    })

    it('calls editRoleMutation when editing an existing role', async () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'Updated Role',
        code: 'updated_role',
        description: 'Updated description',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      expect(mockEditRoleMutation).toHaveBeenCalled()
      expect(mockCreateRoleMutation).not.toHaveBeenCalled()
    })

    it('passes correct input to createRoleMutation', async () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'New Role',
        code: 'new_role',
        description: 'A new role description',
        permissions: [PermissionEnum.PlansView, PermissionEnum.PlansCreate],
      } as CreateRoleInput

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      expect(mockCreateRoleMutation).toHaveBeenCalledWith({
        variables: {
          input: formValues,
        },
        context: {
          silentErrorCodes: [LagoApiError.UnprocessableEntity],
        },
      })
    })

    it('excludes code when editing a role', async () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'Updated Role',
        code: 'updated_role',
        description: 'Updated description',
        permissions: [PermissionEnum.PlansView],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      expect(mockEditRoleMutation).toHaveBeenCalledWith({
        variables: {
          input: {
            id: 'edit-role-123',
            name: 'Updated Role',
            description: 'Updated description',
            permissions: [PermissionEnum.PlansView],
          },
        },
      })
    })

    it('shows success toast after creating a role', async () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'New Role',
        code: 'new_role',
        description: 'A new role description',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          message: 'text_1766158947598y30l6z5btl6',
          severity: 'success',
        })
      })
    })

    it('shows success toast after editing a role', async () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'Updated Role',
        code: 'updated_role',
        description: 'Updated description',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      await waitFor(() => {
        expect(mockAddToast).toHaveBeenCalledWith({
          message: 'text_176615894759841ijqrfnb29',
          severity: 'success',
        })
      })
    })

    it('navigates to role details after creating a role', async () => {
      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'New Role',
        code: 'new_role',
        description: '',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/settings/roles/new-role-id')
      })
    })

    it('navigates to role details after editing a role', async () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'Updated Role',
        code: 'updated_role',
        description: '',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/settings/roles/edit-role-123')
      })
    })

    it('does not navigate or toast when create returns no data', async () => {
      mockCreateRoleMutation.mockResolvedValue({ data: { createRole: null } })

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'New Role',
        code: 'new_role',
        description: '',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      expect(mockAddToast).not.toHaveBeenCalled()
      expect(mockNavigate).not.toHaveBeenCalled()
    })

    it('does not navigate or toast when edit returns no data', async () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })
      mockEditRoleMutation.mockResolvedValue({ data: { updateRole: null } })

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'Updated Role',
        code: 'updated_role',
        description: '',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      expect(mockAddToast).not.toHaveBeenCalled()
      expect(mockNavigate).not.toHaveBeenCalled()
    })

    it('navigates to home when user does not have rolesView permission after creating', async () => {
      mockHasPermissions.mockReturnValue(false)

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'New Role',
        code: 'new_role',
        description: '',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/')
        expect(mockNavigate).not.toHaveBeenCalledWith('/settings/roles/new-role-id')
      })
    })

    it('navigates to home when user does not have rolesView permission after editing', async () => {
      mockUseParams.mockReturnValue({ roleId: 'edit-role-123' })
      mockHasPermissions.mockReturnValue(false)

      const { result } = renderHook(() => useRoleCreateEdit())

      const formValues = {
        name: 'Updated Role',
        code: 'updated_role',
        description: '',
        permissions: [],
      }

      await act(async () => {
        await result.current.handleSave(formValues)
      })

      await waitFor(() => {
        expect(mockNavigate).toHaveBeenCalledWith('/')
        expect(mockNavigate).not.toHaveBeenCalledWith('/settings/roles/edit-role-123')
      })
    })
  })
})
