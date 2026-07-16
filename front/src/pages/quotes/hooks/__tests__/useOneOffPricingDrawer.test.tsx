import { act, renderHook } from '@testing-library/react'
import { ReactNode } from 'react'
import { z } from 'zod'

import { fromBillingItems, toBillingItems } from '~/core/serializers/serializeQuoteBillingItems'
import { CurrencyEnum } from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

import { useOneOffPricingDrawer } from '../useOneOffPricingDrawer'

// --- Mocks ---

const mockCryptoRandomUUID = jest.fn(() => 'mock-uuid-1')

Object.defineProperty(globalThis, 'crypto', {
  value: {
    ...globalThis.crypto,
    randomUUID: mockCryptoRandomUUID,
  },
  writable: true,
})

const mockFormDrawerOpen = jest.fn()
const mockFormDrawerClose = jest.fn()

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => key,
  }),
}))

jest.mock('~/hooks/useOrganizationInfos', () => ({
  useOrganizationInfos: () => ({
    organization: { defaultCurrency: 'USD' },
  }),
}))

// drawerStack.ts uses import.meta.hot — mock the entire useDrawer module instead
jest.mock('~/components/drawers/useDrawer', () => ({
  useFormDrawer: () => ({
    open: mockFormDrawerOpen,
    close: mockFormDrawerClose,
  }),
  useDrawer: () => ({
    open: jest.fn(),
    close: jest.fn(),
  }),
}))

jest.mock('~/components/drawers/drawerStack', () => ({
  drawerStack: {
    push: jest.fn(),
    remove: jest.fn(),
    subscribe: jest.fn(() => jest.fn()),
    onClear: jest.fn(() => jest.fn()),
    clearAll: jest.fn(),
    getSnapshot: jest.fn(() => []),
  },
}))

const mockFormReset = jest.fn()
const mockHandleSubmit = jest.fn()

// Capture the onSubmit and setFieldValue calls from useAppForm
let capturedOnSubmit: ((args: { value: Record<string, unknown> }) => void) | null = null
const mockSetFieldValue = jest.fn()
let mockFormValues = { planId: '', addOnItems: [] as Record<string, unknown>[] }

jest.mock('@tanstack/react-form', () => ({
  revalidateLogic: () => ({}),
  createFormHookContexts: jest.fn(() => ({
    fieldContext: {},
    useFieldContext: jest.fn(),
    formContext: {},
    useFormContext: jest.fn(),
  })),
}))

jest.mock('~/hooks/forms/useAppform', () => ({
  useAppForm: (config: Record<string, unknown>) => {
    if (typeof config.onSubmit === 'function') {
      capturedOnSubmit = config.onSubmit as typeof capturedOnSubmit
    }

    return {
      reset: mockFormReset,
      handleSubmit: mockHandleSubmit,
      setFieldValue: mockSetFieldValue,
      state: {
        canSubmit: true,
        get values() {
          return mockFormValues
        },
      },
      store: {
        subscribe: jest.fn(() => jest.fn()),
        getState: () => ({
          values: mockFormValues,
          canSubmit: true,
        }),
      },
      AppField: () => null,
      AppForm: () => null,
      Subscribe: () => null,
    }
  },
}))

jest.mock('~/core/serializers/serializeQuoteBillingItems', () => ({
  fromBillingItems: jest.fn(),
  toBillingItems: jest.fn(),
}))

jest.mock('~/components/designSystem/RichTextEditor/PricingBlock/PricingDrawerContent', () => ({
  __esModule: true,
  default: () => null,
}))

jest.mock('../useSubscriptionPricingDrawer', () => ({
  useSubscriptionPricingDrawer: () => ({
    onPricingCommand: jest.fn(),
    isPricingDisabled: jest.fn(() => false),
    entities: {},
    syncEntitiesWithBlocks: jest.fn(() => null),
  }),
}))

const mockedFromBillingItems = fromBillingItems as jest.Mock
const mockedToBillingItems = toBillingItems as jest.Mock

const wrapper = ({ children }: { children: ReactNode }) => (
  <AllTheProviders>{children}</AllTheProviders>
)

