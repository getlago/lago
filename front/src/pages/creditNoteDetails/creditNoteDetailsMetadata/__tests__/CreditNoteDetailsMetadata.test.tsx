import { act, cleanup, screen } from '@testing-library/react'

import { CurrencyEnum, GetCreditNoteForDetailsQuery } from '~/generated/graphql'
import { render } from '~/test-utils'

import CreditNoteDetailsMetadata from '../CreditNoteDetailsMetadata'

// Mock the MetadataEditDrawer component
jest.mock('~/pages/creditNoteDetails/metadataEditDrawer/MetadataEditDrawer', () => ({
  MetadataEditDrawer: jest.fn().mockImplementation(() => {
    return <div data-test="metadata-edit-drawer" />
  }),
}))

type CreditNoteType = GetCreditNoteForDetailsQuery['creditNote']

const createMockCreditNote = (
  metadata: Array<{ key: string; value: string }> = [],
): CreditNoteType => ({
  id: 'credit-note-123',
  number: 'CN-001',
  canBeVoided: true,
  totalAmountCents: '10000',
  creditAmountCents: '5000',
  refundAmountCents: '5000',
  offsetAmountCents: '0',
  currency: CurrencyEnum.Usd,
  integrationSyncable: false,
  taxProviderSyncable: false,
  externalIntegrationId: null,
  taxProviderId: null,
  xmlUrl: null,
  refundStatus: null,
  metadata,
  billingEntity: {
    id: 'billing-entity-1',
    einvoicing: false,
    name: 'Billing',
    logoUrl: null,
  },
  customer: {
    id: 'customer-1',
    email: 'customer@example.com',
    netsuiteCustomer: null,
    xeroCustomer: null,
    anrokCustomer: null,
    avalaraCustomer: null,
  },
})

describe('CreditNoteDetailsMetadata', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(cleanup)

  describe('rendering', () => {
    it('renders the metadata section header', async () => {
      const creditNote = createMockCreditNote()

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      // "Metadata" section header (text_1764595550459r2l0ed023um)
      expect(screen.getByText('Metadata')).toBeInTheDocument()
    })

    it('renders the edit button', async () => {
      const creditNote = createMockCreditNote()

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      // "Edit" button (text_63e51ef4985f0ebd75c212fc)
      expect(screen.getByText('Edit')).toBeInTheDocument()
    })

    it('renders empty state message when no metadata', async () => {
      const creditNote = createMockCreditNote([])

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      // No metadata message - using partial text match
      expect(screen.getByText(/No metadata/i)).toBeInTheDocument()
    })

    it('renders the MetadataEditDrawer component', async () => {
      const creditNote = createMockCreditNote()

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      expect(screen.getByTestId('metadata-edit-drawer')).toBeInTheDocument()
    })
  })

  describe('with metadata', () => {
    it('renders metadata key-value pairs', async () => {
      const creditNote = createMockCreditNote([
        { key: 'order_id', value: 'ORD-12345' },
        { key: 'department', value: 'Sales' },
      ])

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      expect(screen.getByText('order_id')).toBeInTheDocument()
      expect(screen.getByText('ORD-12345')).toBeInTheDocument()
      expect(screen.getByText('department')).toBeInTheDocument()
      expect(screen.getByText('Sales')).toBeInTheDocument()
    })

    it('does not render empty state when metadata exists', async () => {
      const creditNote = createMockCreditNote([{ key: 'test', value: 'value' }])

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      expect(screen.queryByText(/No metadata/i)).not.toBeInTheDocument()
    })
  })

  describe('edge cases', () => {
    it('handles undefined creditNote gracefully', async () => {
      await act(() => render(<CreditNoteDetailsMetadata creditNote={undefined} />))

      // Should still render the section
      expect(screen.getByText('Metadata')).toBeInTheDocument()
      expect(screen.getByText(/No metadata/i)).toBeInTheDocument()
    })

    it('handles null metadata array gracefully', async () => {
      const creditNote = createMockCreditNote() as NonNullable<CreditNoteType>

      creditNote.metadata = null

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      expect(screen.getByText(/No metadata/i)).toBeInTheDocument()
    })

    it('handles empty string values in metadata', async () => {
      const creditNote = createMockCreditNote([{ key: 'empty_value', value: '' }])

      await act(() => render(<CreditNoteDetailsMetadata creditNote={creditNote} />))

      expect(screen.getByText('empty_value')).toBeInTheDocument()
    })
  })

  describe('snapshots', () => {
    it('matches snapshot with no metadata', async () => {
      const creditNote = createMockCreditNote([])

      const { container } = await act(() =>
        render(<CreditNoteDetailsMetadata creditNote={creditNote} />),
      )

      expect(container).toMatchSnapshot()
    })

    it('matches snapshot with metadata', async () => {
      const creditNote = createMockCreditNote([
        { key: 'environment', value: 'production' },
        { key: 'version', value: '2.0.0' },
      ])

      const { container } = await act(() =>
        render(<CreditNoteDetailsMetadata creditNote={creditNote} />),
      )

      expect(container).toMatchSnapshot()
    })
  })
})
