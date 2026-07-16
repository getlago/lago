import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'
import { GraphQLError } from 'graphql'
import { DateTime } from 'luxon'
import { ReactNode } from 'react'

import {
  BillingTimeEnum,
  PlanInterval,
  StatusTypeEnum,
  SubscriptionForSubscriptionEditFormFragment,
  UpdateSubscriptionDocument,
} from '~/generated/graphql'

import { useUpdateSubscriptionInformation } from '../useUpdateSubscriptionInformation'

const mockAddToast = jest.fn()

jest.mock('~/core/apolloClient', () => ({
  ...jest.requireActual('~/core/apolloClient'),
  addToast: (...args: unknown[]) => mockAddToast(...args),
}))

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (key: string) => key }),
}))

const subscription = {
  id: 'sub-1',
  name: 'My subscription',
  externalId: 'ext-1',
  subscriptionAt: '2026-01-01',
  endingAt: null,
  billingTime: BillingTimeEnum.Calendar,
  periodEndDate: null,
  status: StatusTypeEnum.Active,
  startedAt: '2026-01-01',
  paymentMethodType: null,
  paymentMethod: null,
  consolidateInvoice: true,
  skipInvoiceCustomSections: false,
  selectedInvoiceCustomSections: [],
  plan: { id: 'plan-1', parent: null, name: 'P', code: 'p', interval: PlanInterval.Monthly },
} as unknown as SubscriptionForSubscriptionEditFormFragment

const expectedInput = {
  id: 'sub-1',
  name: 'My subscription',
  subscriptionAt: DateTime.fromISO('2026-01-01').toUTC().toISO(),
  endingAt: null,
}

const renderUpdateHook = (mocks: MockedResponse[], onSuccess: () => void) => {
  const wrapper = ({ children }: { children: ReactNode }) => (
    <MockedProvider mocks={mocks} addTypename={false}>
      {children}
    </MockedProvider>
  )

  return renderHook(() => useUpdateSubscriptionInformation({ subscription, onSuccess }), {
    wrapper,
  })
}

describe('useUpdateSubscriptionInformation', () => {
  beforeEach(() => {
    mockAddToast.mockClear()
  })

  it('updates the subscription with the editable fields and fires a success toast', async () => {
    let capturedVariables: Record<string, unknown> | undefined
    const onSuccess = jest.fn()

    const mocks = [
      {
        request: { query: UpdateSubscriptionDocument },
        variableMatcher: (variables: Record<string, unknown>) => {
          capturedVariables = variables

          return true
        },
        result: {
          data: {
            updateSubscription: {
              id: 'sub-1',
              status: StatusTypeEnum.Active,
              startedAt: '2026-01-01',
              subscriptionAt: expectedInput.subscriptionAt,
              endingAt: null,
              name: 'My subscription',
              externalId: 'ext-1',
              paymentMethodType: null,
              paymentMethod: null,
              consolidateInvoice: true,
              skipInvoiceCustomSections: false,
              selectedInvoiceCustomSections: [],
              customer: { id: 'cust-1', activeSubscriptionsCount: 1 },
              plan: { id: 'plan-1', name: 'P', code: 'p', interval: PlanInterval.Monthly },
            },
          },
        },
      },
    ]

    const { result } = renderUpdateHook(mocks, onSuccess)

    await act(async () => {
      await result.current.form.handleSubmit()
    })

    await waitFor(() => expect(mockAddToast).toHaveBeenCalledTimes(1))

    expect(capturedVariables).toEqual({ input: expectedInput })
    expect(mockAddToast).toHaveBeenCalledWith({
      severity: 'success',
      message: 'text_65118a52df984447c186962e',
    })
    expect(onSuccess).toHaveBeenCalledTimes(1)
  })

  it('does not toast or call onSuccess when the mutation errors', async () => {
    const onSuccess = jest.fn()

    const mocks = [
      {
        request: { query: UpdateSubscriptionDocument },
        variableMatcher: () => true,
        result: { errors: [new GraphQLError('boom')] },
      },
    ]

    const { result } = renderUpdateHook(mocks, onSuccess)

    await act(async () => {
      await result.current.form.handleSubmit().catch(() => {})
    })

    expect(mockAddToast).not.toHaveBeenCalled()
    expect(onSuccess).not.toHaveBeenCalled()
  })
})
