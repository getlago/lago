import { fireEvent, screen } from '@testing-library/react'

import {
  BillingTimeEnum,
  StatusTypeEnum,
  SubscriptionInformationSectionFragment,
} from '~/generated/graphql'
import { render } from '~/test-utils'

import { SubscriptionInformationSection } from '../SubscriptionInformationSection'

const mockOpenDrawer = jest.fn()

// Mock the drawer hook: the section's only job is to wire the Edit action to it.
// The drawer's own behaviour is covered in useSubscriptionInformationDrawer.test.
jest.mock('../drawers/useSubscriptionInformationDrawer', () => ({
  useSubscriptionInformationDrawer: () => ({ openDrawer: mockOpenDrawer }),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
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

let mockHasPermission = true

jest.mock('~/hooks/usePermissions', () => ({
  usePermissions: () => ({ hasPermissions: () => mockHasPermission }),
}))

const subscription = {
  id: 'sub-1',
  externalId: 'ext-1',
  status: StatusTypeEnum.Active,
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
  name: 'My subscription',
  customer: {
    id: 'cust-1',
    name: 'Acme',
    displayName: 'Acme',
    externalId: 'cust-ext-1',
    deletedAt: null,
    applicableTimezone: null,
  },
  plan: { id: 'plan-1', name: 'Current', interval: null, parent: null },
} as unknown as SubscriptionInformationSectionFragment

describe('SubscriptionInformationSection', () => {
  beforeEach(() => {
    mockOpenDrawer.mockClear()
    mockHasPermission = true
  })

  it('renders the read-only subscription information fields', () => {
    render(<SubscriptionInformationSection subscription={subscription} />)

    expect(screen.getByText('text_6335e8900c69f8ebdfef5312')).toBeInTheDocument() // title
    expect(screen.getByText('ext-1')).toBeInTheDocument()
    expect(screen.getByText('Acme')).toBeInTheDocument()
    expect(screen.getByText('formatted-2026-01-01')).toBeInTheDocument()
  })

  it('opens the edit drawer when the Edit action is clicked', () => {
    render(<SubscriptionInformationSection subscription={subscription} />)

    fireEvent.click(screen.getByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }))

    expect(mockOpenDrawer).toHaveBeenCalledTimes(1)
  })

  it('hides the Edit action without the subscriptionsUpdate permission', () => {
    mockHasPermission = false

    render(<SubscriptionInformationSection subscription={subscription} />)

    expect(
      screen.queryByRole('button', { name: 'text_63e51ef4985f0ebd75c212fc' }),
    ).not.toBeInTheDocument()
  })
})
