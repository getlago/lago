import { render as plainRender, renderHook, screen } from '@testing-library/react'
import { ReactNode } from 'react'

import {
  VIEW_FEE_DETAILS_DRAWER_TEST_ID,
  VIEW_FEE_DETAILS_HEADER_TEST_ID,
  VIEW_FEE_DETAILS_OVERVIEW_TEST_ID,
  VIEW_FEE_DETAILS_SOURCE_ITEM_TEST_ID,
} from '~/components/invoices/details/invoiceDetailsTestIds'
import {
  useViewFeeDetailsDrawer,
  ViewFeeDetailsDrawerProvider,
} from '~/components/invoices/details/ViewFeeDetailsDrawer'
import {
  CurrencyEnum,
  FeeForViewFeeDetailsDrawerFragment,
  FeeTypesEnum,
  PlanInterval,
} from '~/generated/graphql'
import { AllTheProviders } from '~/test-utils'

// Mock the underlying drawer hook so the test doesn't pull in the Vite-only
// `drawerStack` module. We capture the props passed to `drawer.open()` so we
// can render the children ourselves and assert on the body content.
const mockDrawerOpen = jest.fn()
const mockDrawerClose = jest.fn()

jest.mock('~/components/drawers/useDrawer', () => ({
  useDrawer: () => ({
    open: mockDrawerOpen,
    close: mockDrawerClose,
  }),
}))

const buildFee = (
  overrides: Partial<FeeForViewFeeDetailsDrawerFragment> = {},
): FeeForViewFeeDetailsDrawerFragment =>
  ({
    id: 'fee-abc',
    amountCents: '100000',
    amountCurrency: CurrencyEnum.Usd,
    preciseAmountCents: 1000,
    preciseCouponsAmountCents: 0,
    subTotalExcludingTaxesAmountCents: '100000',
    subTotalExcludingTaxesPreciseAmountCents: 1000,
    taxesRate: 20,
    taxesAmountCents: '20000',
    taxesPreciseAmountCents: 200,
    totalAmountCents: '120000',
    preciseTotalAmountCents: 1200,
    units: 1,
    eventsCount: '0',
    payInAdvance: false,
    feeType: FeeTypesEnum.Subscription,
    itemCode: 'plan-code',
    itemName: 'Premium Plan',
    itemType: 'Subscription',
    invoiceDisplayName: 'Premium Plan',
    properties: {
      fromDatetime: '2026-05-01T00:00:00Z',
      toDatetime: '2026-05-31T23:59:59Z',
    },
    trueUpParentFee: null,
    subscription: {
      id: 'sub-1',
      plan: { id: 'plan-1', name: 'Premium', interval: PlanInterval.Monthly },
    },
    charge: null,
    fixedCharge: null,
    addOn: null,
    presentationBreakdowns: null,
    ...overrides,
  }) as unknown as FeeForViewFeeDetailsDrawerFragment

// The hook now reads from `ViewFeeDetailsDrawerProvider`, so each test mounts
// the provider — the same shape that real consumers (e.g. InvoiceOverview) use.
const renderHookUnderTest = () =>
  renderHook(() => useViewFeeDetailsDrawer(), {
    wrapper: ({ children }) => (
      <AllTheProviders>
        <ViewFeeDetailsDrawerProvider>{children}</ViewFeeDetailsDrawerProvider>
      </AllTheProviders>
    ),
  })

// Get the children passed to the most recent drawer.open() call so we can mount
// them in isolation and assert on the actual DOM.
const getBodyFromLastOpen = (): ReactNode => {
  const lastCall = mockDrawerOpen.mock.calls[mockDrawerOpen.mock.calls.length - 1]

  return (lastCall?.[0] as { children: ReactNode } | undefined)?.children
}

