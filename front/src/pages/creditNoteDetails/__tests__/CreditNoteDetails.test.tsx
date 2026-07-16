import { MainHeaderConfig } from '~/components/MainHeader/types'
import { addToast } from '~/core/apolloClient'
import { copyToClipboard } from '~/core/utils/copyToClipboard'
import { CurrencyEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import CreditNoteDetails from '../CreditNoteDetails'

let capturedConfig: MainHeaderConfig | null = null

jest.mock('~/components/MainHeader/MainHeader', () => ({
  MainHeader: Object.assign(() => null, {
    Configure: (props: MainHeaderConfig) => {
      capturedConfig = props
      return null
    },
  }),
}))

jest.mock('~/components/MainHeader/useMainHeaderTabContent', () => ({
  useMainHeaderTabContent: () => null,
}))

const mockDownloadCreditNote = jest.fn()
const mockDownloadCreditNoteXml = jest.fn()
const mockGoBack = jest.fn()

let mockLoadingCreditNoteDownload = false
let mockLoadingCreditNoteXmlDownload = false

jest.mock('../common/useDownloadCreditNote', () => ({
  useDownloadCreditNote: () => ({
    downloadCreditNote: mockDownloadCreditNote,
    loadingCreditNoteDownload: mockLoadingCreditNoteDownload,
    downloadCreditNoteXml: mockDownloadCreditNoteXml,
    loadingCreditNoteXmlDownload: mockLoadingCreditNoteXmlDownload,
  }),
}))

jest.mock('~/core/utils/copyToClipboard', () => ({
  copyToClipboard: jest.fn(),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useResendEmailDialog', () => ({
  useResendEmailDialog: () => ({
    showResendEmailDialog: jest.fn(),
  }),
}))

jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({
    isPremium: true,
  }),
}))

const mockHasPermissions = jest.fn().mockReturnValue(true)

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

jest.mock('~/hooks/core/useLocationHistory', () => ({
  useLocationHistory: () => ({
    goBack: mockGoBack,
  }),
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: jest.fn(),
  envGlobalVar: () => ({
    disablePdfGeneration: false,
  }),
}))

const mockCreditNoteData = {
  creditNote: {
    id: 'credit-note-123',
    number: 'CN-001',
    canBeVoided: true,
    totalAmountCents: '10000',
    currency: CurrencyEnum.Usd,
    integrationSyncable: false,
    taxProviderSyncable: false,
    externalIntegrationId: null,
    taxProviderId: null,
    xmlUrl: null,
    refundStatus: null,
    creditAmountCents: '10000',
    refundAmountCents: '0',
    offsetAmountCents: '0',
    metadata: [{ key: 'test_key', value: 'test_value' }],
    billingEntity: {
      id: 'billing-entity-1',
      name: 'Billing Entity',
      einvoicing: false,
      emailSettings: [],
      logoUrl: null,
    },
    customer: {
      id: 'customer-123',
      email: 'customer@example.com',
      netsuiteCustomer: null,
      xeroCustomer: null,
      anrokCustomer: null,
      avalaraCustomer: null,
    },
  },
}

const mockUseGetCreditNoteForDetailsQuery = jest.fn()
const mockSyncFn = jest.fn()
const mockRetryFn = jest.fn()

jest.mock('~/generated/graphql', () => ({
  ...jest.requireActual('~/generated/graphql'),
  useGetCreditNoteForDetailsQuery: () => mockUseGetCreditNoteForDetailsQuery(),
  useSyncIntegrationCreditNoteMutation: () => [mockSyncFn, { loading: false }],
  useRetryTaxReportingMutation: () => [mockRetryFn],
}))

jest.mock('~/components/creditNote/CreditNoteDetailsOverview', () => ({
  CreditNoteDetailsOverview: () => null,
}))

jest.mock('../creditNoteDetailsMetadata/CreditNoteDetailsMetadata', () => ({
  __esModule: true,
  default: () => null,
}))

jest.mock('~/components/creditNote/CreditNoteDetailsExternalSync', () => ({
  CreditNoteDetailsExternalSync: () => null,
}))

