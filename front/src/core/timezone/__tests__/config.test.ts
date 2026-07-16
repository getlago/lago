import { TimeZonesConfig } from '~/core/timezone/config'

describe('Timezone fongis', () => {
  describe('TimeZonesConfig', () => {
    it('returns expected config values', () => {
      expect(TimeZonesConfig['TZ_ASIA_TOKYO']).toStrictEqual({
        name: 'Asia/Tokyo',
        offset: '+9:00',
        offsetInMinute: 540,
      })
      expect(TimeZonesConfig['TZ_AMERICA_ARGENTINA_BUENOS_AIRES']).toStrictEqual({
        name: 'America/Argentina/Buenos_Aires',
        offset: '-3:00',
        offsetInMinute: -180,
      })
      expect(TimeZonesConfig['TZ_UTC']).toStrictEqual({
        name: 'UTC',
        offset: '±0:00',
        offsetInMinute: 0,
      })
    })
  })
})
