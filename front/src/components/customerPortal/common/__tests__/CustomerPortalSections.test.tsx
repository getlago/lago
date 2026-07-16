import { screen } from '@testing-library/react'

import { PremiumIntegrationTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import CustomerPortalSections, {
  CUSTOMER_PORTAL_SECTIONS_POWERED_BY_TEST_ID,
  CUSTOMER_PORTAL_SECTIONS_TEST_ID,
} from '../CustomerPortalSections'

const MOCK_WALLET_SECTION_TEST_ID = 'mock-wallet-section'
const MOCK_USAGE_SECTION_TEST_ID = 'mock-usage-section'
const MOCK_PORTAL_CUSTOMER_INFOS_TEST_ID = 'mock-portal-customer-infos'
const MOCK_PORTAL_INVOICES_LIST_TEST_ID = 'mock-portal-invoices-list'

const mockUseCustomerPortalData = jest.fn()
const mockUseCustomerPortalTranslate = jest.fn()
const mockUseCustomerPortalNavigation = jest.fn()

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalData', () => ({
  useCustomerPortalData: () => mockUseCustomerPortalData(),
}))

jest.mock('~/components/customerPortal/common/useCustomerPortalTranslate', () => ({
  __esModule: true,
  default: () => mockUseCustomerPortalTranslate(),
}))

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalNavigation', () => ({
  __esModule: true,
  default: () => mockUseCustomerPortalNavigation(),
}))

jest.mock('~/components/customerPortal/wallet/WalletSection', () => ({
  __esModule: true,
  default: ({ viewWallet }: { viewWallet: () => void }) => (
    <button data-test={MOCK_WALLET_SECTION_TEST_ID} onClick={viewWallet} />
  ),
}))

jest.mock('~/components/customerPortal/usage/UsageSection', () => ({
  __esModule: true,
  default: ({ viewSubscription }: { viewSubscription: () => void }) => (
    <button data-test={MOCK_USAGE_SECTION_TEST_ID} onClick={viewSubscription} />
  ),
}))

jest.mock('~/components/customerPortal/PortalCustomerInfos', () => ({
  __esModule: true,
  default: ({ viewEditInformation }: { viewEditInformation: () => void }) => (
    <button data-test={MOCK_PORTAL_CUSTOMER_INFOS_TEST_ID} onClick={viewEditInformation} />
  ),
}))

jest.mock('~/components/customerPortal/PortalInvoicesList', () => ({
  __esModule: true,
  default: () => <div data-test={MOCK_PORTAL_INVOICES_LIST_TEST_ID} />,
}))

jest.mock('~/public/images/logo/lago-logo-grey.svg', () => ({
  __esModule: true,
  default: () => <div data-test="mock-logo" />,
}))

const mockViewWallet = jest.fn()
const mockViewSubscription = jest.fn()
const mockViewEditInformation = jest.fn()

const setupDefaultMocks = () => {
  mockUseCustomerPortalTranslate.mockReturnValue({
    translate: jest.fn((key: string) => key),
  })

  mockUseCustomerPortalData.mockReturnValue({
    data: {
      customerPortalOrganization: {
        premiumIntegrations: [],
      },
    },
    loading: false,
  })

  mockUseCustomerPortalNavigation.mockReturnValue({
    viewWallet: mockViewWallet,
    viewSubscription: mockViewSubscription,
    viewEditInformation: mockViewEditInformation,
  })
}

describe('CustomerPortalSections', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  // GIVEN the component renders
  // WHEN it mounts
  // THEN should render all sections
  it('should render all sections', () => {
    render(<CustomerPortalSections />)

    expect(screen.getByTestId(CUSTOMER_PORTAL_SECTIONS_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(MOCK_WALLET_SECTION_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(MOCK_USAGE_SECTION_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(MOCK_PORTAL_CUSTOMER_INFOS_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId(MOCK_PORTAL_INVOICES_LIST_TEST_ID)).toBeInTheDocument()
  })

  // GIVEN the organization does NOT have RemoveBrandingWatermark
  // WHEN the component renders
  // THEN should show powered by section
  it('should show powered by section when organization does not have RemoveBrandingWatermark', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: {
        customerPortalOrganization: {
          premiumIntegrations: [],
        },
      },
      loading: false,
    })

    render(<CustomerPortalSections />)

    expect(screen.getByTestId(CUSTOMER_PORTAL_SECTIONS_POWERED_BY_TEST_ID)).toBeInTheDocument()
  })

  // GIVEN the organization HAS RemoveBrandingWatermark
  // WHEN the component renders
  // THEN should NOT show powered by section
  it('should not show powered by section when organization has RemoveBrandingWatermark', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: {
        customerPortalOrganization: {
          premiumIntegrations: [PremiumIntegrationTypeEnum.RemoveBrandingWatermark],
        },
      },
      loading: false,
    })

    render(<CustomerPortalSections />)

    expect(
      screen.queryByTestId(CUSTOMER_PORTAL_SECTIONS_POWERED_BY_TEST_ID),
    ).not.toBeInTheDocument()
  })

  // GIVEN portalData is undefined/loading
  // WHEN the component renders
  // THEN should still show powered by section
  it('should show powered by section when portalData is undefined', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: undefined,
      loading: true,
    })

    render(<CustomerPortalSections />)

    expect(screen.getByTestId(CUSTOMER_PORTAL_SECTIONS_POWERED_BY_TEST_ID)).toBeInTheDocument()
  })

  // GIVEN navigation hooks are provided
  // WHEN the component renders
  // THEN should pass correct callbacks to child components
  it('should pass correct navigation callbacks to child components', () => {
    render(<CustomerPortalSections />)

    const walletSection = screen.getByTestId(MOCK_WALLET_SECTION_TEST_ID)
    const usageSection = screen.getByTestId(MOCK_USAGE_SECTION_TEST_ID)
    const customerInfos = screen.getByTestId(MOCK_PORTAL_CUSTOMER_INFOS_TEST_ID)

    walletSection.click()
    expect(mockViewWallet).toHaveBeenCalled()

    usageSection.click()
    expect(mockViewSubscription).toHaveBeenCalled()

    customerInfos.click()
    expect(mockViewEditInformation).toHaveBeenCalled()
  })
})