// --- Helpers ---

const mockAddOnPayload = {
  position: 1,
  code: 'setup',
  name: 'Setup Fee',
  description: 'One-time setup fee',
  units: 1,
  unit_amount_cents: 10000,
  total_amount_cents: 10000,
  invoice_display_name: 'Setup',
  from_datetime: null,
  to_datetime: null,
  tax_codes: ['vat_20'],
}

const mockBillingItemsPayload = {
  addons: [
    {
      type: 'addon' as const,
      id: 'addon-1',
      payload: mockAddOnPayload,
      overrides: {},
    },
  ],
}

// --- Tests ---

describe('useOneOffPricingDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
    capturedOnSubmit = null
    mockFormValues = { planId: '', addOnItems: [] }
    mockCryptoRandomUUID.mockReturnValue('mock-uuid-1')
  })

  describe('GIVEN the hook is called', () => {
    describe('WHEN it returns', () => {
      it('THEN should return onPricingCommand, entities, and syncEntitiesWithBlocks', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        expect(typeof result.current.onPricingCommand).toBe('function')
        expect(result.current.entities).toBeDefined()
        expect(typeof result.current.syncEntitiesWithBlocks).toBe('function')
      })
    })

    describe('WHEN no initialBillingItems is provided', () => {
      it('THEN entities should be an empty object', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        expect(result.current.entities).toEqual({})
      })
    })
  })

  describe('GIVEN initialBillingItems is provided', () => {
    describe('WHEN the hook mounts with billing items containing add-ons', () => {
      it('THEN should call fromBillingItems and populate entities', () => {
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              invoiceDisplayName: 'Setup',
              code: 'setup',
              description: 'One-time setup fee',
              units: '1',
              unitAmountCents: '10000',
              totalAmount: '10000',
              fromDatetime: '',
              toDatetime: '',
            },
          },
          originalPayloads: {
            'local-uuid-1': mockAddOnPayload,
          },
          addOnItems: [
            {
              localId: 'local-uuid-1',
              addOnId: 'addon-1',
              name: 'Setup Fee',
              invoiceDisplayName: 'Setup',
              code: 'setup',
              description: 'One-time setup fee',
              units: '1',
              unitAmountCents: '10000',
              totalAmount: '10000',
              fromDatetime: '',
              toDatetime: '',
            },
          ],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        expect(mockedFromBillingItems).toHaveBeenCalledWith(mockBillingItemsPayload)
        // Entities should include both localId-keyed and backward-compat catalog-keyed entries
        expect(result.current.entities).toEqual({
          'local-uuid-1': expect.objectContaining({
            entityId: 'local-uuid-1',
            entityType: 'addOn',
            name: 'Setup Fee',
            code: 'setup',
          }),
          'addon-1': expect.objectContaining({
            entityId: 'local-uuid-1',
            entityType: 'addOn',
            name: 'Setup Fee',
            code: 'setup',
          }),
        })
      })
    })

    describe('WHEN initialBillingItems has no addons', () => {
      it('THEN should not call fromBillingItems', () => {
        const emptyPayload = { addons: [] }

        renderHook(() => useOneOffPricingDrawer(emptyPayload), { wrapper })

        expect(mockedFromBillingItems).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN onPricingCommand is called', () => {
    describe('WHEN called with an onSave callback and no editData', () => {
      it('THEN should open the form drawer', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        expect(mockFormDrawerOpen).toHaveBeenCalledWith(
          expect.objectContaining({
            title: expect.any(String),
            form: expect.objectContaining({
              id: expect.any(String),
              submit: expect.any(Function),
            }),
            children: expect.anything(),
          }),
        )
      })
    })

    describe('WHEN called for a one-off order type', () => {
      it('THEN should open the form drawer with the add-on selection title', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        expect(mockFormDrawerOpen).toHaveBeenCalledTimes(1)
        const callArgs = mockFormDrawerOpen.mock.calls[0][0]

        // The title for one-off types should be the add-on selection key
        expect(callArgs.title).toBe('text_17799586575620rdqef1d7dq')
      })
    })
  })

  describe('GIVEN isPricingDisabled is called', () => {
    describe('WHEN order type is one-off and entities exist', () => {
      it('THEN should return true', () => {
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
            },
          },
          originalPayloads: {
            'local-uuid-1': mockAddOnPayload,
          },
          addOnItems: [
            { localId: 'local-uuid-1', addOnId: 'addon-1', name: 'Setup Fee', code: 'setup' },
          ],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        expect(result.current.isPricingDisabled()).toBe(true)
      })
    })

    describe('WHEN order type is one-off and no entities exist', () => {
      it('THEN should return false', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        expect(result.current.isPricingDisabled()).toBe(false)
      })
    })
  })

  describe('GIVEN onPricingCommand is called for a one-off quote with existing entities', () => {
    describe('WHEN it is a new insertion (no editData)', () => {
      it('THEN should not open the form drawer', () => {
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
            },
          },
          originalPayloads: {
            'local-uuid-1': mockAddOnPayload,
          },
          addOnItems: [
            { localId: 'local-uuid-1', addOnId: 'addon-1', name: 'Setup Fee', code: 'setup' },
          ],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        expect(mockFormDrawerOpen).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN syncEntitiesWithBlocks is called', () => {
    describe('WHEN all entities are referenced in blocks (no backward-compat entries)', () => {
      it('THEN should return null indicating no orphans', () => {
        // Return entities keyed only by localId — no addOnItems means no backward-compat entries
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
            },
          },
          originalPayloads: {
            'local-uuid-1': mockAddOnPayload,
          },
          addOnItems: [],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        const blocks = [
          {
            pricingType: 'addOns' as const,
            entityIds: ['addon-1'],
            localEntityIds: ['local-uuid-1'],
          },
        ]

        let syncResult: unknown

        act(() => {
          syncResult = result.current.syncEntitiesWithBlocks(blocks)
        })

        expect(syncResult).toBeNull()
      })
    })

    describe('WHEN a block references an add-on by localEntityId and the catalog alias also exists in state', () => {
      it('THEN should treat the add-on as active and return null (the alias is not a real orphan)', () => {
        // Regression: after a save→refetch, hydration dual-keys state by both
        // localId and the catalog addOnId. A block still references the add-on
        // via its localEntityId, so the addOnId alias must NOT be mistaken for a
        // deleted add-on — otherwise a no-op sync (e.g. on the editor preview
        // toggle) rebuilds from catalog payloads and wipes the user's overrides.
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
            },
          },
          originalPayloads: {
            'local-uuid-1': mockAddOnPayload,
          },
          addOnItems: [
            { localId: 'local-uuid-1', addOnId: 'addon-1', name: 'Setup Fee', code: 'setup' },
          ],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        // After hydration, entities has both 'local-uuid-1' and 'addon-1' (backward-compat)
        expect(result.current.entities).toHaveProperty('local-uuid-1')
        expect(result.current.entities).toHaveProperty('addon-1')

        const blocks = [
          {
            pricingType: 'addOns' as const,
            entityIds: ['addon-1'],
            localEntityIds: ['local-uuid-1'],
          },
        ]

        let syncResult: unknown

        act(() => {
          syncResult = result.current.syncEntitiesWithBlocks(blocks)
        })

        // No genuine deletion → no save, and both keys are retained (the alias
        // is still needed to resolve legacy blocks that reference the catalog id)
        expect(syncResult).toBeNull()
        expect(mockedToBillingItems).not.toHaveBeenCalled()
        expect(result.current.entities).toHaveProperty('local-uuid-1')
        expect(result.current.entities).toHaveProperty('addon-1')
      })
    })

    describe('WHEN a block has been deleted so one add-on is no longer referenced', () => {
      it('THEN should remove the orphaned add-on and rebuild survivors via toBillingItems (preserving overrides)', () => {
        const secondPayload = {
          ...mockAddOnPayload,
          position: 2,
          code: 'onboarding',
          name: 'Onboarding Fee',
        }

        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
              units: '2',
              unitAmountCents: '2000',
              totalAmount: '4000',
            },
            'local-uuid-2': {
              entityId: 'local-uuid-2',
              entityType: 'addOn',
              name: 'Onboarding Fee',
              code: 'onboarding',
            },
          },
          originalPayloads: {
            'local-uuid-1': mockAddOnPayload,
            'local-uuid-2': secondPayload,
          },
          addOnItems: [
            { localId: 'local-uuid-1', addOnId: 'addon-1', name: 'Setup Fee', code: 'setup' },
            {
              localId: 'local-uuid-2',
              addOnId: 'addon-2',
              name: 'Onboarding Fee',
              code: 'onboarding',
            },
          ],
        })

        const rebuilt = {
          addons: [
            {
              type: 'addon' as const,
              id: 'addon-1',
              localId: 'local-uuid-1',
              payload: mockAddOnPayload,
              overrides: { units: 2, unit_amount_cents: 2000, total_amount_cents: 4000 },
            },
          ],
        }

        mockedToBillingItems.mockReturnValueOnce(rebuilt)

        const billingItemsWithTwo = {
          addons: [
            {
              type: 'addon' as const,
              id: 'addon-1',
              payload: mockAddOnPayload,
              overrides: {},
            },
            {
              type: 'addon' as const,
              id: 'addon-2',
              payload: secondPayload,
              overrides: {},
            },
          ],
        }

        const { result } = renderHook(() => useOneOffPricingDrawer(billingItemsWithTwo), {
          wrapper,
        })

        // Blocks only reference local-uuid-1, so local-uuid-2 becomes orphaned
        const blocks = [
          {
            pricingType: 'addOns' as const,
            entityIds: ['addon-1'],
            localEntityIds: ['local-uuid-1'],
          },
        ]

        let syncResult: unknown

        act(() => {
          syncResult = result.current.syncEntitiesWithBlocks(blocks)
        })

        // Survivors are rebuilt through toBillingItems so overrides are preserved
        expect(syncResult).toBe(rebuilt)
        expect(mockedToBillingItems).toHaveBeenCalledTimes(1)

        const [survivingItems] = mockedToBillingItems.mock.calls[0]

        // Only the surviving add-on is passed, carrying its localId + catalog addOnId
        // and its edited values (not catalog defaults)
        expect(survivingItems).toHaveLength(1)
        expect(survivingItems[0]).toMatchObject({
          localId: 'local-uuid-1',
          addOnId: 'addon-1',
          units: '2',
          unitAmountCents: '2000',
          totalAmount: '4000',
        })

        // Orphaned add-on removed from state, including its backward-compat alias
        expect(result.current.entities).toHaveProperty('local-uuid-1')
        expect(result.current.entities).not.toHaveProperty('local-uuid-2')
        expect(result.current.entities).not.toHaveProperty('addon-2')
      })
    })

    describe('WHEN there are no entities at all', () => {
      it('THEN should return null', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        const blocks = [{ pricingType: 'addOns' as const, entityIds: [], localEntityIds: [] }]

        let syncResult: unknown

        act(() => {
          syncResult = result.current.syncEntitiesWithBlocks(blocks)
        })

        expect(syncResult).toBeNull()
      })
    })
  })

  describe('GIVEN onPricingCommand is called with editData', () => {
    describe('WHEN it is a one-off order with pricingType addOns and existing entities', () => {
      it('THEN should reset the form with initialAddOnItems from entity data', () => {
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              invoiceDisplayName: 'Setup',
              code: 'setup',
              description: 'One-time setup',
              units: '2',
              unitAmountCents: '5000',
              totalAmount: '10000',
              fromDatetime: '2026-01-01T00:00:00.000Z',
              toDatetime: '2026-01-31T23:59:59.999Z',
            },
          },
          originalPayloads: { 'local-uuid-1': mockAddOnPayload },
          addOnItems: [
            {
              localId: 'local-uuid-1',
              addOnId: 'addon-1',
              name: 'Setup Fee',
              invoiceDisplayName: 'Setup',
              code: 'setup',
              description: 'One-time setup',
              units: '2',
              unitAmountCents: '5000',
              totalAmount: '10000',
              fromDatetime: '2026-01-01T00:00:00.000Z',
              toDatetime: '2026-01-31T23:59:59.999Z',
            },
          ],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: {
              pricingType: 'addOns',
              entityIds: ['addon-1'],
              localEntityIds: ['local-uuid-1'],
            },
          })
        })

        expect(mockFormReset).toHaveBeenCalledWith(
          expect.objectContaining({
            planId: '',
            addOnItems: expect.arrayContaining([
              expect.objectContaining({
                localId: 'local-uuid-1',
                addOnId: 'addon-1',
                name: 'Setup Fee',
                code: 'setup',
                units: '2',
                unitAmountCents: '5000',
              }),
            ]),
          }),
          { keepDefaultValues: true },
        )
        expect(mockFormDrawerOpen).toHaveBeenCalled()
      })
    })

    describe('WHEN it is a one-off with editData and existing entities', () => {
      it('THEN should still open the drawer (bypass the one-off guard for edits)', () => {
        mockedFromBillingItems.mockReturnValue({
          entities: {
            'local-uuid-1': {
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              code: 'setup',
            },
          },
          originalPayloads: { 'local-uuid-1': mockAddOnPayload },
          addOnItems: [
            { localId: 'local-uuid-1', addOnId: 'addon-1', name: 'Setup Fee', code: 'setup' },
          ],
        })

        const { result } = renderHook(() => useOneOffPricingDrawer(mockBillingItemsPayload), {
          wrapper,
        })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: {
              pricingType: 'addOns',
              entityIds: ['addon-1'],
              localEntityIds: ['local-uuid-1'],
            },
          })
        })

        // Edit mode should bypass the one-off single-block guard
        expect(mockFormDrawerOpen).toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN customerCurrency is provided', () => {
    describe('WHEN onPricingCommand is called', () => {
      it('THEN should pass the customerCurrency to the drawer content instead of organization default', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(undefined, CurrencyEnum.Eur), {
          wrapper,
        })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        const callArgs = mockFormDrawerOpen.mock.calls[0][0]
        const childProps = callArgs.children.props

        expect(childProps.currency).toBe(CurrencyEnum.Eur)
      })
    })

    describe('WHEN customerCurrency is null', () => {
      it('THEN should fall back to organization defaultCurrency', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(undefined, null), { wrapper })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        const callArgs = mockFormDrawerOpen.mock.calls[0][0]
        const childProps = callArgs.children.props

        expect(childProps.currency).toBe('USD')
      })
    })

    describe('WHEN customerCurrency is not provided', () => {
      it('THEN should use organization defaultCurrency', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        const callArgs = mockFormDrawerOpen.mock.calls[0][0]
        const childProps = callArgs.children.props

        expect(childProps.currency).toBe('USD')
      })
    })
  })

  describe('GIVEN the form onSubmit handler is invoked', () => {
    describe('WHEN submitting for a one-off with confirmed add-on items', () => {
      it('THEN should call onSave with add-on entity data and billing items', () => {
        const mockOnSave = jest.fn()

        const { result } = renderHook(() => useOneOffPricingDrawer(), {
          wrapper,
        })

        act(() => {
          result.current.onPricingCommand({
            onSave: mockOnSave,
            editData: undefined,
          })
        })

        // Simulate confirmed add-on items (now includes localId)
        mockFormValues = {
          planId: '',
          addOnItems: [
            {
              localId: 'local-uuid-1',
              addOnId: 'addon-1',
              name: 'Setup Fee',
              invoiceDisplayName: 'Setup',
              code: 'setup',
              description: 'Desc',
              units: '2',
              unitAmountCents: '5000',
              totalAmount: '10000',
              fromDatetime: '2026-01-01',
              toDatetime: '2026-01-31',
            },
          ],
        }

        act(() => {
          capturedOnSubmit?.({ value: mockFormValues })
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          {
            pricingType: 'addOns',
            entityIds: ['addon-1'],
            localEntityIds: ['local-uuid-1'],
          },
          expect.objectContaining({
            'local-uuid-1': expect.objectContaining({
              entityId: 'local-uuid-1',
              entityType: 'addOn',
              name: 'Setup Fee',
              units: '2',
            }),
          }),
          undefined, // toBillingItems is mocked, returns undefined
        )

        // Entities should be updated (keyed by localId)
        expect(result.current.entities).toHaveProperty('local-uuid-1')
      })
    })

    describe('WHEN submitting for a one-off with no confirmed add-on items', () => {
      it('THEN should not call onSave', () => {
        const mockOnSave = jest.fn()

        const { result } = renderHook(() => useOneOffPricingDrawer(), {
          wrapper,
        })

        act(() => {
          result.current.onPricingCommand({
            onSave: mockOnSave,
            editData: undefined,
          })
        })

        // Only pending items (empty addOnId)
        mockFormValues = {
          planId: '',
          addOnItems: [{ localId: 'local-uuid-pending', addOnId: '', name: '', code: '' }],
        }

        act(() => {
          capturedOnSubmit?.({ value: mockFormValues })
        })

        expect(mockOnSave).not.toHaveBeenCalled()
      })
    })
  })

  describe('GIVEN the captureAddOnPayload callback', () => {
    describe('WHEN an add-on is selected in the drawer', () => {
      it('THEN should store the add-on payload for later serialization', () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        // Extract onAddOnPayloadCapture from the rendered PricingDrawerContent children
        const callArgs = mockFormDrawerOpen.mock.calls[0][0]
        const captureCallback = callArgs.children.props.onAddOnPayloadCapture

        expect(captureCallback).toBeDefined()

        // Invoke it to exercise captureAddOnPayload — first param is localId
        act(() => {
          captureCallback('local-uuid-new', {
            id: 'addon-new',
            code: 'onboarding',
            name: 'Onboarding Fee',
            description: 'One-time onboarding',
            amountCents: '7500',
            amountCurrency: 'USD',
            invoiceDisplayName: 'Onboarding',
            taxes: [{ id: 'tax-1', code: 'vat_20' }],
          })
        })

        // The payload should now be stored — verify by submitting with this add-on
        mockFormValues = {
          planId: '',
          addOnItems: [
            {
              localId: 'local-uuid-new',
              addOnId: 'addon-new',
              name: 'Onboarding Fee',
              invoiceDisplayName: 'Onboarding',
              code: 'onboarding',
              description: 'One-time onboarding',
              units: '1',
              unitAmountCents: '7500',
              totalAmount: '7500',
              fromDatetime: '2026-01-01',
              toDatetime: '2026-01-31',
            },
          ],
        }

        const mockOnSave = jest.fn()

        // Re-trigger onPricingCommand to set up the onSave ref
        act(() => {
          result.current.onPricingCommand({
            onSave: mockOnSave,
            editData: {
              pricingType: 'addOns',
              entityIds: ['addon-new'],
              localEntityIds: ['local-uuid-new'],
            },
          })
        })

        act(() => {
          capturedOnSubmit?.({ value: mockFormValues })
        })

        expect(mockOnSave).toHaveBeenCalledWith(
          expect.objectContaining({
            pricingType: 'addOns',
            entityIds: ['addon-new'],
            localEntityIds: ['local-uuid-new'],
          }),
          expect.objectContaining({
            'local-uuid-new': expect.objectContaining({ entityId: 'local-uuid-new' }),
          }),
          undefined, // toBillingItems is mocked, returns undefined
        )
      })
    })
  })

  describe('GIVEN the handleSubmit function inside onPricingCommand', () => {
    describe('WHEN form.submit is invoked from the drawer', () => {
      it('THEN should call form.handleSubmit', async () => {
        const { result } = renderHook(() => useOneOffPricingDrawer(), { wrapper })

        act(() => {
          result.current.onPricingCommand({
            onSave: jest.fn(),
            editData: undefined,
          })
        })

        const callArgs = mockFormDrawerOpen.mock.calls[0][0]

        await act(async () => {
          await callArgs.form.submit()
        })

        expect(mockHandleSubmit).toHaveBeenCalled()
      })
    })
  })
})

