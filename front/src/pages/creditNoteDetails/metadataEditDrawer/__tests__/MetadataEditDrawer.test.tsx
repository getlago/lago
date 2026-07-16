import { act, cleanup, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { CurrencyEnum, GetCreditNoteForDetailsQuery } from '~/generated/graphql'
import { render } from '~/test-utils'

import { MetadataEditDrawer, MetadataEditDrawerRef } from '../MetadataEditDrawer'

const mockUpdateCreditNote = jest.fn()

jest.mock('../useEditCreditNote', () => ({
  useEditCreditNote: () => ({
    updateCreditNote: mockUpdateCreditNote,
    isUpdatingCreditNote: false,
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

// Helper to get the drawer element from the MUI portal
const getDrawerElement = (): HTMLElement | null => {
  return document.querySelector('.MuiDrawer-paper')
}

// Helper to get the drawer content queries from the MUI portal
const getDrawerContent = () => {
  const drawer = getDrawerElement()

  return drawer ? within(drawer) : null
}

describe('MetadataEditDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUpdateCreditNote.mockResolvedValue({
      data: { updateCreditNote: { id: 'credit-note-123' } },
    })
  })

  afterEach(cleanup)

  describe('drawer ref methods', () => {
    it('exposes openDrawer method via ref', () => {
      const ref = createRef<MetadataEditDrawerRef>()

      render(<MetadataEditDrawer ref={ref} />)

      expect(ref.current?.openDrawer).toBeDefined()
      expect(typeof ref.current?.openDrawer).toBe('function')
    })

    it('exposes closeDrawer method via ref', () => {
      const ref = createRef<MetadataEditDrawerRef>()

      render(<MetadataEditDrawer ref={ref} />)

      expect(ref.current?.closeDrawer).toBeDefined()
      expect(typeof ref.current?.closeDrawer).toBe('function')
    })

    it('can call openDrawer without error', () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      expect(() => {
        ref.current?.openDrawer({ creditNote })
      }).not.toThrow()
    })

    it('can call closeDrawer without error', () => {
      const ref = createRef<MetadataEditDrawerRef>()

      render(<MetadataEditDrawer ref={ref} />)

      expect(() => {
        ref.current?.closeDrawer()
      }).not.toThrow()
    })
  })

  describe('drawer rendering when opened', () => {
    it('renders the drawer with title and submit button', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      // Wait for drawer to be in the DOM
      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      // Check title (appears twice - in title bar + headline)
      const editMetadataElements = screen.getAllByText('Edit Metadata')

      expect(editMetadataElements.length).toBeGreaterThan(0)

      // Check submit button
      expect(screen.getByText('Save edits')).toBeInTheDocument()

      // Check MetadataFormCard elements
      expect(screen.getByText('Metadata')).toBeInTheDocument()
      expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
    })

    it('renders the description text', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      // Wait for drawer to be in the DOM
      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      // Check description - use a partial match to avoid issues with special characters
      expect(
        screen.getByText(/Metadata will be linked to the credit note object payload/),
      ).toBeInTheDocument()
    })
  })

  describe('with existing metadata', () => {
    it('pre-populates form with existing metadata', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([{ key: 'existing_key', value: 'existing_value' }])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      expect(screen.getByDisplayValue('existing_key')).toBeInTheDocument()
      expect(screen.getByDisplayValue('existing_value')).toBeInTheDocument()
    })

    it('shows multiple metadata items', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([
        { key: 'key1', value: 'value1' },
        { key: 'key2', value: 'value2' },
      ])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      expect(screen.getByDisplayValue('key1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value1')).toBeInTheDocument()
      expect(screen.getByDisplayValue('key2')).toBeInTheDocument()
      expect(screen.getByDisplayValue('value2')).toBeInTheDocument()
    })

    it('handles metadata with empty value', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([{ key: 'key_only', value: '' }])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      expect(screen.getByDisplayValue('key_only')).toBeInTheDocument()
    })
  })

  describe('form validation', () => {
    it('disables submit button when form is pristine', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      const submitButton = screen.getByText('Save edits').closest('button')

      expect(submitButton).toBeDisabled()
    })

    it('enables submit button after adding metadata', async () => {
      const user = userEvent.setup()
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      // Click add metadata button
      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      // Fill in the new metadata fields
      await waitFor(() => {
        const inputs = screen.getAllByRole('textbox')

        expect(inputs.length).toBeGreaterThan(0)
      })

      const inputs = screen.getAllByRole('textbox')

      await user.type(inputs[0], 'new_key')
      await user.type(inputs[1], 'new_value')

      await waitFor(() => {
        const submitButton = screen.getByText('Save edits').closest('button')

        expect(submitButton).not.toBeDisabled()
      })
    })

    it('enables submit button after modifying existing metadata', async () => {
      const user = userEvent.setup()
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([{ key: 'existing_key', value: 'existing_value' }])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      // Modify existing value
      const valueInput = screen.getByDisplayValue('existing_value')

      await user.clear(valueInput)
      await user.type(valueInput, 'modified_value')

      await waitFor(() => {
        const submitButton = screen.getByText('Save edits').closest('button')

        expect(submitButton).not.toBeDisabled()
      })
    })
  })

  describe('form submission', () => {
    it('calls updateCreditNote on form submission', async () => {
      const user = userEvent.setup()
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([{ key: 'existing_key', value: 'existing_value' }])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      // Modify existing value to enable submit
      const valueInput = screen.getByDisplayValue('existing_value')

      await user.clear(valueInput)
      await user.type(valueInput, 'modified_value')

      // Wait for submit button to be enabled
      await waitFor(() => {
        const submitButton = screen.getByText('Save edits').closest('button')

        expect(submitButton).not.toBeDisabled()
      })

      // Submit the form
      const submitButton = screen.getByText('Save edits').closest('button')

      if (submitButton) {
        await user.click(submitButton)
      }

      await waitFor(() => {
        expect(mockUpdateCreditNote).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'credit-note-123',
              metadata: [{ key: 'existing_key', value: 'modified_value' }],
            },
          },
        })
      })
    })

    it('submits with new metadata when adding metadata items', async () => {
      const user = userEvent.setup()
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      // Click add metadata button
      const addButton = screen.getByTestId('add-metadata-button')

      await user.click(addButton)

      // Fill in the new metadata fields
      await waitFor(() => {
        const inputs = screen.getAllByRole('textbox')

        expect(inputs.length).toBeGreaterThan(0)
      })

      const inputs = screen.getAllByRole('textbox')

      await user.type(inputs[0], 'new_key')
      await user.type(inputs[1], 'new_value')

      // Wait for submit button to be enabled
      await waitFor(() => {
        const submitButton = screen.getByText('Save edits').closest('button')

        expect(submitButton).not.toBeDisabled()
      })

      // Submit the form
      const submitButton = screen.getByText('Save edits').closest('button')

      if (submitButton) {
        await user.click(submitButton)
      }

      await waitFor(() => {
        expect(mockUpdateCreditNote).toHaveBeenCalledWith({
          variables: {
            input: {
              id: 'credit-note-123',
              metadata: [{ key: 'new_key', value: 'new_value' }],
            },
          },
        })
      })
    })
  })

  describe('drawer interactions', () => {
    it('can reopen drawer after closing', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      render(<MetadataEditDrawer ref={ref} />)

      // Open drawer
      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerContent()).not.toBeNull()
      })

      // Close drawer
      await act(async () => {
        ref.current?.closeDrawer()
      })

      await waitFor(() => {
        const drawer = document.querySelector('.MuiDrawer-paper')

        expect(drawer).toBeNull()
      })

      // Reopen drawer
      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerContent()).not.toBeNull()
      })
    })
  })

  describe('edge cases', () => {
    it('handles empty metadata array', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
    })

    it('handles creditNote with null metadata', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      // @ts-expect-error - testing edge case
      creditNote.metadata = null

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
    })

    it('handles creditNote with undefined metadata', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote()

      // @ts-expect-error - testing edge case
      creditNote.metadata = undefined

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerElement()).not.toBeNull()
      })

      expect(screen.getByTestId('add-metadata-button')).toBeInTheDocument()
    })
  })

  describe('snapshots', () => {
    it('matches snapshot when open with no metadata', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerContent()).not.toBeNull()
      })

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })

    it('matches snapshot when open with metadata', async () => {
      const ref = createRef<MetadataEditDrawerRef>()
      const creditNote = createMockCreditNote([
        { key: 'order_id', value: 'ORD-001' },
        { key: 'department', value: 'Engineering' },
      ])

      render(<MetadataEditDrawer ref={ref} />)

      await act(async () => {
        ref.current?.openDrawer({ creditNote })
      })

      await waitFor(() => {
        expect(getDrawerContent()).not.toBeNull()
      })

      const drawerPaper = document.querySelector('.MuiDrawer-paper')

      expect(drawerPaper).toMatchSnapshot()
    })
  })
})
