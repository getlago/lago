import { render, screen } from '@testing-library/react'

import { CreditNoteTableItemFragment } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import CreditNoteBadge from '../CreditNoteBadge'

const createMockCreditNote = (
  overrides: Partial<CreditNoteTableItemFragment> = {},
): CreditNoteTableItemFragment =>
  ({
    id: 'credit-note-id',
    creditAmountCents: '0',
    refundAmountCents: '0',
    offsetAmountCents: '0',
    voidedAt: null,
    taxProviderSyncable: false,
    ...overrides,
  }) as CreditNoteTableItemFragment

const renderComponent = (creditNote?: CreditNoteTableItemFragment | null) => {
  return render(<CreditNoteBadge creditNote={creditNote} />, {
    wrapper: AllTheProviders,
  })
}

describe('CreditNoteBadge', () => {
  describe('GIVEN no credit note', () => {
    it('WHEN creditNote is undefined THEN should render nothing', () => {
      const { container } = renderComponent(undefined)

      expect(container).toBeEmptyDOMElement()
    })

    it('WHEN creditNote is null THEN should render nothing', () => {
      const { container } = renderComponent(null)

      expect(container).toBeEmptyDOMElement()
    })
  })

  describe('GIVEN a voided credit note', () => {
    it('THEN should render Voided chip', () => {
      const creditNote = createMockCreditNote({
        voidedAt: '2024-01-01T00:00:00Z',
        creditAmountCents: '1000', // Even with amounts, voided takes precedence
      })

      renderComponent(creditNote)

      expect(screen.getByText('Voided')).toBeInTheDocument()
    })
  })

  describe('GIVEN no credit note types', () => {
    it('WHEN all amounts are 0 THEN should render nothing', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '0',
        refundAmountCents: '0',
        offsetAmountCents: '0',
      })

      const { container } = renderComponent(creditNote)

      expect(container).toBeEmptyDOMElement()
    })
  })

  describe('GIVEN a single credit note type', () => {
    it('WHEN only creditAmountCents > 0 THEN should show Credit chip', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '1000',
        refundAmountCents: '0',
        offsetAmountCents: '0',
      })

      renderComponent(creditNote)

      expect(screen.getByText('Credit')).toBeInTheDocument()
    })

    it('WHEN only refundAmountCents > 0 THEN should show Refund chip', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '0',
        refundAmountCents: '1000',
        offsetAmountCents: '0',
      })

      renderComponent(creditNote)

      expect(screen.getByText('Refund')).toBeInTheDocument()
    })

    it('WHEN only offsetAmountCents > 0 THEN should show Offset chip', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '0',
        refundAmountCents: '0',
        offsetAmountCents: '1000',
      })

      renderComponent(creditNote)

      expect(screen.getByText('Offset')).toBeInTheDocument()
    })
  })

  describe('GIVEN multiple credit note types', () => {
    it('WHEN credit and refund amounts > 0 THEN should show Multiple types chip', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '1000',
        refundAmountCents: '500',
        offsetAmountCents: '0',
      })

      renderComponent(creditNote)

      expect(screen.getByText('Multiple types')).toBeInTheDocument()
    })

    it('WHEN all amounts > 0 THEN should show Multiple types chip', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '1000',
        refundAmountCents: '500',
        offsetAmountCents: '200',
      })

      renderComponent(creditNote)

      expect(screen.getByText('Multiple types')).toBeInTheDocument()
    })
  })

  describe('GIVEN taxProviderSyncable', () => {
    it('WHEN true THEN should render chip correctly', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '1000',
        taxProviderSyncable: true,
      })

      renderComponent(creditNote)

      expect(screen.getByText('Credit')).toBeInTheDocument()
    })

    it('WHEN false THEN should render chip correctly', () => {
      const creditNote = createMockCreditNote({
        creditAmountCents: '1000',
        taxProviderSyncable: false,
      })

      renderComponent(creditNote)

      expect(screen.getByText('Credit')).toBeInTheDocument()
    })
  })
})