// --- Standalone validation schema tests (mirrors the superRefine in useOneOffPricingDrawer) ---

const pricingDrawerValidationSchema = z
  .object({
    planId: z.string(),
    addOnItems: z.array(
      z.object({
        localId: z.string(),
        addOnId: z.string(),
        name: z.string(),
        invoiceDisplayName: z.string(),
        code: z.string(),
        description: z.string(),
        units: z.string(),
        unitAmountCents: z.string(),
        totalAmount: z.string(),
        fromDatetime: z.string(),
        toDatetime: z.string(),
      }),
    ),
  })
  .superRefine((data, ctx) => {
    // Simulates one-off validation (isPlanSelection = false)
    const confirmed = data.addOnItems.filter((item) => item.addOnId)

    if (confirmed.length === 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'At least one add-on required',
        path: ['addOnItems'],
      })
      return
    }

    data.addOnItems.forEach((item, index) => {
      if (!item.addOnId) return

      if (!item.units || item.units === '0') {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Units required',
          path: ['addOnItems', index, 'units'],
        })
      }

      if (!item.unitAmountCents) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Unit price required',
          path: ['addOnItems', index, 'unitAmountCents'],
        })
      }
    })
  })

const validAddOnItem = {
  localId: 'local-uuid-valid',
  addOnId: 'addon-1',
  name: 'Setup Fee',
  invoiceDisplayName: 'Setup',
  code: 'setup',
  description: 'desc',
  units: '2',
  unitAmountCents: '5000',
  totalAmount: '10000',
  fromDatetime: '2026-01-01T00:00:00.000Z',
  toDatetime: '2026-01-31T23:59:59.999Z',
}

