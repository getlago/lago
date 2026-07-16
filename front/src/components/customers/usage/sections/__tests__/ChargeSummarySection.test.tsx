import { screen } from '@testing-library/react'

import { ChargeSummarySection } from '~/components/customers/usage/sections/ChargeSummarySection'
import { VirtualizedBreakdownRows } from '~/components/customers/usage/sections/VirtualizedBreakdownRows'
import { PresentationBreakdownRow } from '~/components/customers/usage/usageDetailsHelpers'
import { CurrencyEnum } from '~/generated/graphql'
import { TranslateFunc } from '~/hooks/core/useInternationalization'
import { render } from '~/test-utils'

// The tanstack virtualizer renders 0 items under jsdom (the scroll element
// measures 0px tall), so we stub it to yield every row deterministically — we
// want to cover OUR row-rendering logic, not the virtualizer internals.
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 48,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, index) => ({ index, start: index * 48, key: index })),
    measureElement: () => {},
  }),
}))

class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}

beforeAll(() => {
  // jsdom ships no ResizeObserver; both ChargeSummarySection and the tanstack
  // virtualizer need it for the virtualized-breakdowns path.
  global.ResizeObserver = ResizeObserverMock
})

const translate = ((key: string) => key) as TranslateFunc

const baseProps = {
  currency: CurrencyEnum.Usd,
  locale: undefined,
  showProjected: false,
  translate,
  unitsHeader: 'Units header',
  amountHeader: 'Amount header',
}

describe('ChargeSummarySection', () => {
  it('renders the charge name, code, headers and inline breakdown rows', () => {
    const usage = {
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM', code: 'bm_code' },
      units: 10,
      amountCents: '1000',
      presentationBreakdowns: [{ presentationBy: { agent: 'alice' }, units: '10' }],
    } as never

    render(<ChargeSummarySection {...baseProps} usage={usage} />)

    expect(screen.getByText('My charge')).toBeInTheDocument()
    expect(screen.getByText('bm_code')).toBeInTheDocument()
    expect(screen.getByText('Units header')).toBeInTheDocument()
    expect(screen.getByText('Amount header')).toBeInTheDocument()
    // inline breakdown chip
    expect(screen.getByText('alice')).toBeInTheDocument()
  })

  it('switches to the virtualized list above the breakdown threshold', () => {
    // 60 distinct breakdowns (> VIRTUALIZATION_THRESHOLD of 50)
    const presentationBreakdowns = Array.from({ length: 60 }, (_, i) => ({
      presentationBy: { agent: `v${i}` },
      units: '1',
    }))

    const usage = {
      charge: { invoiceDisplayName: 'My charge' },
      billableMetric: { name: 'BM', code: 'bm_code' },
      units: 60,
      amountCents: '6000',
      presentationBreakdowns,
    } as never

    render(<ChargeSummarySection {...baseProps} usage={usage} />)

    // Parent table headers still render...
    expect(screen.getByText('Units header')).toBeInTheDocument()
    // ...and the first virtualized breakdown row is present.
    expect(screen.getByText('v0')).toBeInTheDocument()
  })
})

describe('VirtualizedBreakdownRows', () => {
  const makeRows = (count: number): PresentationBreakdownRow[] =>
    Array.from({ length: count }, (_, i) => ({
      id: `row-${i}`,
      __isBreakdown: true,
      presentationBy: { agent: `agent-${i}` },
      breakdownUnits: String(i),
    }))

  it('renders nothing when there are no rows', () => {
    const { container } = render(<VirtualizedBreakdownRows rows={[]} />)

    expect(container).toBeEmptyDOMElement()
  })

  it('renders breakdown rows', () => {
    render(<VirtualizedBreakdownRows rows={makeRows(3)} />)

    expect(screen.getByText('agent-0')).toBeInTheDocument()
  })
})
