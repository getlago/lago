import { useVirtualizer } from '@tanstack/react-virtual'
import { ReactElement, useEffect, useRef } from 'react'

import { COMBOBOX_CONFIG } from './comboBoxConfig'

type BaseComboBoxVirtualizedListProps = {
  elements: ReactElement[]
  value: unknown
  groupItemKey: string
}

/**
 * Calculate the top margin for an item based on its position and the previous element
 * @param index - The index of the current item
 * @param elements - Array of all elements
 * @param groupItemKey - Key used to identify group headers
 * @returns The margin top value in pixels
 */
export const calculateItemMarginTop = (
  index: number,
  elements: ReactElement[],
  groupItemKey: string,
): number => {
  const element = elements[index]
  const isHeader = (element.key as string)?.includes(groupItemKey)

  // Headers have no margin
  if (isHeader) {
    return 0
  }

  // Check if previous element is a header
  const prevElement = index > 0 ? elements[index - 1] : null
  const prevIsHeader = prevElement ? (prevElement.key as string)?.includes(groupItemKey) : true

  // 8px margin after headers or at start, 4px gap between consecutive items
  return prevIsHeader ? COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP : COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS
}

/**
 * Calculate the bottom margin for an item based on its position and the next element
 * @param index - The index of the current item
 * @param elements - Array of all elements
 * @param groupItemKey - Key used to identify group headers
 * @returns The margin bottom value in pixels
 */
const calculateItemMarginBottom = (
  index: number,
  elements: ReactElement[],
  groupItemKey: string,
): number => {
  const element = elements[index]
  const isHeader = (element.key as string)?.includes(groupItemKey)

  // Headers have no margin
  if (isHeader) {
    return 0
  }

  // Check if next element is a header or if this is the last item
  const nextElement = index < elements.length - 1 ? elements[index + 1] : null
  const nextIsHeader = nextElement ? (nextElement.key as string)?.includes(groupItemKey) : false
  const isLastItem = index === elements.length - 1

  // 8px margin before headers or at end
  if (nextIsHeader || isLastItem) {
    return COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM
  }

  return 0
}

/**
 * Calculate the total height of an item including margins for the virtualizer
 * This includes the item's base height plus top and bottom spacing
 * @param index - The index of the current item
 * @param elements - Array of all elements
 * @param groupItemKey - Key used to identify group headers
 * @returns The total height in pixels
 */
export const getItemHeight = (
  index: number,
  elements: ReactElement[],
  groupItemKey: string,
): number => {
  const element = elements[index]
  const isHeader = (element.key as string)?.includes(groupItemKey)

  // Headers have no padding
  if (isHeader) {
    return COMBOBOX_CONFIG.GROUP_HEADER_HEIGHT
  }

  // Items need to include padding in height calculation for virtualizer
  const prevElement = index > 0 ? elements[index - 1] : null
  const nextElement = index < elements.length - 1 ? elements[index + 1] : null

  const prevIsHeader = prevElement ? (prevElement.key as string)?.includes(groupItemKey) : true
  const nextIsHeader = nextElement ? (nextElement.key as string)?.includes(groupItemKey) : false
  const nextIsItem = !nextIsHeader && nextElement !== null

  const paddingTop = prevIsHeader
    ? COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_TOP
    : COMBOBOX_CONFIG.GAP_BETWEEN_ITEMS
  const paddingBottom = nextIsItem
    ? COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM / 2
    : COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM
  const finalPaddingBottom = nextIsHeader ? COMBOBOX_CONFIG.ITEM_GROUP_MARGIN_BOTTOM : paddingBottom

  return COMBOBOX_CONFIG.ITEM_HEIGHT + paddingTop + finalPaddingBottom
}

export const BaseComboBoxVirtualizedList = ({
  elements,
  value,
  groupItemKey,
}: BaseComboBoxVirtualizedListProps) => {
  const parentRef = useRef<HTMLDivElement>(null)

  const rowVirtualizer = useVirtualizer({
    count: elements.length,
    getScrollElement: () => parentRef.current,
    estimateSize: (index) => getItemHeight(index, elements, groupItemKey),
    overscan: 5,
  })

  useEffect(() => {
    const index = elements.findIndex((el) => el.props?.children?.props?.option?.value === value)

    if (index !== -1) {
      rowVirtualizer.scrollToIndex(index, { align: 'start' })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value])

  const virtualizerTotalSize = rowVirtualizer.getTotalSize()

  return (
    <div
      ref={parentRef}
      className="w-full"
      style={{
        maxHeight: '100%',
        overflow: 'auto',
      }}
    >
      <div
        className="relative w-full"
        style={{
          height: `${virtualizerTotalSize}px`,
        }}
      >
        {rowVirtualizer.getVirtualItems().map((virtualRow) => {
          const element = elements[virtualRow.index]
          const marginTop = calculateItemMarginTop(virtualRow.index, elements, groupItemKey)
          const marginBottom = calculateItemMarginBottom(virtualRow.index, elements, groupItemKey)

          return (
            <div
              key={virtualRow.key}
              ref={rowVirtualizer.measureElement}
              data-index={virtualRow.index}
              className="absolute left-0 top-0 w-full"
              style={{
                transform: `translateY(${virtualRow.start}px)`,
              }}
            >
              <div
                style={{
                  marginTop: `${marginTop}px`,
                  marginBottom: `${marginBottom}px`,
                }}
              >
                {element}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
