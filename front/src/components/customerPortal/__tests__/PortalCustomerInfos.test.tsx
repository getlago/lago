import { screen } from '@testing-library/react'
import { act } from 'react'

import { CountryCode, CustomerTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

import PortalCustomerInfos, {
  PORTAL_CUSTOMER_INFOS_CONTENT_TEST_ID,
  PORTAL_CUSTOMER_INFOS_ERROR_TEST_ID,
} from '../PortalCustomerInfos'

const mockUseCustomerPortalData = jest.fn()
const mockUseCustomerPortalTranslate = jest.fn()

jest.mock('~/components/customerPortal/common/hooks/useCustomerPortalData', () => ({
  useCustomerPortalData: () => mockUseCustomerPortalData(),
}))

jest.mock('~/components/customerPortal/common/useCustomerPortalTranslate', () => ({
  __esModule: true,
  default: () => mockUseCustomerPortalTranslate(),
}))

jest.mock('~/components/customerPortal/common/SectionError', () => ({
  __esModule: true,
  default: ({ refresh }: { refresh?: () => void }) => (
    <div data-test="section-error">
      <button data-test="section-error-refresh" onClick={refresh}>
        Refresh
      </button>
    </div>
  ),
}))

jest.mock('~/components/customerPortal/common/SectionTitle', () => ({
  __esModule: true,
  default: ({
    title,
    action,
    loading,
  }: {
    title: string
    action?: { title: string; onClick: () => void }
    loading?: boolean
  }) => (
    <div data-test="section-title">
      <span data-test="section-title-text">{title}</span>
      {loading && <span data-test="section-title-loading">Loading</span>}
      {action && (
        <button data-test="section-title-action" onClick={action.onClick}>
          {action.title}
        </button>
      )}
    </div>
  ),
}))

jest.mock('~/components/customerPortal/common/SectionLoading', () => ({
  LoaderCustomerInformationSection: () => <div data-test="loading-skeleton">Loading</div>,
}))

jest.mock('~/core/formats/formatAddress', () => ({
  formatAddress: jest.fn((address) => {
    const hasAnyValue = Object.values(address).some((value) => !!value)

    return hasAnyValue ? '123 Main St, Springfield, IL 12345' : null
  }),
}))

const mockCustomerPortalUser = {
  id: '1',
  name: 'Acme Corp',
  firstname: 'John',
  lastname: 'Doe',
  legalName: 'Acme Corporation LLC',
  legalNumber: 'LEG-123456',
  taxIdentificationNumber: 'TAX-789',
  customerType: CustomerTypeEnum.Company,
  email: 'john@acme.com',
  displayName: 'Acme Corp',
  premium: false,
  accountType: 'CUSTOMER',
  applicableTimezone: 'TZ_UTC',
  billingEntityBillingConfiguration: {},
  addressLine1: '123 Main St',
  addressLine2: 'Suite 100',
  city: 'Springfield',
  country: CountryCode.Us,
  state: 'IL',
  zipcode: '12345',
  shippingAddress: {
    addressLine1: '456 Oak Ave',
    addressLine2: '',
    city: 'Chicago',
    country: CountryCode.Us,
    state: 'IL',
    zipcode: '60601',
  },
}

const setupDefaultMocks = () => {
  mockUseCustomerPortalTranslate.mockReturnValue({
    translate: jest.fn((key: string) => key),
  })

  mockUseCustomerPortalData.mockReturnValue({
    data: {
      customerPortalUser: mockCustomerPortalUser,
    },
    loading: false,
    error: undefined,
    refetch: jest.fn(),
  })
}

describe('PortalCustomerInfos', () => {
  const mockViewEditInformation = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
    setupDefaultMocks()
  })

  // GIVEN the component is loading
  // WHEN the data has not been fetched yet
  // THEN should render loading skeleton
  it('should render loading skeleton when loading', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: undefined,
      loading: true,
      error: undefined,
      refetch: jest.fn(),
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.getByTestId('loading-skeleton')).toBeInTheDocument()
    expect(screen.queryByTestId(PORTAL_CUSTOMER_INFOS_CONTENT_TEST_ID)).not.toBeInTheDocument()
  })

  // GIVEN the component is loading
  // WHEN the section title renders
  // THEN should show section title with loading state
  it('should show section title with loading state when loading', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: undefined,
      loading: true,
      error: undefined,
      refetch: jest.fn(),
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.getByTestId('section-title-loading')).toBeInTheDocument()
  })

  // GIVEN there is an error fetching data
  // WHEN the component renders
  // THEN should render the error state with section error
  it('should render error state when there is an error', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: undefined,
      loading: false,
      error: new Error('Network error'),
      refetch: jest.fn(),
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.getByTestId(PORTAL_CUSTOMER_INFOS_ERROR_TEST_ID)).toBeInTheDocument()
    expect(screen.getByTestId('section-error')).toBeInTheDocument()
    expect(screen.queryByTestId(PORTAL_CUSTOMER_INFOS_CONTENT_TEST_ID)).not.toBeInTheDocument()
  })

  // GIVEN the error state is displayed
  // WHEN the user clicks the refresh button
  // THEN should call refetch
  it('should call refetch when refresh is clicked in error state', () => {
    const mockRefetch = jest.fn()

    mockUseCustomerPortalData.mockReturnValue({
      data: undefined,
      loading: false,
      error: new Error('Network error'),
      refetch: mockRefetch,
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    act(() => {
      screen.getByTestId('section-error-refresh').click()
    })

    expect(mockRefetch).toHaveBeenCalled()
  })

  // GIVEN customer data is loaded
  // WHEN the component renders
  // THEN should render the content grid
  it('should render content when data is loaded', () => {
    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.getByTestId(PORTAL_CUSTOMER_INFOS_CONTENT_TEST_ID)).toBeInTheDocument()
    expect(screen.queryByTestId('loading-skeleton')).not.toBeInTheDocument()
    expect(screen.queryByTestId(PORTAL_CUSTOMER_INFOS_ERROR_TEST_ID)).not.toBeInTheDocument()
  })

  // GIVEN customer data is loaded with all fields
  // WHEN the component renders
  // THEN should render customer fields (name, firstname/lastname, legalName, etc.)
  it('should render customer fields when data is loaded', () => {
    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.getByText('Acme Corp')).toBeInTheDocument()
    expect(screen.getByText('John Doe')).toBeInTheDocument()
    expect(screen.getByText('Acme Corporation LLC')).toBeInTheDocument()
    expect(screen.getByText('LEG-123456')).toBeInTheDocument()
    expect(screen.getByText('TAX-789')).toBeInTheDocument()
  })

  // GIVEN customer has an email
  // WHEN the component renders
  // THEN should display the email field
  it('should display email field when customer has email', () => {
    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.getByText('john@acme.com')).toBeInTheDocument()
  })

  // GIVEN customer has no email
  // WHEN the component renders
  // THEN should not display the email field
  it('should not display email field when customer has no email', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: {
        customerPortalUser: {
          ...mockCustomerPortalUser,
          email: undefined,
        },
      },
      loading: false,
      error: undefined,
      refetch: jest.fn(),
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.queryByText('john@acme.com')).not.toBeInTheDocument()
  })

  // GIVEN billing and shipping addresses are identical
  // WHEN the component renders
  // THEN should show the identical addresses message instead of the shipping address
  it('should show identical addresses message when addresses match', () => {
    const identicalAddress = {
      addressLine1: '123 Main St',
      addressLine2: 'Suite 100',
      city: 'Springfield',
      country: CountryCode.Us,
      state: 'IL',
      zipcode: '12345',
    }

    mockUseCustomerPortalData.mockReturnValue({
      data: {
        customerPortalUser: {
          ...mockCustomerPortalUser,
          ...identicalAddress,
          shippingAddress: identicalAddress,
        },
      },
      loading: false,
      error: undefined,
      refetch: jest.fn(),
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    // The identical addresses message translation key should be rendered
    expect(screen.getByText('text_1728381336070e8cj1amorap')).toBeInTheDocument()
  })

  // GIVEN billing and shipping addresses are different
  // WHEN the component renders
  // THEN should show separate shipping address
  it('should show separate shipping address when addresses differ', () => {
    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    // The identical addresses message should NOT be present
    expect(screen.queryByText('text_1728381336070e8cj1amorap')).not.toBeInTheDocument()
  })

  // GIVEN customer has no firstname or lastname
  // WHEN the component renders
  // THEN should not show the firstname/lastname field
  it('should not show firstname/lastname field when both are missing', () => {
    mockUseCustomerPortalData.mockReturnValue({
      data: {
        customerPortalUser: {
          ...mockCustomerPortalUser,
          firstname: undefined,
          lastname: undefined,
        },
      },
      loading: false,
      error: undefined,
      refetch: jest.fn(),
    })

    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    expect(screen.queryByText('John Doe')).not.toBeInTheDocument()
    // The firstname field title translation key should not be rendered
    expect(screen.queryByText('text_17261289386311s35rvzyxbz')).not.toBeInTheDocument()
  })

  // GIVEN the edit button is available
  // WHEN the user clicks it
  // THEN should call viewEditInformation
  it('should call viewEditInformation when edit action is clicked', () => {
    render(<PortalCustomerInfos viewEditInformation={mockViewEditInformation} />)

    act(() => {
      screen.getByTestId('section-title-action').click()
    })

    expect(mockViewEditInformation).toHaveBeenCalled()
  })
})
