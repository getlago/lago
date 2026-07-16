import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

import { render } from '~/test-utils'

import { PlanDetailsV2LeftSidebar } from '../PlanDetailsV2LeftSidebar'

jest.mock('~/hooks/core/useInternationalization', () => ({
  useInternationalization: () => ({
    translate: (key: string) => {
      const map: Record<string, string> = {
        text_177928991586601f21f0x87c: 'Plan settings',
        text_1779289915866etwoweh1syv: 'Subscription fee',
        text_1779289915866aj39dyv1wps: 'Fixed charges',
        text_1779289915866ngi8sv5t9lg: 'Usage-based charges',
        text_17792899158664ii2pmrd2le: 'Minimum commitment',
        text_1779289915866vguw0lfmz06: 'Progressive billing',
        text_1779289915866mr56w61hhi5: 'Entitlements',
        text_176072970726882uau5y69f1: 'Add fixed charge',
        text_1772133285142oouequiz2t2: 'Add usage charge',
        text_1753864223060devvklm7vk0: 'Add entitlement',
      }

      return map[key] ?? key
    },
  }),
}))

// jsdom has no layout; stub the virtualizer to yield every row so the virtualized
// branch is exercised. The plain (<= threshold) branch ignores it.
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: ({ count }: { count: number }) => ({
    getTotalSize: () => count * 36,
    getVirtualItems: () =>
      Array.from({ length: count }, (_, index) => ({ index, start: index * 36, key: index })),
    measureElement: () => {},
  }),
}))

class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}

beforeAll(() => {
  global.ResizeObserver = ResizeObserverMock
})

const renderSidebar = (
  props: Partial<React.ComponentProps<typeof PlanDetailsV2LeftSidebar>> = {},
) => render(<PlanDetailsV2LeftSidebar onItemClick={jest.fn()} {...props} />)

const buildUsageCharges = (count: number) =>
  Array.from({ length: count }, (_, i) => ({
    id: `uc-${i}`,
    invoiceDisplayName: `Usage charge ${i}`,
    code: `usage_${i}`,
    billableMetric: { id: `bm-${i}`, name: `Metric ${i}` },
  }))

