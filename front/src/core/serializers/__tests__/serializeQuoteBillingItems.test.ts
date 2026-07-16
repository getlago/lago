import type { AddOnItem } from '~/components/designSystem/RichTextEditor/PricingBlock/constants'

import {
  type AddOnPayload,
  type BillingItemsPayload,
  buildPreviewEntities,
  fromBillingItems,
  toBillingItems,
} from '../serializeQuoteBillingItems'

describe('toBillingItems', () => {
  const makePayload = (overrides: Partial<AddOnPayload> = {}): AddOnPayload => ({
    position: 1,
    code: 'setup',
    name: 'Setup Fee',
    description: 'One-time setup',
    units: 1,
    unit_amount_cents: 50000,
    total_amount_cents: 50000,
    invoice_display_name: 'Setup Fee',
    from_datetime: null,
    to_datetime: null,
    tax_codes: [],
    ...overrides,
  })

  const makeAddOnItem = (overrides: Partial<AddOnItem> = {}): AddOnItem => ({
    localId: 'local-1',
    addOnId: 'addon-1',
    name: 'Setup Fee',
    invoiceDisplayName: 'Setup Fee',
    code: 'setup',
    description: 'One-time setup',
    units: '1',
    unitAmountCents: '50000',
    totalAmount: '50000',
    fromDatetime: '',
    toDatetime: '',
    ...overrides,
  })

  it('produces correct structure with no overrides', () => {
    const items: AddOnItem[] = [makeAddOnItem()]
    const payloads: Record<string, AddOnPayload> = { 'local-1': makePayload() }

    const result = toBillingItems(items, payloads)

    expect(result).toEqual({
      addons: [
        {
          type: 'addon',
          id: 'addon-1',
          localId: 'local-1',
          payload: { ...makePayload(), position: 1 },
          overrides: {},
        },
      ],
    })
  })

  it('detects overrides when user changes values', () => {
    const items: AddOnItem[] = [
      makeAddOnItem({
        invoiceDisplayName: 'Custom Name',
        units: '3',
        unitAmountCents: '60000',
        totalAmount: '180000',
        description: 'Custom desc',
        fromDatetime: '2026-04-01',
        toDatetime: '2026-06-30',
      }),
    ]
    const payloads: Record<string, AddOnPayload> = { 'local-1': makePayload() }

    const result = toBillingItems(items, payloads)

    expect(result.addons[0].overrides).toEqual({
      invoice_display_name: 'Custom Name',
      units: 3,
      unit_amount_cents: 60000,
      total_amount_cents: 180000,
      description: 'Custom desc',
      from_datetime: '2026-04-01',
      to_datetime: '2026-06-30',
    })
  })

  it('assigns position based on array index', () => {
    const items: AddOnItem[] = [
      makeAddOnItem({ localId: 'local-a', addOnId: 'a' }),
      makeAddOnItem({ localId: 'local-b', addOnId: 'b' }),
    ]
    const payloads: Record<string, AddOnPayload> = {
      'local-a': makePayload({ code: 'a' }),
      'local-b': makePayload({ code: 'b' }),
    }

    const result = toBillingItems(items, payloads)

    expect(result.addons[0].payload.position).toBe(1)
    expect(result.addons[1].payload.position).toBe(2)
  })

  it('converts string form values to numbers', () => {
    const items: AddOnItem[] = [
      makeAddOnItem({ units: '5', unitAmountCents: '10000', totalAmount: '50001' }),
    ]
    const payloads: Record<string, AddOnPayload> = { 'local-1': makePayload() }

    const result = toBillingItems(items, payloads)

    // units changed from 1 to 5, so it's an override
    expect(result.addons[0].overrides.units).toBe(5)
    expect(result.addons[0].overrides.unit_amount_cents).toBe(10000)
    expect(result.addons[0].overrides.total_amount_cents).toBe(50001)
  })

  it('does not include unchanged fields in overrides', () => {
    const items: AddOnItem[] = [
      makeAddOnItem({
        description: 'One-time setup', // same as payload
        invoiceDisplayName: 'Setup Fee', // same as payload
      }),
    ]
    const payloads: Record<string, AddOnPayload> = { 'local-1': makePayload() }

    const result = toBillingItems(items, payloads)

    expect(result.addons[0].overrides).toEqual({})
  })

  it('handles empty from/to datetime (no override when payload is null)', () => {
    const items: AddOnItem[] = [makeAddOnItem({ fromDatetime: '', toDatetime: '' })]
    const payloads: Record<string, AddOnPayload> = {
      'local-1': makePayload({ from_datetime: null, to_datetime: null }),
    }

    const result = toBillingItems(items, payloads)

    expect(result.addons[0].overrides).toEqual({})
  })

  it('handles duplicate addOnIds with different localIds', () => {
    const items: AddOnItem[] = [
      makeAddOnItem({ localId: 'local-x', addOnId: 'addon-1', units: '2' }),
      makeAddOnItem({ localId: 'local-y', addOnId: 'addon-1', units: '5' }),
    ]
    const payloads: Record<string, AddOnPayload> = {
      'local-x': makePayload(),
      'local-y': makePayload(),
    }

    const result = toBillingItems(items, payloads)

    expect(result.addons).toHaveLength(2)
    // Both use the same catalog ID
    expect(result.addons[0].id).toBe('addon-1')
    expect(result.addons[1].id).toBe('addon-1')
    // Each has its own position
    expect(result.addons[0].payload.position).toBe(1)
    expect(result.addons[1].payload.position).toBe(2)
    // Each has independent overrides based on its own localId payload
    expect(result.addons[0].overrides.units).toBe(2)
    expect(result.addons[1].overrides.units).toBe(5)
  })
})

