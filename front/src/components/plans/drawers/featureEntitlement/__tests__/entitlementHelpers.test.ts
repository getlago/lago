import { removeEntitlementByFeatureCode, upsertEntitlement } from '../entitlementHelpers'

type Entry = { featureCode: string; featureName?: string }

describe('upsertEntitlement', () => {
  it('appends when list is null', () => {
    const result = upsertEntitlement<Entry>(null, { featureCode: 'a' })

    expect(result).toEqual([{ featureCode: 'a' }])
  })

  it('appends when list is undefined', () => {
    const result = upsertEntitlement<Entry>(undefined, { featureCode: 'a' })

    expect(result).toEqual([{ featureCode: 'a' }])
  })

  it('appends when featureCode is new', () => {
    const result = upsertEntitlement<Entry>([{ featureCode: 'a' }], { featureCode: 'b' })

    expect(result).toEqual([{ featureCode: 'a' }, { featureCode: 'b' }])
  })

  it('replaces existing entry at same index', () => {
    const list: Entry[] = [{ featureCode: 'a', featureName: 'old' }, { featureCode: 'b' }]
    const result = upsertEntitlement(list, { featureCode: 'a', featureName: 'new' })

    expect(result).toEqual([{ featureCode: 'a', featureName: 'new' }, { featureCode: 'b' }])
  })

  it('returns a new array (does not mutate input)', () => {
    const list: Entry[] = [{ featureCode: 'a' }]
    const result = upsertEntitlement(list, { featureCode: 'b' })

    expect(result).not.toBe(list)
    expect(list).toEqual([{ featureCode: 'a' }])
  })
})

describe('removeEntitlementByFeatureCode', () => {
  it('returns empty array when list is null', () => {
    expect(removeEntitlementByFeatureCode<Entry>(null, 'a')).toEqual([])
  })

  it('returns empty array when list is undefined', () => {
    expect(removeEntitlementByFeatureCode<Entry>(undefined, 'a')).toEqual([])
  })

  it('removes the entry matching featureCode', () => {
    const result = removeEntitlementByFeatureCode<Entry>(
      [{ featureCode: 'a' }, { featureCode: 'b' }, { featureCode: 'c' }],
      'b',
    )

    expect(result).toEqual([{ featureCode: 'a' }, { featureCode: 'c' }])
  })

  it('returns equivalent list when no entry matches', () => {
    const list: Entry[] = [{ featureCode: 'a' }]

    expect(removeEntitlementByFeatureCode(list, 'zzz')).toEqual([{ featureCode: 'a' }])
  })

  it('returns a new array (does not mutate input)', () => {
    const list: Entry[] = [{ featureCode: 'a' }]
    const result = removeEntitlementByFeatureCode(list, 'a')

    expect(result).not.toBe(list)
    expect(list).toEqual([{ featureCode: 'a' }])
  })
})
