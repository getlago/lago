import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import NiceModal from '@ebay/nice-modal-react'
import { act, renderHook, waitFor } from '@testing-library/react'
import { ReactNode } from 'react'

import { FORM_DIALOG_NAME } from '~/components/dialogs/const'
import FormDialog from '~/components/dialogs/FormDialog'
import { addToast } from '~/core/apolloClient'
import {
  CommitmentTypeEnum,
  CurrencyEnum,
  PlanDetailsV2Fragment,
  PlanInterval,
  UpdatePlanDocument,
} from '~/generated/graphql'

import { buildUpdatePlanFormDefaults, useUpdatePlanWithCascade } from '../useUpdatePlanWithCascade'

NiceModal.register(FORM_DIALOG_NAME, FormDialog)

jest.mock('~/core/apolloClient', () => {
  const actual = jest.requireActual('~/core/apolloClient')

  return { ...actual, addToast: jest.fn() }
})

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

const basePlan = {
  __typename: 'Plan' as const,
  id: 'plan_1',
  name: 'Pro',
  code: 'pro',
  description: null,
  interval: PlanInterval.Monthly,
  amountCurrency: CurrencyEnum.Usd,
  amountCents: '0',
  payInAdvance: false,
  trialPeriod: 0,
  invoiceDisplayName: null,
  hasOverriddenPlans: false,
  subscriptionsCount: 0,
  billFixedChargesMonthly: false,
  billChargesMonthly: false,
  taxes: [],
  fixedCharges: [],
  charges: [],
}

const updateMock: MockedResponse = {
  request: { query: UpdatePlanDocument },
  variableMatcher: (vars) => vars?.input?.id === basePlan.id,
  result: { data: { updatePlan: { ...basePlan, name: 'Pro Renamed' } } },
}

let capturedUpdateInput: Record<string, unknown> | undefined

const capturingUpdateMock: MockedResponse = {
  request: { query: UpdatePlanDocument },
  variableMatcher: (vars) => {
    capturedUpdateInput = vars?.input
    return vars?.input?.id === basePlan.id
  },
  result: { data: { updatePlan: { ...basePlan } } },
}

const wrapper = (mocks: MockedResponse[]) =>
  function MockedWrapper({ children }: { children: ReactNode }) {
    return (
      <MockedProvider mocks={mocks} addTypename={false}>
        <NiceModal.Provider>{children}</NiceModal.Provider>
      </MockedProvider>
    )
  }

describe('buildUpdatePlanFormDefaults', () => {
  it('hydrates min commitment, thresholds and entitlements from the plan', () => {
    const defaults = buildUpdatePlanFormDefaults({
      id: 'p1',
      name: 'Plan',
      code: 'plan',
      interval: PlanInterval.Monthly,
      amountCurrency: CurrencyEnum.Usd,
      amountCents: '0',
      payInAdvance: false,
      subscriptionsCount: 0,
      minimumCommitment: {
        amountCents: 5000,
        commitmentType: CommitmentTypeEnum.MinimumCommitment,
        taxes: [],
      },
      usageThresholds: [
        { id: 'u1', amountCents: 10000, recurring: false, thresholdDisplayName: null },
        { id: 'u2', amountCents: 20000, recurring: true, thresholdDisplayName: null },
      ],
      entitlements: [{ code: 'seats', name: 'Seats', privileges: [] }],
    } as PlanDetailsV2Fragment)

    expect(defaults.minimumCommitment?.amountCents).toBe('50')
    expect(defaults.nonRecurringUsageThresholds).toHaveLength(1)
    expect(defaults.recurringUsageThreshold?.amountCents).toBe(200)
    expect(defaults.entitlements[0]).toEqual(
      expect.objectContaining({ featureCode: 'seats', featureName: 'Seats' }),
    )
  })

  it('defaults to empty advanced fields when the plan has none', () => {
    const defaults = buildUpdatePlanFormDefaults({
      id: 'p1',
      name: 'P',
      code: 'p',
      interval: PlanInterval.Monthly,
      amountCurrency: CurrencyEnum.Usd,
      amountCents: '0',
      payInAdvance: false,
    } as PlanDetailsV2Fragment)

    expect(defaults.minimumCommitment).toEqual({})
    expect(defaults.entitlements).toEqual([])
    expect(defaults.nonRecurringUsageThresholds).toBeUndefined()
  })

  it('hydrates trialPeriod, payInAdvance and invoiceDisplayName from the plan', () => {
    const defaults = buildUpdatePlanFormDefaults({
      id: 'p1',
      name: 'P',
      code: 'p',
      interval: PlanInterval.Monthly,
      amountCurrency: CurrencyEnum.Usd,
      amountCents: '0',
      trialPeriod: 14,
      payInAdvance: true,
      invoiceDisplayName: 'Custom name',
    } as PlanDetailsV2Fragment)

    expect(defaults.trialPeriod).toBe(14)
    expect(defaults.payInAdvance).toBe(true)
    expect(defaults.invoiceDisplayName).toBe('Custom name')
  })
})

