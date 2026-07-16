import { screen, within } from '@testing-library/react'

import {
  BillingTimeEnum,
  StatusTypeEnum,
  SubscriptionInformationFieldsFragment,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionInformationFields } from '../SubscriptionInformationFields'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    intlFormatDateTimeOrgaTZ: (dateStr: string | null | undefined) => ({
      date: `formatted-${dateStr}`,
      time: '',
      timezone: '',
    }),
    hasFeatureFlag: () => false,
  }),
}))

const baseSubscription = (
  overrides: Partial<SubscriptionInformationFieldsFragment> = {},
): SubscriptionInformationFieldsFragment =>
  ({
    id: 'sub-1',
    externalId: 'ext-1',
    status: StatusTypeEnum.Active,
    startedAt: '2026-01-15',
    subscriptionAt: '2026-01-01',
    endingAt: null,
    terminatedAt: null,
    billingTime: BillingTimeEnum.Calendar,
    downgradePlanDate: null,
    nextSubscriptionAt: null,
    nextSubscriptionType: null,
    nextPlan: null,
    previousPlan: null,
    previousSubscription: null,
    customer: {
      id: 'cust-1',
      name: 'Acme',
      displayName: 'Acme',
      externalId: 'cust-ext-1',
      deletedAt: null,
    },
    plan: { id: 'plan-1', name: 'Current', parent: null },
    ...overrides,
  }) as SubscriptionInformationFieldsFragment

describe('SubscriptionInformationFields', () => {
  // "Start date" label key and the new "Billing anchor date" label key
  const START_DATE_LABEL = 'text_65201c5a175a4b0238abf29e'
  const BILLING_ANCHOR_LABEL = 'text_1781859135627z59hpfpa8pt'

  const getValueUnderLabel = (labelKey: string) =>
    within(screen.getByText(labelKey).parentElement as HTMLElement)

  it('renders the external id, customer name and the start date from startedAt', () => {
    render(<SubscriptionInformationFields subscription={baseSubscription()} />)

    expect(screen.getByText('ext-1')).toBeInTheDocument()
    expect(screen.getByText('Acme')).toBeInTheDocument()
    // "Start date" shows startedAt; the billing anchor (subscriptionAt) keeps its own label
    expect(
      getValueUnderLabel(START_DATE_LABEL).getByText('formatted-2026-01-15'),
    ).toBeInTheDocument()
    expect(
      getValueUnderLabel(BILLING_ANCHOR_LABEL).getByText('formatted-2026-01-01'),
    ).toBeInTheDocument()
    // status label
    expect(screen.getByText('text_1780604419477p7xvwx52oad')).toBeInTheDocument()
  })

  it('shows the upgraded version start date under "Start date" and keeps the original billing anchor under its own label', () => {
    // Upgrade scenario: started_at advances to the new version, subscription_at keeps the anchor
    render(
      <SubscriptionInformationFields
        subscription={baseSubscription({ startedAt: '2026-03-15', subscriptionAt: '2026-01-01' })}
      />,
    )

    expect(
      getValueUnderLabel(START_DATE_LABEL).getByText('formatted-2026-03-15'),
    ).toBeInTheDocument()
    expect(
      getValueUnderLabel(BILLING_ANCHOR_LABEL).getByText('formatted-2026-01-01'),
    ).toBeInTheDocument()
  })

  it('shows "-" for the end date when the subscription is active without an ending date', () => {
    render(<SubscriptionInformationFields subscription={baseSubscription()} />)

    expect(screen.getByText('-')).toBeInTheDocument()
  })

  it('renders the ending date when set on an active subscription', () => {
    render(
      <SubscriptionInformationFields subscription={baseSubscription({ endingAt: '2026-03-15' })} />,
    )

    expect(screen.getByText('formatted-2026-03-15')).toBeInTheDocument()
  })

  it('renders the terminated date when the subscription is terminated', () => {
    render(
      <SubscriptionInformationFields
        subscription={baseSubscription({
          status: StatusTypeEnum.Terminated,
          terminatedAt: '2026-02-20',
        })}
      />,
    )

    expect(screen.getByText('formatted-2026-02-20')).toBeInTheDocument()
  })

  it('renders the parent-plan field only when the plan has a parent', () => {
    const { rerender } = render(<SubscriptionInformationFields subscription={baseSubscription()} />)

    expect(screen.queryByText('text_65201c5a175a4b0238abf2a2')).not.toBeInTheDocument()

    rerender(
      <SubscriptionInformationFields
        subscription={baseSubscription({
          plan: { id: 'plan-1', name: 'Override', parent: { id: 'plan-0', name: 'Parent plan' } },
        })}
      />,
    )

    expect(screen.getByText('text_65201c5a175a4b0238abf2a2')).toBeInTheDocument()
    expect(screen.getByText('Parent plan')).toBeInTheDocument()
  })

  it('renders the deleted suffix and removes the customer link for a deleted customer', () => {
    render(
      <SubscriptionInformationFields
        subscription={baseSubscription({
          customer: {
            id: 'cust-1',
            name: 'Acme',
            displayName: 'Acme',
            externalId: 'cust-ext-1',
            deletedAt: '2026-01-02',
            billingEntity: {
              __typename: undefined,
              id: '',
              code: '',
              name: '',
            },
          },
        })}
      />,
    )

    expect(screen.getByText('Acme text_1764874328964clrgkmh7i9h')).toBeInTheDocument()
  })
})
