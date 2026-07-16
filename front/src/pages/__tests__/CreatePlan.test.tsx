import type { AnyFormApi } from '@tanstack/react-form'
import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render, testMockNavigateFn } from '~/test-utils'
import { createMockPlanForm } from '~/test-utils/createMockPlanForm'

import CreatePlan from '../CreatePlan'

// Initialize cached form (reset in beforeEach)

// --- Mocks ---

const mockSetFieldValue = jest.fn()
const mockHandleSubmit = jest.fn()

let mockIsEdition = false
let mockLoading = false
let mockPlan: Record<string, unknown> | undefined
let mockType = 'creation'

let mockCachedForm: any

jest.mock('~/hooks/plans/usePlanForm', () => ({
  usePlanForm: () => {
    mockCachedForm.setFieldValue = mockSetFieldValue
    mockCachedForm.handleSubmit = mockHandleSubmit

    return {
      form: mockCachedForm,
      isEdition: mockIsEdition,
      loading: mockLoading,
      plan: mockPlan,
      type: mockType,
    }
  },
}))

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  useDuplicatePlanVar: () => ({ type: mockType }),
}))

jest.mock('~/core/apolloClient/reactiveVars/duplicatePlanVar', () => ({
  ...jest.requireActual('~/core/apolloClient/reactiveVars/duplicatePlanVar'),
  useDuplicatePlanVar: () => ({ type: mockType }),
}))

// Mock all child sections to isolate CreatePlan logic
let capturedPlanSettingsProps: Record<string, unknown> | undefined

jest.mock('~/components/plans/PlanSettingsSection', () => {
  const React = jest.requireActual('react')

  return {
    PlanSettingsSection: (props: Record<string, unknown>) => {
      capturedPlanSettingsProps = props

      return React.createElement('div', { 'data-test': 'plan-settings-section-mock' }, [
        React.createElement('input', { key: 'name', 'data-test': 'mock-plan-name-input' }),
      ])
    },
  }
})

jest.mock('~/components/plans/SubscriptionFeeSection', () => {
  const React = jest.requireActual('react')

  return {
    SubscriptionFeeSection: (props: { form: Pick<AnyFormApi, 'setFieldValue'> }) =>
      React.createElement(
        'div',
        { 'data-test': 'subscription-fee-section-mock' },
        React.createElement(
          'button',
          {
            'data-test': 'trigger-subscription-fee-save',
            onClick: () => {
              // Simulate drawer save writing to form
              props.form.setFieldValue('amountCents', '500')
              props.form.setFieldValue('payInAdvance', true)
              props.form.setFieldValue('trialPeriod', 7)
              props.form.setFieldValue('invoiceDisplayName', 'Sub Fee')
            },
          },
          'Save Fee',
        ),
      ),
  }
})

jest.mock('~/components/plans/form/FixedChargesSection', () => {
  const React = jest.requireActual('react')

  return {
    FixedChargesSection: () =>
      React.createElement('div', { 'data-test': 'fixed-charges-section-mock' }),
  }
})

jest.mock('~/components/plans/UsageChargesSection', () => {
  const React = jest.requireActual('react')

  return {
    UsageChargesSection: () =>
      React.createElement('div', { 'data-test': 'usage-charges-section-mock' }),
  }
})

jest.mock('~/components/plans/ProgressiveBillingSection', () => {
  const React = jest.requireActual('react')

  return {
    ProgressiveBillingSection: () =>
      React.createElement('div', { 'data-test': 'progressive-billing-section-mock' }),
  }
})

jest.mock('~/components/plans/CommitmentsSection', () => {
  const React = jest.requireActual('react')

  return {
    CommitmentsSection: () =>
      React.createElement('div', { 'data-test': 'commitments-section-mock' }),
  }
})

jest.mock('~/components/plans/FeatureEntitlementSection', () => {
  const React = jest.requireActual('react')

  return {
    FeatureEntitlementSection: () =>
      React.createElement('div', { 'data-test': 'feature-entitlement-section-mock' }),
  }
})

jest.mock('~/components/designSystem/WarningDialog', () => {
  const React = jest.requireActual('react')
  const mockOpenDialog = jest.fn()

  const MockWarningDialog = React.forwardRef((props: { onContinue?: () => void }, ref: unknown) => {
    React.useImperativeHandle(ref, () => ({
      openDialog: () => {
        mockOpenDialog()
        props.onContinue?.()
      },
    }))

    return React.createElement('div', { 'data-test': 'warning-dialog-mock' })
  })

  MockWarningDialog.displayName = 'WarningDialog'

  return { WarningDialog: MockWarningDialog, WarningDialogRef: {} }
})

jest.mock('~/components/plans/details-v2/shared/useCascadeFormDialog', () => ({
  useCascadeFormDialog: () => ({
    openCascadeDialog: jest.fn(),
  }),
}))

jest.mock('~/components/invoices/useEditInvoiceDisplayName', () => ({
  useEditInvoiceDisplayNameDialog: () => ({
    openEditInvoiceDisplayNameDialog: jest.fn(),
  }),
}))

jest.mock('~/styles/mainObjectsForm', () => {
  const React = jest.requireActual('react')

  return {
    FormLoadingSkeleton: ({ id }: { id: string }) =>
      React.createElement('div', { 'data-test': `loading-skeleton-${id}` }),
  }
})

