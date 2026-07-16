import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { useCurrentUser } from '~/hooks/useCurrentUser'
import { render } from '~/test-utils'
import { createMockPlanForm } from '~/test-utils/createMockPlanForm'

import {
  ADD_MINIMUM_COMMITMENT_TEST_ID,
  CommitmentsSection,
  OPEN_MINIMUM_COMMITMENT_DRAWER_TEST_ID,
} from '../CommitmentsSection'
import { PlanFormInput } from '../types'

// --- Mocks ---

jest.mock('~/hooks/useCurrentUser')

const mockedUseCurrentUser = jest.mocked(useCurrentUser)

jest.mock('~/core/formats/intlFormatNumber', () => ({
  getCurrencySymbol: (currency: string) => currency,
  intlFormatNumber: (value: number, opts?: { style?: string; currency?: string }) => {
    if (opts?.style === 'currency') return `$${value}`
    if (opts?.style === 'percent') return `${value}%`
    return String(value)
  },
}))

jest.mock('~/core/constants/form', () => ({
  FORM_TYPE_ENUM: { creation: 'creation', edition: 'edition' },
  getIntervalTranslationKey: { monthly: 'monthly_key', yearly: 'yearly_key' },
  SEARCH_TAX_INPUT_FOR_MIN_COMMITMENT_CLASSNAME: 'search-tax-min-commitment',
}))

// Mock the MinimumCommitmentDrawer
const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/minimumCommitment/MinimumCommitmentDrawer', () => {
  const React = jest.requireActual('react')

  const MockedDrawer = React.forwardRef((_props: unknown, ref: unknown) => {
    React.useImperativeHandle(ref, () => ({
      openDrawer: mockOpenDrawer,
      closeDrawer: mockCloseDrawer,
    }))

    return React.createElement('div', { 'data-test': 'minimum-commitment-drawer-mock' })
  })

  MockedDrawer.displayName = 'MinimumCommitmentDrawer'

  return { MinimumCommitmentDrawer: MockedDrawer }
})

jest.mock('~/components/premium/PremiumFeature', () => {
  const MockPremiumFeature = (props: { title: string }) => (
    <div data-test="premium-feature">{props.title}</div>
  )

  return { __esModule: true, default: MockPremiumFeature }
})

// --- Helpers ---

const createForm = (overrides: Partial<PlanFormInput> = {}) => createMockPlanForm(overrides)

const defaultProps = {
  form: createForm(),
}

describe('CommitmentsSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockedUseCurrentUser.mockReturnValue({ isPremium: true } as ReturnType<typeof useCurrentUser>)
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the user is premium and no commitment exists', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should render the add button', () => {
        render(<CommitmentsSection {...defaultProps} />)

        expect(screen.getByTestId(ADD_MINIMUM_COMMITMENT_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should render the MinimumCommitmentDrawer', () => {
        render(<CommitmentsSection {...defaultProps} />)

        expect(screen.getByTestId('minimum-commitment-drawer-mock')).toBeInTheDocument()
      })
    })

    describe('WHEN the add button is clicked', () => {
      it('THEN should open the drawer without values (add mode)', async () => {
        const user = userEvent.setup()

        render(<CommitmentsSection {...defaultProps} />)

        await user.click(screen.getByTestId(ADD_MINIMUM_COMMITMENT_TEST_ID))

        expect(mockOpenDrawer).toHaveBeenCalledWith()
      })
    })
  })

  describe('GIVEN a commitment exists', () => {
    const formWithCommitment = createForm({
      minimumCommitment: {
        amountCents: '1000',
        invoiceDisplayName: 'Custom Commitment',
        taxes: [{ id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }],
      },
    })

    describe('WHEN the component is rendered', () => {
      it('THEN should render the Selector card with commitment info', () => {
        render(<CommitmentsSection form={formWithCommitment} />)

        expect(screen.getByTestId(OPEN_MINIMUM_COMMITMENT_DRAWER_TEST_ID)).toBeInTheDocument()
      })

      it('THEN should not render the add button', () => {
        render(<CommitmentsSection form={formWithCommitment} />)

        expect(screen.queryByTestId(ADD_MINIMUM_COMMITMENT_TEST_ID)).not.toBeInTheDocument()
      })
    })

    describe('WHEN the selector is clicked', () => {
      it('THEN should open the drawer with current values', async () => {
        const user = userEvent.setup()

        render(<CommitmentsSection form={formWithCommitment} />)

        await user.click(screen.getByTestId(OPEN_MINIMUM_COMMITMENT_DRAWER_TEST_ID))

        expect(mockOpenDrawer).toHaveBeenCalledWith({
          amountCents: '1000',
          invoiceDisplayName: 'Custom Commitment',
          taxes: [{ id: 'tax-1', code: 'vat', name: 'VAT', rate: 20 }],
        })
      })
    })
  })

  describe('GIVEN the user is not premium', () => {
    beforeEach(() => {
      mockedUseCurrentUser.mockReturnValue({
        isPremium: false,
      } as ReturnType<typeof useCurrentUser>)
    })

    describe('WHEN no commitment exists', () => {
      it('THEN should render the premium feature gate', () => {
        render(<CommitmentsSection {...defaultProps} />)

        expect(screen.getByTestId('premium-feature')).toBeInTheDocument()
      })

      it('THEN should not render the add button', () => {
        render(<CommitmentsSection {...defaultProps} />)

        expect(screen.queryByTestId(ADD_MINIMUM_COMMITMENT_TEST_ID)).not.toBeInTheDocument()
      })
    })
  })
})
