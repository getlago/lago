import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { render } from '~/test-utils'

import InvoicesPage from '../InvoicesPage'

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

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { defaultCurrency: 'USD' },
    hasOrganizationPremiumAddon: jest.fn().mockReturnValue(false),
  }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: jest.fn().mockReturnValue(true),
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
  hasDefinedGQLError: jest.fn().mockReturnValue(false),
}))

const mockRetryAll = jest.fn().mockResolvedValue({ errors: undefined })
const mockCreateExport = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetInvoicesListLazyQuery: () => [
    jest.fn(),
    {
      data: {
        invoices: {
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
  useRetryAllInvoicePaymentsMutation: () => [mockRetryAll],
  useCreateInvoicesDataExportMutation: () => [mockCreateExport],
}))

jest.mock('~/components/invoices/InvoicesList', () => ({
  __esModule: true,
  default: () => <div data-test="invoices-list-mock">InvoicesList</div>,
}))

jest.mock('~/components/invoices/FinalizeInvoiceDialog', () => ({
  FinalizeInvoiceDialog: () => null,
}))

jest.mock('~/components/exports/ExportDialog', () => ({
  ExportDialog: () => null,
}))

describe('InvoicesPage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the InvoicesList component', () => {
        render(<InvoicesPage />)

        expect(screen.getByTestId('invoices-list-mock')).toBeInTheDocument()
      })

      it('THEN should configure MainHeader with entity viewName', () => {
        render(<InvoicesPage />)

        expect(capturedConfig?.entity?.viewName).toBe('text_63ac86d797f728a87b2f9f85')
      })

      it('THEN should configure MainHeader with at least one action', () => {
        render(<InvoicesPage />)

        expect(capturedConfig?.actions?.items?.length).toBeGreaterThanOrEqual(1)
      })

      it('THEN should configure MainHeader with a filtersSection', () => {
        render(<InvoicesPage />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })

  describe('GIVEN there are invoices', () => {
    describe('WHEN the export action is configured', () => {
      it('THEN the first action (export) should not be disabled', () => {
        render(<InvoicesPage />)

        const exportAction = capturedConfig?.actions?.items[0]

        expect(exportAction?.type === 'action' && exportAction.disabled).toBeFalsy()
      })
    })
  })
})
