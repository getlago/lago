import { MockedProvider, MockedResponse } from '@apollo/client/testing'
import { act, renderHook, waitFor } from '@testing-library/react'
import { ReactNode } from 'react'

import { LocalFixedChargeInput } from '~/components/plans/types'
import {
  FixedChargeChargeModelEnum,
  PropertiesInput,
  UpdateSubscriptionFixedChargeDocument,
  UpdateSubscriptionFixedChargeInput,
} from '~/generated/graphql'

import {
  BaselineFixedCharge,
  useSubscriptionFixedChargeMutations,
} from '../useSubscriptionFixedChargeMutations'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({ translate: (k: string) => k }),
}))

const SUB_ID = 'sub_1'

const buildCharge = (overrides: Partial<LocalFixedChargeInput> = {}): LocalFixedChargeInput =>
  ({
    id: 'fc_1',
    code: 'onboarding',
    chargeModel: FixedChargeChargeModelEnum.Standard,
    invoiceDisplayName: 'Onboarding',
    payInAdvance: false,
    prorated: false,
    properties: {},
    units: '2',
    taxes: [],
    applyUnitsImmediately: false,
    addOn: { __typename: 'AddOn', id: 'addon_1', name: 'Onboarding', code: 'onboarding' },
    ...overrides,
  }) as unknown as LocalFixedChargeInput

// Plan-level baseline matching buildCharge()'s defaults, as it would come out
// of the Apollo cache (__typename present, plan-default units).
const buildBaseline = (overrides: Partial<BaselineFixedCharge> = {}): BaselineFixedCharge =>
  ({
    code: 'onboarding',
    chargeModel: FixedChargeChargeModelEnum.Standard,
    invoiceDisplayName: 'Onboarding',
    properties: { __typename: 'FixedChargeProperties', amount: '10' },
    taxes: [],
    ...overrides,
  }) as unknown as BaselineFixedCharge

const wrapper = (mocks: MockedResponse[]) =>
  function W({ children }: { children: ReactNode }) {
    return (
      <MockedProvider mocks={mocks} addTypename={false}>
        {children}
      </MockedProvider>
    )
  }