describe('CreatePlan', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockCachedForm = createMockPlanForm()
    mockIsEdition = false
    mockLoading = false
    mockPlan = undefined
    mockType = 'creation'
    capturedPlanSettingsProps = undefined
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  describe('GIVEN the page is loading', () => {
    describe('WHEN the component is rendered', () => {
      it('THEN should display the loading skeleton', () => {
        mockLoading = true

        render(<CreatePlan />)

        expect(screen.getByTestId('loading-skeleton-create-plan')).toBeInTheDocument()
      })

      it('THEN should not display the form sections', () => {
        mockLoading = true

        render(<CreatePlan />)

        expect(screen.queryByTestId('plan-settings-section-mock')).not.toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the page is loaded in creation mode', () => {
    describe('WHEN the component is rendered', () => {
      it.each([
        ['PlanSettingsSection', 'plan-settings-section-mock'],
        ['SubscriptionFeeSection', 'subscription-fee-section-mock'],
        ['FixedChargesSection', 'fixed-charges-section-mock'],
        ['UsageChargesSection', 'usage-charges-section-mock'],
        ['ProgressiveBillingSection', 'progressive-billing-section-mock'],
        ['CommitmentsSection', 'commitments-section-mock'],
        ['FeatureEntitlementSection', 'feature-entitlement-section-mock'],
      ])('THEN should render %s', (_, testId) => {
        render(<CreatePlan />)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })

      it('THEN should render the submit button', () => {
        render(<CreatePlan />)

        expect(screen.getByTestId('submit')).toBeInTheDocument()
      })

      it('THEN should render the close button', () => {
        render(<CreatePlan />)

        expect(screen.getByTestId('close-create-plan-button')).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN the handleSubscriptionFeeSave callback', () => {
    describe('WHEN the subscription fee drawer saves', () => {
      it('THEN should call setValues with the new subscription fee values', async () => {
        const user = userEvent.setup()

        render(<CreatePlan />)

        await user.click(screen.getByTestId('trigger-subscription-fee-save'))

        expect(mockSetFieldValue).toHaveBeenCalledWith('amountCents', '500')
        expect(mockSetFieldValue).toHaveBeenCalledWith('payInAdvance', true)
        expect(mockSetFieldValue).toHaveBeenCalledWith('trialPeriod', 7)
        expect(mockSetFieldValue).toHaveBeenCalledWith('invoiceDisplayName', 'Sub Fee')
      })
    })
  })

  // handleMinimumCommitmentSave and handleEntitlementDrawerSave are now internal to the section components.
  // Their behavior is tested in CommitmentsSection.test.tsx and FeatureEntitlementSection.test.tsx.

  describe('GIVEN the form submission', () => {
    describe('WHEN the submit button is clicked', () => {
      it('THEN should call handleSubmit', async () => {
        const user = userEvent.setup()

        render(<CreatePlan />)

        await user.click(screen.getByTestId('submit'))

        expect(mockHandleSubmit).toHaveBeenCalled()
      })
    })

    describe('WHEN Enter is pressed in an input field', () => {
      it('THEN should submit the form', async () => {
        const user = userEvent.setup()

        render(<CreatePlan />)

        const input = screen.getByTestId('mock-plan-name-input')

        await user.click(input)
        await user.keyboard('{Enter}')

        expect(mockHandleSubmit).toHaveBeenCalled()
      })
    })

    describe('WHEN the form is in edition mode and not dirty', () => {
      it('THEN should disable the submit button', () => {
        mockIsEdition = true

        render(<CreatePlan />)

        expect(screen.getByTestId('submit')).toBeDisabled()
      })
    })
  })

  describe('GIVEN the close button', () => {
    describe('WHEN clicked and the form is not dirty', () => {
      it('THEN should navigate away', async () => {
        const user = userEvent.setup()

        mockPlan = { id: 'plan-123' }

        render(<CreatePlan />)

        await user.click(screen.getByTestId('close-create-plan-button'))

        expect(testMockNavigateFn).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the PlanSettingsSection props', () => {
    describe('WHEN rendered in creation mode', () => {
      it('THEN should pass form to PlanSettingsSection', () => {
        render(<CreatePlan />)

        expect(capturedPlanSettingsProps?.form).toBeDefined()
      })

      it('THEN should not pass errorCode (error is handled via form.setFieldMeta)', () => {
        render(<CreatePlan />)

        expect(capturedPlanSettingsProps?.errorCode).toBeUndefined()
      })
    })
  })

  describe('GIVEN the sticky footer', () => {
    describe('WHEN loading is true and plan is undefined', () => {
      it('THEN should not render the footer buttons', () => {
        mockLoading = true
        mockPlan = undefined

        render(<CreatePlan />)

        expect(screen.queryByTestId('submit')).not.toBeInTheDocument()
      })
    })

    describe('WHEN loading is true but plan exists', () => {
      it('THEN should render the footer buttons', () => {
        mockLoading = true
        mockPlan = { id: 'plan-123' }

        render(<CreatePlan />)

        expect(screen.getByTestId('submit')).toBeInTheDocument()
      })
    })
  })
})
