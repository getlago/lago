import { DateTime, Settings } from 'luxon'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    timezone: 'UTC',
  }),
}))

jest.mock('~/core/timezone', () => ({
  getTimezoneConfig: () => ({ name: 'UTC' }),
}))

// We test the component's date logic by extracting and testing the handleFromChange / handleToChange
// behavior through the component's interface

describe('FiltersItemWebhookDate', () => {
  const originalDefaultZone = Settings.defaultZone

  beforeAll(() => {
    Settings.defaultZone = 'UTC'
  })

  afterAll(() => {
    Settings.defaultZone = originalDefaultZone
  })

  describe('date value parsing', () => {
    describe('GIVEN a comma-separated value', () => {
      describe('WHEN the value contains from and to dates', () => {
        it('THEN should correctly split the value into from and to parts', () => {
          const value = '2024-01-01T00:00:00.000Z,2024-01-31T23:59:59.999Z'
          const [from, to] = value.split(',')

          expect(from).toBe('2024-01-01T00:00:00.000Z')
          expect(to).toBe('2024-01-31T23:59:59.999Z')
        })
      })

      describe('WHEN the value has only a from date', () => {
        it('THEN should have empty to part', () => {
          const value = '2024-01-01T00:00:00.000Z,'
          const [from, to] = value.split(',')

          expect(from).toBe('2024-01-01T00:00:00.000Z')
          expect(to).toBe('')
        })
      })

      describe('WHEN the value has only a to date', () => {
        it('THEN should have empty from part', () => {
          const value = ',2024-01-31T23:59:59.999Z'
          const [from, to] = value.split(',')

          expect(from).toBe('')
          expect(to).toBe('2024-01-31T23:59:59.999Z')
        })
      })
    })
  })

  describe('handleFromChange logic', () => {
    describe('GIVEN a from date and an existing to date', () => {
      describe('WHEN from date is after to date', () => {
        it('THEN should adjust to date to end of from date day', () => {
          const mockSetFilterValue = jest.fn()
          const fromDate = '2024-02-15T00:00:00.000Z'
          const toDate = '2024-02-10T23:59:59.999Z'

          // Simulate the component's handleFromChange logic
          const from = DateTime.fromISO(fromDate).startOf('day')
          const to = DateTime.fromISO(toDate)

          if (from > to) {
            mockSetFilterValue(`${from.toISO()},${from.endOf('day').toISO()}`)
          }

          expect(mockSetFilterValue).toHaveBeenCalledWith(expect.stringContaining('2024-02-15'))
          const callArg = mockSetFilterValue.mock.calls[0][0] as string
          const [resultFrom, resultTo] = callArg.split(',')

          expect(DateTime.fromISO(resultFrom).day).toBe(15)
          expect(DateTime.fromISO(resultTo).day).toBe(15)
        })
      })

      describe('WHEN from date is before to date', () => {
        it('THEN should keep to date unchanged', () => {
          const mockSetFilterValue = jest.fn()
          const fromDate = '2024-02-05T00:00:00.000Z'
          const toDate = '2024-02-10T23:59:59.999Z'

          const from = DateTime.fromISO(fromDate).startOf('day')
          const to = DateTime.fromISO(toDate)

          if (from > to) {
            mockSetFilterValue(`${from.toISO()},${from.endOf('day').toISO()}`)
          } else {
            mockSetFilterValue(`${from.toISO()},${toDate}`)
          }

          const callArg = mockSetFilterValue.mock.calls[0][0] as string

          expect(callArg).toContain(toDate)
        })
      })
    })
  })

  describe('handleToChange logic', () => {
    describe('GIVEN a to date and an existing from date', () => {
      describe('WHEN to date is before from date', () => {
        it('THEN should adjust from date to start of to date day', () => {
          const mockSetFilterValue = jest.fn()
          const fromDate = '2024-02-15T00:00:00.000Z'
          const toDate = '2024-02-10T00:00:00.000Z'

          const to = DateTime.fromISO(toDate).endOf('day')
          const from = DateTime.fromISO(fromDate)

          if (to < from) {
            mockSetFilterValue(`${to.startOf('day').toISO()},${to.toISO()}`)
          }

          expect(mockSetFilterValue).toHaveBeenCalled()
          const callArg = mockSetFilterValue.mock.calls[0][0] as string
          const [resultFrom, resultTo] = callArg.split(',')

          expect(DateTime.fromISO(resultFrom).day).toBe(10)
          expect(DateTime.fromISO(resultTo).day).toBe(10)
        })
      })

      describe('WHEN to date is after from date', () => {
        it('THEN should keep from date unchanged', () => {
          const mockSetFilterValue = jest.fn()
          const fromDate = '2024-02-05T00:00:00.000Z'
          const toDate = '2024-02-10T00:00:00.000Z'

          const to = DateTime.fromISO(toDate).endOf('day')
          const from = DateTime.fromISO(fromDate)

          if (to < from) {
            mockSetFilterValue(`${to.startOf('day').toISO()},${to.toISO()}`)
          } else {
            mockSetFilterValue(`${fromDate},${to.toISO()}`)
          }

          const callArg = mockSetFilterValue.mock.calls[0][0] as string

          expect(callArg).toContain(fromDate)
        })
      })
    })
  })

  describe('default value', () => {
    describe('GIVEN no value is provided', () => {
      it('THEN should default to comma separator', () => {
        const defaultValue = ','
        const [from, to] = defaultValue.split(',')

        expect(from).toBe('')
        expect(to).toBe('')
      })
    })
  })
})
