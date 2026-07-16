import { renderHook } from '@testing-library/react'

import { QuoteListItemFragment, StatusEnum } from '~/generated/graphql'
import { testMockNavigateFn } from '~/test-utils'

import { useQuoteVersionActions } from '../useQuoteVersionActions'

const mockGoToApproveQuote = jest.fn()
const mockOpenCloneDialog = jest.fn()
const mockHasPermissions = jest.fn()

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

jest.mock('../useApproveQuote', () => ({
  useApproveQuote: () => ({
    goToApproveQuote: mockGoToApproveQuote,
  }),
}))

jest.mock('../useCloneQuote', () => ({
  useCloneQuote: () => ({
    openCloneDialog: mockOpenCloneDialog,
  }),
}))

const createMockQuote = (
  overrides: Partial<Omit<QuoteListItemFragment, 'versions'>> & {
    status?: StatusEnum
    version?: number
    versionId?: string
  } = {},
): QuoteListItemFragment => {
  const { status = StatusEnum.Draft, version = 1, versionId = 'version-1', ...rest } = overrides

  return {
    id: 'quote-v1',
    number: 'QT-001',
    orderType: 'SubscriptionCreation' as QuoteListItemFragment['orderType'],
    createdAt: '2026-04-01T10:00:00Z',
    customer: { id: 'cust-1', displayName: 'Acme' },
    versions: [{ id: versionId, status, version }],
    ...rest,
  }
}

describe('useQuoteVersionActions', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return getActions function', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        expect(result.current.getActions).toBeDefined()
        expect(typeof result.current.getActions).toBe('function')
      })
    })
  })

  describe('GIVEN a draft version with all permissions', () => {
    describe('WHEN getActions is called', () => {
      it('THEN should return 4 actions: approve, edit, void, duplicate', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Draft }))

        expect(actions).toHaveLength(4)
        expect(actions[0].icon).toBe('validate-unfilled')
        expect(actions[1].icon).toBe('pen')
        expect(actions[2].icon).toBe('stop')
        expect(actions[3].icon).toBe('duplicate')
      })
    })

    describe('WHEN approve action is triggered', () => {
      it('THEN should call goToApproveQuote with the version id', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(
          createMockQuote({
            id: 'draft-1',
            versionId: 'version-draft-1',
            status: StatusEnum.Draft,
          }),
        )

        actions[0].onAction()

        expect(mockGoToApproveQuote).toHaveBeenCalledWith('draft-1', 'version-draft-1')
      })
    })

    describe('WHEN edit action is triggered', () => {
      it('THEN should navigate to the edit quote route', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(
          createMockQuote({
            id: 'draft-1',
            versionId: 'version-draft-1',
            status: StatusEnum.Draft,
          }),
        )

        actions[1].onAction()

        expect(testMockNavigateFn).toHaveBeenCalledWith(
          '/quote/draft-1/version/version-draft-1/edit',
        )
      })
    })

    describe('WHEN void action is triggered', () => {
      it('THEN should navigate to the void quote route', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(
          createMockQuote({
            id: 'draft-1',
            versionId: 'version-draft-1',
            status: StatusEnum.Draft,
          }),
        )

        actions[2].onAction()

        expect(testMockNavigateFn).toHaveBeenCalledWith(
          '/quote/draft-1/version/version-draft-1/void',
        )
      })
    })

    describe('WHEN duplicate action is triggered', () => {
      it('THEN should call openCloneDialog with id and number-version string', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(
          createMockQuote({
            id: 'draft-1',
            versionId: 'version-draft-1',
            number: 'QT-001',
            version: 3,
            status: StatusEnum.Draft,
          }),
        )

        actions[3].onAction()

        expect(mockOpenCloneDialog).toHaveBeenCalledWith('version-draft-1', 'QT-001 - v3')
      })
    })
  })

  describe('GIVEN the latest version is approved', () => {
    describe('WHEN getActions is called without a specific version', () => {
      it('THEN should return an empty array', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Approved }))

        expect(actions).toHaveLength(0)
      })
    })

    describe('WHEN getActions is called for an older voided version', () => {
      it('THEN should still return an empty array', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const quote: QuoteListItemFragment = {
          id: 'quote-1',
          number: 'QT-001',
          orderType: 'SubscriptionCreation' as QuoteListItemFragment['orderType'],
          createdAt: '2026-04-01T10:00:00Z',
          customer: { id: 'cust-1', displayName: 'Acme' },
          versions: [
            { id: 'v2', status: StatusEnum.Approved, version: 2 },
            { id: 'v1', status: StatusEnum.Voided, version: 1 },
          ],
        }

        const actions = result.current.getActions(quote, {
          id: 'v1',
          status: StatusEnum.Voided,
          version: 1,
        })

        expect(actions).toHaveLength(0)
      })
    })

    describe('WHEN getActions is called for an older draft version', () => {
      it('THEN should still return an empty array', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const quote: QuoteListItemFragment = {
          id: 'quote-1',
          number: 'QT-001',
          orderType: 'SubscriptionCreation' as QuoteListItemFragment['orderType'],
          createdAt: '2026-04-01T10:00:00Z',
          customer: { id: 'cust-1', displayName: 'Acme' },
          versions: [
            { id: 'v2', status: StatusEnum.Approved, version: 2 },
            { id: 'v1', status: StatusEnum.Draft, version: 1 },
          ],
        }

        const actions = result.current.getActions(quote, {
          id: 'v1',
          status: StatusEnum.Draft,
          version: 1,
        })

        expect(actions).toHaveLength(0)
      })
    })
  })

  describe('GIVEN a voided version with all permissions', () => {
    describe('WHEN getActions is called', () => {
      it('THEN should return only the duplicate action', () => {
        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Voided }))

        expect(actions).toHaveLength(1)
        expect(actions[0].icon).toBe('duplicate')
      })
    })
  })

  describe('GIVEN a draft version with limited permissions', () => {
    describe('WHEN user has no approve permission', () => {
      it('THEN should not include approve action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => {
          if (perms.includes('quotesApprove')) return false
          return true
        })

        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Draft }))

        expect(actions.map((a) => a.icon)).not.toContain('validate-unfilled')
        expect(actions).toHaveLength(3)
      })
    })

    describe('WHEN user has no update permission', () => {
      it('THEN should not include edit action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => {
          if (perms.includes('quotesUpdate')) return false
          return true
        })

        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Draft }))

        expect(actions.map((a) => a.icon)).not.toContain('pen')
        expect(actions).toHaveLength(3)
      })
    })

    describe('WHEN user has no void permission', () => {
      it('THEN should not include void action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => {
          if (perms.includes('quotesVoid')) return false
          return true
        })

        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Draft }))

        expect(actions.map((a) => a.icon)).not.toContain('stop')
        expect(actions).toHaveLength(3)
      })
    })

    describe('WHEN user has no clone permission', () => {
      it('THEN should not include duplicate action', () => {
        mockHasPermissions.mockImplementation((perms: string[]) => {
          if (perms.includes('quotesClone')) return false
          return true
        })

        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Draft }))

        expect(actions.map((a) => a.icon)).not.toContain('duplicate')
        expect(actions).toHaveLength(3)
      })
    })

    describe('WHEN user has no permissions at all', () => {
      it('THEN should return an empty array', () => {
        mockHasPermissions.mockReturnValue(false)

        const { result } = renderHook(() => useQuoteVersionActions())

        const actions = result.current.getActions(createMockQuote({ status: StatusEnum.Draft }))

        expect(actions).toHaveLength(0)
      })
    })
  })
})