const pendingAddOnItem = {
  ...validAddOnItem,
  localId: 'local-uuid-pending',
  addOnId: '', // pending — no addOnId selected yet
}

describe('pricingDrawer validation schema (one-off path)', () => {
  describe('GIVEN valid data with a confirmed add-on', () => {
    describe('WHEN the schema validates', () => {
      it('THEN should pass validation', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [validAddOnItem],
        })

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN no confirmed add-ons (all have empty addOnId)', () => {
    describe('WHEN the schema validates', () => {
      it('THEN should fail with addOnItems error', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [pendingAddOnItem],
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const addOnError = result.error.issues.find((issue) => issue.path.includes('addOnItems'))

          expect(addOnError).toBeDefined()
        }
      })
    })
  })

  describe('GIVEN a confirmed add-on with missing units', () => {
    describe('WHEN the schema validates', () => {
      it('THEN should fail with units error', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [{ ...validAddOnItem, units: '' }],
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const unitsError = result.error.issues.find((issue) => issue.path.includes('units'))

          expect(unitsError).toBeDefined()
        }
      })
    })
  })

  describe('GIVEN a confirmed add-on with units equal to zero', () => {
    describe('WHEN the schema validates', () => {
      it('THEN should fail with units error', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [{ ...validAddOnItem, units: '0' }],
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const unitsError = result.error.issues.find((issue) => issue.path.includes('units'))

          expect(unitsError).toBeDefined()
        }
      })
    })
  })

  describe('GIVEN a confirmed add-on with missing unitAmountCents', () => {
    describe('WHEN the schema validates', () => {
      it('THEN should fail with unitAmountCents error', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [{ ...validAddOnItem, unitAmountCents: '' }],
        })

        expect(result.success).toBe(false)

        if (!result.success) {
          const priceError = result.error.issues.find((issue) =>
            issue.path.includes('unitAmountCents'),
          )

          expect(priceError).toBeDefined()
        }
      })
    })
  })

  describe('GIVEN a mix of pending and confirmed items', () => {
    describe('WHEN the confirmed item is valid', () => {
      it('THEN should pass validation (pending items are skipped)', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [pendingAddOnItem, validAddOnItem],
        })

        expect(result.success).toBe(true)
      })
    })
  })

  describe('GIVEN an empty addOnItems array', () => {
    describe('WHEN the schema validates', () => {
      it('THEN should fail with no confirmed add-ons error', () => {
        const result = pricingDrawerValidationSchema.safeParse({
          planId: '',
          addOnItems: [],
        })

        expect(result.success).toBe(false)
      })
    })
  })
})