describe('PlanDetailsV2LeftSidebar', () => {
  it('renders every root-level section (no "Advanced settings" folder)', () => {
    renderSidebar()

    for (const label of [
      'Plan settings',
      'Subscription fee',
      'Fixed charges',
      'Usage-based charges',
      'Minimum commitment',
      'Progressive billing',
      'Entitlements',
    ]) {
      expect(screen.getByText(label)).toBeInTheDocument()
    }

    // Advanced settings folder has been removed entirely.
    expect(screen.queryByText('Advanced settings')).not.toBeInTheDocument()
  })

  // Drift test — locks in the sub-flow gating contract: Min commitment stays at the root,
  // only Progressive billing and Entitlements hide in sub mode.
  it('drops Progressive billing + Entitlements when isInSubscriptionForm=true (Min commitment stays)', () => {
    renderSidebar({ isInSubscriptionForm: true })

    expect(screen.queryByText('Progressive billing')).not.toBeInTheDocument()
    expect(screen.queryByText('Entitlements')).not.toBeInTheDocument()
    expect(screen.getByText('Minimum commitment')).toBeInTheDocument()
  })

  it('fires onItemClick with the section id when a leaf item is clicked', async () => {
    const handleClick = jest.fn()

    renderSidebar({ onItemClick: handleClick })

    await userEvent.click(screen.getByRole('button', { name: 'Subscription fee' }))

    expect(handleClick).toHaveBeenCalledWith('subscription-fee')
  })

  it('fires onItemClick for the root-level Minimum commitment + Progressive billing items', async () => {
    const handleClick = jest.fn()

    renderSidebar({ onItemClick: handleClick })

    await userEvent.click(screen.getByRole('button', { name: 'Minimum commitment' }))
    expect(handleClick).toHaveBeenCalledWith('minimum-commitment')

    await userEvent.click(screen.getByRole('button', { name: 'Progressive billing' }))
    expect(handleClick).toHaveBeenCalledWith('progressive-billing')
  })

  // BIL-159: a folder row expands/collapses; it must NOT navigate.
  it('toggles a folder (and does NOT fire onItemClick) when its label is clicked', async () => {
    const handleClick = jest.fn()
    const fixedCharges = [
      {
        id: 'fc-1',
        invoiceDisplayName: 'Premium seats',
        code: 'seats',
        addOn: { id: 'ao-1', name: 'Seats' },
      },
    ]

    renderSidebar({ onItemClick: handleClick, fixedCharges })

    // Collapsed by default — child hidden.
    expect(screen.queryByText('Premium seats')).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Fixed charges' }))

    // Expanded by the label click, with no navigation.
    expect(screen.getByText('Premium seats')).toBeInTheDocument()
    expect(handleClick).not.toHaveBeenCalled()

    // Clicking the label again collapses it.
    await userEvent.click(screen.getByRole('button', { name: 'Fixed charges' }))
    expect(screen.queryByText('Premium seats')).not.toBeInTheDocument()
  })

  describe('plus add button', () => {
    it('renders the plus button on Fixed charges, Usage-based charges and Entitlements', () => {
      renderSidebar()

      expect(screen.getByTestId('sidebar-add-fixed-charges')).toBeInTheDocument()
      expect(screen.getByTestId('sidebar-add-usage-charges')).toBeInTheDocument()
      expect(screen.getByTestId('sidebar-add-entitlements')).toBeInTheDocument()
    })

    // Drift test — no Add CTAs in sub mode.
    it('hides every plus button when isInSubscriptionForm=true', () => {
      renderSidebar({ isInSubscriptionForm: true })

      expect(screen.queryByTestId('sidebar-add-fixed-charges')).not.toBeInTheDocument()
      expect(screen.queryByTestId('sidebar-add-usage-charges')).not.toBeInTheDocument()
      expect(screen.queryByTestId('sidebar-add-entitlements')).not.toBeInTheDocument()
    })

    it('fires onAddClick with the section id and does NOT fire onItemClick', async () => {
      const onItemClick = jest.fn()
      const onAddClick = jest.fn()

      renderSidebar({ onItemClick, onAddClick })

      await userEvent.click(screen.getByTestId('sidebar-add-entitlements'))

      expect(onAddClick).toHaveBeenCalledWith('entitlements')
      expect(onItemClick).not.toHaveBeenCalled()
    })

    it('clicking the plus button is a no-op when onAddClick is not provided (does not throw)', async () => {
      const onItemClick = jest.fn()

      renderSidebar({ onItemClick })

      await userEvent.click(screen.getByTestId('sidebar-add-fixed-charges'))

      expect(onItemClick).not.toHaveBeenCalled()
    })
  })

  describe('folder children', () => {
    const fixedCharges = [
      {
        id: 'fc-1',
        invoiceDisplayName: 'Premium seats',
        code: 'seats',
        addOn: { id: 'ao-1', name: 'Seats' },
      },
      { id: 'fc-2', invoiceDisplayName: null, code: 'cards', addOn: { id: 'ao-2', name: 'Cards' } },
      {
        id: 'fc-3',
        invoiceDisplayName: null,
        code: 'fallback-code',
        addOn: { id: 'ao-3', name: '' },
      },
    ]
    const usageCharges = [
      {
        id: 'uc-1',
        invoiceDisplayName: null,
        code: 'api',
        billableMetric: { id: 'bm-1', name: 'API calls' },
      },
    ]
    const entitlements = [
      { code: 'seats', name: 'Seats feature' },
      { code: 'storage', name: '' },
    ]

    it('lists charges with invoiceDisplayName || addOn/metric name || code once the folder is expanded', async () => {
      renderSidebar({ fixedCharges, usageCharges })

      // Folders are collapsed by default — children hidden until toggled.
      expect(screen.queryByText('Premium seats')).not.toBeInTheDocument()

      await userEvent.click(screen.getByTestId('sidebar-toggle-fixed-charges'))

      expect(screen.getByText('Premium seats')).toBeInTheDocument() // invoiceDisplayName
      expect(screen.getByText('Cards')).toBeInTheDocument() // addOn.name fallback
      expect(screen.getByText('fallback-code')).toBeInTheDocument() // code fallback

      await userEvent.click(screen.getByTestId('sidebar-toggle-usage-charges'))

      expect(screen.getByText('API calls')).toBeInTheDocument() // billableMetric.name fallback
    })

    it('fires onItemClick with the charge id when a charge child is clicked', async () => {
      const onItemClick = jest.fn()

      renderSidebar({ fixedCharges, onItemClick })

      await userEvent.click(screen.getByTestId('sidebar-toggle-fixed-charges'))
      await userEvent.click(screen.getByRole('button', { name: 'Premium seats' }))

      expect(onItemClick).toHaveBeenCalledWith('fc-1')
    })

    it('lists entitlements (name || code) and navigates to entitlement-<code> on click', async () => {
      const onItemClick = jest.fn()

      renderSidebar({ entitlements, onItemClick })

      expect(screen.queryByText('Seats feature')).not.toBeInTheDocument()

      await userEvent.click(screen.getByTestId('sidebar-toggle-entitlements'))

      expect(screen.getByText('Seats feature')).toBeInTheDocument() // name
      expect(screen.getByText('storage')).toBeInTheDocument() // code fallback (empty name)

      await userEvent.click(screen.getByRole('button', { name: 'Seats feature' }))

      expect(onItemClick).toHaveBeenCalledWith('entitlement-seats')
    })
  })

  describe('virtualization and viewport sizing', () => {
    it('renders the expanded folder through the virtualized path above the threshold', async () => {
      const { container } = renderSidebar({ usageCharges: buildUsageCharges(51) })

      // Collapsed: only the ~7 section rows, below threshold -> plain (no virtual rows).
      expect(container.querySelector('[data-index]')).toBeNull()

      await userEvent.click(screen.getByTestId('sidebar-toggle-usage-charges'))

      // Expanded: sections + 51 children cross the threshold -> virtualized rows appear.
      expect(container.querySelector('[data-index="0"]')).not.toBeNull()
    })

    it('sizes the nav height to the visible viewport (innerHeight - nav top)', () => {
      renderSidebar()

      const nav = screen.getByRole('navigation', { name: /plan sections/i })

      // jsdom getBoundingClientRect().top is 0, so maxHeight resolves to innerHeight.
      expect(nav.style.maxHeight).toBe(`${window.innerHeight}px`)
    })
  })
})