describe('fromBillingItems', () => {
  let uuidCounter: number

  beforeEach(() => {
    uuidCounter = 0
    jest.spyOn(crypto, 'randomUUID').mockImplementation(() => {
      uuidCounter++

      return `mock-uuid-${uuidCounter}` as ReturnType<typeof crypto.randomUUID>
    })
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  const makeBillingItems = (): BillingItemsPayload => ({
    addons: [
      {
        type: 'addon',
        id: 'addon-1',
        payload: {
          position: 1,
          code: 'setup',
          name: 'Setup Fee',
          description: 'One-time setup',
          units: 1,
          unit_amount_cents: 50000,
          total_amount_cents: 50000,
          invoice_display_name: 'Setup Fee',
          from_datetime: null,
          to_datetime: null,
          tax_codes: [],
        },
        overrides: {},
      },
    ],
  })

  it('reconstructs entities keyed by localId from payload with no overrides', () => {
    const result = fromBillingItems(makeBillingItems())

    const localId = result.addOnItems[0].localId

    expect(localId).toBe('mock-uuid-1')
    expect(result.entities[localId]).toEqual({
      entityId: localId,
      entityType: 'addOn',
      name: 'Setup Fee',
      invoiceDisplayName: 'Setup Fee',
      code: 'setup',
      description: 'One-time setup',
      units: '1',
      unitAmountCents: '50000',
      totalAmount: '50000',
      fromDatetime: '',
      toDatetime: '',
    })
  })

  it('merges overrides onto payload for effective values', () => {
    const billingItems: BillingItemsPayload = {
      addons: [
        {
          type: 'addon',
          id: 'addon-1',
          payload: {
            position: 1,
            code: 'setup',
            name: 'Setup Fee',
            description: 'One-time setup',
            units: 1,
            unit_amount_cents: 50000,
            total_amount_cents: 50000,
            invoice_display_name: 'Setup Fee',
            from_datetime: null,
            to_datetime: null,
            tax_codes: [],
          },
          overrides: {
            invoice_display_name: 'Custom Name',
            units: 3,
            unit_amount_cents: 60000,
            total_amount_cents: 180000,
            from_datetime: '2026-04-01',
            to_datetime: '2026-06-30',
          },
        },
      ],
    }

    const result = fromBillingItems(billingItems)

    const localId = result.addOnItems[0].localId

    expect(result.entities[localId].invoiceDisplayName).toBe('Custom Name')
    expect(result.entities[localId].units).toBe('3')
    expect(result.entities[localId].unitAmountCents).toBe('60000')
    expect(result.entities[localId].totalAmount).toBe('180000')
    expect(result.entities[localId].fromDatetime).toBe('2026-04-01')
    expect(result.entities[localId].toDatetime).toBe('2026-06-30')
  })

  it('reconstructs addOnItems with localId and addOnId for form state', () => {
    const result = fromBillingItems(makeBillingItems())

    expect(result.addOnItems).toEqual([
      {
        localId: 'mock-uuid-1',
        addOnId: 'addon-1',
        name: 'Setup Fee',
        invoiceDisplayName: 'Setup Fee',
        code: 'setup',
        description: 'One-time setup',
        units: '1',
        unitAmountCents: '50000',
        totalAmount: '50000',
        fromDatetime: '',
        toDatetime: '',
      },
    ])
  })

  it('preserves original payloads keyed by localId for future diff', () => {
    const billingItems = makeBillingItems()
    const result = fromBillingItems(billingItems)

    const localId = result.addOnItems[0].localId

    expect(result.originalPayloads[localId]).toEqual(billingItems.addons?.[0].payload)
  })

  it('sorts by position', () => {
    const billingItems: BillingItemsPayload = {
      addons: [
        {
          type: 'addon',
          id: 'addon-b',
          payload: {
            position: 2,
            code: 'b',
            name: 'B',
            description: '',
            units: 1,
            unit_amount_cents: 100,
            total_amount_cents: 100,
            invoice_display_name: 'B',
            from_datetime: null,
            to_datetime: null,
            tax_codes: [],
          },
          overrides: {},
        },
        {
          type: 'addon',
          id: 'addon-a',
          payload: {
            position: 1,
            code: 'a',
            name: 'A',
            description: '',
            units: 1,
            unit_amount_cents: 200,
            total_amount_cents: 200,
            invoice_display_name: 'A',
            from_datetime: null,
            to_datetime: null,
            tax_codes: [],
          },
          overrides: {},
        },
      ],
    }

    const result = fromBillingItems(billingItems)

    expect(result.addOnItems[0].addOnId).toBe('addon-a')
    expect(result.addOnItems[1].addOnId).toBe('addon-b')
  })

  it('handles empty addons array', () => {
    const result = fromBillingItems({ addons: [] })

    expect(result.entities).toEqual({})
    expect(result.addOnItems).toEqual([])
    expect(result.originalPayloads).toEqual({})
  })

  it('handles duplicate addOnIds as separate entries with unique localIds', () => {
    const billingItems: BillingItemsPayload = {
      addons: [
        {
          type: 'addon',
          id: 'addon-1',
          payload: {
            position: 1,
            code: 'setup',
            name: 'Setup Fee',
            description: 'One-time setup',
            units: 1,
            unit_amount_cents: 50000,
            total_amount_cents: 50000,
            invoice_display_name: 'Setup Fee',
            from_datetime: null,
            to_datetime: null,
            tax_codes: [],
          },
          overrides: {},
        },
        {
          type: 'addon',
          id: 'addon-1',
          payload: {
            position: 2,
            code: 'setup',
            name: 'Setup Fee',
            description: 'One-time setup',
            units: 3,
            unit_amount_cents: 50000,
            total_amount_cents: 150000,
            invoice_display_name: 'Setup Fee',
            from_datetime: null,
            to_datetime: null,
            tax_codes: [],
          },
          overrides: { units: 5 },
        },
      ],
    }

    const result = fromBillingItems(billingItems)

    // Both items share the same addOnId but have distinct localIds
    expect(result.addOnItems).toHaveLength(2)
    expect(result.addOnItems[0].addOnId).toBe('addon-1')
    expect(result.addOnItems[1].addOnId).toBe('addon-1')
    expect(result.addOnItems[0].localId).toBe('mock-uuid-1')
    expect(result.addOnItems[1].localId).toBe('mock-uuid-2')

    // Each entry is keyed separately in entities and originalPayloads
    const localId1 = result.addOnItems[0].localId
    const localId2 = result.addOnItems[1].localId

    expect(result.entities[localId1]).toBeDefined()
    expect(result.entities[localId2]).toBeDefined()
    expect(result.entities[localId1].units).toBe('1')
    expect(result.entities[localId2].units).toBe('5') // override applied

    expect(result.originalPayloads[localId1]).toBeDefined()
    expect(result.originalPayloads[localId2]).toBeDefined()
    expect(result.originalPayloads[localId1]).not.toBe(result.originalPayloads[localId2])
  })
})

describe('buildPreviewEntities', () => {
  let uuidCounter: number

  beforeEach(() => {
    uuidCounter = 0
    jest.spyOn(crypto, 'randomUUID').mockImplementation(() => {
      uuidCounter++

      return `mock-uuid-${uuidCounter}` as ReturnType<typeof crypto.randomUUID>
    })
  })

  afterEach(() => {
    jest.restoreAllMocks()
  })

  const makeBillingItems = (
    overrides: Partial<NonNullable<BillingItemsPayload['addons']>[number]> = {},
  ): BillingItemsPayload => ({
    addons: [
      {
        type: 'addon',
        id: 'addon-1',
        payload: {
          position: 1,
          code: 'setup',
          name: 'Setup Fee',
          description: 'One-time setup',
          units: 1,
          unit_amount_cents: 50000,
          total_amount_cents: 50000,
          invoice_display_name: 'Setup Fee',
          from_datetime: null,
          to_datetime: null,
          tax_codes: [],
        },
        overrides: {},
        ...overrides,
      },
    ],
  })

  it('keys entities by both localId and catalog addOnId so legacy content blocks resolve', () => {
    // Content blocks that predate localEntityIds reference add-ons by catalog
    // entityIds; the preview must resolve them even when no localId is persisted.
    const entities = buildPreviewEntities(makeBillingItems())

    const localId = 'mock-uuid-1'

    expect(entities[localId]).toBeDefined()
    expect(entities['addon-1']).toBeDefined()
    expect(entities['addon-1']).toEqual(entities[localId])
    expect(entities['addon-1'].name).toBe('Setup Fee')
  })

  it('keys entities by saved localId and catalog addOnId when localId is persisted', () => {
    const entities = buildPreviewEntities(makeBillingItems({ localId: 'saved-local-1' }))

    expect(entities['saved-local-1']).toBeDefined()
    expect(entities['addon-1']).toEqual(entities['saved-local-1'])
  })

  it('returns an empty map for no addons', () => {
    expect(buildPreviewEntities({ addons: [] })).toEqual({})
  })

  it('includes the plan entity (with PlanPreviewData) when billingItems.plans is present, alongside addons', () => {
    const billingItems = {
      addons: [], // keep empty or reuse an existing addon fixture from this suite
      plans: [
        {
          type: 'plan',
          id: 'plan-1',
          overrides: {},
          payload: {
            position: 0,
            code: 'p',
            name: 'P',
            description: '',
            subscription_external_id: null,
            subscription_name: null,
            billing_time: 'calendar',
            start_date: null,
            end_date: null,
            payment_method_id: null,
            invoice_custom_footer: null,
            interval: 'monthly',
            amount_cents: '13050',
            amount_currency: 'USD',
            pay_in_advance: true,
            charges: [],
            fixed_charges: [],
            minimum_commitment: null,
          },
        },
      ],
    } as any

    const entities = buildPreviewEntities(billingItems)

    expect(entities['plan-1']).toBeDefined()
    expect(entities['plan-1'].entityType).toBe('plan')
    expect(entities['plan-1'].plan?.rows.length).toBeGreaterThan(0)
  })
})
