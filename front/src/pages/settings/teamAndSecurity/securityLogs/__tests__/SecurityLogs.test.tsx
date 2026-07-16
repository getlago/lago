import { act, cleanup, screen, waitFor } from '@testing-library/react'

import {
  GetSecurityLogsDocument,
  LagoApiError,
  LogEventEnum,
  LogTypeEnum,
} from '~/generated/graphql'
import { render, TestMocksType } from '~/test-utils'

import SecurityLogs, { SECURITY_LOGS_CONTAINER_TEST_ID } from '../SecurityLogs'

// Mock IntersectionObserver for jsdom
const mockIntersectionObserver = jest.fn()

mockIntersectionObserver.mockReturnValue({
  observe: jest.fn(),
  unobserve: jest.fn(),
  disconnect: jest.fn(),
})
window.IntersectionObserver = mockIntersectionObserver

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: () => ({
      date: 'Jan 15',
      time: '13:41:39',
      timezone: 'UTC',
    }),
  }),
}))

const mockSecurityLogs = [
  {
    __typename: 'SecurityLog' as const,
    logId: 'log-1',
    logEvent: LogEventEnum.UserSignedUp,
    logType: LogTypeEnum.User,
    deviceInfo: null,
    resources: null,
    loggedAt: '2025-01-15T13:41:39Z',
    userEmail: 'user@example.com',
  },
  {
    __typename: 'SecurityLog' as const,
    logId: 'log-2',
    logEvent: LogEventEnum.ApiKeyCreated,
    logType: LogTypeEnum.ApiKey,
    deviceInfo: null,
    resources: { name: 'Test Key', value_ending: '1234' },
    loggedAt: '2025-01-15T13:41:39Z',
    userEmail: 'admin@example.com',
  },
]

const securityLogsMock = {
  request: {
    query: GetSecurityLogsDocument,
  },
  variableMatcher: () => true,
  result: {
    data: {
      securityLogs: {
        __typename: 'SecurityLogCollection',
        metadata: {
          __typename: 'CollectionMetadata',
          currentPage: 1,
          totalPages: 1,
        },
        collection: mockSecurityLogs,
      },
    },
  },
}

const emptySecurityLogsMock = {
  request: {
    query: GetSecurityLogsDocument,
  },
  variableMatcher: () => true,
  result: {
    data: {
      securityLogs: {
        __typename: 'SecurityLogCollection',
        metadata: {
          __typename: 'CollectionMetadata',
          currentPage: 1,
          totalPages: 1,
        },
        collection: [],
      },
    },
  },
}

const loadingSecurityLogsMock = {
  request: {
    query: GetSecurityLogsDocument,
  },
  variableMatcher: () => true,
  delay: Infinity,
  result: {
    data: null,
  },
}

const errorSecurityLogsMock = {
  request: {
    query: GetSecurityLogsDocument,
  },
  variableMatcher: () => true,
  result: {
    data: null,
    errors: [
      {
        message: 'Something went wrong',
        extensions: { code: 'internal_error', details: {} },
      },
    ],
  },
}

const featureUnavailableErrorMock = {
  request: {
    query: GetSecurityLogsDocument,
  },
  variableMatcher: () => true,
  result: {
    data: null,
    errors: [
      {
        message: 'Feature unavailable',
        extensions: { code: LagoApiError.FeatureUnavailable, details: {} },
      },
    ],
  },
}

async function prepare({ mocks = [securityLogsMock] }: { mocks?: TestMocksType } = {}) {
  await act(() =>
    render(<SecurityLogs />, {
      mocks,
    }),
  )
}

describe('SecurityLogs', () => {
  afterEach(() => {
    cleanup()
    jest.clearAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN security logs are loaded', () => {
      it('THEN should display the container', async () => {
        await prepare()

        expect(screen.getByTestId(SECURITY_LOGS_CONTAINER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should display the table', async () => {
        await prepare()

        await waitFor(() => {
          expect(screen.getByTestId('table-security-logs')).toBeInTheDocument()
        })
      })

      it('THEN should display security log data in the table', async () => {
        await prepare()

        await waitFor(() => {
          expect(screen.getByText('user.signed_up')).toBeInTheDocument()
        })

        expect(screen.getByText('api_key.created')).toBeInTheDocument()
      })

      it('THEN should display formatted dates', async () => {
        await prepare()

        await waitFor(() => {
          const dateTexts = screen.getAllByText('Jan 15, 13:41:39')

          expect(dateTexts.length).toBeGreaterThan(0)
        })
      })
    })

    describe('WHEN security logs are loading', () => {
      it('THEN should not display log data', async () => {
        await prepare({ mocks: [loadingSecurityLogsMock] })

        expect(screen.queryByText('user.signed_up')).not.toBeInTheDocument()
      })
    })

    describe('WHEN there are no security logs', () => {
      it('THEN should display the table with no data rows', async () => {
        await prepare({ mocks: [emptySecurityLogsMock] })

        await waitFor(() => {
          expect(screen.getByTestId('table-security-logs')).toBeInTheDocument()
        })

        expect(screen.queryByText('user.signed_up')).not.toBeInTheDocument()
      })
    })

    describe('WHEN the component renders with data', () => {
      it('THEN should display the filter section and refresh button', async () => {
        await prepare()

        await waitFor(() => {
          expect(screen.getByTestId('table-security-logs')).toBeInTheDocument()
        })

        expect(screen.getByTestId(SECURITY_LOGS_CONTAINER_TEST_ID)).toBeInTheDocument()
      })
    })

    describe('WHEN an API error occurs', () => {
      it('THEN should display the table with error state', async () => {
        await prepare({ mocks: [errorSecurityLogsMock] })

        await waitFor(() => {
          expect(screen.getByTestId('table-security-logs')).toBeInTheDocument()
        })
      })
    })

    describe('WHEN a FeatureUnavailable error occurs', () => {
      it('THEN should display the table with error state', async () => {
        await prepare({ mocks: [featureUnavailableErrorMock] })

        await waitFor(() => {
          expect(screen.getByTestId('table-security-logs')).toBeInTheDocument()
        })
      })
    })
  })
})
