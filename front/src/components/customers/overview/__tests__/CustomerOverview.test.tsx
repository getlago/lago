import { act, screen, waitFor } from '@testing-library/react'

import { FeatureFlagEnum } from '~/generated/graphql'
import * as useOrganizationInfosModule from '~/hooks/useOrganizationInfos'
import * as usePermissionsModule from '~/hooks/usePermissions'
import { render } from '~/test-utils'

import {
  CUSTOMER_OVERVIEW_BREAKDOWN,
  CUSTOMER_OVERVIEW_LEGACY_CARDS,
  CustomerOverview,
} from '../CustomerOverview'

const mockGetCustomerOverdueBalances = jest.fn()
const mockGetCustomerGrossRevenues = jest.fn()
const mockHasPermissions = jest.fn(() => true)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const mockHasFeatureFlag = jest.fn((_flag: FeatureFlagEnum) => false)

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useIsCustomerReadyForOverduePayment', () => ({
  useIsCustomerReadyForOverduePayment: jest.fn(() => ({
    isCustomerReadyForOverduePayment: false,
    loading: false,
    error: undefined,
  })),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: jest.fn(() => ({
    hasPermissions: jest.fn(() => true),
  })),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: jest.fn(() => ({
    organization: { defaultCurrency: 'USD' as const },
    hasFeatureFlag: jest.fn(() => false),
    intlFormatDateTimeOrgaTZ: jest.fn(() => ({ time: '12:00:00', date: '2024-01-01' })),
  })),
}))

jest.mock('~/hooks/useBillingEntitiesOptions', () => ({
  useBillingEntitiesOptions: () => ({
    options: [],
    isLoading: false,
    defaultEntityCode: '',
    hasMultipleEntities: false,
  }),
}))

jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useParams: jest.fn(() => ({ customerId: 'cust-123' })),
  generatePath: jest.fn((route: string, params: { customerId: string }) =>
    route.replace(':customerId', params.customerId),
  ),
}))

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCustomerOverdueBalancesLazyQuery: jest.fn(() => [
    mockGetCustomerOverdueBalances,
    {
      data: {
        overdueBalances: {
          collection: [
            {
              amountCents: '1000',
              currency: 'USD',
              billingEntityId: 'be-1',
              lagoInvoiceIds: ['inv-1'],
            },
          ],
        },
        paymentRequests: { collection: [] },
      },
      loading: false,
      error: undefined,
    },
  ]),
  useGetCustomerGrossRevenuesLazyQuery: jest.fn(() => [
    mockGetCustomerGrossRevenues,
    {
      data: {
        grossRevenues: {
          collection: [
            {
              amountCents: '5000',
              currency: 'USD',
              billingEntityId: 'be-1',
              invoicesCount: 1,
              month: '2026-05',
            },
          ],
        },
      },
      loading: false,
      error: undefined,
    },
  ]),
}))

