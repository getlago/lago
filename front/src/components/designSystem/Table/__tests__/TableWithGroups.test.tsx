import { act, cleanup, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createRef } from 'react'

import { render } from '~/test-utils'

import {
  ColumnConfig,
  defaultRowLabelContent,
  RowConfig,
  TableWithGroups,
  TableWithGroupsRef,
} from '../TableWithGroups'

// Mock ResizeObserver
class MockResizeObserver {
  callback: ResizeObserverCallback

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback
  }

  observe(target: Element) {
    // Simulate initial observation with a width
    this.callback(
      [
        {
          target,
          contentRect: { width: 1000, height: 500 } as DOMRectReadOnly,
          borderBoxSize: [],
          contentBoxSize: [],
          devicePixelContentBoxSize: [],
        },
      ],
      this,
    )
  }

  unobserve() {}
  disconnect() {}
}

// Mock useVirtualizer to simplify testing
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: jest.fn(({ count, horizontal, estimateSize }) => {
    const items = Array.from({ length: count }, (_, i) => ({
      index: i,
      start: horizontal ? i * (estimateSize?.(i) ?? 160) : i * 48,
      size: estimateSize?.(i) ?? (horizontal ? 160 : 48),
      key: i,
    }))

    return {
      getVirtualItems: () => items,
      getTotalSize: () =>
        items.reduce((sum, item) => sum + item.size, 0) || count * (horizontal ? 160 : 48),
      measure: jest.fn(),
    }
  }),
}))

// Sample test data
const createTestRows = (): RowConfig[] => [
  { key: 'group1', label: 'Group 1', type: 'group' },
  { key: 'line1', label: 'Line 1', type: 'line', groupKey: 'group1' },
  { key: 'line2', label: 'Line 2', type: 'line', groupKey: 'group1' },
  { key: 'group2', label: 'Group 2', type: 'group' },
  { key: 'line3', label: 'Line 3', type: 'line', groupKey: 'group2' },
  { key: 'standalone', label: 'Standalone Line', type: 'line' },
]

const createTestColumns = (): ColumnConfig[] => [
  {
    key: 'name',
    label: 'Name',
    sticky: true,
    isFullWidth: true,
    content: defaultRowLabelContent,
  },
  {
    key: 'value',
    label: 'Value',
    minWidth: 120,
    content: (row) => <span data-test={`value-${row.key}`}>{row.key}-value</span>,
  },
  {
    key: 'status',
    label: 'Status',
    align: 'right',
    minWidth: 100,
    content: (row) => <span data-test={`status-${row.key}`}>Active</span>,
  },
]

async function prepare({
  rows = createTestRows(),
  columns = createTestColumns(),
  isLoading = false,
  ref,
}: {
  rows?: RowConfig[]
  columns?: ColumnConfig[]
  isLoading?: boolean
  ref?: React.RefObject<TableWithGroupsRef | null>
} = {}) {
  await act(() =>
    render(<TableWithGroups ref={ref} rows={rows} columns={columns} isLoading={isLoading} />),
  )
}

