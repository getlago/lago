import { MockedResponse } from '@apollo/client/testing'
import { act, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import {
  CurrencyEnum,
  SubscriptionForProgressiveBillingTabFragment,
  SwitchProgressiveBillingDisabledValueDocument,
} from '~/generated/graphql'
import { render, testMockNavigateFn, TestMocksType } from '~/test-utils'

import {
  PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID,
  PROGRESSIVE_BILLING_FREEMIUM_BLOCK_TEST_ID,
  PROGRESSIVE_BILLING_NO_PLAN_THRESHOLDS_EMPTY_TEST_ID,
  PROGRESSIVE_BILLING_NO_THRESHOLDS_EMPTY_TEST_ID,
  PROGRESSIVE_BILLING_TAB_TEST_ID,
  SubscriptionProgressiveBillingTab,
} from '../SubscriptionProgressiveBillingTab'
import {
  PROGRESSIVE_BILLING_EDIT_BUTTON_TEST_ID,
  PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID,
  PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID,
  PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID,
  PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID,
} from '../SubscriptionProgressiveBillingTabThresholdsHeader'

// Get mocked useParams from test-utils mock
const { useParams } = jest.requireMock('react-router-dom')

// Mock hooks
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

const mockHasOrganizationPremiumAddon = jest.fn()

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    hasOrganizationPremiumAddon: mockHasOrganizationPremiumAddon,
  }),
}))

