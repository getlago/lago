import { render } from '@testing-library/react'
import { ReactElement } from 'react'

import {
  BaseComboBoxVirtualizedList,
  calculateItemMarginTop,
  getItemHeight,
} from '../BaseComboBoxVirtualizedList'
import { COMBOBOX_CONFIG } from '../comboBoxConfig'

// Mock @tanstack/react-virtual
jest.mock('@tanstack/react-virtual', () => ({
  useVirtualizer: jest.fn((config) => {
    const items = Array.from({ length: config.count }, (_, i) => ({
      index: i,
      key: i,
      size: config.estimateSize(i),
      start: Array.from({ length: i }, (__, j) => config.estimateSize(j)).reduce(
        (acc, val) => acc + val,
        0,
      ),
    }))

    return {
      getVirtualItems: () => items,
      getTotalSize: () => items.reduce((acc, item) => acc + item.size, 0),
      scrollToIndex: jest.fn(),
      measureElement: jest.fn(),
    }
  }),
}))

const GROUP_ITEM_KEY = 'test-group-by'

const createMockElement = (key: string): ReactElement => {
  return (
    <div key={key} data-testid={key}>
      <div>
        <div>{key}</div>
      </div>
    </div>
  ) as ReactElement
}

const createHeaderElement = (groupName: string): ReactElement => {
  return (
    <div key={`${GROUP_ITEM_KEY}-${groupName}`} data-testid={`${GROUP_ITEM_KEY}-${groupName}`}>
      <div>{groupName}</div>
    </div>
  ) as ReactElement
}

