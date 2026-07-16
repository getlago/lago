import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'
import { ReactNode } from 'react'

import { addToast } from '~/core/apolloClient'
import { UpdatePlanDocument, UpdatePlanInput } from '~/generated/graphql'

import { usePlanUpdate } from '../usePlanUpdate'

jest.mock('~/core/apolloClient', () => {
  const actual = jest.requireActual('~/core/apolloClient')

  return { ...actual, addToast: jest.fn() }
})

const wrapper = (mocks: MockedResponse[]) =>
  function MockedWrapper({ children }: { children: ReactNode }) {
    return (
      <MockedProvider mocks={mocks} addTypename={false}>
        {children}
      </MockedProvider>
    )
  }

const PLAN_ID = 'plan_1'

const mutationInput = { id: PLAN_ID, name: 'X' } as unknown as UpdatePlanInput

const updateMock: MockedResponse = {
  request: {
    query: UpdatePlanDocument,
    variables: { input: mutationInput },
  },
  result: {
    data: { updatePlan: { __typename: 'Plan', id: PLAN_ID, name: 'X' } },
  },
}

describe('usePlanUpdate', () => {
  beforeEach(() => {
    ;(addToast as jest.Mock).mockClear()
  })

  it('fires the success toast and onSuccess callback when the mutation completes', async () => {
    const onSuccess = jest.fn()
    const { result } = renderHook(() => usePlanUpdate({ onSuccess }), {
      wrapper: wrapper([updateMock]),
    })

    await act(async () => {
      await result.current.update({ variables: { input: mutationInput } })
    })

    await waitFor(() => {
      expect(addToast).toHaveBeenCalledWith({
        severity: 'success',
        translateKey: 'text_625fd165963a7b00c8f598a0',
      })
    })

    expect(onSuccess).toHaveBeenCalledTimes(1)
    expect(onSuccess).toHaveBeenCalledWith(expect.objectContaining({ id: PLAN_ID }))
  })
})
