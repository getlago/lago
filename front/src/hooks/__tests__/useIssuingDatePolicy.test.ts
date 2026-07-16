import { renderHook } from '@testing-library/react'
import { DateTime } from 'luxon'

import { ALL_ADJUSTMENT_VALUES, ALL_ANCHOR_VALUES } from '~/core/constants/issuingDatePolicy'
import { intlFormatDateTime } from '~/core/timezone'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { useIssuingDatePolicy } from '../useIssuingDatePolicy'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: jest.fn(),
}))

jest.mock('~/core/timezone', () => ({
  ...jest.requireActual('~/core/timezone'),
  intlFormatDateTime: jest.fn(),
}))

const ISSUING_POLICY_DESCRIPTION_KEY = 'text_1763407530094k0lsbmuh6a1'
const ISSUING_POLICY_EXPECTED_DATE_KEY = 'text_1763407530094w9q8pwx1m0j'

describe('useIssuingDatePolicy', () => {
  const translateMock = jest.fn((key: string) => `translated-${key}`)
  const updateLocaleMock = jest.fn()
  const intlFormatDateTimeMock = intlFormatDateTime as jest.MockedFunction<
    typeof intlFormatDateTime
  >
  const useInternationalizationMock = useInternationalization as jest.MockedFunction<
    typeof useInternationalization
  >

  beforeEach(() => {
    translateMock.mockReset()
    translateMock.mockImplementation((key: string) => `translated-${key}`)
    intlFormatDateTimeMock.mockReset()
    intlFormatDateTimeMock.mockImplementation((isoString: string) => ({
      date: `formatted-${isoString}`,
      time: '',
      timezone: '',
    }))
    useInternationalizationMock.mockReturnValue({
      translate: translateMock,
      locale: 'en',
      updateLocale: updateLocaleMock,
    })
  })

  describe('getIssuingDateInfoForAlert', () => {
    let dateTimeLocalSpy:
      | jest.SpyInstance<
          ReturnType<(typeof DateTime)['local']>,
          Parameters<(typeof DateTime)['local']>
        >
      | undefined
    const mockedCurrentDate = DateTime.fromISO('2025-05-20T12:00:00.000Z') as ReturnType<
      (typeof DateTime)['local']
    >

    let periodStartDate: DateTime
    let periodEndDate: DateTime

    beforeEach(() => {
      dateTimeLocalSpy = jest.spyOn(DateTime, 'local').mockReturnValue(mockedCurrentDate)
      periodStartDate = mockedCurrentDate.startOf('year').startOf('month').startOf('day')
      periodEndDate = periodStartDate.endOf('month')
    })

    afterEach(() => {
      dateTimeLocalSpy?.mockRestore()
      dateTimeLocalSpy = undefined
    })

    type Scenario = {
      description: string
      anchor: (typeof ALL_ANCHOR_VALUES)[keyof typeof ALL_ANCHOR_VALUES]
      adjustment: (typeof ALL_ADJUSTMENT_VALUES)[keyof typeof ALL_ADJUSTMENT_VALUES]
      gracePeriod: number | undefined
      expectedDate: (params: { periodEndDate: DateTime; finalizationDate: DateTime }) => DateTime
    }

    const scenarios: Scenario[] = [
      // Test for: Current period end anchor + keep anchor returns period end date
      {
        description:
          'Current period end anchor + keep anchor returns period end date (gracePeriod = 3)',
        anchor: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        adjustment: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        gracePeriod: 3,
        expectedDate: ({ periodEndDate: scenarioPeriodEndDate }) => scenarioPeriodEndDate,
      },
      {
        description:
          'Current period end anchor + keep anchor returns period end date (gracePeriod = 0)',
        anchor: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        adjustment: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        gracePeriod: 0,
        expectedDate: ({ periodEndDate: scenarioPeriodEndDate }) => scenarioPeriodEndDate,
      },
      {
        description:
          'Current period end anchor + keep anchor returns period end date (gracePeriod = undefined)',
        anchor: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        adjustment: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        gracePeriod: undefined,
        expectedDate: ({ periodEndDate: scenarioPeriodEndDate }) => scenarioPeriodEndDate,
      },
      // Test for: Current period end anchor + align with finalization uses finalization date
      {
        description:
          'Current period end anchor + align with finalization uses finalization date (gracePeriod = 4)',
        anchor: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        adjustment: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        gracePeriod: 4,
        expectedDate: ({ finalizationDate: scenarioFinalizationDate }) => scenarioFinalizationDate,
      },
      {
        description:
          'Current period end anchor + align with finalization uses finalization date (gracePeriod = 0)',
        anchor: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        adjustment: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        gracePeriod: 0,
        expectedDate: ({ finalizationDate: scenarioFinalizationDate }) => scenarioFinalizationDate,
      },
      {
        description:
          'Current period end anchor + align with finalization uses finalization date (gracePeriod = undefined)',
        anchor: ALL_ANCHOR_VALUES.CurrentPeriodEnd,
        adjustment: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        gracePeriod: undefined,
        expectedDate: ({ finalizationDate: scenarioFinalizationDate }) => scenarioFinalizationDate,
      },
      // Test for: Next period start anchor + keep anchor offsets to next day
      {
        description: 'Next period start anchor + keep anchor offsets to next day (gracePeriod = 2)',
        anchor: ALL_ANCHOR_VALUES.NextPeriodStart,
        adjustment: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        gracePeriod: 2,
        expectedDate: ({ periodEndDate: scenarioPeriodEndDate }) =>
          scenarioPeriodEndDate.plus({ days: 1 }),
      },
      {
        description: 'Next period start anchor + keep anchor offsets to next day (gracePeriod = 0)',
        anchor: ALL_ANCHOR_VALUES.NextPeriodStart,
        adjustment: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        gracePeriod: 0,
        expectedDate: ({ periodEndDate: scenarioPeriodEndDate }) =>
          scenarioPeriodEndDate.plus({ days: 1 }),
      },
      {
        description:
          'Next period start anchor + keep anchor offsets to next day (gracePeriod = undefined)',
        anchor: ALL_ANCHOR_VALUES.NextPeriodStart,
        adjustment: ALL_ADJUSTMENT_VALUES.KeepAnchor,
        gracePeriod: undefined,
        expectedDate: ({ periodEndDate: scenarioPeriodEndDate }) =>
          scenarioPeriodEndDate.plus({ days: 1 }),
      },
      // Test for: Next period start anchor + align with finalization offsets finalization by one day
      {
        description:
          'Next period start anchor + align with finalization offsets finalization by one day (gracePeriod = 5)',
        anchor: ALL_ANCHOR_VALUES.NextPeriodStart,
        adjustment: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        gracePeriod: 5,
        expectedDate: ({ finalizationDate: scenarioFinalizationDate }) =>
          scenarioFinalizationDate.plus({ days: 1 }),
      },
      {
        description:
          'Next period start anchor + align with finalization offsets finalization by one day (gracePeriod = 0)',
        anchor: ALL_ANCHOR_VALUES.NextPeriodStart,
        adjustment: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        gracePeriod: 0,
        expectedDate: ({ finalizationDate: scenarioFinalizationDate }) =>
          scenarioFinalizationDate.plus({ days: 1 }),
      },
      {
        description:
          'Next period start anchor + align with finalization offsets finalization by one day (gracePeriod = undefined)',
        anchor: ALL_ANCHOR_VALUES.NextPeriodStart,
        adjustment: ALL_ADJUSTMENT_VALUES.AlignWithFinalizationDate,
        gracePeriod: undefined,
        expectedDate: ({ finalizationDate: scenarioFinalizationDate }) =>
          scenarioFinalizationDate.plus({ days: 1 }),
      },
    ]

    it.each(scenarios)('$description', ({ anchor, adjustment, gracePeriod, expectedDate }) => {
      const { result } = renderHook(() => useIssuingDatePolicy())

      translateMock.mockClear()
      intlFormatDateTimeMock.mockClear()

      const finalizationDate = periodEndDate.plus({
        days: gracePeriod,
      })
      const expectedIssuingDate = expectedDate({ periodEndDate, finalizationDate })

      const info = result.current.getIssuingDateInfoForAlert({
        gracePeriod,
        subscriptionInvoiceIssuingDateAdjustment: adjustment,
        subscriptionInvoiceIssuingDateAnchor: anchor,
      })

      expect(info.descriptionCopyAsHtml).toBe(`translated-${ISSUING_POLICY_DESCRIPTION_KEY}`)
      expect(info.expectedIssuingDateCopy).toBe(`translated-${ISSUING_POLICY_EXPECTED_DATE_KEY}`)
      expect(translateMock).toHaveBeenNthCalledWith(
        1,
        ISSUING_POLICY_DESCRIPTION_KEY,
        expect.objectContaining({
          periodStartDate: `formatted-${periodStartDate.toISO()}`,
          periodEndDate: `formatted-${periodEndDate.toISO()}`,
          gracePeriod: gracePeriod || 0,
          expectedIssuingDate: `formatted-${expectedIssuingDate.toISO()}`,
        }),
      )
      expect(translateMock).toHaveBeenNthCalledWith(
        2,
        ISSUING_POLICY_EXPECTED_DATE_KEY,
        expect.objectContaining({
          expectedIssuingDate: `formatted-${expectedIssuingDate.toISO()}`,
        }),
      )
    })

    it('falls back to defaults when anchor or adjustment are nullish', () => {
      const { result } = renderHook(() => useIssuingDatePolicy())

      translateMock.mockClear()
      intlFormatDateTimeMock.mockClear()

      const gracePeriod = undefined
      // When gracePeriod is undefined, finalizationDate = periodEndDate (no days added)
      const finalizationDate = periodEndDate
      // Defaults: NextPeriodStart + AlignWithFinalizationDate = finalizationDate.plus({ days: 1 })
      const expectedIssuingDate = finalizationDate.plus({ days: 1 })

      const info = result.current.getIssuingDateInfoForAlert({
        gracePeriod,
        subscriptionInvoiceIssuingDateAdjustment: null,
        subscriptionInvoiceIssuingDateAnchor: null,
      })

      expect(info.descriptionCopyAsHtml).toBe(`translated-${ISSUING_POLICY_DESCRIPTION_KEY}`)
      expect(info.expectedIssuingDateCopy).toBe(`translated-${ISSUING_POLICY_EXPECTED_DATE_KEY}`)
      expect(translateMock).toHaveBeenNthCalledWith(
        1,
        ISSUING_POLICY_DESCRIPTION_KEY,
        expect.objectContaining({
          periodStartDate: `formatted-${periodStartDate.toISO()}`,
          periodEndDate: `formatted-${periodEndDate.toISO()}`,
          gracePeriod: gracePeriod || 0,
          expectedIssuingDate: `formatted-${expectedIssuingDate.toISO()}`,
        }),
      )
      expect(translateMock).toHaveBeenNthCalledWith(
        2,
        ISSUING_POLICY_EXPECTED_DATE_KEY,
        expect.objectContaining({
          expectedIssuingDate: `formatted-${expectedIssuingDate.toISO()}`,
        }),
      )
    })
  })
})
