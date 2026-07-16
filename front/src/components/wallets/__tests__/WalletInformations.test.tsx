import { screen } from '@testing-library/react'

import { PaymentMethodTypeEnum, WalletDetailsFragment } from '~/generated/graphql'
import { createMockPaymentMethod } from '~/hooks/customer/__tests__/factories/PaymentMethod.factory'
import { PaymentMethodItem } from '~/hooks/customer/usePaymentMethodsList'
import { render } from '~/test-utils'

import WalletInformations, {
  WALLET_INFORMATIONS_CONTAINER_TEST_ID,
  WALLET_INFORMATIONS_NO_RECURRING_TEST_ID,
} from '../WalletInformations'

let mockHasFeatureFlag = false
let mockPaymentMethodsList: PaymentMethodItem[] = []

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))
jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { defaultCurrency: 'USD' },
    intlFormatDateTimeOrgaTZ: () => ({ date: '2024-01-01' }),
    hasFeatureFlag: () => mockHasFeatureFlag,
  }),
}))
jest.mock('~/hooks/useCurrentUser', () => ({
  useCurrentUser: () => ({ isPremium: true }),
}))
jest.mock('~/hooks/customer/usePaymentMethodsList', () => ({
  usePaymentMethodsList: () => ({
    data: mockPaymentMethodsList,
    loading: false,
    error: false,
    refetch: jest.fn(),
  }),
}))

let mockCustomerIcsData: {
  configurableInvoiceCustomSections: { id: string; name: string }[]
  hasOverwrittenInvoiceCustomSectionsSelection: boolean
  skipInvoiceCustomSections: boolean
} | null = null

jest.mock('~/hooks/useCustomerInvoiceCustomSections', () => ({
  useCustomerInvoiceCustomSections: () => ({
    data: mockCustomerIcsData,
    loading: false,
    error: false,
    customer: null,
  }),
}))

// Shared translation keys (same ones the form dropdown / subscription overview use)
const MANUAL_PAYMENT_TRANSLATION_KEY = 'text_173799550683709p2rqkoqd5'
const INHERITED_BADGE_TRANSLATION_KEY = 'text_1764327933607jgtpungo2pp'

const createMockWallet = (overrides = {}) =>
  ({
    id: 'wallet-1',
    code: 'wallet-code',
    name: 'Test Wallet',
    currency: 'USD',
    rateAmount: 1,
    priority: 1,
    expirationAt: null,
    paidTopUpMinAmountCents: null,
    paidTopUpMaxAmountCents: null,
    appliesTo: null,
    paymentMethod: null,
    selectedInvoiceCustomSections: [],
    recurringTransactionRules: [],
    balanceCents: '10000',
    consumedAmountCents: '5000',
    consumedCredits: '50',
    createdAt: '2024-01-01T00:00:00Z',
    creditsBalance: 100,
    lastBalanceSyncAt: '2024-01-01T00:00:00Z',
    lastConsumedCreditAt: '2024-01-01T00:00:00Z',
    lastOngoingBalanceSyncAt: '2024-01-01T00:00:00Z',
    status: 'active',
    terminatedAt: null,
    ongoingBalanceCents: '8000',
    creditsOngoingBalance: '80',
    ongoingUsageBalanceCents: '0',
    creditsOngoingUsageBalance: 0,
    traceable: true,
    customer: null,
    ...overrides,
  }) as unknown as WalletDetailsFragment

describe('WalletInformations', () => {
  beforeEach(() => {
    mockHasFeatureFlag = false
    mockPaymentMethodsList = []
    mockCustomerIcsData = null
  })

  describe('GIVEN no wallet', () => {
    describe('WHEN rendered', () => {
      it('THEN should render nothing', () => {
        const { container } = render(<WalletInformations />)

        expect(container.innerHTML).toBe('')
      })
    })
  })

  describe('GIVEN wallet data', () => {
    describe('WHEN rendered', () => {
      it('THEN should show wallet informations container', () => {
        render(<WalletInformations wallet={createMockWallet()} />)

        expect(screen.getByTestId(WALLET_INFORMATIONS_CONTAINER_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN wallet with no recurring rules', () => {
    describe('WHEN isPremium', () => {
      it('THEN should show no recurring message', () => {
        render(<WalletInformations wallet={createMockWallet()} />)

        expect(screen.getByTestId(WALLET_INFORMATIONS_NO_RECURRING_TEST_ID)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN payment method details are empty ({})', () => {
    describe('WHEN the payment method is manual', () => {
      it('THEN resolves "Manual payment" without an inherited badge', () => {
        render(
          <WalletInformations
            wallet={createMockWallet({
              customer: { id: 'cust-1', externalId: 'ext-1' },
              paymentMethodType: PaymentMethodTypeEnum.Manual,
              paymentMethod: { details: {} },
            })}
          />,
        )

        expect(screen.getByText(MANUAL_PAYMENT_TRANSLATION_KEY)).toBeInTheDocument()
        expect(screen.queryByText(INHERITED_BADGE_TRANSLATION_KEY)).not.toBeInTheDocument()
      })
    })

    describe('WHEN a specific provider card is selected (resolved from the list)', () => {
      it('THEN shows the card and NOT the inherited badge', () => {
        mockPaymentMethodsList = [
          createMockPaymentMethod({ id: 'pm_default', isDefault: true }),
          createMockPaymentMethod({ id: 'pm_specific', isDefault: false }),
        ]

        render(
          <WalletInformations
            wallet={createMockWallet({
              customer: { id: 'cust-1', externalId: 'ext-1' },
              paymentMethodType: PaymentMethodTypeEnum.Provider,
              paymentMethod: { id: 'pm_specific', details: {} },
            })}
          />,
        )

        expect(
          screen.queryByText(INHERITED_BADGE_TRANSLATION_KEY, { exact: false }),
        ).not.toBeInTheDocument()
        expect(
          screen.queryByText(MANUAL_PAYMENT_TRANSLATION_KEY, { exact: false }),
        ).not.toBeInTheDocument()
      })
    })

    describe('WHEN it falls back to the customer default (no specific method)', () => {
      it('THEN shows the inherited badge', () => {
        mockPaymentMethodsList = [createMockPaymentMethod({ id: 'pm_default', isDefault: true })]

        render(
          <WalletInformations
            wallet={createMockWallet({
              customer: { id: 'cust-1', externalId: 'ext-1' },
              paymentMethodType: PaymentMethodTypeEnum.Provider,
              paymentMethod: null,
            })}
          />,
        )

        expect(
          screen.getByText(INHERITED_BADGE_TRANSLATION_KEY, { exact: false }),
        ).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN no explicitly selected invoice custom sections', () => {
    describe('WHEN the customer inherits sections from the billing entity', () => {
      it('THEN still shows the invoice custom sections (fallback), like the subscription overview', () => {
        mockCustomerIcsData = {
          configurableInvoiceCustomSections: [{ id: 'ics-1', name: 'Footer A' }],
          hasOverwrittenInvoiceCustomSectionsSelection: false,
          skipInvoiceCustomSections: false,
        }

        render(
          <WalletInformations
            wallet={createMockWallet({
              customer: { id: 'cust-1', externalId: 'ext-1' },
              selectedInvoiceCustomSections: [],
              skipInvoiceCustomSections: false,
            })}
          />,
        )

        expect(screen.getByText('Footer A')).toBeInTheDocument()
      })
    })
  })
})
