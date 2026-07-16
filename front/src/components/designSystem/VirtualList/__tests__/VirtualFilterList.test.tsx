import { render, screen } from '@testing-library/react'

import { VirtualFilterList, VIRTUALIZATION_THRESHOLD, VirtualListApi } from '../VirtualFilterList'

const mockScrollToIndex = jest.fn()
let mockVirtualizerConfig: { count: number; estimateSize: () => number } | undefined

// jsdom renders 0 virtual rows (0px viewport); stub the virtualizer to yield
// every row so we exercise OUR rendering paths, not the virtualizer internals.
// The passed config is captured so we can assert what we feed the virtualizer.
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: (config: { count: number; estimateSize: () => number }) => {
    mockVirtualizerConfig = config

    const { count } = config

    return {
      getTotalSize: () => count * 64,
      getVirtualItems: () =>
        Array.from({ length: count }, (_, index) => ({ index, start: index * 64, key: index })),
      measureElement: () => {},
      scrollToIndex: mockScrollToIndex,
    }
  },
}))

class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}

beforeAll(() => {
  global.ResizeObserver = ResizeObserverMock
})

const makeItems = (n: number) => Array.from({ length: n }, (_, i) => ({ id: `f${i}` }))

const renderList = (count: number, gap?: number) =>
  render(
    <div style={{ overflowY: 'auto' }}>
      <VirtualFilterList
        items={makeItems(count)}
        getItemKey={(item) => item.id}
        estimateItemHeight={64}
        gap={gap}
        renderItem={(item) => <div data-testid="row">{item.id}</div>}
      />
    </div>,
  )

describe('VirtualFilterList', () => {
  it('renders a plain list at or below the threshold (no virtualization wrappers)', () => {
    const { container } = renderList(VIRTUALIZATION_THRESHOLD)

    expect(screen.getAllByTestId('row')).toHaveLength(VIRTUALIZATION_THRESHOLD)
    // Plain path: rows are not the absolutely-positioned virtual rows.
    expect(container.querySelector('[data-index]')).toBeNull()
  })

  it('renders through the virtualized path above the threshold', () => {
    const { container } = renderList(VIRTUALIZATION_THRESHOLD + 1)

    // Virtualized path: each row carries data-index inside the positioned spacer.
    expect(container.querySelector('[data-index="0"]')).not.toBeNull()
    expect(screen.getAllByTestId('row')).toHaveLength(VIRTUALIZATION_THRESHOLD + 1)
  })

  it('bakes the gap into each virtualized row except the last (flex gap does not apply to absolute rows)', () => {
    const count = VIRTUALIZATION_THRESHOLD + 1
    const { container } = renderList(count, 16)

    const firstRow = container.querySelector('[data-index="0"]') as HTMLElement
    const lastRow = container.querySelector(`[data-index="${count - 1}"]`) as HTMLElement

    expect(firstRow.style.paddingBottom).toBe('16px')
    // No trailing gap after the last row, matching flex `gap` behavior.
    expect(lastRow.style.paddingBottom).toBe('0px')
  })

  it('feeds the virtualizer an estimateSize that includes the gap (so the spacer reserves space for unmeasured rows)', () => {
    // Regression: a gap-less estimate under-reserves the spacer by `gap` per
    // unmeasured row, pushing any anchor below the list far above its real spot.
    renderList(VIRTUALIZATION_THRESHOLD + 1, 16)

    expect(mockVirtualizerConfig?.estimateSize()).toBe(64 + 16)
  })

  describe('apiRef (jump-to navigation handle)', () => {
    beforeEach(() => mockScrollToIndex.mockClear())

    const renderWithApi = (count: number) => {
      const apiRef: { current: VirtualListApi | null } = { current: null }

      render(
        <div style={{ overflowY: 'auto' }}>
          <VirtualFilterList
            items={makeItems(count)}
            getItemKey={(item) => item.id}
            estimateItemHeight={64}
            renderItem={(item) => <div data-testid="row">{item.id}</div>}
            apiRef={apiRef}
          />
        </div>,
      )

      return apiRef
    }

    it('reports isVirtualized=false on the plain branch', () => {
      const apiRef = renderWithApi(VIRTUALIZATION_THRESHOLD)

      expect(apiRef.current?.isVirtualized).toBe(false)
    })

    it('reports isVirtualized=true and delegates scrollToIndex to the virtualizer above the threshold', () => {
      const apiRef = renderWithApi(VIRTUALIZATION_THRESHOLD + 1)

      expect(apiRef.current?.isVirtualized).toBe(true)

      apiRef.current?.scrollToIndex(3, { align: 'start' })

      expect(mockScrollToIndex).toHaveBeenCalledWith(3, { align: 'start' })
    })
  })
})
