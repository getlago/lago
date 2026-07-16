import { renderHook } from '@testing-library/react'

import { intlFormatDateTime, TimeFormat } from '~/core/timezone/utils'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

import { useFormatterDateHelper } from '../useFormatterDateHelper'

jest.mock('~/core/timezone/utils', () => ({
  TimeFormat: {
    TIME_WITH_SECONDS: 'TIME_WITH_SECONDS',
  },
  intlFormatDateTime: jest.fn(),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: jest.fn(),
}))

describe('useFormatterDateHelper', () => {
  it('should format a date with seconds using intlFormatDateTimeOrgaTZ', () => {
    const intlFormatDateTimeOrgaTZ = jest
      .fn()
      .mockImplementation((date: string, options: { formatTime: TimeFormat }) => {
        expect(options.formatTime).toBe(TimeFormat.TIME_WITH_SECONDS)
        return {
          date: 'Oct 23, 2025',
          time: '8:25:02 AM',
        }
      })

    ;(useOrganizationInfos as jest.Mock).mockReturnValue({
      intlFormatDateTimeOrgaTZ,
    })

    const { result } = renderHook(() => useFormatterDateHelper())

    const output = result.current.formattedDateTimeWithSecondsOrgaTZ('2025-10-23T08:25:02Z')

    expect(output).toEqual('Oct 23, 2025 8:25:02 AM')

    expect(intlFormatDateTimeOrgaTZ).toHaveBeenCalledWith('2025-10-23T08:25:02Z', {
      formatTime: TimeFormat.TIME_WITH_SECONDS,
    })
  })

  it('should format a date with timezone using intlFormatDateTime', () => {
    const mockIntlFormatDateTime = intlFormatDateTime as jest.Mock

    mockIntlFormatDateTime.mockReturnValue({
      date: 'Oct 22, 2025',
      timezone: 'UTC±0:00',
    })
    ;(useOrganizationInfos as jest.Mock).mockReturnValue({
      intlFormatDateTimeOrgaTZ: jest.fn(),
    })

    const { result } = renderHook(() => useFormatterDateHelper())

    const output = result.current.formattedDateWithTimezone('2025-10-22T14:30:45Z')

    expect(output).toEqual('Oct 22, 2025 UTC±0:00')

    expect(mockIntlFormatDateTime).toHaveBeenCalledWith('2025-10-22T14:30:45Z', {})
  })
})
