import { renderHook } from '@testing-library/react'

import { CouponStatusEnum, GetCurrentUserInfosDocument } from '~/generated/graphql'
import { usePermissionsCouponActions } from '~/hooks/usePermissionsCouponActions'
import { AllTheProviders } from '~/test-utils'

// Default permissions for convenience
const DEFAULT_PERMISSIONS = {
  couponsCreate: true,
  couponsUpdate: true,
  couponsDelete: true,
}

const mockCurrentUser = {
  currentMembership: {
    id: '2',
    organization: {
      id: '3',
      name: 'Organization',
      logoUrl: 'https://logo.com',
    },
    permissions: DEFAULT_PERMISSIONS,
  },
}

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockCurrentUser,
}))

async function prepare(permissions: Partial<typeof DEFAULT_PERMISSIONS> = DEFAULT_PERMISSIONS) {
  const membership = {
    id: '2',
    organization: {
      id: '3',
      name: 'Organization',
      logoUrl: 'https://logo.com',
    },
    permissions: {
      ...DEFAULT_PERMISSIONS,
      ...permissions,
    },
  }

  mockCurrentUser.currentMembership = membership

  const mocks = [
    {
      request: {
        query: GetCurrentUserInfosDocument,
      },
      result: {
        data: {
          currentUser: {
            id: '1',
            email: 'gavin@hooli.com',
            premium: true,
            memberships: [membership],
            __typename: 'User',
          },
        },
      },
    },
  ]

  const customWrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({
      children,
      mocks,
      forceTypenames: true,
    })

  const { result } = renderHook(() => usePermissionsCouponActions(), {
    wrapper: customWrapper,
  })

  return { result }
}

describe('usePermissionsCouponActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('canCreate', () => {
    it('should return true when user has couponsCreate permission', async () => {
      const { result } = await prepare()

      expect(result.current.canCreate()).toBe(true)
    })

    it('should return false when user does not have couponsCreate permission', async () => {
      const { result } = await prepare({ couponsCreate: false })

      expect(result.current.canCreate()).toBe(false)
    })
  })

  describe('canEdit', () => {
    it('should return true when user has couponsUpdate permission', async () => {
      const { result } = await prepare()

      expect(result.current.canEdit()).toBe(true)
    })

    it('should return false when user does not have couponsUpdate permission', async () => {
      const { result } = await prepare({ couponsUpdate: false })

      expect(result.current.canEdit()).toBe(false)
    })
  })

  describe('canTerminate', () => {
    it('should return true when coupon is active and user has couponsUpdate permission', async () => {
      const { result } = await prepare()

      expect(result.current.canTerminate({ status: CouponStatusEnum.Active })).toBe(true)
    })

    it('should return false when coupon is terminated', async () => {
      const { result } = await prepare()

      expect(result.current.canTerminate({ status: CouponStatusEnum.Terminated })).toBe(false)
    })

    it('should return false when user does not have couponsUpdate permission', async () => {
      const { result } = await prepare({ couponsUpdate: false })

      expect(result.current.canTerminate({ status: CouponStatusEnum.Active })).toBe(false)
    })

    it('should return false when coupon is terminated and user has no permission', async () => {
      const { result } = await prepare({ couponsUpdate: false })

      expect(result.current.canTerminate({ status: CouponStatusEnum.Terminated })).toBe(false)
    })
  })

  describe('canDelete', () => {
    it('should return true when user has couponsDelete permission', async () => {
      const { result } = await prepare()

      expect(result.current.canDelete()).toBe(true)
    })

    it('should return false when user does not have couponsDelete permission', async () => {
      const { result } = await prepare({ couponsDelete: false })

      expect(result.current.canDelete()).toBe(false)
    })
  })

  describe('integration tests', () => {
    it('should return all expected methods from the hook', async () => {
      const { result } = await prepare()

      expect(typeof result.current.canCreate).toBe('function')
      expect(typeof result.current.canEdit).toBe('function')
      expect(typeof result.current.canTerminate).toBe('function')
      expect(typeof result.current.canDelete).toBe('function')
    })

    it('should handle no permissions scenario correctly', async () => {
      const { result } = await prepare({
        couponsCreate: false,
        couponsUpdate: false,
        couponsDelete: false,
      })

      expect(result.current.canCreate()).toBe(false)
      expect(result.current.canEdit()).toBe(false)
      expect(result.current.canTerminate({ status: CouponStatusEnum.Active })).toBe(false)
      expect(result.current.canDelete()).toBe(false)
    })

    it('should handle all permissions with active coupon correctly', async () => {
      const { result } = await prepare()

      expect(result.current.canCreate()).toBe(true)
      expect(result.current.canEdit()).toBe(true)
      expect(result.current.canTerminate({ status: CouponStatusEnum.Active })).toBe(true)
      expect(result.current.canDelete()).toBe(true)
    })

    it('should handle all permissions with terminated coupon correctly', async () => {
      const { result } = await prepare()

      expect(result.current.canCreate()).toBe(true)
      expect(result.current.canEdit()).toBe(true)
      expect(result.current.canTerminate({ status: CouponStatusEnum.Terminated })).toBe(false)
      expect(result.current.canDelete()).toBe(true)
    })
  })
})