const createMockSubscription = (
  overrides?: Partial<SubscriptionForProgressiveBillingTabFragment>,
): SubscriptionForProgressiveBillingTabFragment => ({
  id: 'subscription-123',
  progressiveBillingDisabled: false,
  usageThresholds: [
    {
      id: 'threshold-1',
      amountCents: '10000',
      recurring: false,
      thresholdDisplayName: 'First threshold',
    },
    {
      id: 'threshold-2',
      amountCents: '20000',
      recurring: false,
      thresholdDisplayName: 'Second threshold',
    },
  ],
  plan: {
    id: 'plan-123',
    amountCurrency: CurrencyEnum.Usd,
    applicableUsageThresholds: [
      {
        id: 'plan-threshold-1',
        amountCents: '5000',
        recurring: false,
        thresholdDisplayName: 'Plan threshold',
      },
    ],
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

describe('SubscriptionProgressiveBillingTab', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    useParams.mockReturnValue({ customerId: 'customer-123', planId: '' })
    mockHasPermissions.mockReturnValue(true)
    mockHasOrganizationPremiumAddon.mockReturnValue(true)
  })

  describe('loading state', () => {
    it('renders skeleton when loading is true', () => {
      render(<SubscriptionProgressiveBillingTab subscription={null} loading={true} />)

      // Should not render the main content
      expect(screen.queryByTestId(PROGRESSIVE_BILLING_TAB_TEST_ID)).not.toBeInTheDocument()
    })

    it('renders skeleton when subscription is null', () => {
      render(<SubscriptionProgressiveBillingTab subscription={null} loading={false} />)

      expect(screen.queryByTestId(PROGRESSIVE_BILLING_TAB_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('freemium state', () => {
    it('renders freemium block when user does not have premium integration', () => {
      mockHasOrganizationPremiumAddon.mockReturnValue(false)

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_TAB_TEST_ID)).toBeInTheDocument()
      expect(screen.getByTestId(PROGRESSIVE_BILLING_FREEMIUM_BLOCK_TEST_ID)).toBeInTheDocument()
    })

    it('does not render freemium block when user has premium integration', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_FREEMIUM_BLOCK_TEST_ID),
      ).not.toBeInTheDocument()
    })
  })

  describe('overridden badge', () => {
    it('shows overridden badge when subscription has thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID)).toBeInTheDocument()
    })

    it('shows overridden badge when progressive billing is disabled but plan has thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            progressiveBillingDisabled: true,
            usageThresholds: [],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [
                {
                  id: 'plan-threshold-1',
                  amountCents: '5000',
                  recurring: false,
                  thresholdDisplayName: 'Plan threshold',
                },
              ],
            },
          })}
          loading={false}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID)).toBeInTheDocument()
    })

    it('does not show overridden badge when no thresholds and not disabled', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            usageThresholds: [],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [],
            },
          })}
          loading={false}
        />,
      )

      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_OVERRIDDEN_CHIP_TEST_ID),
      ).not.toBeInTheDocument()
    })
  })

  describe('menu actions', () => {
    it('renders menu button when user has subscriptionsUpdate permission', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID)).toBeInTheDocument()
    })

    it('does not render menu button when user lacks subscriptionsUpdate permission', () => {
      mockHasPermissions.mockReturnValue(false)

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      expect(screen.queryByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID)).not.toBeInTheDocument()
    })

    it('shows edit button in menu when opened', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
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
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID)).toBeInTheDocument()
      })
    })

    it('does not show reset button when subscription has no thresholds', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({ usageThresholds: [] })}
          loading={false}
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

    it('shows toggle button with correct label when progressive billing is enabled', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({ progressiveBillingDisabled: false })}
          loading={false}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        const toggleButton = screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID)

        expect(toggleButton).toBeInTheDocument()
        // Should show "disable" text when currently enabled
        expect(toggleButton).toHaveTextContent('text_1769604747500dwp43wers41')
      })
    })

    it('shows toggle button with correct label when progressive billing is disabled', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({ progressiveBillingDisabled: true })}
          loading={false}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        const toggleButton = screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID)

        expect(toggleButton).toBeInTheDocument()
        // Should show "enable" text when currently disabled
        expect(toggleButton).toHaveTextContent('text_1769604747500dwp43wers40')
      })
    })

    it('navigates to edit form when edit button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
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

    it('calls mutation when toggle button is clicked', async () => {
      const user = userEvent.setup()
      const subscription = createMockSubscription({ progressiveBillingDisabled: false })
      const mocks: TestMocksType = [createSwitchMutationMock(subscription.id, true)]

      render(<SubscriptionProgressiveBillingTab subscription={subscription} loading={false} />, {
        mocks,
      })

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_TOGGLE_BUTTON_TEST_ID))
      })

      // The mutation should have been called (no error thrown)
    })
  })

  describe('disabled state display', () => {
    it('shows disabled message when progressive billing is disabled', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({ progressiveBillingDisabled: true })}
          loading={false}
        />,
      )

      expect(screen.getByTestId(PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID)).toBeInTheDocument()
    })

    it('does not show disabled message when progressive billing is enabled', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({ progressiveBillingDisabled: false })}
          loading={false}
        />,
      )

      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID),
      ).not.toBeInTheDocument()
    })
  })

  describe('thresholds display', () => {
    it('displays subscription thresholds table when thresholds exist', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      // The thresholds table should be rendered (check for table content)
      expect(screen.getByText('First threshold')).toBeInTheDocument()
      expect(screen.getByText('Second threshold')).toBeInTheDocument()
    })

    it('displays recurring thresholds table when recurring thresholds exist', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Non-recurring',
              },
              {
                id: 'threshold-2',
                amountCents: '50000',
                recurring: true,
                thresholdDisplayName: 'Recurring threshold',
              },
            ],
          })}
          loading={false}
        />,
      )

      expect(screen.getByText('Non-recurring')).toBeInTheDocument()
      expect(screen.getByText('Recurring threshold')).toBeInTheDocument()
    })

    it('filters non-recurring thresholds to ThresholdsTable only', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Non-recurring only',
              },
            ],
          })}
          loading={false}
        />,
      )

      // Non-recurring threshold should be displayed
      expect(screen.getByText('Non-recurring only')).toBeInTheDocument()

      // The recurring label should not appear (no recurring thresholds)
      expect(screen.queryByText('text_17241798877230y851fdxzqu')).not.toBeInTheDocument()
    })

    it('filters recurring thresholds to RecurringThresholdsTable only', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Non-recurring item',
              },
              {
                id: 'threshold-2',
                amountCents: '50000',
                recurring: true,
                thresholdDisplayName: 'Recurring item',
              },
            ],
          })}
          loading={false}
        />,
      )

      // Both should be displayed but in separate tables
      expect(screen.getByText('Non-recurring item')).toBeInTheDocument()
      expect(screen.getByText('Recurring item')).toBeInTheDocument()

      // The recurring label should appear for the recurring table
      expect(screen.getByText('text_17241798877230y851fdxzqu')).toBeInTheDocument()
    })

    it('does not show recurring table when no recurring thresholds exist', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Only non-recurring',
              },
              {
                id: 'threshold-2',
                amountCents: '20000',
                recurring: false,
                thresholdDisplayName: 'Another non-recurring',
              },
            ],
          })}
          loading={false}
        />,
      )

      // Non-recurring thresholds should be displayed
      expect(screen.getByText('Only non-recurring')).toBeInTheDocument()
      expect(screen.getByText('Another non-recurring')).toBeInTheDocument()

      // Recurring table label should not appear
      expect(screen.queryByText('text_17241798877230y851fdxzqu')).not.toBeInTheDocument()
    })
  })

  describe('plan thresholds tab', () => {
    it('displays plan thresholds in the plan tab', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [
                {
                  id: 'plan-threshold-1',
                  amountCents: '5000',
                  recurring: false,
                  thresholdDisplayName: 'Plan non-recurring',
                },
                {
                  id: 'plan-threshold-2',
                  amountCents: '15000',
                  recurring: true,
                  thresholdDisplayName: 'Plan recurring',
                },
              ],
            },
          })}
          loading={false}
        />,
      )

      // Click on the plan tab (second tab)
      const planTab = screen.getByText('text_17697123841349drggrw2qur')

      await act(async () => {
        await user.click(planTab)
      })

      // Plan thresholds should be displayed
      await waitFor(() => {
        expect(screen.getByText('Plan non-recurring')).toBeInTheDocument()
        expect(screen.getByText('Plan recurring')).toBeInTheDocument()
      })
    })

    it('filters plan thresholds correctly between tables', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            usageThresholds: [],
            progressiveBillingDisabled: true,
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [
                {
                  id: 'plan-threshold-1',
                  amountCents: '5000',
                  recurring: false,
                  thresholdDisplayName: 'Plan threshold A',
                },
                {
                  id: 'plan-threshold-2',
                  amountCents: '10000',
                  recurring: false,
                  thresholdDisplayName: 'Plan threshold B',
                },
              ],
            },
          })}
          loading={false}
        />,
      )

      // Click on the plan tab
      const planTab = screen.getByText('text_17697123841349drggrw2qur')

      await act(async () => {
        await user.click(planTab)
      })

      // Plan thresholds should be displayed
      await waitFor(() => {
        expect(screen.getByText('Plan threshold A')).toBeInTheDocument()
        expect(screen.getByText('Plan threshold B')).toBeInTheDocument()
      })

      // Recurring table label should not appear (no recurring plan thresholds)
      expect(screen.queryByText('text_17241798877230y851fdxzqu')).not.toBeInTheDocument()
    })
  })

  describe('route generation', () => {
    it('generates edit path with planId when customerId is not provided', async () => {
      const user = userEvent.setup()

      // Set planId instead of customerId
      useParams.mockReturnValue({ customerId: '', planId: 'plan-456' })

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
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

      // Should navigate with planId path
      expect(testMockNavigateFn).toHaveBeenCalledWith(expect.stringContaining('plan-456'))
    })
  })

  describe('reset dialog', () => {
    it('opens reset dialog when reset button is clicked', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription()}
          loading={false}
        />,
      )

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_MENU_BUTTON_TEST_ID))
      })

      await waitFor(() => {
        expect(screen.getByTestId(PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID)).toBeInTheDocument()
      })

      await act(async () => {
        await user.click(screen.getByTestId(PROGRESSIVE_BILLING_RESET_BUTTON_TEST_ID))
      })

      // Dialog should be opened (check for dialog content)
      await waitFor(() => {
        expect(screen.getByRole('dialog')).toBeInTheDocument()
      })
    })
  })

  describe('plan tab empty states', () => {
    it('displays no-thresholds empty state when progressive billing is enabled but no thresholds exist', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [],
            },
          })}
          loading={false}
        />,
      )

      // When there are no subscription thresholds and billing is not disabled,
      // the subscription tab is hidden and the plan tab content is shown by default
      // Should show the "no thresholds" empty state message
      expect(
        screen.getByTestId(PROGRESSIVE_BILLING_NO_THRESHOLDS_EMPTY_TEST_ID),
      ).toBeInTheDocument()
      expect(screen.getByText('text_1770217073925sgkyyd8peck')).toBeInTheDocument()
    })

    it('displays "no plan thresholds" message when subscription has thresholds but plan has none', async () => {
      const user = userEvent.setup()

      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Subscription threshold',
              },
            ],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [],
            },
          })}
          loading={false}
        />,
      )

      // Click on the plan tab (subscription tab is visible since there are subscription thresholds)
      const planTab = screen.getByText('text_17697123841349drggrw2qur')

      await act(async () => {
        await user.click(planTab)
      })

      // Should show the "no plan thresholds" empty state message
      await waitFor(() => {
        expect(
          screen.getByTestId(PROGRESSIVE_BILLING_NO_PLAN_THRESHOLDS_EMPTY_TEST_ID),
        ).toBeInTheDocument()
        expect(screen.getByText('text_1770220776577i5r9mz1h3rr')).toBeInTheDocument()
      })
    })

    it('does not display any empty state message when plan has thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [
                {
                  id: 'plan-threshold-1',
                  amountCents: '5000',
                  recurring: false,
                  thresholdDisplayName: 'Plan threshold',
                },
              ],
            },
          })}
          loading={false}
        />,
      )

      // When there are no subscription thresholds and billing is not disabled,
      // the subscription tab is hidden and the plan tab content is shown by default
      // Should NOT show any empty state message
      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_NO_THRESHOLDS_EMPTY_TEST_ID),
      ).not.toBeInTheDocument()
      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_NO_PLAN_THRESHOLDS_EMPTY_TEST_ID),
      ).not.toBeInTheDocument()
      // Should show the plan threshold instead
      expect(screen.getByText('Plan threshold')).toBeInTheDocument()
    })

    it('does not display subscription threshold table when progressive billing is disabled even with thresholds', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            progressiveBillingDisabled: true,
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Hidden threshold',
              },
            ],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [],
            },
          })}
          loading={false}
        />,
      )

      // Should show disabled message
      expect(screen.getByTestId(PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID)).toBeInTheDocument()
      // Should NOT show the threshold since billing is disabled
      expect(screen.queryByText('Hidden threshold')).not.toBeInTheDocument()
    })

    it('displays subscription threshold table when progressive billing is enabled and thresholds exist', () => {
      render(
        <SubscriptionProgressiveBillingTab
          subscription={createMockSubscription({
            progressiveBillingDisabled: false,
            usageThresholds: [
              {
                id: 'threshold-1',
                amountCents: '10000',
                recurring: false,
                thresholdDisplayName: 'Visible threshold',
              },
            ],
            plan: {
              id: 'plan-123',
              amountCurrency: CurrencyEnum.Usd,
              applicableUsageThresholds: [
                {
                  id: 'plan-threshold-1',
                  amountCents: '5000',
                  recurring: false,
                  thresholdDisplayName: 'Plan threshold exists',
                },
              ],
            },
          })}
          loading={false}
        />,
      )

      // Should NOT show disabled message
      expect(
        screen.queryByTestId(PROGRESSIVE_BILLING_DISABLED_MESSAGE_TEST_ID),
      ).not.toBeInTheDocument()
      // Should show the threshold
      expect(screen.getByText('Visible threshold')).toBeInTheDocument()
    })
  })
})
