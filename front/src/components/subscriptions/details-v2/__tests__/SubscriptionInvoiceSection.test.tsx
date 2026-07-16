import { render } from '~/test-utils'

import { SubscriptionInvoiceSection } from '../SubscriptionInvoiceSection'

const mockSectionHeader: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockInfoGridItem: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockInvoiceCustomSectionDetails: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockDrawer: jest.Mock<null, [Record<string, unknown>]> = jest.fn()
const mockSaveInvoicing = jest.fn()

jest.mock('~/components/plans/details-v2/shared/SectionHeader', () => ({
  SectionHeader: (props: Record<string, unknown>) => {
    mockSectionHeader(props)

    return null
  },
}))

jest.mock('~/components/layouts/DetailsPage', () => ({
  DetailsPage: {
    InfoGridItem: (props: Record<string, unknown>) => {
      mockInfoGridItem(props)

      return null
    },
  },
}))

jest.mock('~/components/subscriptions/SubscriptionInvoiceCustomSectionDetails', () => ({
  SubscriptionInvoiceCustomSectionDetails: (props: Record<string, unknown>) => {
    mockInvoiceCustomSectionDetails(props)

    return null
  },
}))

jest.mock('~/components/subscriptions/form/InvoicingSettingsDrawer', () => ({
  InvoicingSettingsDrawer: (props: Record<string, unknown>) => {
    mockDrawer(props)

    return null
  },
}))

jest.mock('~/hooks/customer/useUpdateSubscriptionSettings', () => ({
  useUpdateSubscriptionSettings: () => ({
    savePayment: jest.fn(),
    saveInvoicing: mockSaveInvoicing,
  }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: () => true }),
}))

const subscription = {
  id: 'sub_1',
  consolidateInvoice: true,
  skipInvoiceCustomSections: false,
  selectedInvoiceCustomSections: [{ id: 'cs_1', name: 'Bank details' }],
  customer: { id: 'cust_1', externalId: 'ext_1' },
}

const renderSection = (overrides: Partial<typeof subscription> = {}) =>
  render(<SubscriptionInvoiceSection subscription={{ ...subscription, ...overrides }} />)

describe('SubscriptionInvoiceSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders the invoicing header, consolidation, the custom-section display and the drawer', () => {
    renderSection()

    expect(mockSectionHeader).toHaveBeenCalledWith(
      expect.objectContaining({
        title: 'text_17423672025282dl7iozy1ru',
        description: 'text_1782825858647mvpxt3d6et4',
      }),
    )
    expect(mockInfoGridItem).toHaveBeenCalledWith(
      expect.objectContaining({ value: 'text_1778745351091h7z5baw0ta6' }),
    )
    expect(mockInvoiceCustomSectionDetails).toHaveBeenCalledWith(
      expect.objectContaining({ customerId: 'cust_1' }),
    )
    expect(mockDrawer).toHaveBeenCalledWith(
      expect.objectContaining({ onSave: mockSaveInvoicing, showCustomSection: true }),
    )
  })

  it('keeps consolidation but hides the custom-section display without a customer', () => {
    renderSection({ customer: undefined })

    expect(mockInfoGridItem).toHaveBeenCalled()
    expect(mockInvoiceCustomSectionDetails).not.toHaveBeenCalled()
    expect(mockDrawer).toHaveBeenCalledWith(expect.objectContaining({ showCustomSection: false }))
  })
})
