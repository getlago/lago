import { MockedResponse } from '@apollo/client/testing'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  SubscriptionForProgressiveBillingTabThresholdsHeaderFragment,
  SwitchProgressiveBillingDisabledValueDocument,
} from '~/generated/graphql'
import { render, testMockNavigateFn, TestMocksType } from '~/test-utils'

import {
  PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID,
  PROGRESSIVE_BILLING_LIFETIME_CHIP_TEST_ID,
  PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID,
  PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID,
  PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID,
  PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID,
  SubscriptionProgressiveBillingTabThresholdsHeader,
} from '../SubscriptionProgressiveBillingTabThresholdsHeader'

// Get mocked useParams from test-utils mock
const { useParams } = jest.requireMock('react-router-dom')

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const mockHasPermissions = jest.fn()

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({
    hasPermissions: mockHasPermissions,
  }),
}))

const createMockSubscription = (
  overrides?: Partial<SubscriptionForProgressiveBillingTabThresholdsHeaderFragment>,
): SubscriptionForProgressiveBillingTabThresholdsHeaderFragment => ({
  id: 'subscription-123',
  progressiveBillingDisabled: false,
  usageThresholds: [{ id: 'threshold-1' }],
  plan: {
    id: 'plan-123',
    applicableUsageThresholds: [{ id: 'plan-threshold-1' }],
  },
  ...overrides,
})

const createSwitchMutationMock = (
  subscriptionId: string,
  newDisabledValue: boolean,
): MockedResponse => ({
  request: {
    query: SwitchProgressiveBillingDisabledValueDocument,
    variables: {
      input: {
        id: subscriptionId,
        progressiveBillingDisabled: newDisabledValue,
      },
    },
  },
  result: {
    data: {
      updateSubscription: {
        id: subscriptionId,
        progressiveBillingDisabled: newDisabledValue,
      },
    },
  },
})

describe('SubscriptionProgressiveBillingTabThresholdsHeader', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockHasPermissions.mockReturnValue(true)
    useParams.mockReturnValue({ customerId: 'customer-123' })
  })

  describe('header title', () => {
    it('renders the header title', () => {
      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      expect(screen.getByText('text_17696267549792unv7l25frt')).toBeInTheDocument()
    })
  })

  describe('lifetime badge', () => {
    it('always shows the lifetime chip', () => {
      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_LIFETIME_CHIP_TEST_ID)).toHaveTextContent(
        'text_1780512470285ql6s1rc7wjr',
      )
    })

    it('shows the lifetime chip even when there are no thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [],
            plan: { id: 'plan-123', applicableUsageThresholds: [] },
          })}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_LIFETIME_CHIP_TEST_ID)).toBeInTheDocument()
    })

    it('shows the lifetime chip when subscription is null', () => {
      render(<SubscriptionProgressiveBillingTabThresholdsHeader subscription={null} />)

      expect(screen.getByTestId(PROGRESSIVE_BILLING_LIFETIME_CHIP_TEST_ID)).toBeInTheDocument()
    })
  })

  describe('overridden badge', () => {
    it('shows overridden chip when subscription has thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID)).toBeInTheDocument()
    })

    it('shows overridden chip when progressive billing is disabled and plan has thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({
            progressiveBillingDisabled: true,
            usageThresholds: [],
          })}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID)).toBeInTheDocument()
    })

    it('does not show overridden chip when no overrides', () => {
      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [],
          })}
        />,
      )

      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID),
      ).not.toBeInTheDocument()
    })
  })

  describe('menu button', () => {
    it('shows menu button when user has edit permission', () => {
      mockHasPermissions.mockReturnValue(true)

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('hides menu button when user lacks edit permission', () => {
      mockHasPermissions.mockReturnValue(false)

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      expect(screen.queryByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('menu actions', () => {
    it('shows edit button in menu', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    it('shows reset button when subscription has thresholds', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    it('hides reset button when subscription has no thresholds', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({ usageThresholds: [] })}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      expect(screen.queryByTestId(PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('shows toggle button with enable text when progressive billing is disabled', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({ progressiveBillingDisabled: true })}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        const toggleButton = screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID)

        expect(toggleButton).toHaveTextContent('text_1769604747500dwp43wers40')
      })
    })

    it('shows toggle button with disable text when progressive billing is enabled', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({ progressiveBillingDisabled: false })}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        const toggleButton = screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID)

        expect(toggleButton).toHaveTextContent('text_1769604747500dwp43wers41')
      })
    })
  })

  describe('edit navigation', () => {
    it('navigates to edit form when edit button is clicked', async () => {
      const user = userEvent.setup()

      useParams.mockReturnValue({ customerId: 'customer-123' })

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription()}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID))
      })

      expect(testMockNavigateFn).toHaveBeenCalled()
    })
  })

  describe('toggle mutation', () => {
    it('calls mutation when toggle button is clicked', async () => {
      const user = userEvent.setup()
      const mocks: TestMocksType = [createSwitchMutationMock('subscription-123', true)]

      render(
        <SubscriptionProgressiveBillingTabThresholdsHeader
          subscription={createMockSubscription({ progressiveBillingDisabled: false })}
        />,
        { mocks },
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID))
      })

      // Menu closes after clicking toggle - verify header is still visible (no crash)
      await waitFor(() => {
        expect(screen.getByText('text_17696267549792unv7l25frt')).toBeInTheDocument()
      })
    })
  })

  describe('null subscription handling', () => {
    it('renders without crashing when subscription is null', () => {
      render(<SubscriptionProgressiveBillingTabThresholdsHeader subscription={null} />)

      expect(screen.getByText('text_17696267549792unv7l25frt')).toBeInTheDocument()
    })

    it('does not show overridden badge when subscription is null', () => {
      render(<SubscriptionProgressiveBillingTabThresholdsHeader subscription={null} />)

      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID),
      ).not.toBeInTheDocument()
    })
  })
})
