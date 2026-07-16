import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { render, testMockNavigateFn } from '~/test-utils'

import PaymentsPage from '../PaymentsPage'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockDebouncedSearch = jest.fn()

jest.mock('~/hooks/useDebouncedSearch', () => ({
  useDebouncedSearch: () => ({
    debouncedSearch: mockDebouncedSearch,
    isLoading: false,
  }),
}))

const mockIsPremium = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: mockIsPremium(),
  }),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetPaymentsListLazyQuery: () => [
    jest.fn(),
    {
      data: {
        payments: {
          metadata: { currentPage: 1, totalPages: 1, totalCount: 5 },
          collection: [],
        },
      },
      loading: false,
      error: null,
      fetchMore: jest.fn(),
      variables: {},
    },
  ],
}))

jest.mock('~/components/invoices/PaymentsList', () => ({
  PaymentsList: () => <div data-test="payments-list-mock">PaymentsList</div>,
}))

const mockOpenPremiumWarningDialog = jest.fn()

jest.mock('~/components/dialogs/PremiumWarningDialog', () => ({
  usePremiumWarningDialog: () => ({
    open: mockOpenPremiumWarningDialog,
    close: jest.fn(),
  }),
}))

describe('PaymentsPage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    mockIsPremium.mockReturnValue(true)
    mockOpenPremiumWarningDialog.mockClear()
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the PaymentsList component', () => {
        render(<PaymentsPage />)

        expect(screen.getByTestId('payments-list-mock')).toBeInTheDocument()
      })

      it('THEN should configure MainHeader with entity viewName', () => {
        render(<PaymentsPage />)

        expect(capturedConfig?.entity?.viewName).toBe('text_6672ebb8b1b50be550eccbed')
      })

      it('THEN should configure MainHeader with one action', () => {
        render(<PaymentsPage />)

        expect(capturedConfig?.actions?.items).toHaveLength(1)
        expect(capturedConfig?.actions?.items[0].type).toBe('action')
      })

      it('THEN should configure MainHeader with a filtersSection', () => {
        render(<PaymentsPage />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })

  describe('GIVEN the user is premium', () => {
    describe('WHEN the action is configured', () => {
      it('THEN the action should not have endIcon sparkles', () => {
        render(<PaymentsPage />)

        const action = capturedConfig?.actions?.items[0]

        expect(action?.type === 'action' && action.endIcon).toBeUndefined()
      })

      it('THEN clicking the action should navigate', () => {
        render(<PaymentsPage />)

        const action = capturedConfig?.actions?.items[0]

        if (action?.type === 'action') {
          action.onClick()
        }

        expect(testMockNavigateFn).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the user is not premium', () => {
    beforeEach(() => {
      mockIsPremium.mockReturnValue(false)
    })

    describe('WHEN the action is configured', () => {
      it('THEN the action should have endIcon sparkles', () => {
        render(<PaymentsPage />)

        const action = capturedConfig?.actions?.items[0]

        expect(action?.type === 'action' && action.endIcon).toBe('sparkles')
      })

      it('THEN clicking the action should open the premium warning dialog', () => {
        render(<PaymentsPage />)

        const action = capturedConfig?.actions?.items[0]

        if (action?.type === 'action') {
          action.onClick()
        }

        expect(testMockNavigateFn).not.toHaveBeenCalled()
        expect(mockOpenPremiumWarningDialog).toHaveBeenCalled()
      })
    })
  })
})
