import { renderHook } from '@testing-library/react'

import { StatusTypeEnum } from '~/generated/graphql'
import { useSubscriptionPermissionsActions } from '~/hooks/useSubscriptionPermissionsActions'

const DEFAULT_PERMISSIONS = {
  subscriptionsUpdate: true,
}

const mockCurrentUser = {
  currentMembership: {
    id: '1',
    organization: {
      id: '1',
      name: 'Organization',
      logoUrl: 'https://logo.com',
    },
    permissions: DEFAULT_PERMISSIONS,
  },
}

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockCurrentUser,
}))

function prepare(permissions: Partial<typeof DEFAULT_PERMISSIONS> = DEFAULT_PERMISSIONS) {
  mockCurrentUser.currentMembership.permissions = {
    ...DEFAULT_PERMISSIONS,
    ...permissions,
  }

  const { result } = renderHook(() => useSubscriptionPermissionsActions())

  return { result }
}

describe('useSubscriptionPermissionsActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('isStatusEditable', () => {
    it('should return true for active subscription', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(StatusTypeEnum.Active)).toBe(true)
    })

    it('should return true for pending subscription', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(StatusTypeEnum.Pending)).toBe(true)
    })

    it('should return false for terminated subscription', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(StatusTypeEnum.Terminated)).toBe(false)
    })

    it('should return false for canceled subscription', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(StatusTypeEnum.Canceled)).toBe(false)
    })

    it('should return false for incomplete subscription', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(StatusTypeEnum.Incomplete)).toBe(false)
    })

    it('should return false for null status', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(null)).toBe(false)
    })

    it('should return false for undefined status', () => {
      const { result } = prepare()

      expect(result.current.isStatusEditable(undefined)).toBe(false)
    })

    it('should not depend on permissions', () => {
      const { result } = prepare({ subscriptionsUpdate: false })

      expect(result.current.isStatusEditable(StatusTypeEnum.Active)).toBe(true)
    })
  })

  describe('canEditSubscription', () => {
    it('should return true when user has permission and status is active', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(StatusTypeEnum.Active)).toBe(true)
    })

    it('should return true when user has permission and status is pending', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(StatusTypeEnum.Pending)).toBe(true)
    })

    it('should return false when user has permission but status is terminated', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(StatusTypeEnum.Terminated)).toBe(false)
    })

    it('should return false when user has permission but status is canceled', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(StatusTypeEnum.Canceled)).toBe(false)
    })

    it('should return false when user has permission but status is incomplete', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(StatusTypeEnum.Incomplete)).toBe(false)
    })

    it('should return false when user does not have permission even if status is active', () => {
      const { result } = prepare({ subscriptionsUpdate: false })

      expect(result.current.canEditSubscription(StatusTypeEnum.Active)).toBe(false)
    })

    it('should return false when user does not have permission and status is terminated', () => {
      const { result } = prepare({ subscriptionsUpdate: false })

      expect(result.current.canEditSubscription(StatusTypeEnum.Terminated)).toBe(false)
    })

    it('should return false for null status even with permission', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(null)).toBe(false)
    })

    it('should return false for undefined status even with permission', () => {
      const { result } = prepare({ subscriptionsUpdate: true })

      expect(result.current.canEditSubscription(undefined)).toBe(false)
    })
  })
})