describe('useUpdatePlanWithCascade', () => {
  beforeEach(() => {
    ;(addToast as jest.Mock).mockClear()
    capturedUpdateInput = undefined
  })

  it('seeds the form with plan-settings values from the plan', () => {
    const { result } = renderHook(() => useUpdatePlanWithCascade({ plan: basePlan }), {
      wrapper: wrapper([]),
    })

    expect(result.current.form.state.values.name).toBe('Pro')
    expect(result.current.form.state.values.code).toBe('pro')
    expect(result.current.form.state.values.interval).toBe(PlanInterval.Monthly)
  })

  it('runs updatePlan + onSuccess directly when the plan has no overrides', async () => {
    const onSuccess = jest.fn()
    const { result } = renderHook(() => useUpdatePlanWithCascade({ plan: basePlan, onSuccess }), {
      wrapper: wrapper([updateMock]),
    })

    act(() => {
      result.current.form.setFieldValue('name', 'Pro Renamed')
    })

    await act(async () => {
      await result.current.submit()
    })

    await waitFor(() => {
      expect(onSuccess).toHaveBeenCalledTimes(1)
    })

    expect(addToast).toHaveBeenCalledWith({
      severity: 'success',
      translateKey: 'text_625fd165963a7b00c8f598a0',
    })
  })

  it('applyAndSubmit runs the mutator after resetting and then submits', async () => {
    const onSuccess = jest.fn()
    const { result } = renderHook(
      () =>
        useUpdatePlanWithCascade({
          plan: basePlan,
          includeAdvancedFields: true,
          onSuccess,
        }),
      { wrapper: wrapper([updateMock]) },
    )

    await act(async () => {
      await result.current.applyAndSubmit(() => {
        result.current.form.setFieldValue('name', 'Pro Renamed')
      })
    })

    await waitFor(() => {
      expect(onSuccess).toHaveBeenCalledTimes(1)
    })
    expect(result.current.form.state.values.name).toBe('Pro Renamed')
  })

  it('applyAndSubmit opens the cascade dialog when the plan has overridden subs', async () => {
    const { result } = renderHook(
      () =>
        useUpdatePlanWithCascade({
          plan: { ...basePlan, hasOverriddenPlans: true },
          includeAdvancedFields: true,
        }),
      { wrapper: wrapper([updateMock]) },
    )

    act(() => {
      void result.current.applyAndSubmit(() => {
        result.current.form.setFieldValue('name', 'Pro Renamed')
      })
    })

    await waitFor(() => {
      expect(document.body.textContent).toContain('text_1729604107534r3hsj7i64gp')
    })
  })

  it('opens the cascade dialog when the plan has overridden subs', async () => {
    const { result } = renderHook(
      () =>
        useUpdatePlanWithCascade({
          plan: { ...basePlan, hasOverriddenPlans: true },
        }),
      { wrapper: wrapper([updateMock]) },
    )

    act(() => {
      result.current.form.setFieldValue('name', 'Pro Renamed')
    })

    act(() => {
      result.current.submit()
    })

    await waitFor(() => {
      expect(document.body.textContent).toContain('text_1729604107534r3hsj7i64gp')
    })
  })

  describe('includeAdvancedFields option', () => {
    it('omits minimumCommitment, usageThresholds and entitlements when false (default)', async () => {
      const { result } = renderHook(() => useUpdatePlanWithCascade({ plan: basePlan }), {
        wrapper: wrapper([capturingUpdateMock]),
      })

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput).toBeDefined()
      })

      expect(capturedUpdateInput).not.toHaveProperty('minimumCommitment')
      expect(capturedUpdateInput).not.toHaveProperty('usageThresholds')
      expect(capturedUpdateInput).not.toHaveProperty('entitlements')
      expect(capturedUpdateInput).toHaveProperty('description', null)
      expect(capturedUpdateInput).toHaveProperty('invoiceDisplayName', null)
    })

    it('clears an emptied description by sending null in the payload', async () => {
      const { result } = renderHook(
        () => useUpdatePlanWithCascade({ plan: { ...basePlan, description: 'Some description' } }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      act(() => {
        result.current.form.setFieldValue('description', '')
      })

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput).toBeDefined()
      })

      expect(capturedUpdateInput).toHaveProperty('description', null)
    })

    it('clears an emptied invoiceDisplayName by sending null in the payload', async () => {
      const { result } = renderHook(
        () =>
          useUpdatePlanWithCascade({ plan: { ...basePlan, invoiceDisplayName: 'Custom name' } }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      act(() => {
        result.current.form.setFieldValue('invoiceDisplayName', '')
      })

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput).toBeDefined()
      })

      expect(capturedUpdateInput).toHaveProperty('invoiceDisplayName', null)
    })

    it('includes minimumCommitment, usageThresholds and entitlements in payload when true', async () => {
      const planWithAdvanced = {
        ...basePlan,
        minimumCommitment: {
          amountCents: 5000,
          commitmentType: CommitmentTypeEnum.MinimumCommitment,
          taxes: [],
        },
        usageThresholds: [
          { id: 'u1', amountCents: 10000, recurring: false, thresholdDisplayName: null },
          { id: 'u2', amountCents: 20000, recurring: true, thresholdDisplayName: null },
        ],
        entitlements: [{ code: 'seats', name: 'Seats', privileges: [] }],
      } as PlanDetailsV2Fragment

      const { result } = renderHook(
        () => useUpdatePlanWithCascade({ plan: planWithAdvanced, includeAdvancedFields: true }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput).toBeDefined()
      })

      expect(capturedUpdateInput).toHaveProperty('minimumCommitment')
      expect(capturedUpdateInput).toHaveProperty('usageThresholds')
      expect(capturedUpdateInput).toHaveProperty('entitlements')
    })

    it('serializes the minimumCommitment amount back to cents when included', async () => {
      const planWithAdvanced = {
        ...basePlan,
        minimumCommitment: {
          amountCents: 5000,
          commitmentType: CommitmentTypeEnum.MinimumCommitment,
          taxes: [],
        },
      } as PlanDetailsV2Fragment

      const { result } = renderHook(
        () => useUpdatePlanWithCascade({ plan: planWithAdvanced, includeAdvancedFields: true }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput).toBeDefined()
      })

      expect(capturedUpdateInput?.minimumCommitment).toEqual(
        expect.objectContaining({ amountCents: 5000 }),
      )
    })

    it('serializes usageThresholds back to cents with the right recurring flags when included', async () => {
      const planWithAdvanced = {
        ...basePlan,
        usageThresholds: [
          { id: 'u1', amountCents: 10000, recurring: false, thresholdDisplayName: 'First' },
          { id: 'u2', amountCents: 20000, recurring: true, thresholdDisplayName: null },
        ],
      } as PlanDetailsV2Fragment

      const { result } = renderHook(
        () => useUpdatePlanWithCascade({ plan: planWithAdvanced, includeAdvancedFields: true }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput?.usageThresholds).toBeDefined()
      })

      expect(capturedUpdateInput?.usageThresholds).toEqual([
        expect.objectContaining({
          amountCents: 10000,
          recurring: false,
          thresholdDisplayName: 'First',
        }),
        expect.objectContaining({
          amountCents: 20000,
          recurring: true,
          thresholdDisplayName: null,
        }),
      ])
    })

    it('sends usageThresholds: [] when all thresholds are deleted so the API clears them', async () => {
      const planWithThresholds = {
        ...basePlan,
        usageThresholds: [
          { id: 'u1', amountCents: 10000, recurring: false, thresholdDisplayName: null },
          { id: 'u2', amountCents: 20000, recurring: true, thresholdDisplayName: null },
        ],
      } as PlanDetailsV2Fragment

      const { result } = renderHook(
        () => useUpdatePlanWithCascade({ plan: planWithThresholds, includeAdvancedFields: true }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      await act(async () => {
        await result.current.applyAndSubmit(() => {
          result.current.form.setFieldValue('nonRecurringUsageThresholds', undefined)
          result.current.form.setFieldValue('recurringUsageThreshold', undefined)
        })
      })

      await waitFor(() => {
        expect(capturedUpdateInput).toBeDefined()
      })

      expect(capturedUpdateInput?.usageThresholds).toEqual([])
    })

    it('strips display-only entitlement fields from the payload when included', async () => {
      const planWithAdvanced = {
        ...basePlan,
        entitlements: [
          {
            code: 'seats',
            name: 'Seats',
            privileges: [
              {
                code: 'max',
                name: 'Max',
                value: '10',
                valueType: 'integer',
                config: {},
              },
            ],
          },
        ],
      } as PlanDetailsV2Fragment

      const { result } = renderHook(
        () => useUpdatePlanWithCascade({ plan: planWithAdvanced, includeAdvancedFields: true }),
        { wrapper: wrapper([capturingUpdateMock]) },
      )

      await act(async () => {
        await result.current.submit()
      })

      await waitFor(() => {
        expect(capturedUpdateInput?.entitlements).toBeDefined()
      })

      const entitlements = capturedUpdateInput?.entitlements as Array<{
        featureCode: string
        featureName?: string
        featureId?: string
        privileges: Array<{
          privilegeCode: string
          value: string
          privilegeName?: string
          valueType?: string
          config?: unknown
        }>
      }>

      expect(entitlements[0]).toEqual(
        expect.objectContaining({
          featureCode: 'seats',
          featureName: undefined,
          featureId: undefined,
        }),
      )
      expect(entitlements[0].privileges[0]).toEqual(
        expect.objectContaining({
          privilegeCode: 'max',
          value: '10',
          privilegeName: undefined,
          valueType: undefined,
          config: undefined,
        }),
      )
    })
  })
})