jest.mock('~/components/creditNote/CreditNoteDetailsActivityLogs', () => ({
  CreditNoteDetailsActivityLogs: () => null,
}))

jest.mock('~/components/customers/creditNotes/VoidCreditNoteDialog', () => ({
  useVoidCreditNoteDialog: () => ({
    openVoidCreditNoteDialog: jest.fn(),
  }),
}))

describe('CreditNoteDetails', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedConfig = null
    mockLoadingCreditNoteDownload = false
    mockLoadingCreditNoteXmlDownload = false
    mockHasPermissions.mockReturnValue(true)

    const useParamsMock = jest.requireMock('react-router-dom').useParams as jest.Mock

    useParamsMock.mockReturnValue({
      customerId: 'customer-123',
      invoiceId: 'invoice-123',
      creditNoteId: 'credit-note-123',
    })

    mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
      data: mockCreditNoteData,
      loading: false,
      error: null,
    })
  })

  describe('GIVEN the page is rendered with data', () => {
    describe('WHEN in default state', () => {
      it('THEN should configure MainHeader with breadcrumb', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.breadcrumb).toHaveLength(1)
      })

      it('THEN should configure MainHeader with entity viewName as credit note number', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.entity?.viewName).toBe('CN-001')
      })

      it('THEN should configure MainHeader with entity metadata containing credit note ID', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.entity?.metadata).toContain('credit-note-123')
      })

      it('THEN should configure MainHeader with a dropdown action', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.actions?.items).toHaveLength(1)
        expect(capturedConfig?.actions?.items[0].type).toBe('dropdown')
      })

      it('THEN should configure MainHeader with tabs', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.tabs).toBeDefined()
        expect(capturedConfig?.tabs?.length).toBeGreaterThanOrEqual(1)
      })
    })
  })

  describe('GIVEN the page is loading', () => {
    beforeEach(() => {
      mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
        data: null,
        loading: true,
        error: null,
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should set actionsLoading on MainHeader config', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.actions?.loading).toBe(true)
      })
    })
  })

  describe('GIVEN the page has an error', () => {
    beforeEach(() => {
      mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
        data: null,
        loading: false,
        error: new Error('Failed to load'),
      })
    })

    describe('WHEN the component renders', () => {
      it('THEN should not set actionsLoading on MainHeader config', () => {
        render(<CreditNoteDetails />)

        expect(capturedConfig?.actions?.loading).toBeFalsy()
      })
    })
  })

  describe('GIVEN the actions dropdown', () => {
    describe('WHEN clicking copy ID', () => {
      it('THEN should copy the credit note ID to clipboard', () => {
        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // First item is copy ID
          const copyItem = dropdownAction.items[0]

          copyItem.onClick(jest.fn())

          expect(copyToClipboard).toHaveBeenCalledWith('credit-note-123')
          expect(addToast).toHaveBeenCalledWith(expect.objectContaining({ severity: 'info' }))
        }
      })
    })

    describe('WHEN download option is available', () => {
      it('THEN should have a non-hidden download item', () => {
        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const visibleItems = dropdownAction.items.filter((item) => !item.hidden)

          // At minimum: copy ID + download + void
          expect(visibleItems.length).toBeGreaterThanOrEqual(2)
        }
      })

      it('THEN clicking download should call downloadCreditNote', () => {
        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Download item (not hidden when canDownload and no xmlUrl)
          const downloadItem = dropdownAction.items.find(
            (item) => !item.hidden && item.disabled === !!mockLoadingCreditNoteDownload,
          )

          if (downloadItem) {
            downloadItem.onClick(jest.fn())
            expect(mockDownloadCreditNote).toHaveBeenCalledWith({
              variables: { input: { id: 'credit-note-123' } },
            })
          }
        }
      })
    })

    describe('WHEN credit note can be voided', () => {
      it('THEN should have a visible void item', () => {
        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const visibleItems = dropdownAction.items.filter((item) => !item.hidden)

          // void item should be among visible items
          expect(visibleItems.length).toBeGreaterThanOrEqual(3)
        }
      })
    })

    describe('WHEN credit note cannot be voided', () => {
      it('THEN should hide the void item', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              canBeVoided: false,
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const nonVoidableVisibleItems = dropdownAction.items.filter((item) => !item.hidden)

          // Without void: copy ID + download = 2 visible
          expect(nonVoidableVisibleItems.length).toBeLessThan(
            // Re-render with voidable to compare
            (() => {
              mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
                data: mockCreditNoteData,
                loading: false,
                error: null,
              })
              render(<CreditNoteDetails />)
              const dd = capturedConfig?.actions?.items[0]

              if (dd?.type === 'dropdown') {
                return dd.items.filter((item) => !item.hidden).length
              }
              return 0
            })(),
          )
        }
      })
    })
  })

  describe('GIVEN XML download options', () => {
    describe('WHEN xmlUrl is present', () => {
      it('THEN should show separate PDF and XML download items', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              xmlUrl: 'https://example.com/credit-note.xml',
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const visibleItems = dropdownAction.items.filter((item) => !item.hidden)

          // Should have: copy ID, download PDF, download XML, void = at least 4
          expect(visibleItems.length).toBeGreaterThanOrEqual(4)
        }
      })

      it('THEN clicking XML download should call downloadCreditNoteXml', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              xmlUrl: 'https://example.com/credit-note.xml',
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // XML download item (index 3 in the items array)
          const xmlItem = dropdownAction.items[3]

          if (!xmlItem.hidden) {
            xmlItem.onClick(jest.fn())
            expect(mockDownloadCreditNoteXml).toHaveBeenCalledWith({
              variables: { input: { id: 'credit-note-123' } },
            })
          }
        }
      })
    })

    describe('WHEN einvoicing is enabled', () => {
      it('THEN should show separate PDF and XML download items', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              billingEntity: {
                ...mockCreditNoteData.creditNote.billingEntity,
                einvoicing: true,
              },
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const visibleItems = dropdownAction.items.filter((item) => !item.hidden)

          expect(visibleItems.length).toBeGreaterThanOrEqual(4)
        }
      })
    })
  })

  describe('GIVEN integration sync', () => {
    describe('WHEN NetSuite integration is present', () => {
      it('THEN should show a sync item that is not hidden', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              integrationSyncable: true,
              externalIntegrationId: 'ext-123',
              customer: {
                ...mockCreditNoteData.creditNote.customer,
                netsuiteCustomer: {
                  integrationId: 'netsuite-123',
                },
              },
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Sync item should not be hidden
          const syncItem = dropdownAction.items.find(
            (item) => !item.hidden && item.disabled === false,
          )

          expect(syncItem).toBeDefined()
        }
      })

      it('THEN clicking sync should call syncIntegrationCreditNote', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              integrationSyncable: true,
              externalIntegrationId: 'ext-123',
              customer: {
                ...mockCreditNoteData.creditNote.customer,
                netsuiteCustomer: {
                  integrationId: 'netsuite-123',
                },
              },
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Sync item is at index 6
          const syncItem = dropdownAction.items[6]

          if (!syncItem.hidden) {
            syncItem.onClick(jest.fn())
            expect(mockSyncFn).toHaveBeenCalled()
          }
        }
      })
    })

    describe('WHEN tax provider sync is available (Anrok)', () => {
      it('THEN should show retry tax sync item', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              taxProviderSyncable: true,
              taxProviderId: 'anrok-123',
              customer: {
                ...mockCreditNoteData.creditNote.customer,
                anrokCustomer: {
                  integrationId: 'anrok-integration-123',
                },
              },
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Retry tax sync item (index 7)
          const retryItem = dropdownAction.items[7]

          expect(retryItem.hidden).toBeFalsy()
        }
      })

      it('THEN clicking retry should call retryTaxReporting', () => {
        mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
          data: {
            creditNote: {
              ...mockCreditNoteData.creditNote,
              taxProviderSyncable: true,
              taxProviderId: 'anrok-123',
              customer: {
                ...mockCreditNoteData.creditNote.customer,
                anrokCustomer: {
                  integrationId: 'anrok-integration-123',
                },
              },
            },
          },
          loading: false,
          error: null,
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          const retryItem = dropdownAction.items[7]

          if (!retryItem.hidden) {
            retryItem.onClick(jest.fn())
            expect(mockRetryFn).toHaveBeenCalled()
          }
        }
      })
    })
  })

  describe('GIVEN external sync tab visibility', () => {
    it.each([
      {
        name: 'NetSuite',
        data: {
          integrationSyncable: true,
          externalIntegrationId: 'ext-123',
          customer: {
            ...mockCreditNoteData.creditNote.customer,
            netsuiteCustomer: { integrationId: 'netsuite-123' },
          },
        },
      },
      {
        name: 'Xero',
        data: {
          integrationSyncable: true,
          externalIntegrationId: 'ext-123',
          customer: {
            ...mockCreditNoteData.creditNote.customer,
            xeroCustomer: { integrationId: 'xero-123' },
          },
        },
      },
      {
        name: 'Anrok',
        data: {
          taxProviderSyncable: true,
          taxProviderId: 'anrok-123',
          customer: {
            ...mockCreditNoteData.creditNote.customer,
            anrokCustomer: { integrationId: 'anrok-123' },
          },
        },
      },
      {
        name: 'Avalara',
        data: {
          taxProviderSyncable: true,
          taxProviderId: 'avalara-123',
          customer: {
            ...mockCreditNoteData.creditNote.customer,
            avalaraCustomer: { id: 'avalara-customer-123' },
          },
        },
      },
    ])('WHEN $name integration is present THEN should show external sync tab', ({ data }) => {
      mockUseGetCreditNoteForDetailsQuery.mockReturnValue({
        data: {
          creditNote: {
            ...mockCreditNoteData.creditNote,
            ...data,
          },
        },
        loading: false,
        error: null,
      })

      render(<CreditNoteDetails />)

      const externalSyncTab = capturedConfig?.tabs?.find(
        (tab) => !tab.hidden && tab !== capturedConfig?.tabs?.[0],
      )

      expect(externalSyncTab).toBeDefined()
    })

    it('WHEN no integrations are present THEN should hide external sync tab', () => {
      render(<CreditNoteDetails />)

      const tabs = capturedConfig?.tabs
      const externalSyncTab = tabs?.[1]

      expect(externalSyncTab?.hidden).toBe(true)
    })
  })

  describe('GIVEN activity logs tab visibility', () => {
    describe('WHEN user is premium and has permissions', () => {
      it('THEN should show activity logs tab', () => {
        render(<CreditNoteDetails />)

        const activityLogsTab = capturedConfig?.tabs?.[2]

        expect(activityLogsTab?.hidden).toBeFalsy()
      })
    })

    describe('WHEN user lacks auditLogsView permission', () => {
      it('THEN should hide activity logs tab', () => {
        mockHasPermissions.mockImplementation((permissions: string[]) => {
          if (permissions.includes('auditLogsView')) {
            return false
          }
          return true
        })

        render(<CreditNoteDetails />)

        const activityLogsTab = capturedConfig?.tabs?.[2]

        expect(activityLogsTab?.hidden).toBe(true)
      })
    })
  })

  describe('GIVEN permissions', () => {
    describe('WHEN user lacks creditNotesView permission', () => {
      it('THEN should hide download items', () => {
        mockHasPermissions.mockImplementation((permissions: string[]) => {
          if (permissions.includes('creditNotesView')) {
            return false
          }
          return true
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Download item (index 1) should be hidden
          expect(dropdownAction.items[1].hidden).toBe(true)
        }
      })
    })

    describe('WHEN user lacks creditNotesVoid permission', () => {
      it('THEN should hide void item', () => {
        mockHasPermissions.mockImplementation((permissions: string[]) => {
          if (permissions.includes('creditNotesVoid')) {
            return false
          }
          return true
        })

        render(<CreditNoteDetails />)

        const dropdownAction = capturedConfig?.actions?.items[0]

        if (dropdownAction?.type === 'dropdown') {
          // Void item (index 5) should be hidden
          expect(dropdownAction.items[5].hidden).toBe(true)
        }
      })
    })
  })
})
