import { renderHook } from '@testing-library/react'

import {
  ComboboxTestMatrice,
  PayinAdvanceOptionDisabledTestMatrice,
  ProratedOptionDisabledTestMatrice,
} from '~/hooks/plans/__tests__/fixture'
import {
  TGetIsPayInAdvanceOptionDisabledForUsageChargeProps,
  TGetUsageChargeModelComboboxDataProps,
  useChargeForm,
} from '~/hooks/plans/useChargeForm'

const prepareComboboxTest = async ({
  aggregationType,
  isPremium = true,
}: TGetUsageChargeModelComboboxDataProps) => {
  const { result } = renderHook(useChargeForm)

  return {
    getUsageChargeModelComboboxData: result.current.getUsageChargeModelComboboxData({
      aggregationType,
      isPremium,
    }),
  }
}

const preparePayinAdvanceOptionDisabledTest = async ({
  aggregationType,
  chargeModel,
  isPayInAdvance,
  isProrated,
  isRecurring,
}: TGetIsPayInAdvanceOptionDisabledForUsageChargeProps) => {
  const { result } = renderHook(useChargeForm)

  return {
    getIsPayInAdvanceOptionDisabledForUsageCharge:
      result.current.getIsPayInAdvanceOptionDisabledForUsageCharge({
        aggregationType,
        chargeModel,
        isPayInAdvance,
        isProrated,
        isRecurring,
      }),
  }
}

describe('useChargeForm()', () => {
  describe('getUsageChargeModelComboboxData()', () => {
    test.each(Array.from(ComboboxTestMatrice))(
      'should return the correct charge models for $aggregationType',
      async (testSetup) => {
        const { aggregationType, expectedChargesModels } = testSetup

        const { getUsageChargeModelComboboxData } = await prepareComboboxTest({
          aggregationType,
          isPremium: true,
        })

        expect(getUsageChargeModelComboboxData.map(({ value }) => value)).toEqual(
          expectedChargesModels,
        )
      },
    )
  })

  describe('preparePayinAdvanceOptionDisabledTest()', () => {
    test.each(Array.from(PayinAdvanceOptionDisabledTestMatrice))(
      'should return the correct value for aggregationType: $aggregationType, chargeModel: $chargeModel, isPayInAdvance: $isPayInAdvance, isProrated: $isProrated, isRecurring: $isRecurring',
      async (testSetup) => {
        const {
          aggregationType,
          chargeModel,
          isPayInAdvance,
          isProrated,
          isRecurring,
          expectedDisabledValue,
        } = testSetup

        const { getIsPayInAdvanceOptionDisabledForUsageCharge } =
          await preparePayinAdvanceOptionDisabledTest({
            aggregationType,
            chargeModel,
            isPayInAdvance,
            isProrated,
            isRecurring,
          })

        expect(getIsPayInAdvanceOptionDisabledForUsageCharge).toEqual(expectedDisabledValue)
      },
    )
  })

  describe('getIsProratedOptionDisabled()', () => {
    test.each(Array.from(ProratedOptionDisabledTestMatrice))(
      'should return the correct value for aggregationType: $aggregationType, chargeModel: $chargeModel',
      async (testSetup) => {
        const { aggregationType, chargeModel, isPayInAdvance, expectedDisabledValue } = testSetup

        const { result } = renderHook(useChargeForm)
        const getIsProRatedOptionDisabledForUsageCharge =
          result.current.getIsProRatedOptionDisabledForUsageCharge({
            aggregationType,
            chargeModel,
            isPayInAdvance,
          })

        expect(getIsProRatedOptionDisabledForUsageCharge).toEqual(expectedDisabledValue)
      },
    )
  })
})
