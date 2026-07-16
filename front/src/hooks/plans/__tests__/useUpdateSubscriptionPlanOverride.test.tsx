import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'
import { GraphQLError } from 'graphql'
import { ReactNode } from 'react'

import { UpdateSubscriptionDocument } from '~/generated/graphql'

import { useUpdateSubscriptionPlanOverride } from '../useUpdateSubscriptionPlanOverride'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))

const SUB_ID = 'sub_1'

const wrapper = (mocks: MockedResponse[]) =>
  function W({ children }: { children: ReactNode }) {
    return (
      // errorPolicy 'all' mirrors the app client: GraphQL errors resolve in
      // `result.errors` rather than throwing.
      <MockedProvider
        mocks={mocks}
        addTypename={false}
        defaultOptions={{ mutate: { errorPolicy: 'all' } }}
      >
        {children}
      </MockedProvider>
    )
  }

describe('useUpdateSubscriptionPlanOverride', () => {
  it('fires updateSubscription with planOverrides and no charges array, and returns true', async () => {
    let captured: Record<string, unknown> | undefined
    const mock: MockedResponse = {
      request: { query: UpdateSubscriptionDocument },
      variableMatcher: (vars) => {
        captured = vars?.input
        return vars?.input?.id === SUB_ID
      },
      result: () => ({ data: { updateSubscription: { id: SUB_ID } } }),
    }

    const { result } = renderHook(
      () => useUpdateSubscriptionPlanOverride({ subscriptionId: SUB_ID }),
      { wrapper: wrapper([mock]) },
    )

    let success: boolean | undefined

    await act(async () => {
      success = await result.current.updatePlanOverride({ description: 'Edited' })
    })

    await waitFor(() => expect(captured).toBeDefined())
    expect(success).toBe(true)
    expect(
      (captured as { planOverrides?: { description?: string } }).planOverrides?.description,
    ).toBe('Edited')
    expect(
      (captured as { planOverrides?: { charges?: unknown } }).planOverrides?.charges,
    ).toBeUndefined()
  })

  it('returns false when the backend rejects the override (drawer must stay open)', async () => {
    const mock: MockedResponse = {
      request: { query: UpdateSubscriptionDocument },
      variableMatcher: () => true,
      result: { errors: [new GraphQLError('Unprocessable entity')] },
    }

    const { result } = renderHook(
      () => useUpdateSubscriptionPlanOverride({ subscriptionId: SUB_ID }),
      { wrapper: wrapper([mock]) },
    )

    let success: boolean | undefined

    await act(async () => {
      success = await result.current.updatePlanOverride({ description: 'Edited' })
    })

    expect(success).toBe(false)
  })
})