describe('useViewFeeDetailsDrawer', () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  describe('GIVEN the hook is mounted but never invoked', () => {
    it('THEN should NOT call drawer.open', () => {
      renderHookUnderTest()

      expect(mockDrawerOpen).not.toHaveBeenCalled()
    })
  })

  describe('GIVEN open is invoked with a fee', () => {
    it('THEN should call drawer.open with title, children and actions', () => {
      const { result } = renderHookUnderTest()

      result.current.open(buildFee())

      expect(mockDrawerOpen).toHaveBeenCalledTimes(1)
      expect(mockDrawerOpen).toHaveBeenCalledWith(
        expect.objectContaining({
          title: expect.any(String),
          children: expect.anything(),
          actions: expect.anything(),
        }),
      )
    })
  })

  describe('GIVEN close is invoked', () => {
    it('THEN should call drawer.close', () => {
      const { result } = renderHookUnderTest()

      result.current.close()

      expect(mockDrawerClose).toHaveBeenCalledTimes(1)
    })
  })

  describe('GIVEN a fee without presentation breakdowns', () => {
    describe('WHEN the drawer body is rendered', () => {
      it.each([
        ['drawer container', VIEW_FEE_DETAILS_DRAWER_TEST_ID],
        ['header', VIEW_FEE_DETAILS_HEADER_TEST_ID],
        ['overview section', VIEW_FEE_DETAILS_OVERVIEW_TEST_ID],
        ['source item section', VIEW_FEE_DETAILS_SOURCE_ITEM_TEST_ID],
      ])('THEN should render the %s (single-view variant)', (_, testId) => {
        const { result } = renderHookUnderTest()

        result.current.open(buildFee())
        // The drawer body wraps itself in a <MemoryRouter>; use plain RTL
        // render here so we don't end up with nested Routers.
        plainRender(<>{getBodyFromLastOpen()}</>)

        expect(screen.getByTestId(testId)).toBeInTheDocument()
      })
    })
  })

  describe('GIVEN a fee with presentation breakdowns', () => {
    describe('WHEN the drawer body is rendered', () => {
      it('THEN should render Overview and Presentation group key tabs', () => {
        const { result } = renderHookUnderTest()

        result.current.open(
          buildFee({
            presentationBreakdowns: [{ presentationBy: { region: 'us-east' }, units: '60' }],
          } as unknown as Partial<FeeForViewFeeDetailsDrawerFragment>),
        )
        plainRender(<>{getBodyFromLastOpen()}</>)

        expect(screen.getByTestId(VIEW_FEE_DETAILS_OVERVIEW_TEST_ID)).toBeInTheDocument()
        expect(screen.getAllByRole('tab').length).toBeGreaterThanOrEqual(2)
      })
    })
  })

  describe('GIVEN a fee with a trueUpParentFee in the tabbed variant', () => {
    describe('WHEN the Overview tab is rendered', () => {
      it('THEN should display the parent fee id in the Parent ID row', () => {
        const { result } = renderHookUnderTest()

        result.current.open(
          buildFee({
            trueUpParentFee: { id: 'parent-fee-1' },
            presentationBreakdowns: [{ presentationBy: { region: 'us' }, units: '10' }],
          } as unknown as Partial<FeeForViewFeeDetailsDrawerFragment>),
        )
        plainRender(<>{getBodyFromLastOpen()}</>)

        expect(screen.getAllByText('parent-fee-1').length).toBeGreaterThan(0)
      })

      it('THEN should NOT render the Parent ID row when trueUpParentFee is null', () => {
        const { result } = renderHookUnderTest()

        result.current.open(
          buildFee({
            trueUpParentFee: null,
            presentationBreakdowns: [{ presentationBy: { region: 'us' }, units: '10' }],
          } as unknown as Partial<FeeForViewFeeDetailsDrawerFragment>),
        )
        plainRender(<>{getBodyFromLastOpen()}</>)

        expect(screen.queryByText('parent-fee-1')).not.toBeInTheDocument()
      })
    })
  })
})
