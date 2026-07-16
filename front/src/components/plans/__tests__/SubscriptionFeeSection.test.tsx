import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'
import { createMockPlanForm } from '~/test-utils/createMockPlanForm'

import { SubscriptionFeeSection } from '../SubscriptionFeeSection'
import { PlanFormInput } from '../types'

// --- Mocks ---

jest.mock('~/contexts/PlanFormContext', () => ({
  usePlanFormContext: () => ({
    currency: 'USD',
    interval: 'monthly',
  }),
}))

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
}))

// Mock the SubscriptionFeeDrawer
const mockOpenDrawer = jest.fn()
const mockCloseDrawer = jest.fn()

jest.mock('~/components/plans/drawers/subscriptionFee/SubscriptionFeeDrawer', () => {
  const React = jest.requireActual('react')

  const MockedDrawer = React.forwardRef((_props: unknown, ref: unknown) => {
    React.useImperativeHandle(ref, () => ({
      openDrawer: mockOpenDrawer,
      closeDrawer: mockCloseDrawer,
    }))

    return React.createElement('div', { 'data-test': 'subscription-fee-drawer-mock' })
  })

  MockedDrawer.displayName = 'SubscriptionFeeDrawer'

  return { SubscriptionFeeDrawer: MockedDrawer }
})

// --- Helpers ---

const createForm = (overrides: Partial<PlanFormInput> = {}) => createMockPlanForm(overrides)

const defaultProps = {
  form: createForm(),
}

const getSelector = () => screen.getByRole('button', { name: /\$100/i })

describe('SubscriptionFeeSection', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the component is rendered', () => {
    describe('WHEN default props are provided', () => {
      it('THEN should render the selector with formatted amount', () => {
        render(<SubscriptionFeeSection {...defaultProps} />)

        expect(getSelector()).toBeInTheDocument()
      })

      it('THEN should render the SubscriptionFeeDrawer', () => {
        render(<SubscriptionFeeSection {...defaultProps} />)

        expect(screen.getByTestId('subscription-fee-drawer-mock')).toBeInTheDocument()
      })
    })

    describe('WHEN the selector is clicked', () => {
      it('THEN should open the drawer with current formik values', async () => {
        const user = userEvent.setup()
        const form = createForm({
          amountCents: '250',
          payInAdvance: true,
          trialPeriod: 14,
          invoiceDisplayName: 'Custom Fee',
        })

        render(<SubscriptionFeeSection {...defaultProps} form={form} />)

        await user.click(screen.getByRole('button', { name: /\$250/i }))

        expect(mockOpenDrawer).toHaveBeenCalledWith({
          amountCents: '250',
          payInAdvance: true,
          trialPeriod: 14,
          invoiceDisplayName: 'Custom Fee',
        })
      })
    })

    describe('WHEN formik values have no trialPeriod', () => {
      it('THEN should default to 0 when drawer is opened', async () => {
        const user = userEvent.setup()
        const form = createForm({
          trialPeriod: undefined as unknown as number,
        })

        render(<SubscriptionFeeSection {...defaultProps} form={form} />)

        await user.click(getSelector())

        expect(mockOpenDrawer).toHaveBeenCalledWith(
          expect.objectContaining({
            trialPeriod: 0,
          }),
        )
      })
    })

    describe('WHEN formik trialPeriod is 0', () => {
      it('THEN should preserve 0 as a number instead of converting to undefined', async () => {
        const user = userEvent.setup()
        const form = createForm({ trialPeriod: 0 })

        render(<SubscriptionFeeSection {...defaultProps} form={form} />)

        await user.click(getSelector())

        expect(mockOpenDrawer).toHaveBeenCalledWith(
          expect.objectContaining({
            trialPeriod: 0,
          }),
        )
      })
    })
  })

  describe('GIVEN the section has validation errors', () => {
    describe('WHEN amountCents has an error', () => {
      it('THEN should still render the section', () => {
        const form = createForm()

        render(<SubscriptionFeeSection {...defaultProps} form={form} />)

        expect(getSelector()).toBeInTheDocument()
      })
    })
  })
})