describe('useSubscriptionFixedChargeMutations', () => {
  it('fires updateSubscriptionFixedCharge with subscriptionId + fixedChargeCode', async () => {
    let called = false
    const updateMock: MockedResponse = {
      request: { query: UpdateSubscriptionFixedChargeDocument },
      variableMatcher: (vars) =>
        vars?.input?.subscriptionId === SUB_ID && vars?.input?.fixedChargeCode === 'onboarding',
      result: () => {
        called = true
        return {
          data: {
            updateSubscriptionFixedCharge: { __typename: 'FixedCharge', id: 'fc_override_1' },
          },
        }
      },
    }

    const { result } = renderHook(
      () => useSubscriptionFixedChargeMutations({ subscriptionId: SUB_ID }),
      { wrapper: wrapper([updateMock]) },
    )

    await act(async () => {
      await result.current.handleSaveCharge(buildCharge())
    })

    await waitFor(() => expect(called).toBe(true))
  })

  // After a successful edit, the override-units row must refresh. The no-cache
  // query's data is only reliably updated by calling its OWN refetch, so when
  // one is supplied it is used (instead of the name-based client.refetchQueries).
  it('calls the provided refetchOverrides after a successful save', async () => {
    const updateMock: MockedResponse = {
      request: { query: UpdateSubscriptionFixedChargeDocument },
      variableMatcher: () => true,
      result: {
        data: { updateSubscriptionFixedCharge: { __typename: 'FixedCharge', id: 'fc_override_1' } },
      },
    }
    const refetchOverrides = jest.fn().mockResolvedValue(undefined)

    const { result } = renderHook(
      () => useSubscriptionFixedChargeMutations({ subscriptionId: SUB_ID, refetchOverrides }),
      { wrapper: wrapper([updateMock]) },
    )

    let saved: boolean | unknown

    await act(async () => {
      saved = await result.current.handleSaveCharge(buildCharge())
    })

    expect(saved).toBe(true)
    await waitFor(() => expect(refetchOverrides).toHaveBeenCalledTimes(1))
  })

  it('does not call refetchOverrides when the save fails', async () => {
    const updateMock: MockedResponse = {
      request: { query: UpdateSubscriptionFixedChargeDocument },
      variableMatcher: () => true,
      // Error link surfaces failures as a resolved result with data: null.
      result: { data: { updateSubscriptionFixedCharge: null } },
    }
    const refetchOverrides = jest.fn().mockResolvedValue(undefined)

    const { result } = renderHook(
      () => useSubscriptionFixedChargeMutations({ subscriptionId: SUB_ID, refetchOverrides }),
      { wrapper: wrapper([updateMock]) },
    )

    let saved: boolean | unknown

    await act(async () => {
      saved = await result.current.handleSaveCharge(buildCharge())
    })

    expect(saved).toBe(false)
    expect(refetchOverrides).not.toHaveBeenCalled()
  })

  it('prunes usage-only properties from the override input (standard)', async () => {
    let capturedInput: UpdateSubscriptionFixedChargeInput | undefined

    const updateMock: MockedResponse = {
      request: { query: UpdateSubscriptionFixedChargeDocument },
      variableMatcher: (vars) => {
        capturedInput = vars?.input

        return true
      },
      result: {
        data: { updateSubscriptionFixedCharge: { __typename: 'FixedCharge', id: 'fc_override_1' } },
      },
    }

    const { result } = renderHook(
      () => useSubscriptionFixedChargeMutations({ subscriptionId: SUB_ID }),
      { wrapper: wrapper([updateMock]) },
    )

    const propertiesWithUsageFields: PropertiesInput = {
      amount: '10',
      pricingGroupKeys: ['region'],
      packageSize: 10,
      freeUnits: 0,
    }

    await act(async () => {
      await result.current.handleSaveCharge(
        buildCharge({
          chargeModel: FixedChargeChargeModelEnum.Standard,
          properties: propertiesWithUsageFields,
        }),
      )
    })

    await waitFor(() => expect(capturedInput).toBeDefined())
    expect(capturedInput?.properties).toStrictEqual({ amount: '10' })
  })

  // The BE routes the request to the per-subscription override table ONLY when
  // the params carry nothing but units (+ applyUnitsImmediately). These tests
  // lock in the diff-based input so unchanged fields stay out of the payload.
  describe('units-only fast path (diff against plan baseline)', () => {
    const captureInput = () => {
      let capturedInput: UpdateSubscriptionFixedChargeInput | undefined
      const mock: MockedResponse = {
        request: { query: UpdateSubscriptionFixedChargeDocument },
        variableMatcher: (vars) => {
          capturedInput = vars?.input

          return true
        },
        result: {
          data: {
            updateSubscriptionFixedCharge: { __typename: 'FixedCharge', id: 'fc_override_1' },
          },
        },
      }

      return { mock, getInput: () => capturedInput }
    }

    it('sends only units + applyUnitsImmediately when nothing else changed', async () => {
      const { mock, getInput } = captureInput()

      const { result } = renderHook(
        () =>
          useSubscriptionFixedChargeMutations({
            subscriptionId: SUB_ID,
            fixedCharges: [buildBaseline()],
          }),
        { wrapper: wrapper([mock]) },
      )

      await act(async () => {
        // Same display name, same (standard) properties, same taxes as the
        // baseline — only units differ. The baseline carries __typename and the
        // drawer value doesn't; the comparison must not be fooled by that.
        await result.current.handleSaveCharge(
          buildCharge({ units: '25', properties: { amount: '10' } }),
        )
      })

      await waitFor(() => expect(getInput()).toBeDefined())
      expect(getInput()).toStrictEqual({
        subscriptionId: SUB_ID,
        fixedChargeCode: 'onboarding',
        units: '25',
        applyUnitsImmediately: false,
      })
    })

    it('includes properties when the amount changed', async () => {
      const { mock, getInput } = captureInput()

      const { result } = renderHook(
        () =>
          useSubscriptionFixedChargeMutations({
            subscriptionId: SUB_ID,
            fixedCharges: [buildBaseline()],
          }),
        { wrapper: wrapper([mock]) },
      )

      await act(async () => {
        await result.current.handleSaveCharge(
          buildCharge({ units: '25', properties: { amount: '99' } }),
        )
      })

      await waitFor(() => expect(getInput()).toBeDefined())
      expect(getInput()?.properties).toStrictEqual({ amount: '99' })
      expect(getInput()?.taxCodes).toBeUndefined()
      expect(getInput()?.invoiceDisplayName).toBeUndefined()
    })

    it('includes taxCodes when the taxes changed', async () => {
      const { mock, getInput } = captureInput()

      const { result } = renderHook(
        () =>
          useSubscriptionFixedChargeMutations({
            subscriptionId: SUB_ID,
            fixedCharges: [buildBaseline()],
          }),
        { wrapper: wrapper([mock]) },
      )

      await act(async () => {
        await result.current.handleSaveCharge(
          buildCharge({
            units: '25',
            properties: { amount: '10' },
            taxes: [{ __typename: 'Tax', id: 'tax_1', name: 'VAT', rate: 20, code: 'vat' }],
          }),
        )
      })

      await waitFor(() => expect(getInput()).toBeDefined())
      expect(getInput()?.taxCodes).toStrictEqual(['vat'])
      expect(getInput()?.properties).toBeUndefined()
    })

    it('includes invoiceDisplayName when it changed', async () => {
      const { mock, getInput } = captureInput()

      const { result } = renderHook(
        () =>
          useSubscriptionFixedChargeMutations({
            subscriptionId: SUB_ID,
            fixedCharges: [buildBaseline()],
          }),
        { wrapper: wrapper([mock]) },
      )

      await act(async () => {
        await result.current.handleSaveCharge(
          buildCharge({
            units: '25',
            properties: { amount: '10' },
            invoiceDisplayName: 'Custom name',
          }),
        )
      })

      await waitFor(() => expect(getInput()).toBeDefined())
      expect(getInput()?.invoiceDisplayName).toBe('Custom name')
      expect(getInput()?.properties).toBeUndefined()
    })

    it('sends the full payload when the charge has no plan baseline', async () => {
      const { mock, getInput } = captureInput()

      const { result } = renderHook(
        () =>
          useSubscriptionFixedChargeMutations({
            subscriptionId: SUB_ID,
            fixedCharges: [buildBaseline({ code: 'some_other_code' })],
          }),
        { wrapper: wrapper([mock]) },
      )

      await act(async () => {
        await result.current.handleSaveCharge(
          buildCharge({ units: '25', properties: { amount: '10' } }),
        )
      })

      await waitFor(() => expect(getInput()).toBeDefined())
      // No baseline to diff against → conservative full payload (clone path).
      expect(getInput()?.properties).toStrictEqual({ amount: '10' })
      expect(getInput()?.taxCodes).toStrictEqual([])
      expect(getInput()?.invoiceDisplayName).toBe('Onboarding')
    })
  })
})
