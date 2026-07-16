import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'
import { ReactNode } from 'react'

import { LocalUsageChargeInput } from '~/components/plans/types'
import {
  ChargeModelEnum,
  CurrencyEnum,
  UpdateSubscriptionChargeDocument,
} from '~/generated/graphql'

import { useSubscriptionChargeMutations } from '../useSubscriptionChargeMutations'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))

const SUB_ID = 'sub_1'

const buildCharge = (overrides: Partial<LocalUsageChargeInput> = {}): LocalUsageChargeInput =>
  ({
    id: 'ch_1',
    code: 'api_calls',
    chargeModel: ChargeModelEnum.Standard,
    invoiceDisplayName: 'API',
    invoiceable: true,
    payInAdvance: false,
    prorated: false,
    minAmountCents: '0',
    regroupPaidFees: null,
    properties: { amount: '12' },
    filters: [],
    taxes: [],
    billableMetric: { id: 'bm_1', code: 'api_calls' },
    ...overrides,
  }) as unknown as LocalUsageChargeInput

const wrapper = (mocks: MockedResponse[]) =>
  function W({ children }: { children: ReactNode }) {
    return (
      <MockedProvider mocks={mocks} addTypename={false}>
        {children}
      </MockedProvider>
    )
  }

describe('useSubscriptionChargeMutations', () => {
  it('fires updateSubscriptionCharge with subscriptionId + chargeCode', async () => {
    let called = false
    const updateMock: MockedResponse = {
      request: { query: UpdateSubscriptionChargeDocument },
      variableMatcher: (vars) =>
        vars?.input?.subscriptionId === SUB_ID && vars?.input?.chargeCode === 'api_calls',
      result: () => {
        called = true
        return { data: { updateSubscriptionCharge: { __typename: 'Charge', id: 'ch_override_1' } } }
      },
    }

    const { result } = renderHook(
      () => useSubscriptionChargeMutations({ subscriptionId: SUB_ID, currency: CurrencyEnum.Usd }),
      { wrapper: wrapper([updateMock]) },
    )

    await act(async () => {
      await result.current.handleSaveCharge(buildCharge())
    })

    await waitFor(() => expect(called).toBe(true))
  })
})
