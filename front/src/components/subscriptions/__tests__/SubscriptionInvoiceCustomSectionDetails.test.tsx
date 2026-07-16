import { screen } from '@testing-library/react'

import { render } from '~/test-utils'

import {
  INVOICE_CUSTOM_FOOTER_SECTION,
  SubscriptionInvoiceCustomSectionDetails,
} from '../SubscriptionInvoiceCustomSectionDetails'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/useCustomerInvoiceCustomSections', () => ({
  useCustomerInvoiceCustomSections: jest.fn(() => ({
    data: null,
    loading: false,
    error: false,
    customer: null,
  })),
}))

const { useCustomerInvoiceCustomSections } = jest.requireMock(
  '~/hooks/useCustomerInvoiceCustomSections',
)

describe('SubscriptionInvoiceCustomSectionDetails', () => {
  beforeEach(() => {
    ;(useCustomerInvoiceCustomSections as jest.Mock).mockReturnValue({
      data: null,
      loading: false,
      error: false,
      customer: null,
    })
  })

  it('displays explicit selected sections (APPLY)', () => {
    render(
      <SubscriptionInvoiceCustomSectionDetails
        customerId="customer-id"
        selectedInvoiceCustomSections={[{ id: 'section-1', name: 'Bank details' }]}
        skipInvoiceCustomSections={false}
      />,
    )

    expect(screen.getByTestId(INVOICE_CUSTOM_FOOTER_SECTION)).toBeInTheDocument()
    expect(screen.getByText('Bank details')).toBeInTheDocument()
  })

  it('displays the section when sections are explicitly skipped (NONE)', () => {
    render(
      <SubscriptionInvoiceCustomSectionDetails
        customerId="customer-id"
        selectedInvoiceCustomSections={[]}
        skipInvoiceCustomSections={true}
      />,
    )

    expect(screen.getByTestId(INVOICE_CUSTOM_FOOTER_SECTION)).toBeInTheDocument()
  })

  it('displays inherited billing-entity sections when the customer has no overwritten selection', () => {
    ;(useCustomerInvoiceCustomSections as jest.Mock).mockReturnValue({
      data: {
        customerId: 'customer-id',
        externalId: 'customer-external-id',
        configurableInvoiceCustomSections: [
          { id: 'section-1', name: 'Bank details' },
          { id: 'section-2', name: 'Legal terms' },
        ],
        hasOverwrittenInvoiceCustomSectionsSelection: false,
        skipInvoiceCustomSections: false,
      },
      loading: false,
      error: false,
      customer: null,
    })

    render(
      <SubscriptionInvoiceCustomSectionDetails
        customerId="customer-id"
        selectedInvoiceCustomSections={[]}
        skipInvoiceCustomSections={false}
      />,
    )

    expect(screen.getByTestId(INVOICE_CUSTOM_FOOTER_SECTION)).toBeInTheDocument()
    expect(screen.getByText('Bank details')).toBeInTheDocument()
    expect(screen.getByText('Legal terms')).toBeInTheDocument()
  })

  it('renders nothing without a customer id and no explicit sections', () => {
    render(
      <SubscriptionInvoiceCustomSectionDetails
        selectedInvoiceCustomSections={[]}
        skipInvoiceCustomSections={false}
      />,
    )

    expect(screen.queryByTestId(INVOICE_CUSTOM_FOOTER_SECTION)).not.toBeInTheDocument()
  })

  it('renders nothing when the customer has no sections to inherit (fallback empty)', () => {
    ;(useCustomerInvoiceCustomSections as jest.Mock).mockReturnValue({
      data: {
        customerId: 'customer-id',
        externalId: 'customer-external-id',
        configurableInvoiceCustomSections: [],
        hasOverwrittenInvoiceCustomSectionsSelection: false,
        skipInvoiceCustomSections: false,
      },
      loading: false,
      error: false,
      customer: null,
    })

    render(
      <SubscriptionInvoiceCustomSectionDetails
        customerId="customer-id"
        selectedInvoiceCustomSections={[]}
        skipInvoiceCustomSections={false}
      />,
    )

    expect(screen.queryByTestId(INVOICE_CUSTOM_FOOTER_SECTION)).not.toBeInTheDocument()
  })
})