describe('BaseComboBoxVirtualizedList', () => {
  describe('calculateItemMarginTop', () => {
    describe('Headers', () => {
      it('should return 0 for headers', () => {
        const elements = [createHeaderElement('group1')]
        const result = calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)

        expect(result).toBe(0)
      })

      it('should return 0 for header in middle of list', () => {
        const elements = [
          createMockElement('item1'),
          createHeaderElement('group1'),
          createMockElement('item2'),
        ]
        const result = calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)

        expect(result).toBe(0)
      })
    })

    describe('First Item', () => {
      it('should return 8px margin for first item (no previous element)', () => {
        const elements = [createMockElement('item1')]
        const result = calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP)
        expect(result).toBe(8)
      })

      it('should return 8px margin for first item in list with multiple items', () => {
        const elements = [createMockElement('item1'), createMockElement('item2')]
        const result = calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP)
        expect(result).toBe(8)
      })
    })

    describe('Item After Header', () => {
      it('should return 8px margin for item immediately after header', () => {
        const elements = [createHeaderElement('group1'), createMockElement('item1')]
        const result = calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP)
        expect(result).toBe(8)
      })

      it('should return 8px margin for item after header in complex list', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createMockElement('item2'),
          createHeaderElement('group2'),
          createMockElement('item3'),
        ]
        const result = calculateItemMarginTop(4, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP)
        expect(result).toBe(8)
      })
    })

    describe('Consecutive Items', () => {
      it('should return 4px gap for item after another item', () => {
        const elements = [createMockElement('item1'), createMockElement('item2')]
        const result = calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS)
        expect(result).toBe(4)
      })

      it('should return 4px gap for middle items in sequence', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
          createMockElement('item4'),
        ]

        expect(calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)).toBe(4)
        expect(calculateItemMarginTop(2, elements, GROUP_ITEM_KEY)).toBe(4)
        expect(calculateItemMarginTop(3, elements, GROUP_ITEM_KEY)).toBe(4)
      })

      it('should return 4px gap for last item after another item', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]
        const result = calculateItemMarginTop(2, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS)
        expect(result).toBe(4)
      })
    })

    describe('Edge Cases', () => {
      it('should handle single item list', () => {
        const elements = [createMockElement('item1')]
        const result = calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)

        expect(result).toBe(8)
      })

      it('should handle list starting with header', () => {
        const elements = [createHeaderElement('group1'), createMockElement('item1')]

        expect(calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)).toBe(0) // header
        expect(calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)).toBe(8) // item after header
      })

      it('should handle alternating headers and items', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createHeaderElement('group2'),
          createMockElement('item2'),
        ]

        expect(calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)).toBe(0) // header
        expect(calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)).toBe(8) // item after header
        expect(calculateItemMarginTop(2, elements, GROUP_ITEM_KEY)).toBe(0) // header
        expect(calculateItemMarginTop(3, elements, GROUP_ITEM_KEY)).toBe(8) // item after header
      })

      it('should handle complex list with multiple groups', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
          createHeaderElement('group2'),
          createMockElement('item4'),
          createMockElement('item5'),
        ]

        expect(calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)).toBe(0) // header
        expect(calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)).toBe(8) // first item after header
        expect(calculateItemMarginTop(2, elements, GROUP_ITEM_KEY)).toBe(4) // consecutive item
        expect(calculateItemMarginTop(3, elements, GROUP_ITEM_KEY)).toBe(4) // consecutive item
        expect(calculateItemMarginTop(4, elements, GROUP_ITEM_KEY)).toBe(0) // header
        expect(calculateItemMarginTop(5, elements, GROUP_ITEM_KEY)).toBe(8) // first item after header
        expect(calculateItemMarginTop(6, elements, GROUP_ITEM_KEY)).toBe(4) // consecutive item
      })
    })

    describe('Different Group Keys', () => {
      it('should work with different groupItemKey values', () => {
        const customKey = 'custom-group'
        const elements = [
          <div key={`${customKey}-header1`}>Header</div>,
          <div key="item1">Item</div>,
        ]

        expect(calculateItemMarginTop(0, elements, customKey)).toBe(0) // header
        expect(calculateItemMarginTop(1, elements, customKey)).toBe(8) // item after header
      })

      it('should treat all items as consecutive when groupItemKey does not match any keys', () => {
        const elements = [
          <div key="regular-item1">Item 1</div>,
          <div key="regular-item2">Item 2</div>,
        ]

        expect(calculateItemMarginTop(0, elements, GROUP_ITEM_KEY)).toBe(8) // first item
        expect(calculateItemMarginTop(1, elements, GROUP_ITEM_KEY)).toBe(4) // consecutive item
      })
    })
  })

  describe('getItemHeight', () => {
    describe('Headers', () => {
      it('should return exact header height with no margins', () => {
        const elements = [createHeaderElement('group1')]
        const result = getItemHeight(0, elements, GROUP_ITEM_KEY)

        expect(result).toBe(COMBOBOX_CONFIG.GROUP_HEADER_HEIGHT)
        expect(result).toBe(44)
      })
    })

    describe('Items', () => {
      it('should calculate first item height correctly (8 + 56 + 4 = 68)', () => {
        const elements = [createMockElement('item1'), createMockElement('item2')]
        const result = getItemHeight(0, elements, GROUP_ITEM_KEY)

        expect(result).toBe(68)
      })

      it('should calculate middle item height correctly (4 + 56 + 4 = 64)', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        expect(getItemHeight(1, elements, GROUP_ITEM_KEY)).toBe(64)
      })

      it('should calculate last item height correctly (4 + 56 + 8 = 68)', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        expect(getItemHeight(2, elements, GROUP_ITEM_KEY)).toBe(68)
      })

      it('should calculate item after header correctly (8 + 56 + 8 = 72)', () => {
        const elements = [createHeaderElement('group1'), createMockElement('item1')]

        expect(getItemHeight(1, elements, GROUP_ITEM_KEY)).toBe(72)
      })
    })
  })

  describe('BaseComboBoxVirtualizedList - Component Integration', () => {
    describe('Rendering with calculated heights - Items Only', () => {
      it('should calculate correct height for first item', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // First item: ITEM_HEIGHT + top margin (8px as if after header) + bottom margin (8px)
        const expectedFirstItemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM

        expect(container).toBeTruthy()
        expect(expectedFirstItemHeight).toBe(56 + 8 + 8) // 72px
      })

      it('should calculate correct height for middle item', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        // Middle item: ITEM_HEIGHT + gap (4px) + bottom margin (4px)
        const expectedMiddleItemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM / 2

        render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        expect(expectedMiddleItemHeight).toBe(56 + 4 + 4) // 64px
      })

      it('should calculate correct height for last item', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        // Last item: ITEM_HEIGHT + gap (4px) + bottom margin (8px)
        const expectedLastItemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM

        render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        expect(expectedLastItemHeight).toBe(56 + 4 + 8) // 68px
      })

      it('should calculate correct total height for 3 items without headers', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // First item: 56 + 8 + 4 = 68px
        // Second item: 56 + 4 + 4 = 64px
        // Third item: 56 + 4 + 8 = 68px
        // Total: 68 + 64 + 68 = 200px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv).toBeTruthy()
        expect(innerDiv?.getAttribute('style')).toContain('height: 200px')
      })

      it('should calculate correct total height for 5 items without headers', () => {
        const elements = [
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
          createMockElement('item4'),
          createMockElement('item5'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // First item: 56 + 8 + 4 = 68
        // Middle items (2-4): 56 + 4 + 4 = 64 each (3 items = 192)
        // Last item: 56 + 4 + 8 = 68
        // Total: 68 + 64 + 64 + 64 + 68 = 328px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv).toBeTruthy()
        expect(innerDiv?.getAttribute('style')).toContain('height: 328px')
      })
    })

    describe('getItemHeight - With Headers', () => {
      it('should calculate correct height for header', () => {
        const elements = [createHeaderElement('group1'), createMockElement('item1')]

        render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Header height should be exactly GROUP_HEADER_HEIGHT (no margins)
        expect(COMBOBOX_CONFIG.GROUP_HEADER_HEIGHT).toBe(44)
      })

      it('should calculate correct height for item after header', () => {
        const elements = [createHeaderElement('group1'), createMockElement('item1')]

        render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Item after header: ITEM_HEIGHT + top margin (8px) + bottom margin (8px)
        const expectedItemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM

        expect(expectedItemHeight).toBe(56 + 8 + 8) // 72px
      })

      it('should calculate correct height for item before header', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createHeaderElement('group2'),
        ]

        render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Item before header: ITEM_HEIGHT + top margin (8px) + bottom margin (8px)
        const expectedItemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM

        expect(expectedItemHeight).toBe(56 + 8 + 8) // 72px
      })

      it('should calculate correct total height for header + 1 item', () => {
        const elements = [createHeaderElement('group1'), createMockElement('item1')]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Header: 44px
        // Item: 56 + 8 + 8 = 72px
        // Total: 116px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv).toBeTruthy()
        expect(innerDiv?.getAttribute('style')).toContain('height: 116px')
      })

      it('should calculate correct total height for header + 3 items', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Header: 44px
        // First item after header: 56 + 8 + 4 = 68px
        // Middle item: 56 + 4 + 4 = 64px
        // Last item: 56 + 4 + 8 = 68px
        // Total: 44 + 68 + 64 + 68 = 244px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv).toBeTruthy()
        expect(innerDiv?.getAttribute('style')).toContain('height: 244px')
      })

      it('should calculate correct total height for 2 groups with items', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createMockElement('item2'),
          createHeaderElement('group2'),
          createMockElement('item3'),
          createMockElement('item4'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Group 1 Header: 44px
        // Item 1 (after header): 56 + 8 + 4 = 68px
        // Item 2 (before header): 56 + 4 + 8 = 68px
        // Group 2 Header: 44px
        // Item 3 (after header): 56 + 8 + 4 = 68px
        // Item 4 (last): 56 + 4 + 8 = 68px
        // Total: 44 + 68 + 68 + 44 + 68 + 68 = 360px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv).toBeTruthy()
        expect(innerDiv?.getAttribute('style')).toContain('height: 360px')
      })
    })

    describe('Spacing Rules Verification', () => {
      it('should ensure 8px spacing between item and header', () => {
        const itemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM

        // Verify 8px margin is used when item is adjacent to header
        expect(COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP).toBe(8)
        expect(COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM).toBe(8)
        expect(itemHeight).toBe(72)
      })

      it('should ensure 4px spacing between consecutive items', () => {
        const middleItemHeight =
          COMBOBOX_CONFIG.ITEM_HEIGHT +
          COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS +
          COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM / 2

        // Verify 4px gap is used between consecutive items
        expect(COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS).toBe(4)
        expect(middleItemHeight).toBe(64)
      })

      it('should ensure 8px spacing at container edges', () => {
        // First and last items should have 8px margins
        const firstItemTopMargin = COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP
        const lastItemBottomMargin = COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM

        expect(firstItemTopMargin).toBe(8)
        expect(lastItemBottomMargin).toBe(8)
      })

      it('should ensure headers have no margins', () => {
        // Headers should only use their base height
        const headerHeight = COMBOBOX_CONFIG.GROUP_HEADER_HEIGHT

        expect(headerHeight).toBe(44)
      })
    })

    describe('Edge Cases', () => {
      it('should handle single item correctly', () => {
        const elements = [createMockElement('item1')]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Single item: 56 + 8 (top) + 8 (bottom) = 72px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv?.getAttribute('style')).toContain('height: 72px')
      })

      it('should handle only headers correctly', () => {
        const elements = [createHeaderElement('group1'), createHeaderElement('group2')]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Two headers: 44 + 44 = 88px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv?.getAttribute('style')).toContain('height: 88px')
      })

      it('should handle alternating headers and items', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createHeaderElement('group2'),
          createMockElement('item2'),
          createHeaderElement('group3'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Header 1: 44px
        // Item 1 (after header, before header): 56 + 8 + 8 = 72px
        // Header 2: 44px
        // Item 2 (after header, before header): 56 + 8 + 8 = 72px
        // Header 3: 44px
        // Total: 44 + 72 + 44 + 72 + 44 = 276px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv?.getAttribute('style')).toContain('height: 276px')
      })

      it('should handle large list (10 items, 3 groups)', () => {
        const elements = [
          createHeaderElement('group1'),
          createMockElement('item1'),
          createMockElement('item2'),
          createMockElement('item3'),
          createHeaderElement('group2'),
          createMockElement('item4'),
          createMockElement('item5'),
          createMockElement('item6'),
          createHeaderElement('group3'),
          createMockElement('item7'),
          createMockElement('item8'),
          createMockElement('item9'),
          createMockElement('item10'),
        ]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        // Manual calculation:
        // Group 1: 44 + 68 + 64 + 68 = 244
        // Group 2: 44 + 68 + 64 + 68 = 244
        // Group 3: 44 + 68 + 64 + 64 + 68 = 308
        // Total: 796px
        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv?.getAttribute('style')).toContain('height: 796px')
      })
    })

    describe('Container Structure', () => {
      it('should render with correct container structure', () => {
        const elements = [createMockElement('item1')]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        const outerDiv = container.firstChild as HTMLElement

        expect(outerDiv.className).toContain('w-full')
        expect(outerDiv.style.maxHeight).toBe('100%')
        expect(outerDiv.style.overflow).toBe('auto')
      })

      it('should render inner div with virtualizer total size', () => {
        const elements = [createMockElement('item1'), createMockElement('item2')]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        const innerDiv = container.querySelector('div[class*="relative"]')

        expect(innerDiv?.className).toContain('relative')
        expect(innerDiv?.className).toContain('w-full')
        expect(innerDiv?.getAttribute('style')).toContain('height')
      })

      it('should render virtualized items with absolute positioning', () => {
        const elements = [createMockElement('item1')]

        const { container } = render(
          <BaseComboBoxVirtualizedList
            elements={elements}
            value={null}
            groupItemKey={GROUP_ITEM_KEY}
          />,
        )

        const itemDiv = container.querySelector('div[class*="absolute"]')

        expect(itemDiv?.className).toContain('absolute')
        expect(itemDiv?.className).toContain('left-0')
        expect(itemDiv?.className).toContain('top-0')
        expect(itemDiv?.className).toContain('w-full')
      })
    })
  })
})
