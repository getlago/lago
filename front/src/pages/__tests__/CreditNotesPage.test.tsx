import { screen } from '@testing-library/react'

import { MainHeaderConfig } from '~/components/MainHeader/types'
import { render } from '~/test-utils'

import CreditNotesPage from '../CreditNotesPage'

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

const mockCreateExport = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCreditNotesListLazyQuery: () => [
    jest.fn(),
    {
      data: {
        creditNotes: {
          metadata: { currentPage: 1, totalPages: 1, totalCount: 3 },
          collection: [],
        },
      },
      loading: false,
      error: null,
      fetchMore: jest.fn(),
      variables: {},
    },
  ],
  useCreateCreditNotesDataExportMutation: () => [mockCreateExport],
}))

jest.mock('~/components/creditNote/CreditNotesTable', () => ({
  __esModule: true,
  default: () => <div data-test="credit-notes-table-mock">CreditNotesTable</div>,
}))

jest.mock('~/components/exports/ExportDialog', () => ({
  ExportDialog: () => null,
}))

describe('CreditNotesPage', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
  })

  describe('GIVEN the page is rendered', () => {
    describe('WHEN in default state', () => {
      it('THEN should render the CreditNotesTable component', () => {
        render(<CreditNotesPage />)

        expect(screen.getByTestId('credit-notes-table-mock')).toBeInTheDocument()
      })

      it('THEN should configure MainHeader with entity viewName', () => {
        render(<CreditNotesPage />)

        expect(capturedConfig?.entity?.viewName).toBe('text_66461ada56a84401188e8c63')
      })

      it('THEN should configure MainHeader with one export action', () => {
        render(<CreditNotesPage />)

        expect(capturedConfig?.actions?.items).toHaveLength(1)
        expect(capturedConfig?.actions?.items[0].type).toBe('action')
      })

      it('THEN should configure MainHeader with a filtersSection', () => {
        render(<CreditNotesPage />)

        expect(capturedConfig?.filtersSection).toBeDefined()
      })
    })
  })

  describe('GIVEN there are credit notes', () => {
    describe('WHEN the export action is configured', () => {
      it('THEN the export action should not be disabled', () => {
        render(<CreditNotesPage />)

        const action = capturedConfig?.actions?.items[0]

        expect(action?.type === 'action' && action.disabled).toBeFalsy()
      })
    })
  })
})