describe('TableWithGroups', () => {
  beforeAll(() => {
    global.ResizeObserver = MockResizeObserver as unknown as typeof ResizeObserver
  })

  afterEach(cleanup)

  describe('Basic Rendering', () => {
    it('renders the table with headers', async () => {
      await prepare()

      // Check headers are rendered
      expect(screen.getByText('Name')).toBeInTheDocument()
      expect(screen.getByText('Value')).toBeInTheDocument()
      expect(screen.getByText('Status')).toBeInTheDocument()
    })

    it('renders group rows', async () => {
      await prepare()

      expect(screen.getByText('Group 1')).toBeInTheDocument()
      expect(screen.getByText('Group 2')).toBeInTheDocument()
    })

    it('renders standalone lines (lines without groupKey)', async () => {
      await prepare()

      expect(screen.getByText('Standalone Line')).toBeInTheDocument()
    })

    it('hides child lines when groups are collapsed (default state)', async () => {
      await prepare()

      // Child lines should be hidden by default
      expect(screen.queryByText('Line 1')).not.toBeInTheDocument()
      expect(screen.queryByText('Line 2')).not.toBeInTheDocument()
      expect(screen.queryByText('Line 3')).not.toBeInTheDocument()
    })

    it('renders with custom ReactNode labels', async () => {
      const customRows: RowConfig[] = [
        {
          key: 'custom-group',
          label: <span data-test="custom-label">Custom Label</span>,
          type: 'group',
        },
      ]

      await prepare({ rows: customRows })

      expect(screen.getByTestId('custom-label')).toBeInTheDocument()
    })
  })

  describe('Loading State', () => {
    it('renders skeleton elements when loading', async () => {
      await prepare({ isLoading: true })

      // Should render skeletons in place of content (custom Skeleton component uses animate-pulse class)
      const skeletons = document.querySelectorAll('.animate-pulse')

      expect(skeletons.length).toBeGreaterThan(0)
    })
  })

  describe('Expand/Collapse Functionality', () => {
    it('expands a group when clicking on it', async () => {
      await prepare()

      // Initially child lines are hidden
      expect(screen.queryByText('Line 1')).not.toBeInTheDocument()

      // Click on Group 1 to expand
      const group1 = screen.getByText('Group 1')

      await act(async () => {
        await userEvent.click(group1)
      })

      // Child lines should now be visible
      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
        expect(screen.getByText('Line 2')).toBeInTheDocument()
      })
    })

    it('collapses an expanded group when clicking again', async () => {
      await prepare()

      const group1 = screen.getByText('Group 1')

      // Expand
      await act(async () => {
        await userEvent.click(group1)
      })

      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
      })

      // Collapse
      await act(async () => {
        await userEvent.click(group1)
      })

      await waitFor(() => {
        expect(screen.queryByText('Line 1')).not.toBeInTheDocument()
      })
    })

    it('supports keyboard navigation (Enter key)', async () => {
      await prepare()

      // Find the group row element with role="button"
      const group1Row = screen.getByText('Group 1').closest('[role="button"]') as HTMLElement

      // Focus and press Enter
      await act(async () => {
        group1Row.focus()
        await userEvent.keyboard('{Enter}')
      })

      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
      })
    })

    it('supports keyboard navigation (Space key)', async () => {
      await prepare()

      // Find the group row element with role="button"
      const group1Row = screen.getByText('Group 1').closest('[role="button"]') as HTMLElement

      // Focus and press Space
      await act(async () => {
        group1Row.focus()
        await userEvent.keyboard(' ')
      })

      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
      })
    })

    it('does not trigger expand on non-group rows', async () => {
      // First expand to show standalone line
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // The standalone line should be visible
      expect(screen.getByText('Standalone Line')).toBeInTheDocument()

      // Click on standalone line should not cause errors
      const standaloneLine = screen.getByText('Standalone Line')

      await act(async () => {
        await userEvent.click(standaloneLine)
      })

      // Component should still work
      expect(screen.getByText('Standalone Line')).toBeInTheDocument()
    })
  })

  describe('Ref Methods', () => {
    it('expandAll expands all groups', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Initially collapsed
      expect(screen.queryByText('Line 1')).not.toBeInTheDocument()
      expect(screen.queryByText('Line 3')).not.toBeInTheDocument()

      // Expand all
      await act(async () => {
        ref.current?.expandAll()
      })

      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
        expect(screen.getByText('Line 2')).toBeInTheDocument()
        expect(screen.getByText('Line 3')).toBeInTheDocument()
      })
    })

    it('collapseAll collapses all groups', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // First expand all
      await act(async () => {
        ref.current?.expandAll()
      })

      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
      })

      // Then collapse all
      await act(async () => {
        ref.current?.collapseAll()
      })

      await waitFor(() => {
        expect(screen.queryByText('Line 1')).not.toBeInTheDocument()
        expect(screen.queryByText('Line 3')).not.toBeInTheDocument()
      })
    })

    it('toggleGroup toggles a specific group', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Toggle group1 to expand
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
        // group2 should still be collapsed
        expect(screen.queryByText('Line 3')).not.toBeInTheDocument()
      })

      // Toggle group1 again to collapse
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      await waitFor(() => {
        expect(screen.queryByText('Line 1')).not.toBeInTheDocument()
      })
    })

    it('isGroupExpanded returns correct state', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Initially collapsed
      expect(ref.current?.isGroupExpanded('group1')).toBe(false)
      expect(ref.current?.isGroupExpanded('group2')).toBe(false)

      // Expand group1
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      expect(ref.current?.isGroupExpanded('group1')).toBe(true)
      expect(ref.current?.isGroupExpanded('group2')).toBe(false)
    })

    it('hasExpandedGroups returns false when all groups are collapsed', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Initially all groups are collapsed
      expect(ref.current?.hasExpandedGroups()).toBe(false)
    })

    it('hasExpandedGroups returns true when at least one group is expanded', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Expand one group
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      expect(ref.current?.hasExpandedGroups()).toBe(true)
    })

    it('hasExpandedGroups returns true when all groups are expanded', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Expand all groups
      await act(async () => {
        ref.current?.expandAll()
      })

      expect(ref.current?.hasExpandedGroups()).toBe(true)
    })

    it('hasCollapsedGroups returns true when all groups are collapsed', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Initially all groups are collapsed
      expect(ref.current?.hasCollapsedGroups()).toBe(true)
    })

    it('hasCollapsedGroups returns true when at least one group is collapsed', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Expand only one group, leaving group2 collapsed
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      expect(ref.current?.hasCollapsedGroups()).toBe(true)
    })

    it('hasCollapsedGroups returns false when all groups are expanded', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Expand all groups
      await act(async () => {
        ref.current?.expandAll()
      })

      expect(ref.current?.hasCollapsedGroups()).toBe(false)
    })

    it('hasExpandedGroups and hasCollapsedGroups work correctly together', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Initially: no expanded, all collapsed
      expect(ref.current?.hasExpandedGroups()).toBe(false)
      expect(ref.current?.hasCollapsedGroups()).toBe(true)

      // Expand one group: some expanded, some collapsed
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      expect(ref.current?.hasExpandedGroups()).toBe(true)
      expect(ref.current?.hasCollapsedGroups()).toBe(true)

      // Expand all: all expanded, none collapsed
      await act(async () => {
        ref.current?.expandAll()
      })

      expect(ref.current?.hasExpandedGroups()).toBe(true)
      expect(ref.current?.hasCollapsedGroups()).toBe(false)

      // Collapse all: none expanded, all collapsed
      await act(async () => {
        ref.current?.collapseAll()
      })

      expect(ref.current?.hasExpandedGroups()).toBe(false)
      expect(ref.current?.hasCollapsedGroups()).toBe(true)
    })

    it('getExpandedState returns empty object when all groups are collapsed', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      const state = ref.current?.getExpandedState()

      expect(state).toEqual({})
    })

    it('getExpandedState returns correct state after expanding groups', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      const state = ref.current?.getExpandedState()

      expect(state).toEqual({ group1: true })
    })

    it('getExpandedState returns all groups expanded after expandAll', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      await act(async () => {
        ref.current?.expandAll()
      })

      const state = ref.current?.getExpandedState()

      expect(state).toEqual({ group1: true, group2: true })
    })

    it('setExpandedState sets the correct expanded state', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Initially collapsed
      expect(screen.queryByText('Line 1')).not.toBeInTheDocument()

      // Set expanded state
      await act(async () => {
        ref.current?.setExpandedState({ group1: true })
      })

      // group1 should be expanded
      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
        expect(screen.queryByText('Line 3')).not.toBeInTheDocument()
      })
    })

    it('setExpandedState can restore a previously saved state', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Expand group1
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      // Save state
      const savedState = ref.current?.getExpandedState()

      // Expand all
      await act(async () => {
        ref.current?.expandAll()
      })

      await waitFor(() => {
        expect(screen.getByText('Line 3')).toBeInTheDocument()
      })

      // Restore saved state
      await act(async () => {
        if (savedState) {
          ref.current?.setExpandedState(savedState)
        }
      })

      // Only group1 should be expanded
      await waitFor(() => {
        expect(screen.getByText('Line 1')).toBeInTheDocument()
        expect(screen.queryByText('Line 3')).not.toBeInTheDocument()
      })
    })
  })

  describe('Column Configuration', () => {
    it('renders sticky columns', async () => {
      await prepare()

      // The Name column is sticky and should be visible
      expect(screen.getByText('Name')).toBeInTheDocument()
    })

    it('renders columns with correct alignment', async () => {
      const columns: ColumnConfig[] = [
        {
          key: 'left',
          label: 'Left Aligned',
          align: 'left',
          content: () => <span>Left</span>,
        },
        {
          key: 'center',
          label: 'Center Aligned',
          align: 'center',
          content: () => <span>Center</span>,
        },
        {
          key: 'right',
          label: 'Right Aligned',
          align: 'right',
          content: () => <span>Right</span>,
        },
      ]

      await prepare({
        rows: [{ key: 'row1', label: 'Row 1', type: 'group' }],
        columns,
      })

      // Headers should be rendered
      expect(screen.getByText('Left Aligned')).toBeInTheDocument()
      expect(screen.getByText('Center Aligned')).toBeInTheDocument()
      expect(screen.getByText('Right Aligned')).toBeInTheDocument()
    })

    it('renders content using column content function', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      // Expand to see line content
      await act(async () => {
        ref.current?.expandAll()
      })

      await waitFor(() => {
        expect(screen.getByTestId('value-line1')).toHaveTextContent('line1-value')
        expect(screen.getByTestId('status-line1')).toHaveTextContent('Active')
      })
    })
  })

  describe('defaultRowLabelContent helper', () => {
    it('renders group label with bold styling', async () => {
      await prepare()

      const group1Label = screen.getByText('Group 1')

      expect(group1Label).toBeInTheDocument()
      // The group label should have the Typography component with bodyHl variant
      expect(group1Label).toHaveAttribute('data-test', 'bodyHl')
    })

    it('renders line label with regular styling and padding', async () => {
      const ref = createRef<TableWithGroupsRef>()

      await prepare({ ref })

      await act(async () => {
        ref.current?.expandAll()
      })

      await waitFor(() => {
        const lineLabel = screen.getByText('Line 1')

        expect(lineLabel).toBeInTheDocument()
        expect(lineLabel).toHaveClass('pl-8')
      })
    })

    it('renders chevron icon for groups', async () => {
      await prepare()

      // Chevron icons should be present for groups
      const chevronIcons = document.querySelectorAll('[data-test*="chevron-right-filled"]')

      expect(chevronIcons.length).toBeGreaterThan(0)
    })

    it('rotates chevron when group is expanded', async () => {
      await prepare()

      // Get chevron before expansion
      const chevronBefore = document.querySelector('[data-test*="chevron-right-filled"]')

      expect(chevronBefore).not.toHaveClass('rotate-90')

      // Click to expand
      const group1 = screen.getByText('Group 1')

      await act(async () => {
        await userEvent.click(group1)
      })

      // Get chevron after expansion
      const chevronAfter = document.querySelector('.rotate-90')

      expect(chevronAfter).toBeInTheDocument()
    })
  })

  describe('Hover Effects', () => {
    it('applies hover background to group rows', async () => {
      await prepare()

      const group1Row = screen.getByText('Group 1').closest('[role="button"]')

      expect(group1Row).toBeInTheDocument()

      // Simulate hover
      await act(async () => {
        await userEvent.hover(group1Row as Element)
      })

      // The row should have hover class
      await waitFor(() => {
        expect(group1Row).toHaveClass('bg-grey-100')
      })

      // Unhover
      await act(async () => {
        await userEvent.unhover(group1Row as Element)
      })

      await waitFor(() => {
        expect(group1Row).toHaveClass('bg-white')
      })
    })
  })

  describe('Edge Cases', () => {
    it('handles empty rows array', async () => {
      await prepare({ rows: [] })

      // Should render without errors, just headers
      expect(screen.getByText('Name')).toBeInTheDocument()
    })

    it('handles rows with only groups (no lines)', async () => {
      const groupOnlyRows: RowConfig[] = [
        { key: 'group1', label: 'Group 1', type: 'group' },
        { key: 'group2', label: 'Group 2', type: 'group' },
      ]

      await prepare({ rows: groupOnlyRows })

      expect(screen.getByText('Group 1')).toBeInTheDocument()
      expect(screen.getByText('Group 2')).toBeInTheDocument()
    })

    it('handles rows with only standalone lines (no groups)', async () => {
      const linesOnlyRows: RowConfig[] = [
        { key: 'line1', label: 'Line 1', type: 'line' },
        { key: 'line2', label: 'Line 2', type: 'line' },
      ]

      await prepare({ rows: linesOnlyRows })

      // Standalone lines should be visible
      expect(screen.getByText('Line 1')).toBeInTheDocument()
      expect(screen.getByText('Line 2')).toBeInTheDocument()
    })

    it('handles columns with no sticky columns', async () => {
      const noStickyColumns: ColumnConfig[] = [
        {
          key: 'col1',
          label: 'Column 1',
          content: (row) => <span>{row.label}</span>,
        },
        {
          key: 'col2',
          label: 'Column 2',
          content: (row) => <span>{row.key}</span>,
        },
      ]

      await prepare({
        rows: [{ key: 'row1', label: 'Row 1', type: 'group' }],
        columns: noStickyColumns,
      })

      expect(screen.getByText('Column 1')).toBeInTheDocument()
      expect(screen.getByText('Column 2')).toBeInTheDocument()
    })

    it('handles columns with all sticky columns', async () => {
      const allStickyColumns: ColumnConfig[] = [
        {
          key: 'col1',
          label: 'Column 1',
          sticky: true,
          content: (row) => <span>{row.label}</span>,
        },
        {
          key: 'col2',
          label: 'Column 2',
          sticky: true,
          content: (row) => <span>{row.key}</span>,
        },
      ]

      await prepare({
        rows: [{ key: 'row1', label: 'Row 1', type: 'group' }],
        columns: allStickyColumns,
      })

      expect(screen.getByText('Column 1')).toBeInTheDocument()
      expect(screen.getByText('Column 2')).toBeInTheDocument()
    })
  })

  describe('ColumnHelpers', () => {
    it('provides isExpanded helper correctly to content function', async () => {
      const contentSpy = jest.fn((_row, helpers) => (
        <span data-test="expanded-state">{helpers.isExpanded ? 'expanded' : 'collapsed'}</span>
      ))

      const columns: ColumnConfig[] = [
        {
          key: 'test',
          label: 'Test',
          content: contentSpy,
        },
      ]

      const ref = createRef<TableWithGroupsRef>()

      await prepare({
        rows: [{ key: 'group1', label: 'Group 1', type: 'group' }],
        columns,
        ref,
      })

      // Initially collapsed
      expect(screen.getByTestId('expanded-state')).toHaveTextContent('collapsed')

      // Expand
      await act(async () => {
        ref.current?.toggleGroup('group1')
      })

      await waitFor(() => {
        expect(screen.getByTestId('expanded-state')).toHaveTextContent('expanded')
      })
    })

    it('provides ChevronIcon as null for non-group rows', async () => {
      const contentSpy = jest.fn((_row, helpers) => (
        <span data-test="chevron-check">
          {helpers.ChevronIcon === null ? 'no-chevron' : 'has-chevron'}
        </span>
      ))

      const columns: ColumnConfig[] = [
        {
          key: 'test',
          label: 'Test',
          content: contentSpy,
        },
      ]

      await prepare({
        rows: [{ key: 'line1', label: 'Line 1', type: 'line' }],
        columns,
      })

      // Line rows should not have chevron
      expect(screen.getByTestId('chevron-check')).toHaveTextContent('no-chevron')
    })
  })
})
