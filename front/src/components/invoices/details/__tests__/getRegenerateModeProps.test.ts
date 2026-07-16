import { getRegenerateModeProps } from '../InvoiceDetailsTableBodyLine'

// Stub the drawer hook so the transitive `drawerStack.ts` (Vite-only `import.meta.hot`)
// is never loaded when this helper-only test imports BodyLine.
jest.mock('~/components/invoices/details/ViewFeeDetailsDrawer', () => ({
  useViewFeeDetailsDrawer: () => ({ open: jest.fn(), close: jest.fn() }),
}))

describe('getRegenerateModeProps', () => {
  const mockOnAdd = jest.fn()
  const mockOnDelete = jest.fn()
  const mockLocalFees = [{ id: 'fee-1' }, { id: 'fee-2' }] as any
  const mockInvoiceSubscriptionId = 'sub-123'

  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('regenerate mode (all props provided)', () => {
    it('should return all regenerate mode props when all required arguments are provided', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      expect(result).toEqual({
        onAdd: mockOnAdd,
        onDelete: mockOnDelete,
        localFees: mockLocalFees,
        invoiceSubscriptionId: mockInvoiceSubscriptionId,
      })
    })

    it('should include the correct invoiceSubscriptionId for the subscription', () => {
      const specificSubscriptionId = 'specific-sub-id'
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        mockLocalFees,
        specificSubscriptionId,
      )

      expect(result.invoiceSubscriptionId).toBe(specificSubscriptionId)
    })

    it('should preserve the onAdd function reference', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      expect(result.onAdd).toBe(mockOnAdd)
    })

    it('should preserve the onDelete function reference', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      expect(result.onDelete).toBe(mockOnDelete)
    })

    it('should preserve the localFees array reference', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      expect(result.localFees).toBe(mockLocalFees)
    })
  })

  describe('non-regenerate mode (missing props)', () => {
    it('should return empty object when onAdd is undefined', () => {
      const result = getRegenerateModeProps(
        undefined,
        mockOnDelete,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      expect(result).toEqual({})
    })

    it('should return empty object when onDelete is undefined', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        undefined,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      expect(result).toEqual({})
    })

    it('should return empty object when localFees is undefined', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        undefined,
        mockInvoiceSubscriptionId,
      )

      expect(result).toEqual({})
    })

    it('should return empty object when all optional props are undefined', () => {
      const result = getRegenerateModeProps(
        undefined,
        undefined,
        undefined,
        mockInvoiceSubscriptionId,
      )

      expect(result).toEqual({})
    })

    it('should return empty object when localFees is an empty array (falsy in conditional)', () => {
      // Note: This tests the current implementation behavior
      // An empty array is still truthy in JavaScript, so this should return the props
      const emptyFees: any[] = []
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        emptyFees,
        mockInvoiceSubscriptionId,
      )

      // Empty array is truthy, so props should be returned
      expect(result).toEqual({
        onAdd: mockOnAdd,
        onDelete: mockOnDelete,
        localFees: emptyFees,
        invoiceSubscriptionId: mockInvoiceSubscriptionId,
      })
    })
  })

  describe('type safety - ensures invoiceSubscriptionId is always provided with onAdd', () => {
    /**
     * This test documents the critical bug fix from ISSUE-1556:
     * When onAdd is provided (regenerate mode), invoiceSubscriptionId MUST be included.
     * The helper function enforces this by only returning regenerate props when all
     * required arguments are present.
     */
    it('should always include invoiceSubscriptionId when returning regenerate mode props', () => {
      const result = getRegenerateModeProps(
        mockOnAdd,
        mockOnDelete,
        mockLocalFees,
        mockInvoiceSubscriptionId,
      )

      // When we have regenerate mode props, invoiceSubscriptionId must be present
      if ('onAdd' in result) {
        expect(result).toHaveProperty('invoiceSubscriptionId')
        expect(result.invoiceSubscriptionId).toBeTruthy()
      }
    })

    it('should never return partial regenerate props (all or nothing)', () => {
      // Test that we don't get a partial object like { onAdd: fn } without invoiceSubscriptionId
      const testCases = [
        {
          onAdd: mockOnAdd,
          onDelete: undefined,
          localFees: mockLocalFees,
          subId: mockInvoiceSubscriptionId,
        },
        {
          onAdd: undefined,
          onDelete: mockOnDelete,
          localFees: mockLocalFees,
          subId: mockInvoiceSubscriptionId,
        },
        {
          onAdd: mockOnAdd,
          onDelete: mockOnDelete,
          localFees: undefined,
          subId: mockInvoiceSubscriptionId,
        },
      ]

      testCases.forEach(({ onAdd, onDelete, localFees, subId }) => {
        const result = getRegenerateModeProps(onAdd, onDelete, localFees, subId)

        // Result should either be empty or have ALL properties
        const hasAnyProp =
          'onAdd' in result ||
          'onDelete' in result ||
          'localFees' in result ||
          'invoiceSubscriptionId' in result
        const hasAllProps =
          'onAdd' in result &&
          'onDelete' in result &&
          'localFees' in result &&
          'invoiceSubscriptionId' in result

        if (hasAnyProp) {
          expect(hasAllProps).toBe(true)
        }
      })
    })
  })
})