describe('CustomerOverview', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasFeatureFlag.mockImplementation(() => false)
    mockHasPermissions.mockReturnValue(true)

    jest.mocked(useOrganizationInfosModule.useOrganizationInfos).mockReturnValue({
      organization: { defaultCurrency: 'USD' } as ReturnType<
        typeof useOrganizationInfosModule.useOrganizationInfos
      >['organization'],
      hasFeatureFlag: mockHasFeatureFlag,
      intlFormatDateTimeOrgaTZ: jest.fn(() => ({ time: '12:00:00', date: '2024-01-01' })),
    } as unknown as ReturnType<typeof useOrganizationInfosModule.useOrganizationInfos>)

    jest.mocked(usePermissionsModule.usePermissions).mockReturnValue({
      hasPermissions: mockHasPermissions,
    } as unknown as ReturnType<typeof usePermissionsModule.usePermissions>)
  })

  describe('GIVEN multi_currency feature flag is enabled', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the breakdown table', async () => {
        mockHasFeatureFlag.mockImplementation(
          (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiCurrency,
        )

        await act(async () => {
          render(<CustomerOverview externalCustomerId="ext-123" />)
        })

        await waitFor(() => {
          expect(screen.getByTestId(CUSTOMER_OVERVIEW_BREAKDOWN)).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN multi_entity_billing feature flag is enabled', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the breakdown table', async () => {
        mockHasFeatureFlag.mockImplementation(
          (flag: FeatureFlagEnum) => flag === FeatureFlagEnum.MultiEntityBilling,
        )

        await act(async () => {
          render(<CustomerOverview externalCustomerId="ext-123" />)
        })

        await waitFor(() => {
          expect(screen.getByTestId(CUSTOMER_OVERVIEW_BREAKDOWN)).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN both multi_currency and multi_entity_billing flags are enabled', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the breakdown table (not legacy cards)', async () => {
        mockHasFeatureFlag.mockReturnValue(true)

        await act(async () => {
          render(<CustomerOverview externalCustomerId="ext-123" />)
        })

        await waitFor(() => {
          expect(screen.getByTestId(CUSTOMER_OVERVIEW_BREAKDOWN)).toBeInTheDocument()
          expect(screen.queryByTestId(CUSTOMER_OVERVIEW_LEGACY_CARDS)).not.toBeInTheDocument()
        })
      })

      it('THEN should execute both lazy queries', async () => {
        mockHasFeatureFlag.mockReturnValue(true)

        await act(async () => {
          render(<CustomerOverview externalCustomerId="ext-123" />)
        })

        await waitFor(() => {
          expect(mockGetCustomerOverdueBalances).toHaveBeenCalled()
          expect(mockGetCustomerGrossRevenues).toHaveBeenCalled()
        })
      })
    })
  })

  describe('GIVEN both feature flags are off', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should fall back to the legacy cards', async () => {
        mockHasFeatureFlag.mockReturnValue(false)

        await act(async () => {
          render(<CustomerOverview externalCustomerId="ext-123" />)
        })

        await waitFor(() => {
          expect(screen.getByTestId(CUSTOMER_OVERVIEW_LEGACY_CARDS)).toBeInTheDocument()
        })
      })
    })
  })

  describe('GIVEN both queries return errors', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should return null', async () => {
        const { useGetCustomerOverdueBalancesLazyQuery, useGetCustomerGrossRevenuesLazyQuery } =
          jest.requireMock('~/generated/graphql')

        ;(useGetCustomerOverdueBalancesLazyQuery as jest.Mock).mockReturnValue([
          mockGetCustomerOverdueBalances,
          { data: undefined, loading: false, error: new Error('overdue error') },
        ])
        ;(useGetCustomerGrossRevenuesLazyQuery as jest.Mock).mockReturnValue([
          mockGetCustomerGrossRevenues,
          { data: undefined, loading: false, error: new Error('gross error') },
        ])

        const { container } = render(<CustomerOverview externalCustomerId="ext-123" />)

        await waitFor(() => {
          expect(container.firstChild).toBeNull()
        })
      })
    })
  })

  describe('GIVEN breakdown mode and both gross and overdue collections are empty', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should hide the Invoice balances section entirely', async () => {
        const { useGetCustomerOverdueBalancesLazyQuery, useGetCustomerGrossRevenuesLazyQuery } =
          jest.requireMock('~/generated/graphql')

        ;(useGetCustomerOverdueBalancesLazyQuery as jest.Mock).mockReturnValue([
          mockGetCustomerOverdueBalances,
          {
            data: {
              overdueBalances: { collection: [] },
              paymentRequests: { collection: [] },
            },
            loading: false,
            error: undefined,
          },
        ])
        ;(useGetCustomerGrossRevenuesLazyQuery as jest.Mock).mockReturnValue([
          mockGetCustomerGrossRevenues,
          {
            data: { grossRevenues: { collection: [] } },
            loading: false,
            error: undefined,
          },
        ])
        mockHasFeatureFlag.mockReturnValue(true)

        const { container } = render(<CustomerOverview externalCustomerId="ext-123" />)

        await waitFor(() => {
          expect(container.firstChild).toBeNull()
        })
      })
    })
  })

  describe('GIVEN analyticsView permission is denied', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should not call the query functions', async () => {
        mockHasPermissions.mockReturnValue(false)

        await act(async () => {
          render(<CustomerOverview externalCustomerId="ext-123" />)
        })

        expect(mockGetCustomerOverdueBalances).not.toHaveBeenCalled()
        expect(mockGetCustomerGrossRevenues).not.toHaveBeenCalled()
      })
    })
  })
})
