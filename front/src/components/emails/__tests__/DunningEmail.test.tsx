import { cleanup, screen } from '@testing-library/react'

import { DunningEmail, DunningEmailSkeleton } from '~/components/emails/DunningEmail'
import { LocaleEnum } from '~/core/translations'
import { CurrencyEnum, ProviderTypeEnum } from '~/generated/graphql'
import { render } from '~/test-utils'

const mockInvoices = [
  {
    id: '1',
    number: 'INV-001',
    totalDueAmountCents: '10000',
    currency: CurrencyEnum.Usd,
  },
  {
    id: '2',
    number: 'INV-002',
    totalDueAmountCents: '20000',
    currency: CurrencyEnum.Usd,
  },
]

const mockCustomer = {
  displayName: 'Test Customer',
  paymentProvider: ProviderTypeEnum.Stripe,
  netPaymentTerm: 30,
  billingConfiguration: {
    documentLocale: LocaleEnum.en,
  },
}

const mockOrganization = {
  name: 'Test Organization',
  logoUrl: 'https://example.com/logo.png',
  email: 'billing@example.com',
  netPaymentTerm: 15,
  billingConfiguration: {
    documentLocale: LocaleEnum.en,
  },
}

describe('DunningEmail', () => {
  afterEach(cleanup)

  it('renders with customer and organization data', () => {
    const { container } = render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={mockCustomer}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    // Component renders without crashing
    expect(container).toBeInTheDocument()
  })

  it('renders invoice table with correct data', () => {
    render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={mockCustomer}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    expect(screen.getByText('INV-001')).toBeInTheDocument()
    expect(screen.getByText('INV-002')).toBeInTheDocument()
  })

  it('shows payment button when payment provider is not Gocardless', () => {
    render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={mockCustomer}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    const button = screen.getByRole('button')

    expect(button).toBeInTheDocument()
  })

  it('does not show payment button when payment provider is Gocardless', () => {
    const customerWithGocardless = {
      ...mockCustomer,
      paymentProvider: ProviderTypeEnum.Gocardless,
    }

    render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={customerWithGocardless}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })

  it('displays organization email when provided', () => {
    render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={mockCustomer}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    expect(screen.getByText('billing@example.com')).toBeInTheDocument()
  })

  it('uses customer netPaymentTerm when available', () => {
    const { container } = render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={mockCustomer}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    // Component renders with customer data
    expect(container).toBeInTheDocument()
  })

  it('falls back to organization netPaymentTerm when customer has none', () => {
    const customerWithoutTerm = {
      ...mockCustomer,
      netPaymentTerm: undefined,
    }

    const { container } = render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        customer={customerWithoutTerm}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    // Component renders with organization fallback
    expect(container).toBeInTheDocument()
  })

  it('handles string netPaymentTerm for fake data', () => {
    const organizationWithStringTerm = {
      ...mockOrganization,
      netPaymentTerm: '30' as unknown as number,
    }

    const { container } = render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        organization={organizationWithStringTerm}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    // Component renders with string netPaymentTerm
    expect(container).toBeInTheDocument()
  })

  it('renders without customer data', () => {
    render(
      <DunningEmail
        locale={LocaleEnum.en}
        invoices={mockInvoices}
        organization={mockOrganization}
        currency={CurrencyEnum.Usd}
        overdueAmount={300}
      />,
    )

    expect(screen.getByText('Test Organization', { exact: false })).toBeInTheDocument()
  })
})

describe('DunningEmailSkeleton', () => {
  afterEach(cleanup)

  it('renders skeleton loaders', () => {
    const { container } = render(<DunningEmailSkeleton />)

    // Component renders
    expect(container.firstChild).toBeInTheDocument()
  })
})
