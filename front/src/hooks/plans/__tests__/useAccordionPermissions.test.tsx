import { renderHook } from '@testing-library/react'

import { GetCurrentUserInfosDocument } from '~/generated/graphql'
import { useAccordionPermissions } from '~/hooks/plans/useAccordionPermissions'
import { AllTheProviders } from '~/test-utils'

type PlanPermissions = {
  plansCreate: boolean
  plansUpdate: boolean
  plansDelete: boolean
  subscriptionsUpdate: boolean
}

const DEFAULT_PERMISSIONS: PlanPermissions = {
  plansCreate: true,
  plansUpdate: true,
  plansDelete: true,
  subscriptionsUpdate: true,
}

const mockCurrentUser = {
  currentMembership: {
    id: '2',
    organization: { id: '3', name: 'Organization', logoUrl: 'https://logo.com' },
    permissions: DEFAULT_PERMISSIONS,
  },
}

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => mockCurrentUser,
}))

const prepare = (permissions: Partial<PlanPermissions> = {}, isInSubscriptionForm = false) => {
  const membership = {
    id: '2',
    organization: { id: '3', name: 'Organization', logoUrl: 'https://logo.com' },
    permissions: { ...DEFAULT_PERMISSIONS, ...permissions },
  }

  mockCurrentUser.currentMembership = membership

  const mocks = [
    {
      request: { query: GetCurrentUserInfosDocument },
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

  const wrapper = ({ children }: { children: React.ReactNode }) =>
    AllTheProviders({ children, mocks, forceTypenames: true })

  return renderHook(() => useAccordionPermissions(isInSubscriptionForm), { wrapper })
}

describe('useAccordionPermissions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('returns all true when user has every plan permission and not in subscription form', () => {
    const { result } = prepare()

    expect(result.current).toEqual({ canCreate: true, canUpdate: true, canDelete: true })
  })

  it('gates each capability on its own permission flag', () => {
    expect(prepare({ plansCreate: false }).result.current.canCreate).toBe(false)
    expect(prepare({ plansUpdate: false }).result.current.canUpdate).toBe(false)
    expect(prepare({ plansDelete: false }).result.current.canDelete).toBe(false)
  })

  it('allows update via subscriptionsUpdate but blocks create/delete in sub mode', () => {
    const { result } = prepare({ subscriptionsUpdate: true }, true)

    expect(result.current.canUpdate).toBe(true)
    expect(result.current.canCreate).toBe(false)
    expect(result.current.canDelete).toBe(false)
  })

  it('blocks update in sub mode without subscriptionsUpdate', () => {
    const { result } = prepare({ subscriptionsUpdate: false }, true)

    expect(result.current.canUpdate).toBe(false)
  })

  it('keeps unrelated flags true when only one permission is revoked', () => {
    const { result } = prepare({ plansCreate: false })

    expect(result.current).toEqual({ canCreate: false, canUpdate: true, canDelete: true })
  })
})
